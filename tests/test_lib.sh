#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/assert.sh"
. "$here/../plugins/bloodstream-radio/scripts/lib.sh"

# URLs are exactly the spec values.
assert_eq "$STREAM_URL" "https://uk1.internet-radio.com/proxy/bloodstream?mp=/autodj" "stream url"
assert_eq "$STATUS_URL" "https://uk1.internet-radio.com/proxy/bloodstream/status-json.xsl" "status url"

# player_args mapping.
assert_contains "$(player_args mpv)" "--no-video" "mpv args"
assert_contains "$(player_args ffplay)" "-nodisp" "ffplay args"
assert_contains "$(player_args cvlc)" "dummy" "cvlc args"
assert_eq "$(player_args whatever)" "" "unknown player has no args"

# detect_player: with a fake mpv first on PATH, it is chosen.
fakebin="$(mktemp -d)"
printf '#!/bin/sh\n' > "$fakebin/mpv"; chmod +x "$fakebin/mpv"
assert_eq "$(PATH="$fakebin:$PATH" detect_player)" "mpv" "detect picks mpv"

# detect_player: with an empty PATH it fails (no players) and returns non-zero.
emptydir="$(mktemp -d)"
assert_fail bash -c "PATH='$emptydir'; . '$here/../plugins/bloodstream-radio/scripts/lib.sh'; detect_player" # no players on empty PATH
rmdir "$emptydir"

# is_running: live pid true, dead pid false.
export BSR_PID_FILE="$(mktemp)"
. "$here/../plugins/bloodstream-radio/scripts/lib.sh"   # re-source so PID_FILE picks up override
sleep 30 & livepid=$!
echo "$livepid" > "$BSR_PID_FILE"
assert_ok is_running # live pid is running
kill "$livepid" 2>/dev/null
echo "999999" > "$BSR_PID_FILE"
assert_fail is_running # dead pid is not running
rm -f "$BSR_PID_FILE"

# New config defaults present.
assert_eq "$NOWPLAYING_CACHE" "${TMPDIR:-/tmp}/bloodstream-radio.nowplaying" "nowplaying cache default"
assert_eq "$POLLER_PID_FILE" "${TMPDIR:-/tmp}/bloodstream-radio.poller.pid" "poller pid default"
assert_eq "$POLL_INTERVAL" "20" "poll interval default"
assert_eq "$SHOW_LISTENERS" "1" "show listeners default"

# poller_running mirrors is_running on POLLER_PID_FILE.
export BSR_POLLER_PID_FILE="$(mktemp)"
. "$here/../plugins/bloodstream-radio/scripts/lib.sh"   # re-source to pick up override
sleep 30 & ppid=$!
echo "$ppid" > "$BSR_POLLER_PID_FILE"
assert_ok poller_running    # live poller pid
kill "$ppid" 2>/dev/null
echo "999999" > "$BSR_POLLER_PID_FILE"
assert_fail poller_running  # dead poller pid
rm -f "$BSR_POLLER_PID_FILE"

rm -rf "$fakebin"
pass test_lib
