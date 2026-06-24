#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# reset-stats.sh — wipe ALL leaderboard statistics.
#
# Every leaderboard and player stat on bitochi.com is computed live from the
# `scores` table, so deleting all rows resets the entire system to zero. Use it
# for a full reset, or as a periodic (e.g. monthly) season wipe.
#
# Before the wipe, a snapshot is automatically saved to the `snapshots` D1
# table so all retention / engagement metrics survive the reset and remain
# visible in the admin stats.html under "Season history".
# Requires LB_KEY env var for the snapshot (exported as env var, or set inline).
#
# Usage:
#   ./reset-stats.sh                  # PRODUCTION (remote) wipe — asks to confirm
#   ./reset-stats.sh --local          # target the local dev DB instead
#   ./reset-stats.sh --backup         # export a timestamped backup first
#   ./reset-stats.sh --yes            # skip the interactive confirmation
#   ./reset-stats.sh --game serpent   # wipe ONE game only (keeps the rest)
#   ./reset-stats.sh --no-snapshot    # skip the automatic pre-wipe snapshot
#   ./reset-stats.sh --hof            # promote current #1s to Hall of Fame before wipe
#   ./reset-stats.sh --backup --hof --yes  # typical monthly-cron invocation
#
# Flags combine freely. Requires `wrangler` (run via npx) and Cloudflare auth
# (CLOUDFLARE_API_TOKEN env var, or run `npx wrangler login` once).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DB="bitochi-leaderboard"
API="https://api.bitochi.com"
cd "$(dirname "$0")"          # run from leaderboard/ so wrangler.toml is found

REMOTE="--remote"
ENVLABEL="PRODUCTION (remote)"
DO_BACKUP=0
ASSUME_YES=0
GAME=""
DO_SNAPSHOT=1
DO_HOF=0

while [ $# -gt 0 ]; do
  case "$1" in
    --local)        REMOTE="--local"; ENVLABEL="LOCAL dev" ;;
    --backup)       DO_BACKUP=1 ;;
    --yes|-y)       ASSUME_YES=1 ;;
    --no-snapshot)  DO_SNAPSHOT=0 ;;
    --hof)          DO_HOF=1 ;;
    --game)         shift; GAME="${1:-}"; [ -n "$GAME" ] || { echo "--game needs a value"; exit 2; } ;;
    -h|--help)      sed -n '2,29p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# Build the WHERE clause + a human label for the scope of the wipe.
if [ -n "$GAME" ]; then
  WHERE="WHERE game = '$(printf '%s' "$GAME" | sed "s/'/''/g")'"
  SCOPE="game '$GAME'"
  SNAP_LABEL="${GAME}-$(date -u +%Y-%m)"
else
  WHERE=""
  SCOPE="ALL games"
  SNAP_LABEL="season-$(date -u +%Y-%m)"
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

# ── Pre-wipe snapshot ────────────────────────────────────────────────────────
# Saves current season stats permanently so they survive the scores deletion.
# Requires LB_KEY env var (same key used by watch apps to submit scores).
if [ "$DO_SNAPSHOT" = "1" ] && [ "$REMOTE" = "--remote" ]; then
  if [ -n "${LB_KEY:-}" ]; then
    echo "Saving season snapshot (label: $SNAP_LABEL) ..."
    SNAP_RESP=$(curl -s -X POST "$API/snapshot" \
      -H "Content-Type: application/json" \
      -H "X-LB-Key: $LB_KEY" \
      -d "{\"label\": \"$SNAP_LABEL\"}" 2>/dev/null || echo '{"ok":false}')
    echo "  Snapshot response: $SNAP_RESP"
  else
    echo "⚠️  Warning: LB_KEY not set — skipping pre-reset snapshot."
    echo "   Set LB_KEY env var to preserve season stats: export LB_KEY=yourkey"
    echo "   Or use --no-snapshot to silence this warning."
  fi
fi

# ── Pre-wipe Hall of Fame promotion ─────────────────────────────────────────
# Promotes current #1 per game/variant to the Hall of Fame before the wipe.
# Requires LB_KEY env var. Only runs if --hof flag was passed.
if [ "$DO_HOF" = "1" ] && [ "$REMOTE" = "--remote" ]; then
  if [ -n "${LB_KEY:-}" ]; then
    HOF_NOTE="${SNAP_LABEL}"
    echo "Promoting current leaders to Hall of Fame (note: $HOF_NOTE) ..."
    HOF_RESP=$(curl -s -X POST "$API/hof" \
      -H "Content-Type: application/json" \
      -H "X-LB-Key: $LB_KEY" \
      -d "{\"promote\": true, \"note\": \"$HOF_NOTE\"}" 2>/dev/null || echo '{"ok":false}')
    echo "  HoF response: $HOF_RESP"
  else
    echo "⚠️  Warning: LB_KEY not set — skipping Hall of Fame promotion."
    echo "   Set LB_KEY env var: export LB_KEY=yourkey"
  fi
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
