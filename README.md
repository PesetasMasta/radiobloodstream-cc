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

## Statusline now-playing (optional)

Show the current track in your Claude Code statusline while the radio plays:
`🩸 Artist - Title · N` (N = listeners). It appears only while playing and
disappears when you `/bsr stop`.

Add this to the end of your statusline command script (the script your
`statusLine` setting in `~/.claude/settings.json` points at), so it composes
with whatever you already show:

```bash
# BloodStream Radio now-playing segment (only renders while playing)
bsr_seg=$(bash /path/to/bloodstream-radio/scripts/statusline-segment.sh 2>/dev/null)
[ -n "$bsr_seg" ] && printf '  |  %s' "$bsr_seg"
```

Replace `/path/to/bloodstream-radio` with the plugin's installed location. The
statusline runs outside the plugin, so `${CLAUDE_PLUGIN_ROOT}` is not available
there — use an absolute path.

If you don't already have a statusline command, set `statusLine` in
`~/.claude/settings.json` to a script containing just those lines.

### Tuning

| Env var | Default | Effect |
|---|---|---|
| `BSR_STATUS_SHOW_LISTENERS` | `1` | Set `0` to hide the `· N` listener count |
| `BSR_POLL_INTERVAL` | `20` | Seconds between now-playing refreshes |

The segment reads a small cache file refreshed by a background poller that
`/bsr play` starts and `/bsr stop` ends — your statusline never makes a network
call.

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
