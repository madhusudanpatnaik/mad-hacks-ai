#!/usr/bin/env bash
# tests/run-all.sh — the ENTIRE test surface.
#
# 2 suites, 159+ assertions:
#   intelligence/ — retrieval + state (retrieval MRR, per-category floors,
#                   state-as-filter invariants). 6 sub-suites.
#   e2e/          — operator-integration (scope adversarial + full pipeline
#                   walk of /mad-hunt). 2 sub-suites.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"

pass=0
fail=0
sep() { printf '%.0s═' $(seq 1 74); echo; }

section() {
  sep
  printf " %s\n" "$1"
  sep
}

section "SUITE 1/2  intelligence — retrieval + state layer"
if bash "$REPO/tests/intelligence/run-all.sh"; then
  pass=$((pass+1))
else
  fail=$((fail+1))
fi

echo ""
section "SUITE 2/2  e2e — operator-integration (scope gate + full pipeline)"
if bash "$REPO/tests/e2e/run-all.sh"; then
  pass=$((pass+1))
else
  fail=$((fail+1))
fi

echo ""
sep
if [ "$fail" -eq 0 ]; then
  echo " ✓ ALL TEST SUITES PASSED  ($pass/2)"
  exit 0
else
  echo " ✗ FAILURES: $fail/2 top-level suites"
  exit 1
fi
