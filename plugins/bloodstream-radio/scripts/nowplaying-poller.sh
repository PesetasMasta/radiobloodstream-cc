#!/usr/bin/env bash
# Background poller: refresh the now-playing cache while the player runs.
# shellcheck source=lib.sh
dir="$(dirname "${BASH_SOURCE[0]}")"
. "$dir/lib.sh"
# shellcheck source=now.sh
. "$dir/now.sh"

# Fetch the raw status JSON. Overridable in tests via a redefinition.
bsr_fetch_status() {
  curl -s -m 8 "$STATUS_URL"
}

# One refresh: fetch -> current_status -> cache. Failed fetch leaves prior cache.
poller_tick() {
  local json line
  json="$(bsr_fetch_status)" || return 0
  [ -n "$json" ] || return 0
  line="$(printf '%s' "$json" | current_status)"
  printf '%s\n' "$line" > "$NOWPLAYING_CACHE"
}

# Loop only when executed directly (so tests can source poller_tick).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  while is_running; do
    poller_tick
    sleep "$POLL_INTERVAL"
  done
fi
