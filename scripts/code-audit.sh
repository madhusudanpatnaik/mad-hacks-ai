#!/usr/bin/env bash
# T3MP3ST code-audit — keyless white-box source review (all local_read/safe).
# Secrets + dependency risk + dangerous-sink grep. No network, no keys.
# Usage: code-audit.sh <path-to-repo>   (default: .)
set -uo pipefail
SRC="${1:-.}"
[ -d "$SRC" ] || { echo "⛔ not a directory: $SRC"; exit 2; }
NAME="$(basename "$(cd "$SRC" && pwd)")"
OUT="./.t3mp3st/code-${NAME}/audit"; mkdir -p "$OUT"
have(){ command -v "$1" >/dev/null 2>&1; }
sec(){ echo; echo "=== $1 ==="; }
echo "T3MP3ST code-audit → $SRC → $OUT"

sec "Secrets (gitleaks)"
if have gitleaks; then gitleaks detect --source "$SRC" --no-git --redact --report-format json --report-path "$OUT/gitleaks.json" 2>/dev/null || true
  n=$(jq 'length' "$OUT/gitleaks.json" 2>/dev/null || echo 0); echo "  gitleaks findings: $n (redacted → gitleaks.json)"
else echo "  (gitleaks not installed)"; fi

sec "Secrets (trufflehog, verified)"
if have trufflehog; then trufflehog filesystem "$SRC" --json --no-update 2>/dev/null | jq -rc 'select(.Verified==true) | "- VERIFIED "+(.DetectorName)+" in "+(.SourceMetadata.Data.Filesystem.file // "?")' 2>/dev/null | tee "$OUT/trufflehog-verified.txt" | head -20
  [ -s "$OUT/trufflehog-verified.txt" ] || echo "  (no VERIFIED secrets)"
else echo "  (trufflehog not installed)"; fi

sec "Dependency risk"
DEPFILES=$(cd "$SRC" && ls package.json requirements.txt go.mod Gemfile pom.xml build.gradle Cargo.toml composer.json 2>/dev/null | tr '\n' ' ')
echo "  manifests: ${DEPFILES:-none}"
if have osv-scanner; then osv-scanner --format json --recursive "$SRC" > "$OUT/osv.json" 2>/dev/null || true; echo "  osv-scanner → osv.json"
elif have grype; then grype "dir:$SRC" -o json > "$OUT/grype.json" 2>/dev/null || true; echo "  grype → grype.json"
else echo "  (no osv-scanner/grype — check manifests manually vs NVD/OSV; note pinned vs floating versions)"; fi

sec "Dangerous sinks (semgrep or grep)"
if have semgrep; then semgrep scan --config auto --json --quiet "$SRC" > "$OUT/semgrep.json" 2>/dev/null || true
  jq -r '.results[] | "- ["+(.extra.severity // "INFO")+"] "+(.check_id|split(".")|last)+" @ "+(.path)+":"+(.start.line|tostring)' "$OUT/semgrep.json" 2>/dev/null | head -40 | tee "$OUT/sinks.txt"
else
  echo "  (semgrep not installed — pattern grep for common sinks)"
  {
    echo "## command exec"; grep -rInE 'os\.system|subprocess\.(call|run|Popen)|child_process\.(exec|spawn)|Runtime\.getRuntime|shell_exec|passthru|`' "$SRC" 2>/dev/null | grep -vE 'node_modules/|\.min\.js' | head -20
    echo "## eval / deserialization"; grep -rInE "\beval\(|\bexec\(|pickle\.loads|yaml\.load\(|Marshal\.load|unserialize\(|readObject\(" "$SRC" 2>/dev/null | grep -vE 'node_modules/' | head -20
    echo "## SQL string-building"; grep -rInE "(SELECT|INSERT|UPDATE|DELETE).*(\+|%|\|\|| f\"| \`).*(req|param|input|user|id)" "$SRC" 2>/dev/null | grep -vE 'node_modules/' | head -20
    echo "## DOM XSS sinks"; grep -rInE "innerHTML|dangerouslySetInnerHTML|document\.write|insertAdjacentHTML|v-html" "$SRC" 2>/dev/null | grep -vE 'node_modules/|\.min\.js' | head -20
    echo "## SSRF / open fetch"; grep -rInE "requests\.get\(|urllib|fetch\(|axios\.(get|post)\(|http\.get\(" "$SRC" 2>/dev/null | grep -vE 'node_modules/' | head -15
  } | tee "$OUT/sinks.txt"
fi

sec "Exposure hygiene"
(cd "$SRC" && { [ -e .git ] && echo "  ⚠️ .git present (ensure not web-served)"; ls .env* 2>/dev/null | sed 's/^/  ⚠️ env file: /'; })
echo; echo "✅ audit artifacts → $OUT/"
echo "   Next: for each sink, TRACE entry→sink reachability (is user input tainted to it?), then VERIFY with a PoC before it becomes a finding (pipeline.md)."
