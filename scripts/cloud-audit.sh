#!/usr/bin/env bash
# mad-Hacks_ai cloud-audit — keyless IaC / cloud-config misconfig review (all local_read/safe).
# NO live cloud access, NO credentials — static analysis of IaC + configs only.
# Usage: cloud-audit.sh <path-to-repo-or-iac-dir>   (default: .)
set -uo pipefail
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
SRC="${1:-.}"; [ -d "$SRC" ] || { echo "⛔ not a directory: $SRC"; exit 2; }
NAME="$(basename "$(cd "$SRC" && pwd)")"; OUT="./.t3mp3st/cloud-${NAME}/audit"; mkdir -p "$OUT"
have(){ command -v "$1" >/dev/null 2>&1; }
sec(){ echo; echo "=== $1 ==="; }
echo "mad-Hacks_ai cloud-audit → $SRC → $OUT  (static, keyless)"

sec "IaC files detected"
find "$SRC" -maxdepth 4 \( -name '*.tf' -o -name '*.yaml' -o -name '*.yml' -o -name 'Dockerfile*' -o -name '*.json' \) 2>/dev/null \
  | grep -viE 'node_modules|\.git' | head -20 | sed 's/^/  /' || echo "  (none)"

sec "Misconfig scan (checkov / trivy)"
if have checkov; then checkov -d "$SRC" -o json --compact > "$OUT/checkov.json" 2>/dev/null || true
  jq -r '.results.failed_checks[]? | "- ["+.severity//"MEDIUM"+"] "+.check_id+" "+.check_name+" @ "+.file_path+":"+((.file_line_range[0])|tostring)' "$OUT/checkov.json" 2>/dev/null | head -40 | tee "$OUT/findings.txt"
elif have trivy; then trivy config --format json "$SRC" > "$OUT/trivy.json" 2>/dev/null || true
  jq -r '.Results[]?.Misconfigurations[]? | "- ["+.Severity+"] "+.ID+" "+.Title' "$OUT/trivy.json" 2>/dev/null | head -40 | tee "$OUT/findings.txt"
else echo "  (no checkov/trivy — grep fallback)"
  { echo "## public/open access"; grep -rInE '0\.0\.0\.0/0|"\*"|public-read|AllUsers|allUsers|"Effect": *"Allow".*"\*"' "$SRC" 2>/dev/null | grep -viE 'node_modules|\.git' | head -20
    echo "## hardcoded secrets in IaC"; grep -rInE 'password|secret|api_?key|access_?key|token' "$SRC" 2>/dev/null | grep -iE '=|:' | grep -viE 'node_modules|\.git|description|#' | head -15
    echo "## disabled security"; grep -rInE 'encrypted *= *false|enable_?logging *= *false|skip_?final_?snapshot *= *true|publicly_accessible *= *true' "$SRC" 2>/dev/null | head -15
  } | tee "$OUT/findings.txt"
fi

sec "Secrets in cloud configs (gitleaks)"
have gitleaks && { gitleaks detect --source "$SRC" --no-git --redact --report-format json --report-path "$OUT/gitleaks.json" 2>/dev/null || true; jq 'length' "$OUT/gitleaks.json" 2>/dev/null | xargs echo "  secrets:"; }

echo; echo "✅ cloud-audit → $OUT/  — VERIFY each misconfig is reachable/exploitable before it's a finding."
