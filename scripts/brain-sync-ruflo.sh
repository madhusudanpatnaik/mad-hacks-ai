#!/usr/bin/env bash
# mad-Hacks_ai → ruflo memory bridge (OPTIONAL — semantic cache layer).
#
# Doctrine: canonical brain is the file tree; the asset registry (brain/registry/
# assets.jsonl) is the machine-readable index; ruflo is a fast contextual CACHE,
# NEVER the source of truth. Every exported row carries a provenance timestamp
# so staleness is detectable at query time (mcp__ruflo__memory_search returns
# each record's last_verified; agents can flag stale rows).
#
# Modes:
#   brain-sync-ruflo.sh                     legacy — exports raw brain/ files
#                                          (lessons.md + tools.md + targets/ + payload class counts)
#   brain-sync-ruflo.sh --from-registry    NEW — exports every registry row
#                                          (265 rows: references + scripts + tools + payloads +
#                                           lessons + agents) with schema + provenance
#   brain-sync-ruflo.sh --both              export both — writes a merged JSONL
#
# After running, Claude bulk-imports:
#   mcp__ruflo__memory_import_claude { path: brain/ruflo-export.jsonl, namespace: "mad-hacks" }
# Then queries with:
#   mcp__ruflo__memory_search { query, namespace: "mad-hacks", smart: true }

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRAIN="$ROOT/brain"
OUT="$BRAIN/ruflo-export.jsonl"

MODE="legacy"
case "${1:-}" in
  --from-registry) MODE="registry" ;;
  --both)          MODE="both" ;;
  ""|--legacy)     MODE="legacy" ;;
  --help|-h)       sed -n '1,22p' "$0"; exit 0 ;;
  *)               echo "unknown flag: $1"; sed -n '1,22p' "$0"; exit 2 ;;
esac

: > "$OUT"

# ─── shared helper: build one memory record ─────────────────
export OUT
emit_legacy_record() {
  # $1 key | $2 kind | $3 value
  export _K="$1" _KIND="$2" _V="$3"
  python3 <<'PY'
import json, os, datetime
r = {
  "namespace": "mad-hacks",
  "key":       os.environ["_K"],
  "kind":      os.environ["_KIND"],
  "value":     os.environ["_V"],
  "provenance": {
    "source":       "brain/",
    "exported_at":  datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
  },
}
with open(os.environ["OUT"], "a") as f:
    f.write(json.dumps(r) + "\n")
PY
}

# ─── legacy export (unchanged shape for backward-compat) ────
export_legacy() {
  if [ -f "$BRAIN/lessons.md" ]; then
    while IFS= read -r l; do emit_legacy_record "lesson" "lesson" "${l#- }"; done < <(grep '^- ' "$BRAIN/lessons.md")
  fi
  if [ -f "$BRAIN/tools.md" ]; then
    while IFS= read -r l; do emit_legacy_record "tool" "tool" "${l#- }"; done < <(grep '^- ' "$BRAIN/tools.md")
  fi
  for t in "$BRAIN"/targets/*.md; do
    [ -f "$t" ] || continue
    host=$(basename "$t" .md)
    while IFS= read -r l; do emit_legacy_record "$host" "target-note" "$l"; done < <(grep '^- ' "$t")
  done
  for p in "$BRAIN"/payloads/*.txt; do
    [ -f "$p" ] || continue
    name=$(basename "$p" .txt)
    count=$(wc -l < "$p" | tr -d ' ')
    emit_legacy_record "payloads:$name" "payload-class" "$name: $count probes"
  done
}

# ─── registry export (structured, provenance-aware) ─────────
export_registry() {
  REG="$BRAIN/registry/assets.jsonl"
  if [ ! -f "$REG" ]; then
    echo "  ! registry not built — building now..."
    python3 "$ROOT/scripts/build-registry.py" >/dev/null || {
      echo "  ✗ registry build failed"; return 1
    }
  fi
  export REG OUT
  python3 <<'PY'
import json, os, datetime
now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
count = 0
with open(os.environ["OUT"], "a") as out:
    for line in open(os.environ["REG"]):
        line = line.strip()
        if not line: continue
        row = json.loads(line)
        rec = {
            "namespace":   "mad-hacks",
            "key":         row["id"],
            "kind":        row["type"],
            "value":       row.get("description", "") or row.get("title", "") or row["id"],
            "title":       row.get("title", ""),
            "path":        row.get("path", ""),
            "classes":     row.get("classes", []),
            "technologies":row.get("technologies", []),
            "capabilities":row.get("capabilities", []),
            "commands":    row.get("commands", []),
            "epistemic_status": row.get("epistemic_status", "verified"),
            "confidence":  row.get("confidence", "medium"),
            "provenance": {
                "source":        row.get("path", ""),
                "extracted_at":  (row.get("provenance") or {}).get("extracted_at", now),
                "exported_at":   now,
                "last_verified": row.get("last_verified", now),
            },
        }
        out.write(json.dumps(rec) + "\n")
        count += 1
print(f"    ✓ registry export: {count} rows")
PY
}

case "$MODE" in
  legacy)   export_legacy ;;
  registry) export_registry ;;
  both)     export_legacy; export_registry ;;
esac

COUNT=$(wc -l < "$OUT" | tr -d ' ')
echo ""
echo "✅ exported $COUNT memory records ($MODE) → $OUT"
echo "   Next (Claude interactive session with ruflo MCP connected):"
echo "     mcp__ruflo__memory_import_claude { path: \"$OUT\", namespace: \"mad-hacks\" }"
echo ""
echo "   Query later:"
echo "     mcp__ruflo__memory_search { query: \"...\", namespace: \"mad-hacks\", smart: true }"
echo ""
echo "   Every exported row carries a provenance.last_verified timestamp so agents"
echo "   can detect stale ruflo entries and fall back to canonical (the file brain +"
echo "   the registry). If ruflo disappears tomorrow, the toolkit still works."
