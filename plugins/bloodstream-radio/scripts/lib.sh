# BloodStream Radio plugin — shared config and helpers.
# Sourced by bsr.sh / play.sh / stop.sh / now.sh. No side effects on source.

STREAM_URL="https://uk1.internet-radio.com/proxy/bloodstream?mp=/autodj"
STATUS_URL="https://uk1.internet-radio.com/proxy/bloodstream/status-json.xsl"
PID_FILE="${BSR_PID_FILE:-${TMPDIR:-/tmp}/bloodstream-radio.pid}"
NOWPLAYING_CACHE="${BSR_NOWPLAYING_CACHE:-${TMPDIR:-/tmp}/bloodstream-radio.nowplaying}"
POLLER_PID_FILE="${BSR_POLLER_PID_FILE:-${TMPDIR:-/tmp}/bloodstream-radio.poller.pid}"
POLL_INTERVAL="${BSR_POLL_INTERVAL:-20}"
SHOW_LISTENERS="${BSR_STATUS_SHOW_LISTENERS:-1}"

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

# True iff POLLER_PID_FILE holds a live process.
poller_running() {
  [ -f "$POLLER_PID_FILE" ] || return 1
  local pid
  pid="$(cat "$POLLER_PID_FILE" 2>/dev/null)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}
