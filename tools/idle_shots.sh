#!/bin/bash
# Capture the HOME/main scene (and a couple of option pages) of the idle games
# from the already-running CIQ simulator.
set -u
SDK="${SDK:-/Users/kkorolczuk/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b}"
DEVICE="${DEVICE:-fenix8solar51mm}"
KEYDER="${KEYDER:-developer_key.der}"
ROOT="$( cd "$( dirname "$0" )/.." && pwd )"
OUT="$ROOT/tools/idle_out"
TMP="${TMPDIR:-/tmp}"
mkdir -p "$OUT"
SIM_APP="$SDK/bin/ConnectIQ.app"

focus_sim() { open -a "$SIM_APP" >/dev/null 2>&1; sleep 0.8; }
win_bounds() {
    local b
    b=$(osascript -e 'tell application "System Events" to tell (first process whose name contains "simulator") to get {position, size} of window 1' 2>/dev/null)
    echo "$b" | awk -F', *' '{print $1, $2, $3, $4}'
}
capture() {
    focus_sim
    local x y w h; read -r x y w h < <(win_bounds)
    if [ -z "$x" ]; then echo "  ! no window bounds"; return 1; fi
    screencapture -x -R"$x,$y,$w,$h" "$1"
    echo "  -> $1"
}
btn() {
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
    pkill -f monkeydo >/dev/null 2>&1
    pkill -9 -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null 2>&1
    sleep 2
    "$SDK/bin/connectiq" >"$TMP/ciq.log" 2>&1 &
    sleep 8
}
load() {
    restart_sim
    "$SDK/bin/monkeydo" "$1" "$DEVICE" >"$TMP/md.log" 2>&1 &
    sleep 12
}

shoot() { # $1=prg $2=app
    local prg="$1"; local app="$2"
    echo "== $app =="
    load "$prg"
    focus_sim; btn_select; sleep 1.5           # PLAY -> enter game
    # Burst: DOWN dismisses overlays on the first press without navigating, then
    # pages forward. Capture every step so we can pick HOME + each option page.
    local i
    for i in 0 1 2 3 4 5 6; do
        capture "$OUT/${app}_$(printf '%02d' $i).png"
        focus_sim; btn_down; sleep 0.9
    done
}

for app in ${APPS:-island}; do
    shoot "$ROOT/_PROD/$app.prg" "$app"
done
echo "Done -> $OUT"
