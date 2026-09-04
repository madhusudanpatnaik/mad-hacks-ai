#!/usr/bin/env bash
# tests/e2e/run-all.sh — the operator-integration regression suite.
#
# Distinct from tests/intelligence/ (retrieval-layer measurement). This suite
# exercises the ACTUAL /mad-hunt organism at the pipeline level:
#   * scope adversarial gate (45 assertions)
#   * agent portability + provenance (255 assertions)
#   * end-to-end engagement chain (65 assertions)
#
# Runs under 60 seconds on a warm brain. Exit 0 = all green, 1 = any failure.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"

pass=0
fail=0
sep() { printf '%.0s─' $(seq 1 72); echo; }

section() {
  local title="$1"
  sep
  printf " %s\n" "$title"
  sep
}

section "1/3  scope adversarial boundary (14 attack variants + side-effect invariants)"
if python3 "$REPO/tests/e2e/test_scope_boundary.py"; then
  pass=$((pass+1))
else
  fail=$((fail+1))
fi

echo ""
section "2/3  agent portability + provenance (fresh sync / corrupt / delete / manifest self-consistency)"
if python3 "$REPO/tests/e2e/test_agent_portability.py"; then
  pass=$((pass+1))
else
  fail=$((fail+1))
fi

echo ""
section "3/3  end-to-end engagement chain (scope → state → recon → recall → evidence → report)"
if python3 "$REPO/tests/e2e/test_engagement_e2e.py"; then
  pass=$((pass+1))
else
  fail=$((fail+1))
fi

echo ""
sep
if [ "$fail" -eq 0 ]; then
  echo " ✓ ALL E2E SUITES PASSED  ($pass/3)"
  exit 0
else
  echo " ✗ FAILURES: $fail/3 suites"
  exit 1
fi
