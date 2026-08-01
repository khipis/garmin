#!/usr/bin/env python3
"""Drive the running simulator through DAILY SPORT CHALLENGE and grab frames.

Usage: python3 dailysport/_drive.py <outdir> <steps...>
  steps: s = select, b = back, u = up, d = down, . = press nothing and capture,
         q = fast capture (no window focus), wN = wait N tenths of a second
"""
import os
import re
import subprocess
import sys
import time

from PIL import Image

SDK = ("/Users/kkorolczuk/Library/Application Support/Garmin/ConnectIQ/Sdks/"
       "connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b")
DISP_CX, DISP_CY, DISP_R = 0.519, 0.490, 0.372
BTN = {"s": (0.920, 0.331), "b": (0.920, 0.625),
       "u": (0.092, 0.470), "d": (0.092, 0.625)}


_cached = None


def bounds(retries=6):
    """Geometry of the *device* window. The simulator also opens consoles and
    dialogs, and grabbing whichever one happens to be window 1 is how you end
    up with a screenshot of a settings panel."""
    global _cached
    if _cached is not None:
        return _cached
    for _ in range(retries):
        pos = _nums('get position of every window')
        siz = _nums('get size of every window')
        best = None
        for i in range(min(len(pos), len(siz)) // 2):
            x, y = pos[2 * i], pos[2 * i + 1]
            w, h = siz[2 * i], siz[2 * i + 1]
            if h > 480 and 0.5 < w / float(h) < 0.95:
                if best is None or w * h > best[2] * best[3]:
                    best = (x, y, w, h)
        if best is not None:
            _cached = best
            return _cached
        time.sleep(0.8)
    raise SystemExit("simulator device window not found")


def _nums(script):
    out = subprocess.run(
        ["osascript", "-e",
         'tell application "System Events" to tell (first process whose name '
         'contains "simulator") to ' + script],
        capture_output=True, text=True).stdout
    return [int(v) for v in re.findall(r"-?\d+", out)]


def _front():
    out = subprocess.run(
        ["osascript", "-e",
         'tell application "System Events" to get name of first process '
         'whose frontmost is true'],
        capture_output=True, text=True).stdout.strip()
    return out


def focus(tries=8):
    """Raise the device window and confirm it. screencapture grabs a screen
    rect rather than a window, so capturing without confirmed focus silently
    photographs whatever the user happens to have in front."""
    for _ in range(tries):
        # `tell <proc> to (set frontmost to true)` is a syntax error on current
        # System Events; set the property on the process directly instead.
        subprocess.run(["osascript", "-e",
                        'tell application "System Events" to set frontmost of '
                        '(first process whose name contains "simulator") to '
                        'true'], capture_output=True)
        subprocess.run(["osascript", "-e",
                        'tell application "System Events" to tell (first '
                        'process whose name contains "simulator") to perform '
                        'action "AXRaise" of window 1'], capture_output=True)
        time.sleep(0.35)
        if "simulator" in _front().lower():
            return
    raise SystemExit("could not raise the simulator window (front: %s)"
                     % _front())


def press(step):
    x, y, w, h = bounds()
    fx, fy = BTN[step]
    subprocess.run(["cliclick", "c:%d,%d" % (int(x + w * fx), int(y + h * fy))],
                   capture_output=True)


def shot(path):
    # Re-focus every frame: screencapture grabs a screen rect, not a window,
    # so anything the user brings to the front would end up in the shot.
    focus()
    x, y, w, h = bounds()
    subprocess.run(["screencapture", "-x", "-R%d,%d,%d,%d" % (x, y, w, h), path],
                   capture_output=True)
    im = Image.open(path)
    W, H = im.size
    cx, cy, r = int(DISP_CX * W), int(DISP_CY * H), int(DISP_R * W)
    im.crop((cx - r, cy - r, cx + r, cy + r)).save(path)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    focus()
    i = 0
    for step in sys.argv[2:]:
        if step.startswith("w"):
            time.sleep(int(step[1:]) / 10.0)
            continue
        if step in BTN:
            press(step)
            time.sleep(0.3)
        shot("%s/%02d_%s.png" % (out, i, step))
        i += 1
    print("frames:", i)


main()
