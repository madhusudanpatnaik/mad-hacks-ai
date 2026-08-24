#!/usr/bin/env bash
# mad-Hacks_ai → ruflo memory bridge (OPTIONAL intelligence layer).
#
# The native file-brain is the spine. This exports it as JSONL so it can be pushed into
# ruflo's semantic memory (cross-engagement recall + pattern-learning). ruflo tools are MCP,
# not shell — this script PREPARES the payload; Claude then calls the MCP in a loop:
#
#   for each line in the export:  mcp__ruflo__memory_store { key, value, namespace: "mad-hacks" }
#   or bulk:                      mcp__ruflo__memory_import_claude  (point it at the export)
#   recall later:                 mcp__ruflo__memory_search { query, namespace: "mad-hacks" }
#
# Why bridge at all: file-brain = exact recall by target; ruflo = fuzzy/semantic recall across
# ALL engagements ("have we seen this tech stack / this bug pattern before?") + learned patterns.
# Use ruflo's MEMORY only — keep the t3-* subagents as the orchestrator, not ruflo's swarm.
#
# Usage: brain-sync-ruflo.sh  → writes brain/ruflo-export.jsonl
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRAIN="$ROOT/brain"; OUT="$BRAIN/ruflo-export.jsonl"; : > "$OUT"
esc(){ python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip()))' 2>/dev/null || printf '"%s"' "$(cat)"; }
emit(){ printf '{"namespace":"mad-hacks","key":%s,"kind":%s,"value":%s}\n' "$(printf '%s' "$1"|esc)" "$(printf '%s' "$2"|esc)" "$(printf '%s' "$3"|esc)" >> "$OUT"; }

# lessons + tools (global heuristics)
[ -f "$BRAIN/lessons.md" ] && grep '^- ' "$BRAIN/lessons.md" | while IFS= read -r l; do emit "lesson" "lesson" "${l#- }"; done
[ -f "$BRAIN/tools.md" ]   && grep '^- ' "$BRAIN/tools.md"   | while IFS= read -r l; do emit "tool" "tool" "${l#- }"; done
# per-target findings + exhausted vectors
for t in "$BRAIN"/targets/*.md; do
  [ -f "$t" ] || continue; host="$(basename "$t" .md)"
  grep '^- ' "$t" | while IFS= read -r l; do emit "$host" "target-note" "$l"; done
done
# payload class index (not the raw probes — just which classes exist + counts)
for p in "$BRAIN"/payloads/*.txt; do
  [ -f "$p" ] || continue; emit "payloads:$(basename "$p" .txt)" "payload-class" "$(basename "$p" .txt): $(wc -l < "$p" | tr -d ' ') probes"
done

echo "✅ exported $(wc -l < "$OUT" | tr -d ' ') memory records → $OUT"
echo "   Next (Claude): load ruflo via ToolSearch, then bulk-store into namespace \"mad-hacks\"."
echo "   Recall in future runs with mcp__ruflo__memory_search before brain.sh recall."
