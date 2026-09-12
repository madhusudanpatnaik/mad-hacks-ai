#!/usr/bin/env bash
# telemetry-report.sh — summarize brain/telemetry/retrievals.jsonl into an
# actionable per-session view. Every brain.sh recall-class / search that
# surfaces a JSONL record appends {ts, subcmd, query, record_type, record_id,
# source_pack} to that log. Without a reader, the eval loop is aspirational:
# this is the reader.
#
# Modes:
#   --report (default)  overview: per-pack contribution, top records, top queries
#   --pack <name>       drill into one pack's records and the queries that fired
#   --record <id>       show every retrieval of one specific record
#   --json              raw aggregation as JSONL (for feeding other tools)
#
# Time filters (all modes):
#   --since <YYYY-MM-DD> only include retrievals on/after this date
#   --last <hours>      last N hours (e.g. --last 24 for last day)
#
# Reads: brain/telemetry/retrievals.jsonl (session-local, gitignored)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

TELE="brain/telemetry/retrievals.jsonl"
MODE="report"
FILTER_PACK=""
FILTER_RECORD=""
SINCE=""
LAST_HOURS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --report|report) MODE="report"; shift ;;
    --json)          MODE="json"; shift ;;
    --pack)          MODE="pack"; FILTER_PACK="${2:-}"; shift 2 ;;
    --record)        MODE="record"; FILTER_RECORD="${2:-}"; shift 2 ;;
    --since)         SINCE="${2:-}"; shift 2 ;;
    --last)          LAST_HOURS="${2:-}"; shift 2 ;;
    --help|-h)       sed -n '2,20p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "usage: telemetry-report.sh [--report|--json|--pack <n>|--record <id>] [--since YYYY-MM-DD | --last <hrs>]" >&2; exit 2 ;;
  esac
done

[ -f "$TELE" ] || { echo "  no telemetry yet — brain.sh recall/search hasn't surfaced any JSONL records"; exit 0; }
command -v jq >/dev/null || { echo "⛔ jq required" >&2; exit 3; }

