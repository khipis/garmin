#!/usr/bin/env bash
# Loops upload --rm-on-success until _STORE/*.iq is empty.
# New .iq files added by another agent are picked up each iteration.
# Stops when the folder is empty OR when nothing changes across two consecutive
# runs (all remaining files lack an appId → they can't be uploaded).

set -euo pipefail
STORE_DIR="$(cd "$(dirname "$0")/../_STORE" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

prev_slugs=""
stall=0

while true; do
  # Collect slugs currently in _STORE
  slugs=$(ls "$STORE_DIR"/*.iq 2>/dev/null | xargs -I{} basename {} .iq | sort | tr '\n' ',' | sed 's/,$//')

  if [ -z "$slugs" ]; then
    echo ""
    echo "=== _STORE is empty — all done ==="
    break
  fi

  echo ""
  echo ">>> _STORE files: $slugs"
  echo ">>> $(date '+%H:%M:%S') — running upload --rm-on-success ..."

  # Run upload for the current batch; always --rm-on-success so each
  # successful publish removes the file immediately.
  (cd "$SCRIPT_DIR" && node index.mjs upload --rm-on-success) || true

  # Check what is STILL in _STORE after the run
  remaining=$(ls "$STORE_DIR"/*.iq 2>/dev/null | xargs -I{} basename {} .iq | sort | tr '\n' ',' | sed 's/,$//' || true)

  if [ -z "$remaining" ]; then
    echo ""
    echo "=== _STORE is empty — all done ==="
    break
  fi

  # Detect stall: same files left as before (unmatched / no appId)
  if [ "$remaining" = "$prev_slugs" ]; then
    stall=$((stall + 1))
    if [ "$stall" -ge 3 ]; then
      echo ""
      echo "=== Stalled for 3 rounds — remaining files have no appId in config: $remaining ==="
      echo "=== Waiting 60 s before retrying (another agent may update config) ==="
      sleep 60
      stall=0
    else
      echo ">>> No change (stall $stall/3), waiting 30 s for new builds..."
      sleep 30
    fi
  else
    stall=0
    echo ">>> Some files remain ($remaining), re-running immediately..."
  fi

  prev_slugs="$remaining"
done
