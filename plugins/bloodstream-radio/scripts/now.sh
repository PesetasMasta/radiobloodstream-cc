#!/usr/bin/env bash
# Print BloodStream Radio's current track + listener count.
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Read status JSON on stdin, print one line: "<title>\t<listeners>".
# Offline / no live source -> empty title and 0. Single jq/node pass.
current_status() {
  local json
  json="$(cat)"
  if command -v jq >/dev/null 2>&1; then
    local src
    src='.icestats.source | if type=="array" then .[0] else . end'
    printf '%s' "$json" | jq -r "[($src | .title // \"\"), ($src | .listeners // 0)] | @tsv" 2>/dev/null \
      || printf '\t0'
  else
    printf '%s' "$json" | node -e '
      let d=""; process.stdin.on("data",c=>d+=c).on("end",()=>{
        try {
          const s = JSON.parse(d).icestats.source;
          const o = Array.isArray(s) ? s[0] : s;
          const title = (o && o.title) ? o.title : "";
          const listeners = (o && o.listeners != null) ? o.listeners : 0;
          console.log(`${title}\t${listeners}`);
        } catch (e) { console.log(`\t0`); }
      });'
  fi
}

# Bare "Artist - Title" (or empty when offline).
current_title() {
  current_status | cut -f1
}

# Human one-line status, built on current_status (keeps parsing DRY).
parse_now() {
  local line title listeners
  line="$(current_status)"
  title="${line%%$'\t'*}"
  listeners="${line#*$'\t'}"
  if [ -z "$title" ]; then
    echo "BloodStream Radio is offline right now."
  else
    echo "Now playing: $title · $listeners listeners"
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

# Run main only when executed directly (so tests can source the functions).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
