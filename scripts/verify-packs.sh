#!/usr/bin/env bash
# verify-packs.sh — pack integration CI check.
#
# Every pack under packs/ MUST satisfy this 4-link chain, or be explicitly
# marked as .deprecated (queued for removal) or .vendored (mad-hacks-curated,
# no upstream):
#
#   1. UPSTREAM.md         → row with URL + pinned SHA  (or .vendored marker)
#   2. router.md           → route pointing at packs/<name>  (or .internal marker)
#   3. EXTRACTION.md       → per-pack manifest listing extracted records
#   4. pack-index.jsonl    → brain/registry/pack-index.jsonl entry (SPOT for status)
#
# Modes:
#   --report   (default)  human-readable table, exit 0 regardless
#   --strict              exit non-zero if ANY chain link is broken (wire into pre-commit / CI)
#   --json                machine-readable JSONL, one object per pack, exit 0
#
# The user's directive: "eliminate fragmented provenance — every pack must have
# UPSTREAM → router → extracted knowledge → indexed brain, with CI failing if
# any link is missing."
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
REPO="$PWD"

MODE="${1:-report}"
case "$MODE" in
  --report|report) MODE="report" ;;
  --strict)        MODE="strict" ;;
  --json)          MODE="json" ;;
  --help|-h) sed -n '2,25p' "$0" | sed 's/^# \?//'; exit 0 ;;
  *) echo "usage: verify-packs.sh [--report|--strict|--json]" >&2; exit 2 ;;
esac

UPSTREAM="packs/UPSTREAM.md"
ROUTER="references/router.md"
INDEX="brain/registry/pack-index.jsonl"

[ -f "$UPSTREAM" ] || { echo "⛔ $UPSTREAM missing" >&2; exit 3; }
[ -f "$ROUTER" ]   || { echo "⛔ $ROUTER missing" >&2; exit 3; }
[ -f "$INDEX" ]    || { mkdir -p "$(dirname "$INDEX")"; : > "$INDEX"; }

check_pack() {
  local pack="$1" dir="packs/$1"
  local deprecated="" vendored="" internal=""
  local up=0 rt=0 ex=0 ix=0

  [ -f "$dir/.deprecated" ] && deprecated=1
  [ -f "$dir/.vendored" ]   && vendored=1
  [ -f "$dir/.internal" ]   && internal=1

  # 1. UPSTREAM row (unless vendored)
  if [ -n "$vendored" ]; then up=1
  elif grep -qE "^\| \`packs/${pack}/\`" "$UPSTREAM" 2>/dev/null; then up=1
  fi

  # 2. router.md route (unless internal)
  if [ -n "$internal" ]; then rt=1
  elif grep -qE "packs/${pack}(/|\b)" "$ROUTER" 2>/dev/null; then rt=1
  fi

  # 3. EXTRACTION.md manifest
  [ -f "$dir/EXTRACTION.md" ] && ex=1

  # 4. pack-index.jsonl entry
  if grep -qE "\"pack\"[[:space:]]*:[[:space:]]*\"${pack}\"" "$INDEX" 2>/dev/null; then ix=1; fi

  local total=$((up + rt + ex + ix))
  local status="FAIL"
  [ $total -eq 4 ] && status="PASS"
  [ -n "$deprecated" ] && status="DEPRECATED"

  # Emit per-mode
  case "$MODE" in
    json)
      local score
      score=$(awk -v n="$total" 'BEGIN{printf "%.2f", n/4}')
      printf '{"pack":"%s","status":"%s","upstream":%s,"router":%s,"extraction":%s,"index":%s,"deprecated":%s,"vendored":%s,"internal":%s,"score":%s}\n' \
        "$pack" "$status" "$up" "$rt" "$ex" "$ix" \
        "${deprecated:-0}" "${vendored:-0}" "${internal:-0}" "$score"
      ;;
    report|strict)
      local flag_u flag_r flag_e flag_i tag
      flag_u=$([ $up -eq 1 ] && echo "✓" || echo "✗")
      flag_r=$([ $rt -eq 1 ] && echo "✓" || echo "✗")
      flag_e=$([ $ex -eq 1 ] && echo "✓" || echo "✗")
      flag_i=$([ $ix -eq 1 ] && echo "✓" || echo "✗")
      tag=""
      [ -n "$vendored" ]   && tag="${tag}[vendored] "
      [ -n "$internal" ]   && tag="${tag}[internal] "
      [ -n "$deprecated" ] && tag="${tag}[deprecated] "
      printf '  %-28s  UP:%s  RT:%s  EX:%s  IX:%s  → %-10s %s\n' \
        "$pack" "$flag_u" "$flag_r" "$flag_e" "$flag_i" "$status" "$tag"
      ;;
  esac

  # Return code semantics used by --strict aggregator
  case "$status" in
    PASS|DEPRECATED) return 0 ;;
    *) return 1 ;;
  esac
}

# ── main loop ──
[ "$MODE" != "json" ] && {
  echo "══════════════════════════════════════════════════════════════════════════"
  echo " pack integration chain: UPSTREAM → ROUTER → EXTRACTION → INDEX"
  echo "══════════════════════════════════════════════════════════════════════════"
}

pass=0; fail=0; dep=0; total=0
for dir in packs/*/; do
  pack="$(basename "$dir")"
  [ "$pack" = "UPSTREAM.md" ] && continue  # not a dir
  total=$((total + 1))
  if check_pack "$pack"; then
    if [ -f "$dir/.deprecated" ]; then dep=$((dep + 1))
    else pass=$((pass + 1))
    fi
  else
    fail=$((fail + 1))
  fi
done

if [ "$MODE" != "json" ]; then
  echo "──────────────────────────────────────────────────────────────────────────"
  live=$((total - dep))
  pct=$(awk -v p="$pass" -v l="$live" 'BEGIN{ if (l==0) print "n/a"; else printf "%.0f%%", (p*100)/l }')
  printf "  total: %d   pass: %d   deprecated: %d   fail: %d   integration: %s\n" \
    "$total" "$pass" "$dep" "$fail" "$pct"
  echo "══════════════════════════════════════════════════════════════════════════"
  echo
  echo "Legend: UP=UPSTREAM.md row · RT=router.md route · EX=EXTRACTION.md · IX=pack-index.jsonl"
  echo "Markers a pack can carry to skip a link: .vendored (skip UP), .internal (skip RT), .deprecated (skip all)"
fi

if [ "$MODE" = "strict" ] && [ $fail -gt 0 ]; then exit 1; fi
exit 0
