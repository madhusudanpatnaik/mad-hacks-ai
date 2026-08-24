#!/usr/bin/env bash
# T3MP3ST report — scaffold a finding, or assemble findings into a report.
# Usage:
#   report.sh finding <target> <slug>   → new findings/F-NNN-<slug>.md from template
#   report.sh build   <target>          → assemble findings/*.md + evidence index → report.md
set -euo pipefail
CMD="${1:-}"; TARGET="${2:-}"; SLUG="${3:-}"
[ -n "$TARGET" ] || { echo "usage: report.sh {finding <target> <slug> | build <target>}"; exit 2; }
BASE="./.t3mp3st/${TARGET}"; FIND="$BASE/findings"; EV="$BASE/evidence"
mkdir -p "$FIND" "$EV"

case "$CMD" in
  finding)
    [ -n "$SLUG" ] || { echo "usage: report.sh finding <target> <slug>"; exit 2; }
    N=$(printf 'F-%03d' "$(( $(ls "$FIND"/F-*.md 2>/dev/null | wc -l | tr -d ' ') + 1 ))")
    F="$FIND/${N}-${SLUG}.md"
    cat > "$F" <<EOF
# ${N}: <title — vuln + where>

- **Severity:**   info|low|medium|high|critical
- **CVSS:**       <vector + score>
- **CWE:**        CWE-XXX
- **Confidence:** hypothesis|probable|confirmed
- **Affected:**   <exact URL / host / file:line / resource id>
- **MITRE:**      <Txxxx>

## Summary
<what it is, one paragraph>

## Evidence
- EV-1: \`<command>\`
  \`\`\`
  <raw output excerpt — redact secrets/PII>
  \`\`\`
  (artifact: evidence/EV-1.txt)

## Reproduction
<exact minimal deterministic steps>

## Impact
<demonstrated, not theoretical — what an attacker can do + blast radius>

## Remediation
<specific fix>

## Retest
<acceptance criteria to confirm the fix closed it>

## Uncertainty
<what was NOT verified; residual risk>
EOF
    echo "✅ $F"
    echo "   Remember the gates: VERIFY (proof in real captured output) then REFUTE (try to disprove) before marking confirmed."
    ;;
  build)
    R="$BASE/report.md"
    {
      echo "# Security Assessment — ${TARGET}"
      echo; echo "_Generated $(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo 'UTC')_  · Operator: Claude Code (T3MP3ST keyless)"
      echo; echo "## Scope & authorization"
      if [ -f "$BASE/../SCOPE.md" ]; then echo "See SCOPE.md."; elif [ -f "./.t3mp3st/SCOPE.md" ]; then sed 's/^/> /' "./.t3mp3st/SCOPE.md" | head -20; else echo "> ⚠️ no SCOPE.md recorded."; fi
      echo; echo "## Findings"
      shopt -s nullglob
      files=("$FIND"/F-*.md)
      if [ ${#files[@]} -eq 0 ]; then echo "_No findings recorded._"; else
        for f in "${files[@]}"; do echo; echo "---"; echo; cat "$f"; done
      fi
      echo; echo "---"; echo; echo "## Evidence index"
      if ls "$EV"/* >/dev/null 2>&1; then for e in "$EV"/*; do echo "- $(basename "$e")  ($(wc -l < "$e" 2>/dev/null | tr -d ' ') lines)"; done; else echo "_none_"; fi
      echo; echo "## Methodology"
      echo "T3MP3ST keyless kill chain: classify → scope → decompose → recon → weaponize → exploit → VERIFY → REFUTE → report. Tools driven over Bash by Claude Code as backbone."
    } > "$R"
    echo "✅ assembled $R  (findings: $(ls "$FIND"/F-*.md 2>/dev/null | wc -l | tr -d ' '))"
    ;;
  *) echo "usage: report.sh {finding <target> <slug> | build <target>}"; exit 2;;
esac
