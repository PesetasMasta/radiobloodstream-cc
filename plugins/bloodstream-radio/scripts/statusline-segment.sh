#!/usr/bin/env bash
# Print the BloodStream Radio statusline segment, or nothing.
# Pure-local: reads the cache written by nowplaying-poller.sh. No network.
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Only show while the player is actually running.
is_running || exit 0
# And only if the cache is fresh (guards against a crashed poller).
[ -f "$NOWPLAYING_CACHE" ] || exit 0

# Freshness: cache mtime within 90s. Portable mtime (BSD stat then GNU stat).
now_epoch="$(date +%s)"
mtime="$(stat -f %m "$NOWPLAYING_CACHE" 2>/dev/null || stat -c %Y "$NOWPLAYING_CACHE" 2>/dev/null)"
[ -n "$mtime" ] || exit 0
[ "$((now_epoch - mtime))" -lt 90 ] || exit 0

line="$(cat "$NOWPLAYING_CACHE")"
title="${line%%$'\t'*}"
listeners="${line#*$'\t'}"

if [ -z "$title" ]; then
  printf '🩸'
  exit 0
fi

if [ "$SHOW_LISTENERS" = "1" ] && [ -n "$listeners" ] && [ "$listeners" -gt 0 ] 2>/dev/null; then
  printf '🩸 %s · %s' "$title" "$listeners"
else
  printf '🩸 %s' "$title"
fi
