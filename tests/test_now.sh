#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/assert.sh"
. "$here/../plugins/bloodstream-radio/scripts/now.sh"   # sourcing must NOT curl

out_online="$(parse_now < "$here/fixtures/online.json")"
assert_contains "$out_online" "Metallica - One" "title shown"
assert_contains "$out_online" "24" "listeners shown"

out_offline="$(parse_now < "$here/fixtures/offline.json")"
assert_contains "$out_offline" "offline" "offline message"

pass test_now
