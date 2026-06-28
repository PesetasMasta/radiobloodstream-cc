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
