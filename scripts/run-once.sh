#!/bin/bash
# Run /process-replies once, headlessly, and append the summary to logs/.
# Called by the launchd poller (scripts/poll.sh). Also handy on its own to
# test the pipeline or catch up by hand.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

if [ -f .env ]; then
  set -a; source .env; set +a
fi

mkdir -p logs
LOG=logs/process-replies.log

run() {
  echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  claude -p "/process-replies"
  echo
}

# Show output when run by hand; just log it when launchd runs it.
if [ -t 1 ]; then run 2>&1 | tee -a "$LOG"; else run >> "$LOG" 2>&1; fi
