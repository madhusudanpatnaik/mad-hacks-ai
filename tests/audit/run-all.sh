#!/usr/bin/env bash
# tests/audit/run-all.sh — sliced-audit control-plane regression suite.
#
# One sub-suite (test_audit.py) covering 5 areas:
#   1. slice selection (audit-slice.sh next)
#   2. hunter scoring (audit-hunt.sh 3-dim scoring)
#   3. retrieval filtering (intelligence-recall.sh --slice)
#   4. state transitions (init/start/complete/decision/accounting)
#   5. verifier schema (verifier-strict.md verdict shape)
#
# Uses /usr/bin/python3 (has PyYAML on macOS via Xcode CLT); falls back to
# the standard probe if not available.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"

# Pick a python with PyYAML
PY=""
for py in /usr/bin/python3 /opt/homebrew/bin/python3 /usr/local/bin/python3 python3; do
  if command -v "$py" >/dev/null 2>&1 && "$py" -c "import yaml" >/dev/null 2>&1; then
    PY="$py"; break
  fi
done
if [ -z "$PY" ]; then
  echo "tests/audit: no python3 with PyYAML found — skipping audit suite" >&2
  echo "  install via: pip3 install --user pyyaml  |  apk add py3-yaml  |  apt install python3-yaml" >&2
  exit 0    # not a failure — audit tests are opt-in via PyYAML availability
fi

sep() { printf '%.0s─' $(seq 1 72); echo; }
sep
echo " audit — sliced-audit control-plane regression"
sep
if "$PY" "$REPO/tests/audit/test_audit.py"; then
  echo ""
  echo " ✓ AUDIT SUITE PASSED"
  exit 0
else
  echo ""
  echo " ✗ AUDIT SUITE FAILED"
  exit 1
fi
