#!/bin/bash
# Drive the running CIQ simulator with a button sequence and grab a frame after
# every step. Usage: shot_seq.sh <prg> <name> <seq>
# seq letters: S=select/start  D=down  U=up  B=back  .=just capture
set -u
SDK="${SDK:-/Users/kkorolczuk/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b}"
DEVICE="${DEVICE:-fenix8solar51mm}"
ROOT="$( cd "$( dirname "$0" )/.." && pwd )"
OUT="${OUT:-$ROOT/tools/idle_out}"
mkdir -p "$OUT"
SIM_APP="$SDK/bin/ConnectIQ.app"

PRG="$1"; NAME="$2"; SEQ="$3"

focus_sim() { open -a "$SIM_APP" >/dev/null 2>&1; sleep 0.5; }
win_bounds() {
    osascript -e 'tell application "System Events" to tell (first process whose name contains "simulator") to get {position, size} of window 1' 2>/dev/null \
      | awk -F', *' '{print $1, $2, $3, $4}'
}
press() { # $1=xfrac $2=yfrac
    local x y w h; read -r x y w h < <(win_bounds)
    [ -z "$x" ] && return 1
    local cx cy
    cx=$(awk -v x="$x" -v w="$w" -v f="$1" 'BEGIN{printf "%d", x + w*f}')
    cy=$(awk -v y="$y" -v h="$h" -v f="$2" 'BEGIN{printf "%d", y + h*f}')
    cliclick "c:${cx},${cy}" >/dev/null 2>&1
}
hold() { # $1=xfrac $2=yfrac — long press (shared name entry saves on hold)
    local x y w h; read -r x y w h < <(win_bounds)
    [ -z "$x" ] && return 1
    local cx cy
    cx=$(awk -v x="$x" -v w="$w" -v f="$1" 'BEGIN{printf "%d", x + w*f}')
    cy=$(awk -v y="$y" -v h="$h" -v f="$2" 'BEGIN{printf "%d", y + h*f}')
    cliclick "dd:${cx},${cy}" "w:1600" "du:${cx},${cy}" >/dev/null 2>&1
}
capture() {
    local x y w h; read -r x y w h < <(win_bounds)
    [ -z "$x" ] && { echo "  ! no window"; return 1; }
    screencapture -x -R"$x,$y,$w,$h" "$1"
}

restart_sim() {
    pkill -f monkeydo >/dev/null 2>&1
    pkill -9 -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null 2>&1
    sleep 2
    "$SDK/bin/connectiq" >/tmp/ciq.log 2>&1 &
    sleep 9
    "$SDK/bin/monkeydo" "$PRG" "$DEVICE" >/tmp/md.log 2>&1 &
    sleep 13
}

if [ "${RESTART:-1}" = "1" ]; then
    restart_sim
    focus_sim
    # The shared daily-challenge splash eats the first key press.
    press 0.920 0.331; sleep 1.2
fi
focus_sim

i=0
for (( k=0; k<${#SEQ}; k++ )); do
    c="${SEQ:$k:1}"
    focus_sim
    case "$c" in
        S) press 0.920 0.331 ;;
        D) press 0.092 0.625 ;;
        U) press 0.092 0.470 ;;
        B) press 0.920 0.625 ;;
        H) hold 0.920 0.331 ;;
        .) : ;;
    esac
    sleep 1.0
    capture "$OUT/${NAME}_$(printf '%02d' $i).png"
    i=$((i+1))
done
echo "Done -> $OUT/${NAME}_*.png"
