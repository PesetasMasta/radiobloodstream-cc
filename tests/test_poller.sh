#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/assert.sh"
. "$here/../plugins/bloodstream-radio/scripts/nowplaying-poller.sh"   # sourcing must NOT loop

export BSR_NOWPLAYING_CACHE="$(mktemp -u)"
# Re-source so NOWPLAYING_CACHE picks up the override.
. "$here/../plugins/bloodstream-radio/scripts/nowplaying-poller.sh"

# Drive poller_tick deterministically by overriding the fetch with a fixture.
bsr_fetch_status() { cat "$here/fixtures/online.json"; }
poller_tick
assert_eq "$(cat "$BSR_NOWPLAYING_CACHE")" "$(printf 'Metallica - One\t24')" "tick writes title+listeners"

# Offline fixture -> empty title + 0 written.
bsr_fetch_status() { cat "$here/fixtures/offline.json"; }
poller_tick
assert_eq "$(cat "$BSR_NOWPLAYING_CACHE")" "$(printf '\t0')" "tick writes offline marker"

rm -f "$BSR_NOWPLAYING_CACHE"
pass test_poller
