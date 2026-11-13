#!/bin/bash
# Run /process-replies on an interval in the background (macOS launchd).
#
#   scripts/poll.sh start [seconds]   default 600 (10 min); use 30 for a live demo
#   scripts/poll.sh stop
#   scripts/poll.sh status
#
# Polling is off until you start it. Each tick is a full Claude run, so stop it
# when you're done.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="com.cadence-demo.process-replies"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

write_plist() {
  local interval="$1" claude_bin
  claude_bin="$(command -v claude)" || { echo "claude not found on PATH" >&2; exit 1; }
  mkdir -p "$REPO/logs" "$(dirname "$PLIST")"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$REPO/scripts/run-once.sh</string></array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>$(dirname "$claude_bin"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
  <key>StartInterval</key><integer>$interval</integer>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$REPO/logs/launchd.out.log</string>
  <key>StandardErrorPath</key><string>$REPO/logs/launchd.err.log</string>
</dict>
</plist>
EOF
}

case "${1:-}" in
  start)
    interval="${2:-600}"
    write_plist "$interval"
    launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
    launchctl bootstrap "$DOMAIN" "$PLIST"
    echo "Polling ON: every ${interval}s. Stop with: scripts/poll.sh stop"
    ;;
  stop)
    launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
    echo "Polling OFF."
    ;;
  status)
    if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
      echo "Polling ON: every $(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "$PLIST")s."
    else
      echo "Polling OFF."
    fi
    ;;
  *)
    echo "Usage: $0 start [seconds] | stop | status" >&2
    exit 1
    ;;
esac
