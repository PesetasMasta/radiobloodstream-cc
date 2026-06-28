# BloodStream Radio — Claude Code Plugin

**Date:** 2026-06-28
**Status:** Approved design, pre-implementation
**Repo:** `radiobloodstream-cc` (new public repo; the `radiobloodstream.com` site repo is untouched)

## Goal

Let any Claude Code user stream BloodStream Radio while they code, with live
now-playing info, distributed as its own public plugin marketplace. This is a
distribution / marketing channel for the station into the developer audience —
not a feature of the site itself.

## Decisions (locked)

- **Dedicated public repo**, not a folder inside `radiobloodstream.com`. The
  plugin only depends on two stable public URLs, so co-location buys nothing and
  would mix plugin edits into the site's high-churn, auto-deploying repo.
- **Branded standalone plugin** (own marketplace), not a station entry in the
  existing `claude-music` plugin. A `claude-music` PR is an optional later
  follow-up and is **out of scope** here.
- **Command name `/brs`** (short, namespaced) with an action argument.
- **Full v1 feature set:** play, stop, and live now-playing + listener count.
- **`mpv` is the recommended player.**

## Source of truth (verified 2026-06-28)

Both URLs are public and already used by the live site:

- Audio stream: `https://uk1.internet-radio.com/proxy/bloodstream?mp=/autodj`
- Status JSON (Icecast 2.4.4): `https://uk1.internet-radio.com/proxy/bloodstream/status-json.xsl`
  — exposes `icestats.source[].title` (current track) and `…listeners`.

These two values live in exactly one place in the codebase (`scripts/lib.sh`).

## Repository layout

```
radiobloodstream-cc/
├── .claude-plugin/
│   └── marketplace.json          # lists the plugin; enables /plugin marketplace add
├── plugins/
│   └── bloodstream-radio/
│       ├── .claude-plugin/
│       │   └── plugin.json        # name, version, description, author
│       ├── commands/
│       │   └── brs.md             # the /brs slash command (routes on argument)
│       └── scripts/
│           ├── lib.sh             # the 2 URLs + detect_player() + paths
│           ├── play.sh            # detached playback + PID file
│           ├── stop.sh            # kill by PID file
│           └── now.sh             # parse status JSON -> "Artist — Title · N listeners"
├── README.md                      # one-line install + troubleshooting
└── LICENSE                        # MIT
```

## Command UX

A single namespaced command with an action argument; default action is `play`.

- `/brs play` — start playback in the background; keeps running while you work.
- `/brs stop` — stop playback.
- `/brs now` — print the current track and listener count.

The `brs.md` command reads `$ARGUMENTS` to pick the action and uses
`$CLAUDE_PLUGIN_ROOT` to locate the matching script under `scripts/`.

## Components and data flow

### `scripts/lib.sh`
Single config + helper module sourced by the others.
- Defines `STREAM_URL` and `STATUS_URL` (the only place they appear).
- Defines `PID_FILE` under `${TMPDIR:-/tmp}/bloodstream-radio.pid`.
- `detect_player()` tries `mpv` → `ffplay` → `cvlc`, echoing the first found.
  If none exist, it prints OS-appropriate install hints
  (`brew install mpv` on macOS, `apt install mpv` / `dnf install mpv` on Linux)
  and returns non-zero so callers exit cleanly — never a crash/stack trace.
- `afplay` is intentionally **not** in the chain: it cannot play an Icecast URL.

### `scripts/play.sh`
- Sources `lib.sh`, resolves the player.
- If a live PID already exists, prints "already playing" and exits 0 (no-op).
- Launches the player detached (`nohup "$player" <stream-args> >/dev/null 2>&1 &`)
  with the player-specific no-video / quiet flags, writes `$!` to `PID_FILE`.
- Prints a confirmation line including which player was used.

### `scripts/stop.sh`
- Reads `PID_FILE`. If missing or the PID is not a live process → "nothing
  playing", exit 0, and clean up a stale file.
- Otherwise kills the process and removes `PID_FILE`.

### `scripts/now.sh`
- `curl -s -m 8` the status JSON.
- Parse `source[].title` and `listeners`. Use `jq` when present; otherwise a
  `node -e` JSON fallback so it works without jq. (No fragile `sed`/grep on JSON.)
- Output: `Now playing: <Artist — Title> · <N> listeners`. If the source is
  offline/absent → `BloodStream Radio is offline right now.`

## Platforms / scope

- macOS, Linux, and WSL via POSIX `bash`.
- Native Windows is **out for v1** (documented in README).
- `claude-music` station PR: **out of scope**, noted as a follow-up.

## Error handling

| Condition | Behavior |
|-----------|----------|
| No supported player installed | `detect_player()` prints install hint, scripts exit cleanly |
| Stream offline | `now` reports offline; `play` still attempts to connect |
| `stop` with nothing running | Friendly "nothing playing" message |
| Stale PID file (process dead) | Detected via liveness check, file cleaned up |
| `play` when already playing | No-op with a notice (no duplicate players) |

## Testing

- `shellcheck` on every script.
- **`now.sh` parse test:** run the parser against a captured
  `status-json.xsl` sample fixture — no network in the test.
- **PID lifecycle test:** exercise `play`/`stop` using a dummy `sleep` process
  as a stand-in for the real player; assert PID file creation, no-op on second
  play, and cleanup on stop.
- **Manual audio check:** verify real playback on macOS with `mpv` before
  tagging v1.

## Installation (for the README)

```text
/plugin marketplace add PesetasMasta/radiobloodstream-cc
/plugin install bloodstream-radio@radiobloodstream-cc
# then:
/brs play
```

Plus a prominent "you need a stream player — `brew install mpv`" note.

## Out of scope (v1)

- Volume / next-track controls (single AutoDJ stream; nothing to skip).
- Native Windows support.
- Submitting the station to the `claude-music` plugin.
- Auto-play on session start via hooks (could be a later opt-in).
