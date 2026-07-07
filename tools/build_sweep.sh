#!/bin/bash
# Build every game that was converted to the unified menu; report PASS/FAIL.
SDK="${SDK:-/Users/kkorolczuk/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b}"
DEVICE="${DEVICE:-fenix8solar51mm}"
ROOT="$( cd "$( dirname "$0" )/.." && pwd )"
cd "$ROOT" || exit 1

GAMES="pongpro blobs tic_tac_pro \
akari archery battleship chickencross diceroyale drwal flappypidgeon gemmatch \
gyromaze hangman hologrid jumptower lightsout manpac minesweeper pinballpro \
pixelinvaders skyroll slotbandit sniperscope stacktower starcombat starswarm sudoku twentyfortyeight voidrocks \
connect_four_lite dots_boxes edgesurvivor gobblet_mini hex_mini makao_lite morris_classic othello_blitz territory_clash \
arcade billiards blackjack blocks bomb boxing bricks catapult checkers chess \
dinosaur fish jazzball memo minigolf moon parachute poker run serpent skijump solitare"

pass=0; fail=0; fails=""
for app in $GAMES; do
    if [ ! -f "$app/monkey.jungle" ]; then echo "SKIP $app (no jungle)"; continue; fi
    out="/tmp/sweep_$app.prg"
    log="/tmp/sweep_$app.log"
    if "$SDK/bin/monkeyc" -o "$out" -f "$app/monkey.jungle" -y developer_key.der -d "$DEVICE" -l 0 >"$log" 2>&1; then
        echo "PASS $app"; pass=$((pass+1))
    else
        echo "FAIL $app"; fail=$((fail+1)); fails="$fails $app"
    fi
done
echo "──────────────────────────"
echo "PASS=$pass FAIL=$fail"
[ -n "$fails" ] && echo "FAILED:$fails"
