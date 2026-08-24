#!/usr/bin/env bash
# mad-Hacks_ai contract-audit — keyless static Solidity/smart-contract review (all local_read/safe).
# NO on-chain tx, NO signing — static analysis only. Usage: contract-audit.sh <path-to-contracts>
set -uo pipefail
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
SRC="${1:-.}"; [ -e "$SRC" ] || { echo "usage: contract-audit.sh <dir-or-.sol>"; exit 2; }
NAME="$(basename "$(cd "$(dirname "$SRC")" && pwd)")"; OUT="./.t3mp3st/contract-${NAME}/audit"; mkdir -p "$OUT"
have(){ command -v "$1" >/dev/null 2>&1; }
sec(){ echo; echo "=== $1 ==="; }
echo "mad-Hacks_ai contract-audit → $SRC → $OUT  (static, keyless — no on-chain actions)"

sec "Solidity files"; find "$SRC" -name '*.sol' 2>/dev/null | grep -viE 'node_modules|lib/forge-std|openzeppelin' | head -20 | sed 's/^/  /' || echo "  (none)"

sec "Static analysis (slither)"
if have slither; then slither "$SRC" --json "$OUT/slither.json" 2>/dev/null || true
  jq -r '.results.detectors[]? | "- ["+.impact+"] "+.check+": "+(.description|split("\n")[0])' "$OUT/slither.json" 2>/dev/null | head -40 | tee "$OUT/findings.txt"
elif have solhint; then solhint "$SRC/**/*.sol" 2>/dev/null | head -40 | tee "$OUT/findings.txt"
else echo "  (no slither/solhint — grep for classic bug patterns)"
  { echo "## reentrancy (state change after external call)"; grep -rInE '\.call\{|\.call\(|\.transfer\(|\.send\(' "$SRC" 2>/dev/null | grep -viE 'node_modules|lib/' | head -15
    echo "## access control gaps"; grep -rInE 'function .*(public|external)' "$SRC" 2>/dev/null | grep -viE 'onlyOwner|require|view|pure|node_modules' | head -15
    echo "## dangerous ops"; grep -rInE 'delegatecall|selfdestruct|tx\.origin|block\.timestamp|blockhash|assembly' "$SRC" 2>/dev/null | grep -viE 'node_modules|lib/' | head -15
    echo "## unchecked math / low-level"; grep -rInE 'unchecked *\{|assembly *\{' "$SRC" 2>/dev/null | grep -viE 'node_modules' | head -10
  } | tee "$OUT/findings.txt"
fi

sec "Secrets (private keys / mnemonics in repo)"
have gitleaks && { gitleaks detect --source "$SRC" --no-git --redact --report-format json --report-path "$OUT/gitleaks.json" 2>/dev/null || true; jq 'length' "$OUT/gitleaks.json" 2>/dev/null | xargs echo "  secrets:"; }

echo; echo "✅ contract-audit → $OUT/  — VERIFY each issue is exploitable (write a Foundry PoC in a fork, never mainnet)."
echo "   Deep methodology: references/knowledge-packs.md + arsenal.md (slither/myth/echidna/forge)."
