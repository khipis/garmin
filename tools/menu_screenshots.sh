#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# menu_screenshots.sh — Capture unified-menu screenshots from the CIQ simulator.
#
# For each game it:
#   1. side-loads the built .prg into the ALREADY-RUNNING simulator (monkeydo)
#   2. dismisses the launch "tip" overlay with a key press
#   3. optionally sends extra navigation keys (e.g. to open OPTIONS)
#   4. grabs the simulator window with macOS `screencapture`
#
# Prereqs:
#   • The ConnectIQ simulator must be running:  "$SDK/bin/connectiq" &
#   • macOS Screen-Recording permission for the terminal running this script.
#
# Usage:
#   tools/menu_screenshots.sh                # build + shoot the pilot set
#   DEVICE=fr965 tools/menu_screenshots.sh   # different device
#
# Output: unified_menu/<label>.png
# ═══════════════════════════════════════════════════════════════════════════
set -u

SDK="${SDK:-/Users/kkorolczuk/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b}"
DEVICE="${DEVICE:-fenix8solar51mm}"
KEYDER="${KEYDER:-developer_key.der}"
ROOT="$( cd "$( dirname "$0" )/.." && pwd )"
OUT="$ROOT/unified_menu"
TMP="${TMPDIR:-/tmp}"
mkdir -p "$OUT"

# Key codes (macOS virtual keycodes) → simulator device buttons.
K_RETURN=36   # START / ENTER / dismiss overlay
K_DOWN=125    # DOWN button  (menu: move selection down)
K_UP=126      # UP button
K_ESC=53      # BACK

SIM_APP="$SDK/bin/ConnectIQ.app"

# Raising the sim by `set frontmost` proved unreliable while another app (an
# editor) sits over the same screen area; `open -a` on the bundle reliably puts
# the sim on top, which is required both for cliclick input AND for a correct
# region screencapture (which grabs whatever is topmost at the coords).
focus_sim() { open -a "$SIM_APP" >/dev/null 2>&1; sleep 0.8; }

win_bounds() { # echoes: x y w h
    local b
    b=$(osascript -e 'tell application "System Events" to tell (first process whose name contains "simulator") to get {position, size} of window 1' 2>/dev/null)
    echo "$b" | awk -F', *' '{print $1, $2, $3, $4}'
}

capture() { # $1 = output png
    focus_sim
    local x y w h; read -r x y w h < <(win_bounds)
    if [ -z "$x" ]; then echo "  ! could not read window bounds"; return 1; fi
    screencapture -x -R"$x,$y,$w,$h" "$1"
    echo "  → $1"
}

# fenix is a BUTTON device (no touchscreen): the on-screen BEZEL buttons are
# clickable GUI elements, so drive the UI by clicking them with cliclick.
# Button positions as fractions of the sim window box (constant for this device):
#   DOWN   = bottom-left bezel button   (moves menu selection down)
#   SELECT = top-right bezel button     (activates the selected row)
btn() { # $1=fraction-x  $2=fraction-y
    local x y w h; read -r x y w h < <(win_bounds)
    if [ -z "$x" ]; then return 1; fi
    local cx cy
    cx=$(awk -v x="$x" -v w="$w" -v f="$1" 'BEGIN{printf "%d", x + w*f}')
    cy=$(awk -v y="$y" -v h="$h" -v f="$2" 'BEGIN{printf "%d", y + h*f}')
    cliclick "c:${cx},${cy}" >/dev/null 2>&1
}
btn_down()   { btn 0.092 0.625; }
btn_select() { btn 0.920 0.331; }

restart_sim() {
    # The sim degrades after many rapid load/kill cycles and starts serving the
    # "loading" screen instead of the app. A full relaunch per game is the only
    # reliable cure, and the window reopens at the same position.
    pkill -f monkeydo >/dev/null 2>&1
    pkill -9 -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null 2>&1
    sleep 2
    "$SDK/bin/connectiq" >"$TMP/ciq.log" 2>&1 &
    sleep 8
}

load() { # $1=prg — relaunch the sim, side-load, wait for the app to come up
    restart_sim
    "$SDK/bin/monkeydo" "$1" "$DEVICE" >"$TMP/md.log" 2>&1 &
    sleep 12
}

shoot() { # $1=prg  $2=app
    local prg="$1"; local app="$2"
    echo "== $app =="
    load "$prg"                               # launch cards are suppressed in this build
    capture "$OUT/${app}_menu.png"            # menu (START selected by default)
    focus_sim; btn_down; sleep 0.7; btn_select; sleep 1.2   # START → OPTIONS → open
    capture "$OUT/${app}_options.png"
}

build() { # $1=app folder  $2=out prg
    echo "-- building $1"
    "$SDK/bin/monkeyc" -o "$2" -f "$ROOT/$1/monkey.jungle" -y "$ROOT/$KEYDER" -d "$DEVICE" -l 0 \
        >"$TMP/build_$1.log" 2>&1
    if [ $? -ne 0 ]; then echo "  BUILD FAILED ($1):"; tail -6 "$TMP/build_$1.log"; return 1; fi
}

# ── Pilot set: one game per architecture family ──────────────────────────────
PILOTS="pongpro blobs tic_tac_pro"
for app in ${APPS:-$PILOTS}; do
    prg="$TMP/$app.prg"
    build "$app" "$prg" || continue
    shoot "$prg" "$app"
done

echo "Done. Screenshots in: $OUT"
