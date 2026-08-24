#!/usr/bin/env bash
# T3MP3ST ingest — scan a repo or payload set and PROPOSE how to fold it into the toolkit.
# Read-only: it never modifies the skill; it prints a merge plan for you to apply.
# Usage:
#   ingest.sh <repo-or-file>            → classify + propose merges
set -uo pipefail
SRC="${1:-}"; [ -n "$SRC" ] || { echo "usage: ingest.sh <repo-dir-or-payload-file>"; exit 2; }
[ -e "$SRC" ] || { echo "⛔ not found: $SRC"; exit 2; }
SK=~/.claude/skills/mad-hacks
echo "==================== T3MP3ST INGEST ===================="
echo "Source: $SRC"; echo

if [ -f "$SRC" ]; then
  echo "[TYPE] file — treating as a payload/wordlist."
  echo "[PROPOSE] → add curated entries to $SK/references/payloads.md under the matching vuln class."
  echo "[PREVIEW] first lines:"; head -8 "$SRC" | sed 's/^/    /'
  echo; echo "[NEXT] Have Claude read it, dedupe against payloads.md, and append only novel, class-tagged probes."
  exit 0
fi

echo "[TYPE] directory — scanning for reusable assets..."
scan(){ grep -rIl "$1" "$SRC" 2>/dev/null | grep -vE 'node_modules/|\.git/' | head -8; }

echo; echo "── System prompts / agent definitions (→ new t3-* subagent or references/prompts/) ──"
grep -rIlE "You are|system prompt|role:|persona|You're an? (elite|expert)" "$SRC" 2>/dev/null | grep -viE 'node_modules|\.git' | head -10 || echo "  (none obvious)"

echo; echo "── Payloads / wordlists (→ references/payloads.md) ──"
find "$SRC" -type f \( -iname '*payload*' -o -iname '*wordlist*' -o -iname '*.txt' \) 2>/dev/null | grep -viE 'node_modules|\.git|license|readme' | head -12 || echo "  (none)"

echo; echo "── Tools / scripts (→ references/arsenal.md as adapters, or scripts/) ──"
find "$SRC" -maxdepth 3 -type f \( -name '*.sh' -o -name '*.py' -o -name '*.mjs' \) 2>/dev/null | grep -viE 'node_modules|test|\.git' | head -12 || echo "  (none)"

echo; echo "── Detection rules (nuclei/semgrep/yara → arsenal usage or a rules/ dir) ──"
find "$SRC" -type f \( -iname '*.yaml' -o -iname '*.yar' \) 2>/dev/null | xargs grep -lIE 'id:|rule |matchers:' 2>/dev/null | head -10 || echo "  (none)"

echo; echo "── Methodology / playbooks (→ references/ or a mission family) ──"
find "$SRC" -iname '*.md' 2>/dev/null | grep -viE 'node_modules|\.git|CHANGELOG|LICENSE' | head -10 || echo "  (none)"

cat <<EOF

==================== MERGE PLAN (apply with Claude) ====================
1. Prompts    → author a new ~/.claude/agents/t3-<name>.md (verbatim prompt in the body or in references/prompts/), following the existing t3-* format.
2. Payloads   → dedupe + class-tag into references/payloads.md (keep it curated, not a dump).
3. Tools      → add an adapter row to references/arsenal.md (binary, risk, execution mode, commandHint) or drop a wrapper in scripts/.
4. Rules      → reference nuclei/semgrep/yara templates from arsenal usage; store custom rules in a rules/ dir.
5. Methodology→ fold into the matching references/mission-families.md family or add a new runbook section.
ALWAYS: keep the doctrine + gates intact; new material is evidence-tools, never new authority.
=======================================================================
EOF
