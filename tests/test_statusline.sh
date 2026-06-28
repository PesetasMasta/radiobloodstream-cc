#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/assert.sh"
seg="$here/../plugins/bloodstream-radio/scripts/statusline-segment.sh"

export BSR_PID_FILE="$(mktemp -u)"
export BSR_NOWPLAYING_CACHE="$(mktemp)"
chmod +x "$here/fake-player.sh"

# Not running -> empty output, regardless of cache.
printf 'Some Song\t9\n' > "$BSR_NOWPLAYING_CACHE"
assert_eq "$(bash "$seg")" "" "not running -> empty"

# Start a fake player so is_running is true.
"$here/fake-player.sh" & echo $! > "$BSR_PID_FILE"

# Running + fresh non-empty cache -> drop + title + listeners.
out="$(bash "$seg")"
assert_contains "$out" "🩸" "has drop"
assert_contains "$out" "Some Song" "has title"
assert_contains "$out" "· 9" "has listeners"

# SHOW_LISTENERS=0 hides the count.
out0="$(BSR_STATUS_SHOW_LISTENERS=0 bash "$seg")"
assert_contains "$out0" "Some Song" "title still shown"
case "$out0" in *"· 9"*) echo "FAIL: listeners should be hidden"; exit 1;; esac

# Empty title (offline) -> drop only, no title text.
printf '\t0\n' > "$BSR_NOWPLAYING_CACHE"
out_empty="$(bash "$seg")"
assert_contains "$out_empty" "🩸" "drop shown when offline"
case "$out_empty" in *" · "*) echo "FAIL: no listeners separator when offline"; exit 1;; esac

# Stale cache (mtime old) -> empty even though running.
printf 'Stale Song\t5\n' > "$BSR_NOWPLAYING_CACHE"
touch -t 200001010000 "$BSR_NOWPLAYING_CACHE"
assert_eq "$(bash "$seg")" "" "stale cache -> empty"

# Cleanup
kill "$(cat "$BSR_PID_FILE")" 2>/dev/null
rm -f "$BSR_PID_FILE" "$BSR_NOWPLAYING_CACHE"
pass test_statusline
