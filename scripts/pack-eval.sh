#!/usr/bin/env bash
# pack-eval.sh — A/B impact scorecard per pack.
#
# For each pack in brain/registry/pack-index.jsonl and each query in
# brain/eval/reference-queries.jsonl, count records that WOULD surface via
# brain.sh recall-class/search, WITH the pack vs WITHOUT the pack. Delta =
# the pack's unique contribution to retrieval.
#
# contribution_score = (sum of deltas across queries) / (total records surfaced)
#
# High score = pack is unique and load-bearing. Zero = pack is redundant
# (other packs cover the same class). Per user directive: "only call a pack
# 'integrated' when it measurably improves audits" — this is the measure.
#
# Modes:
#   --report (default)  human-readable table sorted by contribution
#   --json              one JSONL row per pack, machine-readable
#
# Output: contribution_score per pack, plus per-query delta breakdown when
# --verbose. Records surfaced counted directly from JSONL via jq — no
# telemetry pollution during the eval run.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

MODE="${1:-report}"
case "$MODE" in
  --report|report) MODE="report" ;;
  --json)          MODE="json" ;;
  --verbose|-v)    MODE="verbose" ;;
  --help|-h) sed -n '2,25p' "$0" | sed 's/^# \?//'; exit 0 ;;
  *) echo "usage: pack-eval.sh [--report|--json|--verbose]" >&2; exit 2 ;;
esac

REFQ="brain/eval/reference-queries.jsonl"
PIDX="brain/registry/pack-index.jsonl"
LES="brain/lessons.jsonl"
PAT="brain/patterns.jsonl"
TOL="brain/tools.jsonl"

[ -f "$REFQ" ] || { echo "⛔ $REFQ missing" >&2; exit 3; }
[ -f "$PIDX" ] || { echo "⛔ $PIDX missing" >&2; exit 3; }
command -v jq >/dev/null || { echo "⛔ jq required" >&2; exit 3; }

# ── For one JSONL file + query, count records matching the query ──
# args: jsonl_file, query_type (recall-class|search), query_value, exclude_pack
count_matches() {
  local jl="$1" qtype="$2" qval="$3" excl="$4"
  [ -f "$jl" ] || { echo 0; return; }

  local excl_filter='select(true)'
  [ -n "$excl" ] && excl_filter="select((.source_pack // \"\") != \"$excl\")"

  local base_filter
  if [ "$qtype" = "recall-class" ]; then
    base_filter="select(.id) | select(.class == \"$qval\")"
  else
    # search — case-insensitive substring across any string field
    local ql; ql=$(printf '%s' "$qval" | tr '[:upper:]' '[:lower:]')
    base_filter="select(.id) | . as \$rec | select([.[] | select(type == \"string\") | ascii_downcase] | any(contains(\"$ql\")))"
  fi

  # wc -l always returns a numeric count (no exit-1 quirk like grep -c)
  jq -c "$base_filter | $excl_filter" "$jl" 2>/dev/null | wc -l | tr -d ' '
}

# ── For one pack, compute total contribution across the reference query set ──
score_pack() {
  local pack="$1"
  local total_with=0 total_without=0
  local queries_moved=0 total_queries=0

  while IFS= read -r q; do
    total_queries=$((total_queries + 1))
    local qtype qval
    qtype=$(echo "$q" | jq -r '.type')
    qval=$(echo "$q" | jq -r '.query')

    # Sum across all three JSONL files (patterns, lessons, tools)
    local with=0 without=0
    for jl in "$PAT" "$LES" "$TOL"; do
      with=$((with + $(count_matches "$jl" "$qtype" "$qval" "")))
      without=$((without + $(count_matches "$jl" "$qtype" "$qval" "$pack")))
    done

    total_with=$((total_with + with))
    total_without=$((total_without + without))

    local delta=$((with - without))
    if [ "$delta" -gt 0 ]; then
      queries_moved=$((queries_moved + 1))
      [ "$MODE" = "verbose" ] && printf '    %s (%s): with=%d  without=%d  delta=+%d\n' "$qtype" "$qval" "$with" "$without" "$delta"
    fi
  done < <(jq -c 'select(.type)' "$REFQ")

  local delta=$((total_with - total_without))
  local pct="0.00"
  [ "$total_with" -gt 0 ] && pct=$(awk -v d="$delta" -v t="$total_with" 'BEGIN{printf "%.2f", (d*100)/t}')

  # Emit result — mode-specific
  case "$MODE" in
    json)
      printf '{"pack":"%s","queries_moved":%d,"total_queries":%d,"records_with":%d,"records_without":%d,"delta":%d,"contribution_score":%s}\n' \
        "$pack" "$queries_moved" "$total_queries" "$total_with" "$total_without" "$delta" "$pct"
      ;;
    verbose)
      printf '\n══════ %s ══════\n' "$pack"
      printf '  queries moved: %d/%d   delta: +%d records   contribution: %s%%\n' \
        "$queries_moved" "$total_queries" "$delta" "$pct"
      ;;
    report)
      printf '  %-30s  moved:%2d/%2d  Δ:+%-3d  contrib:%6s%%\n' \
        "$pack" "$queries_moved" "$total_queries" "$delta" "$pct"
      ;;
  esac
}

# ── main ──
if [ "$MODE" != "json" ]; then
  echo "══════════════════════════════════════════════════════════════════════════"
  echo " pack A/B eval — per-pack unique contribution to retrieval"
  echo " (Δ = records this pack uniquely brings; contribution = Δ / total * 100%)"
  echo "══════════════════════════════════════════════════════════════════════════"
fi

# Sort packs by name for deterministic output; caller can re-sort by contribution
TMPOUT=$(mktemp)
while IFS= read -r pack; do
  score_pack "$pack" >> "$TMPOUT"
done < <(jq -r 'select(.pack) | .pack' "$PIDX")

if [ "$MODE" = "report" ]; then
  # Sort by contribution_score descending — meaningful ranking
  sort -t'%' -k1,1r "$TMPOUT" | sort -t':' -k5 -rn
  echo "──────────────────────────────────────────────────────────────────────────"
  echo "Legend: contribution=0% means the pack is redundant (other packs cover"
  echo "        the same classes/queries). High contribution = uniquely load-bearing."
  echo "══════════════════════════════════════════════════════════════════════════"
elif [ "$MODE" = "verbose" ]; then
  cat "$TMPOUT"
else
  cat "$TMPOUT"
fi
rm -f "$TMPOUT"
