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
