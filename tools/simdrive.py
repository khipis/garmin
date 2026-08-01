#!/usr/bin/env python3
"""Drive the running Connect IQ simulator by watch-relative coordinates.

The simulator window holds a round display whose centre and radius were measured
once against the fenix8 bezel art; everything here is expressed as a fraction of
the watch face so the same script works whatever the window is dragged to.
"""
import os
import re
import subprocess
import sys
import time

from PIL import Image

DISP_CX, DISP_CY, DISP_R = 0.519, 0.490, 0.372   # fractions of window width/height
BTN = {                                          # bezel buttons, window fractions
    "select": (0.920, 0.331),
    "back":   (0.920, 0.625),
    "up":     (0.092, 0.470),
    "down":   (0.092, 0.625),
}


def bounds():
    out = subprocess.run(
        ["osascript", "-e",
         'tell application "System Events" to tell (first process whose name '
         'contains "simulator") to get {position, size} of window 1'],
        capture_output=True, text=True).stdout
    n = [int(v) for v in re.findall(r"-?\d+", out)]
    if len(n) < 4:
        raise SystemExit("simulator window not found")
    return n[0], n[1], n[2], n[3]


def focus():
    sdk = os.environ.get("SDK", "/Users/kkorolczuk/Library/Application Support/"
                         "Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b")
    subprocess.run(["open", "-a", sdk + "/bin/ConnectIQ.app"],
                   capture_output=True)
    time.sleep(0.4)


def click(sx, sy):
    subprocess.run(["cliclick", "c:%d,%d" % (sx, sy)], capture_output=True)


def button(name):
    x, y, w, h = bounds()
    fx, fy = BTN[name]
    click(int(x + w * fx), int(y + h * fy))


def tap(fx, fy):
    """Tap a point given as a fraction of the round watch display."""
    x, y, w, h = bounds()
    sx = x + w * DISP_CX + (fx - 0.5) * 2 * (w * DISP_R)
    sy = y + h * DISP_CY + (fy - 0.5) * 2 * (w * DISP_R)
    click(int(sx), int(sy))


def shot(path):
    x, y, w, h = bounds()
    subprocess.run(["screencapture", "-x", "-R%d,%d,%d,%d" % (x, y, w, h), path],
                   capture_output=True)
    im = Image.open(path)
    W, H = im.size
    cx, cy, r = int(DISP_CX * W), int(DISP_CY * H), int(DISP_R * W)
    im.crop((cx - r, cy - r, cx + r, cy + r)).save(path)


def run(steps, outdir, name):
    os.makedirs(outdir, exist_ok=True)
    for i, s in enumerate(steps):
        focus()
        if s in BTN:
            button(s)
        elif s.startswith("tab"):
            k, n = (int(v) for v in s[3:].split("/"))
            tap(0.5 + (k - (n - 1) / 2.0) * 0.09, 0.14)
        elif s.startswith("tap"):
            fx, fy = (float(v) for v in s[3:].split(","))
            tap(fx, fy)
        time.sleep(1.0)
        shot("%s/%s_%02d.png" % (outdir, name, i))


def sheet(outdir, name, cols=5, size=260):
    import glob
    fs = sorted(glob.glob("%s/%s_*.png" % (outdir, name)))
    ims = [Image.open(f).resize((size, size)) for f in fs]
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGB", (cols * (size + 6), rows * (size + 6)), (18, 18, 18))
    for i, im in enumerate(ims):
        out.paste(im, ((i % cols) * (size + 6) + 3, (i // cols) * (size + 6) + 3))
    p = "/tmp/%s_sheet.png" % name
    out.save(p)
    return p


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "run":
        run(sys.argv[4:], sys.argv[2], sys.argv[3])
    elif mode == "sheet":
        print(sheet(sys.argv[2], sys.argv[3]))
