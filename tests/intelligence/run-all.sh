#!/usr/bin/env bash
# run-all.sh — run every intelligence-layer test + emit a scoreboard.
#
# Runs (in order):
#   1. test_retrieval.py   — MRR / R@5 / R@10 / P@5 / nDCG@10 over 64 canonical queries
#   2. test_retrieval.py --category {direct,synonym,indirect,ambiguous,tech-cross}
#                          — per-category breakdown (adversarial harness)
#   3. test_state.py       — state distinguishability + no-silent-upgrade
#   4. test_end_to_end.py  — full observe → recall → hypothesis → test → exhaust → recall loop
#
# Exit: 0 pass, 1 fail. Prints a compact scoreboard suitable for CI + human eyes.

set -u
cd "$(dirname "$0")/../.." || exit 2

FAIL=0
run_step() {
  local name="$1"; shift
  echo ""
  echo "────────────────────────────────────────────────────────────────────────"
  echo " $name"
  echo "────────────────────────────────────────────────────────────────────────"
  if "$@"; then :; else FAIL=$((FAIL+1)); fi
}

echo "═══════════════════════════════════════════════════════════════════════"
echo " intelligence-layer regression suite"
echo "═══════════════════════════════════════════════════════════════════════"

run_step "1/6  retrieval — ALL queries (aggregate)" \
  python3 tests/intelligence/test_retrieval.py --quiet

for cat in direct synonym indirect ambiguous tech-cross; do
  run_step "     retrieval — category=$cat" \
    python3 tests/intelligence/test_retrieval.py --category "$cat" --quiet
done

run_step "5/6  state — adversarial (negative-knowledge, scope, no-upgrade)" \
  python3 tests/intelligence/test_state.py --verbose

run_step "6/6  end-to-end — full intelligence loop" \
  python3 tests/intelligence/test_end_to_end.py

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo " ✓ ALL SUITES PASSED"
  exit 0
else
  echo " ✗ $FAIL SUITE(S) FAILED"
  exit 1
fi
