#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/assert.sh"
scripts="$here/../plugins/bloodstream-radio/scripts"

export BSR_PID_FILE="$(mktemp -u)"          # unique, not-yet-existing path
export BSR_PLAYER="$here/fake-player.sh"     # use the dummy instead of mpv
chmod +x "$here/fake-player.sh"

# stop with nothing running -> friendly, exit 0, no pid file.
out="$(bash "$scripts/stop.sh")"
assert_contains "$out" "Nothing playing" "stop when idle"
assert_fail test -f "$BSR_PID_FILE" # no pid file after idle stop

# play -> pid file created, process alive.
out="$(bash "$scripts/play.sh")"
assert_contains "$out" "Playing BloodStream Radio" "play confirmation"
assert_ok test -f "$BSR_PID_FILE" # pid file exists after play
pid="$(cat "$BSR_PID_FILE")"
assert_ok kill -0 "$pid" # player process alive

# second play -> no-op, same pid.
out="$(bash "$scripts/play.sh")"
assert_contains "$out" "already playing" "second play is a no-op"
assert_eq "$(cat "$BSR_PID_FILE")" "$pid" "pid unchanged on second play"

# stop -> process gone, pid file removed.
out="$(bash "$scripts/stop.sh")"
assert_contains "$out" "Stopped" "stop confirmation"
assert_fail test -f "$BSR_PID_FILE" # pid file removed after stop
assert_fail kill -0 "$pid" # player process gone after stop

# stale pid file -> stop cleans it and reports idle.
echo "999999" > "$BSR_PID_FILE"
out="$(bash "$scripts/stop.sh")"
assert_contains "$out" "Nothing playing" "stale pid treated as idle"
assert_fail test -f "$BSR_PID_FILE" # stale pid file cleaned

# dispatcher routes (default action is play).
out="$(bash "$scripts/bsr.sh")"
assert_contains "$out" "Playing BloodStream Radio" "dispatcher defaults to play"
bash "$scripts/bsr.sh" stop >/dev/null
out="$(bash "$scripts/bsr.sh" bogus)"
assert_contains "$out" "usage" "dispatcher rejects unknown action"

# Poller lifecycle: play starts a poller, stop removes it + the cache.
export BSR_POLLER_PID_FILE="$(mktemp -u)"
export BSR_NOWPLAYING_CACHE="$(mktemp -u)"
bash "$scripts/play.sh" >/dev/null
assert_ok test -f "$BSR_POLLER_PID_FILE"          # poller pid recorded
ppid="$(cat "$BSR_POLLER_PID_FILE")"
assert_ok kill -0 "$ppid"                         # poller alive
bash "$scripts/stop.sh" >/dev/null
assert_fail test -f "$BSR_POLLER_PID_FILE"        # poller pid removed
assert_fail test -f "$BSR_NOWPLAYING_CACHE"       # cache removed
assert_fail kill -0 "$ppid"                       # poller process gone

pass test_playstop
