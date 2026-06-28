#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/assert.sh"
cmd="$here/../plugins/bloodstream-radio/commands/bsr.md"

assert_ok test -f "$cmd"
body="$(cat "$cmd")"
assert_contains "$body" "argument-hint" "has argument-hint frontmatter"
assert_contains "$body" "allowed-tools" "declares allowed-tools"
assert_contains "$body" "CLAUDE_PLUGIN_ROOT" "references plugin root"
assert_contains "$body" "scripts/bsr.sh" "invokes the dispatcher"
assert_contains "$body" '$ARGUMENTS' "passes user arguments"

# The dispatcher path it references must resolve and route correctly.
export BSR_PID_FILE="$(mktemp -u)"
export BSR_PLAYER="$here/fake-player.sh"; chmod +x "$here/fake-player.sh"
out="$(bash "$here/../plugins/bloodstream-radio/scripts/bsr.sh" now < /dev/null 2>/dev/null || true)"
# 'now' hits the network; just assert the dispatcher ran and produced a line.
assert_ok test -n "$out"

pass test_command