# Build a jq time filter. Records store ts as "YYYY-MM-DDTHH:MM:SSZ".
TIME_FILTER='select(.ts)'
if [ -n "$LAST_HOURS" ]; then
  # Convert "last N hours" to an ISO cutoff (portable macOS/Linux)
  CUTOFF=$(python3 -c "from datetime import datetime, timedelta, timezone; print((datetime.now(timezone.utc) - timedelta(hours=$LAST_HOURS)).strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>/dev/null)
  [ -n "$CUTOFF" ] && TIME_FILTER="select(.ts >= \"$CUTOFF\")"
elif [ -n "$SINCE" ]; then
  TIME_FILTER="select(.ts >= \"${SINCE}T00:00:00Z\")"
fi

# Total in-scope retrievals
TOTAL=$(jq -c "$TIME_FILTER" "$TELE" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TOTAL" -eq 0 ]; then
  echo "  no retrievals match the filter (mode=$MODE since=${SINCE:-any} last=${LAST_HOURS:-any}hrs)"
  exit 0
fi

# ── mode dispatch ──
case "$MODE" in
  json)
    jq -c "$TIME_FILTER" "$TELE"
    ;;

  pack)
    [ -n "$FILTER_PACK" ] || { echo "⛔ --pack requires a name" >&2; exit 2; }
    echo "══════════════════════════════════════════════════════════════════════════"
    echo " telemetry drill: source_pack=$FILTER_PACK  (last ${LAST_HOURS:-∞}hrs / since ${SINCE:-any})"
    echo "══════════════════════════════════════════════════════════════════════════"
    HITS=$(jq -c "$TIME_FILTER | select(.source_pack == \"$FILTER_PACK\")" "$TELE" | wc -l | tr -d ' ')
    echo "  total retrievals for this pack: $HITS / $TOTAL ($(awk -v h="$HITS" -v t="$TOTAL" 'BEGIN{printf "%.1f", h*100/t}')% share)"
    echo ""
    echo "  BY record (top 15):"
    jq -r "$TIME_FILTER | select(.source_pack == \"$FILTER_PACK\") | \"\(.record_id)  [\(.record_type)]\"" "$TELE" | sort | uniq -c | sort -rn | head -15 | awk '{printf "    %4d  %-16s %s\n", $1, $2, $3}'
    echo ""
    echo "  BY query (top 10):"
    jq -r "$TIME_FILTER | select(.source_pack == \"$FILTER_PACK\") | \"\(.subcmd) \(.query)\"" "$TELE" | sort | uniq -c | sort -rn | head -10 | awk '{n=$1; $1=""; printf "    %4d  %s\n", n, $0}'
    echo "══════════════════════════════════════════════════════════════════════════"
    ;;

  record)
    [ -n "$FILTER_RECORD" ] || { echo "⛔ --record requires an id (e.g. PAT-xa-01)" >&2; exit 2; }
    echo "══════════════════════════════════════════════════════════════════════════"
    echo " telemetry drill: record_id=$FILTER_RECORD"
    echo "══════════════════════════════════════════════════════════════════════════"
    HITS=$(jq -c "$TIME_FILTER | select(.record_id == \"$FILTER_RECORD\")" "$TELE" | wc -l | tr -d ' ')
    echo "  total retrievals for this record: $HITS"
    echo ""
    echo "  timeline (last 20):"
    jq -r "$TIME_FILTER | select(.record_id == \"$FILTER_RECORD\") | \"    \(.ts)  \(.subcmd)  \(.query)\"" "$TELE" | tail -20
    echo "══════════════════════════════════════════════════════════════════════════"
    ;;

  report|*)
    echo "══════════════════════════════════════════════════════════════════════════"
    echo " retrieval telemetry report  (window: since=${SINCE:-any} last=${LAST_HOURS:-∞}hrs)"
    echo "══════════════════════════════════════════════════════════════════════════"
    echo "  total in-scope retrievals: $TOTAL"
    echo ""
    echo "  BY source_pack (contribution to sessions in this window):"
    jq -r "$TIME_FILTER | .source_pack" "$TELE" | sort | uniq -c | sort -rn | \
      awk -v t="$TOTAL" '{printf "    %-30s  %4d  (%.1f%%)\n", $2, $1, $1*100/t}'
    echo ""
    echo "  BY record_type:"
    jq -r "$TIME_FILTER | .record_type" "$TELE" | sort | uniq -c | sort -rn | \
      awk -v t="$TOTAL" '{printf "    %-16s  %4d  (%.1f%%)\n", $2, $1, $1*100/t}'
    echo ""
    echo "  TOP records (which specific atoms fire most):"
    jq -r "$TIME_FILTER | \"\(.record_id) [\(.record_type)] \(.source_pack)\"" "$TELE" | sort | uniq -c | sort -rn | head -10 | \
      awk '{n=$1; $1=""; printf "    %4d  %s\n", n, $0}'
    echo ""
    echo "  TOP queries (what operators actually asked):"
    jq -r "$TIME_FILTER | \"\(.subcmd) \(.query)\"" "$TELE" | sort | uniq -c | sort -rn | head -10 | \
      awk '{n=$1; $1=""; printf "    %4d  %s\n", n, $0}'
    echo ""
    echo "  DEAD packs (zero retrievals in window — candidates for demote/deprecate):"
    ALL_PACKS=$(jq -r 'select(.pack) | .pack' brain/registry/pack-index.jsonl 2>/dev/null | sort -u)
    LIVE_PACKS=$(jq -r "$TIME_FILTER | .source_pack" "$TELE" | sort -u)
    comm -23 <(echo "$ALL_PACKS") <(echo "$LIVE_PACKS") | awk '{printf "    %s\n", $0}' | head -10
    echo "══════════════════════════════════════════════════════════════════════════"
    echo "  Drill: --pack <name>  |  --record <id>  |  --json (feed other tools)"
    ;;
esac
