#!/usr/bin/env bash
# Run all plugin tests. Exits non-zero on the first failure.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
for t in "$here"/test_*.sh; do
  echo "== $(basename "$t") =="
  bash "$t"
done
echo "ALL TESTS PASSED"
