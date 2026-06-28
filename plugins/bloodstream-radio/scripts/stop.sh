#!/usr/bin/env bash
# Stop BloodStream Radio playback.
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Stop the poller first (independent of player state) and clear the cache.
if poller_running; then
  kill "$(cat "$POLLER_PID_FILE")" 2>/dev/null
fi
rm -f "$POLLER_PID_FILE" "$NOWPLAYING_CACHE"

if ! is_running; then
  rm -f "$PID_FILE"
  echo "Nothing playing."
  exit 0
fi

pid="$(cat "$PID_FILE")"
kill "$pid" 2>/dev/null
rm -f "$PID_FILE"
echo "Stopped BloodStream Radio."
