#!/usr/bin/env bash
# tests/run-all.sh — the ENTIRE test surface.
#
# 3 suites, 439+ assertions:
#   intelligence/ — retrieval + state (retrieval MRR, per-category floors,
#                   state-as-filter invariants). 6 sub-suites, 49 assertions.
#   e2e/          — operator-integration (scope + portability + engagement
#                   chain). 3 sub-suites, 365 assertions.
#   audit/        — sliced-audit control plane (slice selection, hunter
#                   scoring, retrieval filtering, state transitions,
#                   verifier schema). 1 sub-suite, 25 assertions.
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

section "SUITE 1/3  intelligence — retrieval + state layer"
if bash "$REPO/tests/intelligence/run-all.sh"; then
  pass=$((pass+1))
else
  fail=$((fail+1))
fi

echo ""
section "SUITE 2/3  e2e — operator-integration (scope gate + full pipeline)"
if bash "$REPO/tests/e2e/run-all.sh"; then
  pass=$((pass+1))
else
  fail=$((fail+1))
fi

echo ""
section "SUITE 3/3  audit — sliced-audit control plane"
if bash "$REPO/tests/audit/run-all.sh"; then
  pass=$((pass+1))
else
  fail=$((fail+1))
fi

echo ""
sep
if [ "$fail" -eq 0 ]; then
  echo " ✓ ALL TEST SUITES PASSED  ($pass/3)"
  exit 0
else
  echo " ✗ FAILURES: $fail/3 top-level suites"
  exit 1
fi
