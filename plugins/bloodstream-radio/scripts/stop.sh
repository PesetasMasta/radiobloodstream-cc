#!/usr/bin/env bash
# Stop BloodStream Radio playback.
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! is_running; then
  rm -f "$PID_FILE"
  echo "Nothing playing."
  exit 0
fi

pid="$(cat "$PID_FILE")"
kill "$pid" 2>/dev/null
rm -f "$PID_FILE"
echo "Stopped BloodStream Radio."
