# BloodStream Radio Claude Code Plugin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a public Claude Code plugin so any developer can stream BloodStream Radio (`/bsr play|stop|now`) while they code.

**Architecture:** A standalone marketplace repo. A single namespaced slash command `/bsr` runs a dispatcher script that shells out to a detected audio player (`mpv → ffplay → cvlc`) for background playback (tracked by a PID file), and reads the station's public Icecast `status-json.xsl` for now-playing metadata. The only moving parts are POSIX bash scripts plus JSON manifests.

**Tech Stack:** bash (POSIX), `curl`, `jq` (with a `node` JSON fallback), Claude Code plugin manifests (`marketplace.json` / `plugin.json`).

## Global Constraints

- Plugin package name: `bloodstream-radio`. Command: `/bsr`. Marketplace/repo name: `radiobloodstream-cc`.
- Stream URL (verbatim, single source in `scripts/lib.sh`): `https://uk1.internet-radio.com/proxy/bloodstream?mp=/autodj`
- Status URL (verbatim, single source in `scripts/lib.sh`): `https://uk1.internet-radio.com/proxy/bloodstream/status-json.xsl`
- Player chain is exactly `mpv → ffplay → cvlc`. `afplay` is deliberately excluded (cannot play an Icecast URL).
- Platforms: macOS, Linux, WSL via bash. Native Windows is out of scope for v1.
- No volume / next-track controls (single AutoDJ stream). No session-start auto-play hook. No `claude-music` PR. All out of scope for v1.
- Every script must source config from `lib.sh` — the two URLs appear in exactly one file.
- All scripts must pass `shellcheck` when it is available.

## File Structure

```
radiobloodstream-cc/
├── .claude-plugin/marketplace.json          # marketplace listing
├── plugins/bloodstream-radio/
│   ├── .claude-plugin/plugin.json           # plugin manifest
│   ├── commands/bsr.md                       # /bsr slash command -> dispatcher
│   └── scripts/
│       ├── lib.sh                            # the 2 URLs, PID_FILE, detect_player, player_args, is_running
│       ├── bsr.sh                            # dispatcher: routes play|stop|now (realizes "routes on argument")
│       ├── play.sh                           # detached playback + PID file
│       ├── stop.sh                           # kill by PID file
│       └── now.sh                            # parse status JSON -> now-playing line
├── tests/
│   ├── assert.sh                             # tiny assertion helpers
│   ├── fake-player.sh                        # dummy player (sleeps) for PID tests
│   ├── fixtures/online.json                  # sample status JSON, source present
│   ├── fixtures/offline.json                 # sample status JSON, no live source
│   ├── test_lib.sh
│   ├── test_now.sh
│   ├── test_playstop.sh
│   └── test_command.sh
├── README.md
└── LICENSE
```

> **Note on the spec:** the design listed `play.sh/stop.sh/now.sh` and said the command "routes on argument". This plan realizes that routing with a tiny `bsr.sh` dispatcher so the command markdown stays trivial and the routing is unit-testable. No behavioral change.

---

### Task 1: Repo scaffolding and manifests

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `plugins/bloodstream-radio/.claude-plugin/plugin.json`
- Create: `LICENSE`
- Create: `.gitignore`
- Test: `tests/test_manifests.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: a valid marketplace at repo root exposing plugin `bloodstream-radio` with `source: "./plugins/bloodstream-radio"`; a valid plugin manifest naming the plugin `bloodstream-radio` version `0.1.0`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_manifests.sh`:

