#!/usr/bin/env bash
# Dispatcher for the /bsr command: route play | stop | now.
dir="$(dirname "${BASH_SOURCE[0]}")"
case "${1:-play}" in
  play) exec bash "$dir/play.sh" ;;
  stop) exec bash "$dir/stop.sh" ;;
  now)  exec bash "$dir/now.sh" ;;
  *)    echo "usage: /bsr [play|stop|now]"; exit 1 ;;
esac
