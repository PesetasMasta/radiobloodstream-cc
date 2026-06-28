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

# current_status: online fixture -> "title<TAB>listeners"
cs_online="$(current_status < "$here/fixtures/online.json")"
assert_eq "$cs_online" "$(printf 'Metallica - One\t24')" "current_status online"

# current_status: offline fixture -> empty title + 0
cs_offline="$(current_status < "$here/fixtures/offline.json")"
assert_eq "$cs_offline" "$(printf '\t0')" "current_status offline"

# current_title derives bare title
assert_eq "$(current_title < "$here/fixtures/online.json")" "Metallica - One" "current_title online"
assert_eq "$(current_title < "$here/fixtures/offline.json")" "" "current_title offline"

# parse_now still works (unchanged behavior)
assert_contains "$(parse_now < "$here/fixtures/online.json")" "Metallica - One" "parse_now title"
assert_contains "$(parse_now < "$here/fixtures/online.json")" "24" "parse_now listeners"
assert_contains "$(parse_now < "$here/fixtures/offline.json")" "offline" "parse_now offline"

pass test_now