```bash
#!/usr/bin/env bash
# Validates the plugin manifests are well-formed JSON with the required fields.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"

node -e '
const fs = require("fs");
const m = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const p = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (m.name !== "radiobloodstream-cc") throw new Error("marketplace name wrong: " + m.name);
if (!Array.isArray(m.plugins) || m.plugins.length !== 1) throw new Error("expected 1 plugin");
const entry = m.plugins[0];
if (entry.name !== "bloodstream-radio") throw new Error("plugin entry name wrong: " + entry.name);
if (entry.source !== "./plugins/bloodstream-radio") throw new Error("plugin source wrong: " + entry.source);
if (p.name !== "bloodstream-radio") throw new Error("plugin.json name wrong: " + p.name);
if (p.version !== "0.1.0") throw new Error("plugin.json version wrong: " + p.version);
if (!p.description) throw new Error("plugin.json missing description");
console.log("manifests OK");
' "$root/.claude-plugin/marketplace.json" "$root/plugins/bloodstream-radio/.claude-plugin/plugin.json"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_manifests.sh`
Expected: FAIL — `ENOENT` / no such file (manifests don't exist yet).

- [ ] **Step 3: Create the manifests, LICENSE, and .gitignore**

`.claude-plugin/marketplace.json`:

```json
{
  "name": "radiobloodstream-cc",
  "owner": {
    "name": "PesetasMasta",
    "url": "https://github.com/PesetasMasta"
  },
  "metadata": {
    "description": "BloodStream Radio for Claude Code — listen while you code.",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "bloodstream-radio",
      "source": "./plugins/bloodstream-radio",
      "description": "Stream BloodStream Radio (metal/rock/punk) in the background while you code.",
      "version": "0.1.0",
      "category": "fun"
    }
  ]
}
```

`plugins/bloodstream-radio/.claude-plugin/plugin.json`:

```json
{
  "name": "bloodstream-radio",
  "version": "0.1.0",
  "description": "Stream BloodStream Radio while you code. /bsr play | stop | now.",
  "author": {
    "name": "PesetasMasta",
    "url": "https://radiobloodstream.com"
  },
  "homepage": "https://radiobloodstream.com",
  "keywords": ["radio", "music", "metal", "focus", "stream"]
}
```

`LICENSE` (MIT — fill the year and holder):

```text
MIT License

Copyright (c) 2026 BloodStream Radio

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

`.gitignore`:

```text
*.pid
.DS_Store
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_manifests.sh`
Expected: PASS — prints `manifests OK`.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin plugins/bloodstream-radio/.claude-plugin LICENSE .gitignore tests/test_manifests.sh
git commit -m "feat: scaffold plugin marketplace and manifests"
```

---

### Task 2: Config + helpers (`lib.sh`)

**Files:**
- Create: `plugins/bloodstream-radio/scripts/lib.sh`
- Create: `tests/assert.sh`
- Test: `tests/test_lib.sh`

**Interfaces:**
- Consumes: nothing.
- Produces (sourceable, side-effect-free on source):
  - vars `STREAM_URL`, `STATUS_URL`, `PID_FILE` (overridable via `BSR_PID_FILE`).
  - `detect_player()` → echoes first of `mpv|ffplay|cvlc` on PATH and returns 0; if none, prints an install hint to stderr and returns 1.
  - `player_args <name>` → echoes the quiet/no-video flags for that player (`""` for unknown).
  - `is_running()` → returns 0 iff `PID_FILE` holds a live PID; no stdout.

- [ ] **Step 1: Write the assertion helper**

Create `tests/assert.sh`:

```bash
# Minimal assertion helpers for plain-bash tests. Source this file.
assert_eq() {
  if [ "$1" != "$2" ]; then
    echo "FAIL: expected [$2], got [$1]${3:+ ($3)}"; exit 1
  fi
}
assert_contains() {
  case "$1" in
    *"$2"*) : ;;
    *) echo "FAIL: [$1] does not contain [$2]${3:+ ($3)}"; exit 1 ;;
  esac
}
assert_ok()   { if ! "$@"; then echo "FAIL: expected success: $*"; exit 1; fi; }
assert_fail() { if "$@"; then echo "FAIL: expected failure: $*"; exit 1; fi; }
pass() { echo "PASS: ${1:-$0}"; }
```

- [ ] **Step 2: Write the failing test**

Create `tests/test_lib.sh`:

```bash
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
assert_fail env PATH="$fakebin/none" bash -c ". '$here/../plugins/bloodstream-radio/scripts/lib.sh'; detect_player"

# is_running: live pid true, dead pid false.
export BSR_PID_FILE="$(mktemp)"
. "$here/../plugins/bloodstream-radio/scripts/lib.sh"   # re-source so PID_FILE picks up override
sleep 30 & livepid=$!
echo "$livepid" > "$BSR_PID_FILE"
assert_ok is_running "live pid is running"
kill "$livepid" 2>/dev/null
echo "999999" > "$BSR_PID_FILE"
assert_fail is_running "dead pid is not running"
rm -f "$BSR_PID_FILE"

pass test_lib
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash tests/test_lib.sh`
Expected: FAIL — `lib.sh` not found / functions undefined.

- [ ] **Step 4: Implement `lib.sh`**

Create `plugins/bloodstream-radio/scripts/lib.sh`:

```bash
# BloodStream Radio plugin — shared config and helpers.
# Sourced by bsr.sh / play.sh / stop.sh / now.sh. No side effects on source.

STREAM_URL="https://uk1.internet-radio.com/proxy/bloodstream?mp=/autodj"
STATUS_URL="https://uk1.internet-radio.com/proxy/bloodstream/status-json.xsl"
PID_FILE="${BSR_PID_FILE:-${TMPDIR:-/tmp}/bloodstream-radio.pid}"

install_hint() {
  case "$(uname -s)" in
    Darwin) echo "No stream player found. Install one with: brew install mpv" ;;
    *)      echo "No stream player found. Install one with: sudo apt install mpv  (or: sudo dnf install mpv)" ;;
  esac
}

# Echo the first available player; return 1 (with a hint on stderr) if none.
detect_player() {
  local p
  for p in mpv ffplay cvlc; do
    if command -v "$p" >/dev/null 2>&1; then
      echo "$p"; return 0
    fi
  done
  install_hint >&2
  return 1
}

# Quiet / no-video flags for a given player binary name.
player_args() {
  case "$1" in
    mpv)    echo "--no-video --really-quiet" ;;
    ffplay) echo "-nodisp -autoexit -loglevel quiet" ;;
    cvlc)   echo "--intf dummy --quiet" ;;
    *)      echo "" ;;
  esac
}

# True iff PID_FILE holds a live process.
is_running() {
  [ -f "$PID_FILE" ] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_lib.sh`
Expected: PASS — prints `PASS: test_lib`.

- [ ] **Step 6: shellcheck (if available)**

Run: `command -v shellcheck >/dev/null && shellcheck plugins/bloodstream-radio/scripts/lib.sh || echo "shellcheck not installed — skipping"`
Expected: no warnings, or the skip message.

- [ ] **Step 7: Commit**

```bash
git add tests/assert.sh tests/test_lib.sh plugins/bloodstream-radio/scripts/lib.sh
git commit -m "feat: add lib.sh config, player detection, pid helpers"
```

---

### Task 3: Now-playing (`now.sh`)

**Files:**
- Create: `plugins/bloodstream-radio/scripts/now.sh`
- Create: `tests/fixtures/online.json`
- Create: `tests/fixtures/offline.json`
- Test: `tests/test_now.sh`

**Interfaces:**
- Consumes: `STATUS_URL` from `lib.sh`.
- Produces:
  - `parse_now()` → reads status JSON on stdin, prints `Now playing: <title> · <N> listeners`, or `BloodStream Radio is offline right now.` when no live source/title. Uses `jq` if present, else a `node` fallback.
  - Running `now.sh` directly curls `STATUS_URL` and pipes it through `parse_now`.

- [ ] **Step 1: Create fixtures**

`tests/fixtures/online.json` (Icecast `source` as an array — the real shape):

```json
{"icestats":{"server_id":"Icecast 2.4.4","source":[{"title":"Metallica - One","listeners":24,"genre":"Rock Metal"}]}}
```

`tests/fixtures/offline.json` (no live source):

```json
{"icestats":{"server_id":"Icecast 2.4.4"}}
```

- [ ] **Step 2: Write the failing test**

Create `tests/test_now.sh`:

```bash
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash tests/test_now.sh`
Expected: FAIL — `now.sh` not found / `parse_now` undefined.

- [ ] **Step 4: Implement `now.sh`**

Create `plugins/bloodstream-radio/scripts/now.sh`:

```bash
#!/usr/bin/env bash
# Print BloodStream Radio's current track + listener count.
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Read status JSON on stdin, print a human line.
parse_now() {
  local json
  json="$(cat)"
  if command -v jq >/dev/null 2>&1; then
    local src title listeners
    src='.icestats.source | if type=="array" then .[0] else . end'
    title="$(printf '%s' "$json" | jq -r "($src) | .title // empty" 2>/dev/null)"
    listeners="$(printf '%s' "$json" | jq -r "($src) | .listeners // 0" 2>/dev/null)"
    if [ -z "$title" ]; then
      echo "BloodStream Radio is offline right now."
    else
      echo "Now playing: $title · $listeners listeners"
    fi
  else
    printf '%s' "$json" | node -e '
      let d=""; process.stdin.on("data",c=>d+=c).on("end",()=>{
        try {
          const s = JSON.parse(d).icestats.source;
          const o = Array.isArray(s) ? s[0] : s;
          if (!o || !o.title) { console.log("BloodStream Radio is offline right now."); return; }
          console.log(`Now playing: ${o.title} · ${o.listeners || 0} listeners`);
        } catch (e) { console.log("BloodStream Radio is offline right now."); }
      });'
  fi
}

main() {
  local json
  if ! json="$(curl -s -m 8 "$STATUS_URL")"; then
    echo "BloodStream Radio is offline right now."
    return 0
  fi
  printf '%s' "$json" | parse_now
}

# Run main only when executed directly (so tests can source parse_now).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_now.sh`
Expected: PASS — prints `PASS: test_now`.

- [ ] **Step 6: Smoke-test against the live endpoint (network)**

Run: `bash plugins/bloodstream-radio/scripts/now.sh`
Expected: a `Now playing: … · N listeners` line (or the offline message if the station is down).

- [ ] **Step 7: shellcheck (if available)**

Run: `command -v shellcheck >/dev/null && shellcheck plugins/bloodstream-radio/scripts/now.sh || echo "shellcheck not installed — skipping"`
Expected: no warnings, or the skip message.

- [ ] **Step 8: Commit**

```bash
git add plugins/bloodstream-radio/scripts/now.sh tests/fixtures tests/test_now.sh
git commit -m "feat: add now.sh now-playing reader with jq/node parsing"
```

---

### Task 4: Playback control (`play.sh`, `stop.sh`, `bsr.sh`)

**Files:**
- Create: `plugins/bloodstream-radio/scripts/play.sh`
- Create: `plugins/bloodstream-radio/scripts/stop.sh`
- Create: `plugins/bloodstream-radio/scripts/bsr.sh`
- Create: `tests/fake-player.sh`
- Test: `tests/test_playstop.sh`

**Interfaces:**
- Consumes: `STREAM_URL`, `PID_FILE`, `detect_player`, `player_args`, `is_running` from `lib.sh`. Honors `BSR_PLAYER` (path/name of a player to use instead of detection — used by tests).
- Produces:
  - `play.sh`: starts a detached player against `STREAM_URL`, writes its PID to `PID_FILE`; no-op (exit 0) if already running.
  - `stop.sh`: kills the tracked PID and removes `PID_FILE`; friendly message if nothing is running; cleans a stale file.
  - `bsr.sh <action>`: routes `play|stop|now` (default `play`) to the matching script.

- [ ] **Step 1: Create the fake player**

Create `tests/fake-player.sh` (ignores all args, just lives so it has a PID):

```bash
#!/usr/bin/env bash
# Test stand-in for a real audio player: ignore args, stay alive.
exec sleep 30
```

Make it executable: `chmod +x tests/fake-player.sh`

- [ ] **Step 2: Write the failing test**

Create `tests/test_playstop.sh`:

```bash
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
assert_fail test -f "$BSR_PID_FILE" "no pid file after idle stop"

# play -> pid file created, process alive.
out="$(bash "$scripts/play.sh")"
assert_contains "$out" "Playing BloodStream Radio" "play confirmation"
assert_ok test -f "$BSR_PID_FILE" "pid file exists after play"
pid="$(cat "$BSR_PID_FILE")"
assert_ok kill -0 "$pid" "player process alive"

# second play -> no-op, same pid.
out="$(bash "$scripts/play.sh")"
assert_contains "$out" "already playing" "second play is a no-op"
assert_eq "$(cat "$BSR_PID_FILE")" "$pid" "pid unchanged on second play"

# stop -> process gone, pid file removed.
out="$(bash "$scripts/stop.sh")"
assert_contains "$out" "Stopped" "stop confirmation"
assert_fail test -f "$BSR_PID_FILE" "pid file removed after stop"
assert_fail kill -0 "$pid" "player process gone after stop"

# stale pid file -> stop cleans it and reports idle.
echo "999999" > "$BSR_PID_FILE"
out="$(bash "$scripts/stop.sh")"
assert_contains "$out" "Nothing playing" "stale pid treated as idle"
assert_fail test -f "$BSR_PID_FILE" "stale pid file cleaned"

# dispatcher routes (default action is play).
out="$(bash "$scripts/bsr.sh")"
assert_contains "$out" "Playing BloodStream Radio" "dispatcher defaults to play"
bash "$scripts/bsr.sh" stop >/dev/null
out="$(bash "$scripts/bsr.sh" bogus)"
assert_contains "$out" "usage" "dispatcher rejects unknown action"

pass test_playstop
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash tests/test_playstop.sh`
Expected: FAIL — `play.sh` / `stop.sh` / `bsr.sh` not found.

- [ ] **Step 4: Implement `play.sh`**

Create `plugins/bloodstream-radio/scripts/play.sh`:

```bash
#!/usr/bin/env bash
# Start BloodStream Radio playback in the background.
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_running; then
  echo "BloodStream Radio is already playing. /bsr stop to end."
  exit 0
fi

player="${BSR_PLAYER:-$(detect_player)}" || exit 1
name="$(basename "$player")"
# shellcheck disable=SC2046  # word-splitting of player_args is intended
nohup "$player" $(player_args "$name") "$STREAM_URL" >/dev/null 2>&1 &
echo "$!" > "$PID_FILE"
echo "Playing BloodStream Radio (via $name). /bsr stop to end."
```

- [ ] **Step 5: Implement `stop.sh`**

Create `plugins/bloodstream-radio/scripts/stop.sh`:

```bash
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
```

- [ ] **Step 6: Implement `bsr.sh`**

Create `plugins/bloodstream-radio/scripts/bsr.sh`:

```bash
#!/usr/bin/env bash
# Dispatcher for the /bsr command: route play | stop | now.
dir="$(dirname "${BASH_SOURCE[0]}")"
case "${1:-play}" in
  play) exec bash "$dir/play.sh" ;;
  stop) exec bash "$dir/stop.sh" ;;
  now)  exec bash "$dir/now.sh" ;;
  *)    echo "usage: /bsr [play|stop|now]"; exit 1 ;;
esac
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bash tests/test_playstop.sh`
Expected: PASS — prints `PASS: test_playstop`.

- [ ] **Step 8: shellcheck (if available)**

Run: `command -v shellcheck >/dev/null && shellcheck plugins/bloodstream-radio/scripts/play.sh plugins/bloodstream-radio/scripts/stop.sh plugins/bloodstream-radio/scripts/bsr.sh || echo "shellcheck not installed — skipping"`
Expected: no warnings, or the skip message.

- [ ] **Step 9: Commit**

```bash
git add plugins/bloodstream-radio/scripts/play.sh plugins/bloodstream-radio/scripts/stop.sh plugins/bloodstream-radio/scripts/bsr.sh tests/fake-player.sh tests/test_playstop.sh
git commit -m "feat: add play/stop/dispatcher with pid lifecycle"
```

---

### Task 5: The `/bsr` slash command

**Files:**
- Create: `plugins/bloodstream-radio/commands/bsr.md`
- Test: `tests/test_command.sh`

**Interfaces:**
- Consumes: `scripts/bsr.sh` via `${CLAUDE_PLUGIN_ROOT}`.
- Produces: the `/bsr` command. Passes the user's argument (default `play`) to the dispatcher and shows its output.

- [ ] **Step 1: Write the failing test**

Create `tests/test_command.sh` (validates the command wiring without a live Claude session):

```bash
#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/assert.sh"
cmd="$here/../plugins/bloodstream-radio/commands/bsr.md"

assert_ok test -f "$cmd" "command file exists"
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
assert_ok test -n "$out" "dispatcher 'now' produced output"

pass test_command
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_command.sh`
Expected: FAIL — `bsr.md` does not exist.

- [ ] **Step 3: Implement `commands/bsr.md`**

Create `plugins/bloodstream-radio/commands/bsr.md`:

```markdown
---
description: Play, stop, or show now-playing for BloodStream Radio
argument-hint: "[play|stop|now]"
allowed-tools: Bash
---

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/bsr.sh" "$ARGUMENTS"`
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_command.sh`
Expected: PASS — prints `PASS: test_command`.

- [ ] **Step 5: Commit**

```bash
git add plugins/bloodstream-radio/commands/bsr.md tests/test_command.sh
git commit -m "feat: add /bsr slash command"
```

---

### Task 6: README, full test sweep, and live install verification

**Files:**
- Create: `README.md`
- Create: `tests/run.sh` (runs every test_*.sh)

**Interfaces:**
- Consumes: everything above.
- Produces: user-facing install/usage docs and a one-command test runner.

- [ ] **Step 1: Write the test runner**

Create `tests/run.sh`:

```bash
#!/usr/bin/env bash
# Run all plugin tests. Exits non-zero on the first failure.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
for t in "$here"/test_*.sh; do
  echo "== $(basename "$t") =="
  bash "$t"
done
echo "ALL TESTS PASSED"
```

- [ ] **Step 2: Run the whole suite**

Run: `bash tests/run.sh`
Expected: each test prints PASS, ending with `ALL TESTS PASSED`.

- [ ] **Step 3: Write `README.md`**

Create `README.md`:

````markdown
# BloodStream Radio — Claude Code plugin

Stream [BloodStream Radio](https://radiobloodstream.com) (metal / rock / punk)
in the background while you code, right from Claude Code.

## Install

```text
/plugin marketplace add PesetasMasta/radiobloodstream-cc
/plugin install bloodstream-radio@radiobloodstream-cc
```

You need a command-line stream player. `mpv` is recommended:

```bash
brew install mpv          # macOS
sudo apt install mpv      # Debian/Ubuntu
sudo dnf install mpv      # Fedora
```

`ffplay` (from ffmpeg) and `cvlc` (from VLC) also work.

## Usage

```text
/bsr play     # start playback in the background
/bsr now      # current track + listener count
/bsr stop     # stop playback
```

`/bsr` with no argument is the same as `/bsr play`.

## Requirements & notes

- macOS, Linux, and WSL. Native Windows is not supported in this version.
- `afplay` (macOS built-in) is not used — it cannot play an Icecast stream.
- Playback runs detached and is tracked by a PID file in your temp dir;
  `/bsr stop` ends it.

## Troubleshooting

- **"No stream player found"** — install `mpv` (see above).
- **No sound but it says playing** — test the stream directly:
  `mpv 'https://uk1.internet-radio.com/proxy/bloodstream?mp=/autodj'`
- **`/bsr now` says offline** — the station source may genuinely be down; check
  https://radiobloodstream.com.

## License

MIT — see [LICENSE](LICENSE).
````

- [ ] **Step 4: Live install verification (manual, on macOS)**

```bash
# Ensure a player exists.
command -v mpv || brew install mpv

# Add the local repo as a marketplace and install the plugin in Claude Code:
#   /plugin marketplace add /Users/joker/dev/radiobloodstream-cc
#   /plugin install bloodstream-radio@radiobloodstream-cc
# Then in Claude Code:
#   /bsr play   -> you should hear the stream within a few seconds
#   /bsr now    -> prints the current track + listeners
#   /bsr stop   -> audio stops
```

Expected: audio plays on `/bsr play`, `/bsr now` shows a real track, `/bsr stop` ends it.

- [ ] **Step 5: Commit**

```bash
git add README.md tests/run.sh
git commit -m "docs: add README and test runner"
```

- [ ] **Step 6: Tag v0.1.0**

```bash
git tag v0.1.0
```

---

## Self-Review

**Spec coverage:**
- Dedicated repo, branded standalone plugin, `/bsr`, full feature set — Tasks 1–6. Covered.
- Two URLs centralized in `lib.sh` — Task 2 (asserted by `test_lib.sh`). Covered.
- Player chain `mpv → ffplay → cvlc`, afplay excluded — Task 2 `detect_player` + README. Covered.
- play / stop / now behaviors incl. no-op double-play, stale PID, offline message — Tasks 3–4 with tests. Covered.
- jq-with-node-fallback parsing — Task 3. Covered.
- Platforms macOS/Linux/WSL; Windows out — README (Task 6). Covered.
- Testing: shellcheck, parse fixture test, PID lifecycle test, manual audio — Tasks 2/3/4/6. Covered.
- Out-of-scope items (volume/next, claude-music PR, auto-play hook) — not implemented, by design.

**Placeholder scan:** No TBD/TODO/"add error handling" placeholders; every code step is complete. LICENSE holder/year are concrete (2026 / BloodStream Radio).

**Type consistency:** `STREAM_URL`, `STATUS_URL`, `PID_FILE`, `detect_player`, `player_args`, `is_running`, `parse_now`, `BSR_PID_FILE`, `BSR_PLAYER` are used identically across `lib.sh`, the scripts, and the tests. Dispatcher actions `play|stop|now` match the command and tests.
