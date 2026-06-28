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

# Seed the loading state: an empty-title cache line makes the 🩸 appear on the
# next statusline render, before the poller's first fetch resolves a track.
printf '\t0\n' > "$NOWPLAYING_CACHE"

# Start the now-playing poller (for the statusline) unless one is already up.
if ! poller_running; then
  nohup bash "$(dirname "${BASH_SOURCE[0]}")/nowplaying-poller.sh" >/dev/null 2>&1 &
  echo "$!" > "$POLLER_PID_FILE"
fi

echo "Playing BloodStream Radio (via $name). /bsr stop to end."
