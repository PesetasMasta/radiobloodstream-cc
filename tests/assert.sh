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
assert_ok() {
  local desc="${@: -1}"
  if [ $# -gt 1 ] && [ "$desc" != "" ] && ! [[ "$desc" =~ ^- ]]; then
    # Last arg looks like a description
    set -- "${@:1:$(($# - 1))}"
  fi
  if ! "$@"; then echo "FAIL: expected success: $*"; exit 1; fi;
}
assert_fail() {
  local desc="${@: -1}"
  if [ $# -gt 1 ] && [ "$desc" != "" ] && ! [[ "$desc" =~ ^- ]]; then
    # Last arg looks like a description
    set -- "${@:1:$(($# - 1))}"
  fi
  if "$@"; then echo "FAIL: expected failure: $*"; exit 1; fi;
}
pass() { echo "PASS: ${1:-$0}"; }
