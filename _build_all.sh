#!/bin/bash
SDK="/Users/kkorolczuk/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
BASE="/Users/kkorolczuk/work/garmin"
KEY="$BASE/developer_key.der"
OLD_KEY="$BASE/developer_key_old.der"
PROD="$BASE/_PROD"
STORE="$BASE/_STORE"
DEV="fenix8solar51mm"

OLD_KEY_APPS="solitare intervalbeeper fakenotificationescape"

APPS=(
  8ball
  adhddecider
  angrypomodoro
  arcade
  blackjack
  blobs
  blocks
  bomb
  boxing
  bricks
  catapult
  checkers
  chess
  diveboatmodeplanner
  divegasblender
  diveplantoolkit
  divepreparationchecker
  divequickcalculator
  divercommunicator
  diveriskindicator
  divesafetytoolkit
  droneflightchecker
  fakenotificationescape
  fish
  fishingbitepredictor
  breathtrainingtool
  breathtrainingsystem
  cellwars
  dinosaur
  shadowclonerunner
  edgesurvivor
  mini_go_9x9
  othello_blitz
  tic_tac_pro
  intervalbeeper
  jazzball
  minigolf
  moon
  parachute
  pets
  poker
  recoverytimer
  run
  serpent
  skijump
  solitare
  timer
)

FILTER=""
MODE="both"
if [ -n "$1" ]; then
  if [ "$1" = "prod" ] || [ "$1" = "store" ] || [ "$1" = "both" ]; then
    MODE="$1"
  else
    FILTER="$1"
  fi
fi
if [ -n "$2" ]; then
  if [ "$2" = "prod" ] || [ "$2" = "store" ] || [ "$2" = "both" ]; then
    MODE="$2"
  fi
fi
FAIL=0

for app in "${APPS[@]}"; do
  if [ -n "$FILTER" ] && [ "$app" != "$FILTER" ]; then continue; fi
  jungle="$BASE/$app/monkey.jungle"
  if [ ! -f "$jungle" ]; then
    echo "SKIP $app (no monkey.jungle)"
    continue
  fi

  APP_KEY="$KEY"
  if echo "$OLD_KEY_APPS" | grep -qw "$app"; then
    APP_KEY="$OLD_KEY"
  fi

  if [ "$MODE" = "prod" ] || [ "$MODE" = "both" ]; then
    echo -n "PROD $app ... "
    if "$SDK/bin/monkeyc" -o "$PROD/$app.prg" -f "$jungle" -y "$APP_KEY" -d "$DEV" -l 0 >/dev/null 2>&1; then echo "BUILD SUCCESSFUL"; else echo "BUILD FAILED"; FAIL=1; fi
  fi

  if [ "$MODE" = "store" ] || [ "$MODE" = "both" ]; then
    echo -n "STORE $app ... "
    if "$SDK/bin/monkeyc" -o "$STORE/$app.iq" -f "$jungle" -y "$APP_KEY" -e -r -l 0 >/dev/null 2>&1; then echo "BUILD SUCCESSFUL"; else echo "BUILD FAILED"; FAIL=1; fi
  fi
done

echo "=== BUILD COMPLETE ==="
