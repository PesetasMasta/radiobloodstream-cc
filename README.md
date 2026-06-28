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
