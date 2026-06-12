#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# reset-stats.sh — wipe ALL leaderboard statistics.
#
# Every leaderboard and player stat on bitochi.com is computed live from the
# `scores` table, so deleting all rows resets the entire system to zero. Use it
# for a full reset, or as a periodic (e.g. monthly) season wipe.
#
# Usage:
#   ./reset-stats.sh                  # PRODUCTION (remote) wipe — asks to confirm
#   ./reset-stats.sh --local          # target the local dev DB instead
#   ./reset-stats.sh --backup         # export a timestamped backup first
#   ./reset-stats.sh --yes            # skip the interactive confirmation
#   ./reset-stats.sh --game serpent   # wipe ONE game only (keeps the rest)
#   ./reset-stats.sh --backup --yes   # typical monthly-cron invocation
#
# Flags combine freely. Requires `wrangler` (run via npx) and Cloudflare auth
# (CLOUDFLARE_API_TOKEN env var, or run `npx wrangler login` once).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DB="bitochi-leaderboard"
cd "$(dirname "$0")"          # run from leaderboard/ so wrangler.toml is found

REMOTE="--remote"
ENVLABEL="PRODUCTION (remote)"
DO_BACKUP=0
ASSUME_YES=0
GAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --local)   REMOTE="--local"; ENVLABEL="LOCAL dev" ;;
    --backup)  DO_BACKUP=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    --game)    shift; GAME="${1:-}"; [ -n "$GAME" ] || { echo "--game needs a value"; exit 2; } ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# Build the WHERE clause + a human label for the scope of the wipe.
if [ -n "$GAME" ]; then
  WHERE="WHERE game = '$(printf '%s' "$GAME" | sed "s/'/''/g")'"
  SCOPE="game '$GAME'"
else
  WHERE=""
  SCOPE="ALL games"
fi

echo "Target DB  : $DB"
echo "Environment: $ENVLABEL"
echo "Scope      : $SCOPE"

# ── Optional backup (full DB dump) ──────────────────────────────────────────
if [ "$DO_BACKUP" = "1" ]; then
  TS="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT="backup-scores-$TS.sql"
  echo "Backing up full database to $OUT ..."
  npx wrangler d1 export "$DB" $REMOTE --output "$OUT"
  echo "Backup saved: $OUT"
fi

# ── Confirmation guard ──────────────────────────────────────────────────────
if [ "$ASSUME_YES" != "1" ]; then
  echo
  echo "This DELETES $SCOPE from 'scores' on $ENVLABEL."
  echo "Every affected leaderboard / player stat resets to zero."
  echo "This cannot be undone (unless you used --backup)."
  printf "Type the database name to confirm (%s): " "$DB"
  read -r CONFIRM
  if [ "$CONFIRM" != "$DB" ]; then
    echo "Aborted — nothing was deleted."
    exit 1
  fi
fi

# ── Wipe ────────────────────────────────────────────────────────────────────
echo "Wiping scores ($SCOPE) ..."
npx wrangler d1 execute "$DB" $REMOTE --command "DELETE FROM scores $WHERE;"

# Reset the AUTOINCREMENT id counter on a full wipe (best-effort, cosmetic).
if [ -z "$GAME" ]; then
  npx wrangler d1 execute "$DB" $REMOTE \
    --command "DELETE FROM sqlite_sequence WHERE name='scores';" || true
fi

echo "Done. Leaderboard stats reset to zero for: $SCOPE."
