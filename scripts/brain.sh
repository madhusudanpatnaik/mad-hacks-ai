#!/usr/bin/env bash
# T3MP3ST brain — persistent, keyless, cross-engagement memory (plain files).
# Read at mission start (recall), written at mission end (note/finding/exhausted/learn),
# and grown every time you feed in a repo (payload/tool). Lives with the skill so it
# travels across every repo you work in.
#
# Usage:
#   brain.sh recall <target>              → everything known about a target + relevant lessons
#   brain.sh recall-class <class>         → class-relevant lessons (uses brain/lesson-index.md)
#   brain.sh search <query>               → hybrid registry search across every asset
#                                           (references + scripts + tools + payloads + lessons + agents)
#   brain.sh registry [--stats|--rebuild] → view registry state or regenerate it
#   brain.sh note <target> "<text>"       → timestamped observation on a target
#   brain.sh finding <target> "<text>"    → record a CONFIRMED finding (verifier-passed)
#   brain.sh exhausted <target> "<vector>"→ record a dead end (don't repeat it)
#   brain.sh learn "<lesson>"             → global heuristic that applies everywhere
#   brain.sh payload <class> <file>       → fold a payload list into brain/payloads/<class>.txt (deduped)
#   brain.sh tool "<name> — <use>"        → record a new tool/adapter learned from a repo
#   brain.sh stats                        → what the brain currently holds
set -uo pipefail
# Derive REPO_ROOT from THIS script's location — works regardless of where the
# repo is checked out (~/dev/mad-hacks, /opt/mad-hacks, symlinked into
# ~/.claude/skills/mad-hacks, etc.). The earlier hardcoded
# $HOME/.claude/skills/mad-hacks/brain silently pointed at nothing when the
# repo lived elsewhere, causing recall/learn/payload to write to a phantom
# path. MADHACKS_BRAIN env overrides for the rare relocation use case.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRAIN="${MADHACKS_BRAIN:-$REPO_ROOT/brain}"
mkdir -p "$BRAIN/targets" "$BRAIN/payloads"
TS(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
slug(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's#[^a-z0-9._-]#_#g'; }

# ── JSONL SPOTs (per normalized-schema decision, 2026-09-07) ──
LESSONS_JL="$BRAIN/lessons.jsonl"
PATTERNS_JL="$BRAIN/patterns.jsonl"
TOOLS_JL="$BRAIN/tools.jsonl"
PACK_INDEX_JL="$BRAIN/registry/pack-index.jsonl"
TELEMETRY_JL="$BRAIN/telemetry/retrievals.jsonl"

# ── A/B eval — MADHACKS_BRAIN_EXCLUDE lets you mask any pack's records ──
# Set MADHACKS_BRAIN_EXCLUDE="packA,packB" to filter those packs out of
# recall/search JSONL queries. Enables per-pack impact measurement by
# comparing recall/search output WITH vs WITHOUT the pack. See
# scripts/pack-eval.sh for the automated per-pack contribution scorecard.
EXCLUDE_PACKS="${MADHACKS_BRAIN_EXCLUDE:-}"

# jq filter that drops any record whose source_pack is in $EXCLUDE_PACKS.
# Returns "select(true)" (no-op) when EXCLUDE_PACKS is empty.
_exclude_filter() {
  if [ -z "$EXCLUDE_PACKS" ]; then
    echo "select(true)"
  else
    # Build: select((.source_pack // "") as $sp | ["a","b"] | index($sp) | not)
    local excl_arr
    excl_arr=$(printf '%s\n' "$EXCLUDE_PACKS" | tr ',' '\n' | jq -R . | jq -sc .)
    echo "select((.source_pack // \"\") as \$sp | $excl_arr | index(\$sp) | not)"
  fi
}

# log_retrieval — foundation for layer #6 (per-pack retrieval-hit rate + eval scorecard).
# Silent: writes JSONL to $TELEMETRY_JL, no stdout output. Called by recall/recall-class/search
# whenever a JSONL record is surfaced. Aggregate later via jq for per-pack impact scoring.
# Args: subcommand, query, record_type (lesson|pattern|tool|pack), record_id, source_pack
log_retrieval() {
  local subcmd="${1:-?}" query="${2:-?}" rtype="${3:-?}" rid="${4:-?}" spack="${5:-?}"
  mkdir -p "$(dirname "$TELEMETRY_JL")"
  # jq -c produces one compact line; safer than hand-rolling JSON escape
  jq -cn --arg ts "$(TS)" --arg s "$subcmd" --arg q "$query" \
         --arg rt "$rtype" --arg ri "$rid" --arg sp "$spack" \
    '{ts:$ts,subcmd:$s,query:$q,record_type:$rt,record_id:$ri,source_pack:$sp}' \
    >> "$TELEMETRY_JL" 2>/dev/null || true
}

CMD="${1:-}"; shift || true

case "$CMD" in
  recall)
    T="${1:-}"; [ -n "$T" ] || { echo "usage: brain.sh recall <target>"; exit 2; }
    F="$BRAIN/targets/$(slug "$T").md"
    echo "═══ BRAIN RECALL: $T ═══"
    if [ -f "$F" ]; then cat "$F"; else echo "(no prior memory for this target — fresh engagement)"; fi
    echo; echo "── Relevant global lessons (prose) ──"
    if [ -f "$BRAIN/lessons.md" ]; then
      grep -iE "$(printf '%s' "$T" | sed 's#[^a-zA-Z0-9]#|#g')|always|never|gotcha" "$BRAIN/lessons.md" 2>/dev/null | tail -15 || true
      echo "(full: $BRAIN/lessons.md)"
    else echo "(none yet)"; fi
    # ── JSONL atomic records — patterns first (actionable), then lessons ──
    if [ -f "$PATTERNS_JL" ] || [ -f "$LESSONS_JL" ]; then
      echo; echo "── Atomic records (JSONL — normalized) ──"
      if command -v jq >/dev/null 2>&1; then
        if [ -f "$PATTERNS_JL" ]; then
          pat_count=$(jq -sr '[.[] | select(.id)] | length' "$PATTERNS_JL" 2>/dev/null || echo 0)
          [ "$pat_count" -gt 0 ] && echo "  patterns: $pat_count total  (query by class: brain.sh recall-class <class>)"
        fi
        if [ -f "$LESSONS_JL" ]; then
          les_count=$(jq -sr '[.[] | select(.id)] | length' "$LESSONS_JL" 2>/dev/null || echo 0)
          [ "$les_count" -gt 0 ] && echo "  lessons:  $les_count total  (query by class: brain.sh recall-class <class>)"
        fi
        if [ -f "$PACK_INDEX_JL" ]; then
          pack_count=$(jq -sr '[.[] | select(.pack)] | length' "$PACK_INDEX_JL" 2>/dev/null || echo 0)
          [ "$pack_count" -gt 0 ] && echo "  integrated packs: $pack_count  (jq . $PACK_INDEX_JL for details)"
        fi
      else
        echo "  (jq missing — install for JSONL recall: brew install jq)"
      fi
    fi
    echo; echo "── Payload classes available ──"; ls "$BRAIN/payloads" 2>/dev/null | sed 's/\.txt$//' | tr '\n' ' '; echo
    ;;
  note|finding|exhausted)
    T="${1:-}"; TEXT="${2:-}"; [ -n "$T" ] && [ -n "$TEXT" ] || { echo "usage: brain.sh $CMD <target> \"<text>\""; exit 2; }
    F="$BRAIN/targets/$(slug "$T").md"
    [ -f "$F" ] || printf '# Brain: %s\n\n## Confirmed findings\n\n## Observations\n\n## Exhausted vectors (do not repeat)\n' "$T" > "$F"
    case "$CMD" in
      finding)   sed -i '' "/## Confirmed findings/a\\
- [$(TS)] $TEXT
" "$F" 2>/dev/null || echo "- [$(TS)] $TEXT" >> "$F" ;;
      note)      sed -i '' "/## Observations/a\\
- [$(TS)] $TEXT
" "$F" 2>/dev/null || echo "- [$(TS)] $TEXT" >> "$F" ;;
      exhausted) sed -i '' "/## Exhausted vectors/a\\
- [$(TS)] $TEXT
" "$F" 2>/dev/null || echo "- [$(TS)] $TEXT" >> "$F" ;;
    esac
    echo "✅ $CMD recorded → $F"
    ;;
  learn)
    TEXT="${1:-}"; [ -n "$TEXT" ] || { echo "usage: brain.sh learn \"<lesson>\""; exit 2; }
    echo "- [$(TS)] $TEXT" >> "$BRAIN/lessons.md"; echo "✅ lesson recorded → $BRAIN/lessons.md"
    ;;
  tool)
    TEXT="${1:-}"; [ -n "$TEXT" ] || { echo "usage: brain.sh tool \"<name> — <use>\""; exit 2; }
    echo "- [$(TS)] $TEXT" >> "$BRAIN/tools.md"; echo "✅ tool recorded → $BRAIN/tools.md"
    ;;
  payload)
    CLASS="${1:-}"; FILE="${2:-}"; [ -n "$CLASS" ] && [ -f "$FILE" ] || { echo "usage: brain.sh payload <class> <file>"; exit 2; }
    OUT="$BRAIN/payloads/$(slug "$CLASS").txt"; touch "$OUT"
    before=$(wc -l < "$OUT" | tr -d ' ')
    # Preserve symlinks: some payload files symlink into wordlists/ so writes
    # reach the canonical location. `mv tmp $OUT` would replace the symlink
    # with a regular file, silently breaking the wordlists/ → brain/payloads/
    # design. Compute deduped content into tmp, then WRITE THROUGH the symlink
    # via redirect (cat > "$OUT") instead of replacing the inode.
    TMP=$(mktemp)
    cat "$OUT" "$FILE" | awk 'NF && !seen[$0]++' > "$TMP"
    cat "$TMP" > "$OUT"
    rm -f "$TMP"
    after=$(wc -l < "$OUT" | tr -d ' ')
    if [ -L "$OUT" ]; then LINK_NOTE=" (symlink → $(readlink "$OUT"))"; else LINK_NOTE=""; fi
    echo "✅ payloads[$CLASS]: $before → $after ( +$((after-before)) new ) → $OUT$LINK_NOTE"
    ;;
  search)
    QUERY="${1:-}"; [ -n "$QUERY" ] || { echo "usage: brain.sh search <query>"; exit 2; }
    REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    REG="$REPO_ROOT/brain/registry/assets.jsonl"
    if [ ! -f "$REG" ]; then
      echo "(no registry yet — building it now...)"
      python3 "$REPO_ROOT/scripts/build-registry.py" >/dev/null
    fi
    # Delegate the primary lexical search to build-registry.py (uses same FTS code path)
    python3 "$REPO_ROOT/scripts/build-registry.py" --search "$QUERY" 2>&1 | \
      awk 'BEGIN{p=0} /^── search/{p=1} p'
    # Also grep the JSONL files directly — build-registry.py doesn't index them YET
    # (follow-up work: extend collect_all() to walk lessons.jsonl/patterns.jsonl/tools.jsonl)
    if command -v jq >/dev/null 2>&1; then
      QL=$(printf '%s' "$QUERY" | tr '[:upper:]' '[:lower:]')
      EXFILT="$(_exclude_filter)"
      [ -n "$EXCLUDE_PACKS" ] && echo "" && echo "  (A/B eval: excluding packs [$EXCLUDE_PACKS])"
      for jl in "$PATTERNS_JL" "$LESSONS_JL" "$TOOLS_JL"; do
        [ -f "$jl" ] || continue
        base=$(basename "$jl" .jsonl)
        hits=$(jq -c --arg q "$QL" \
          "select(.id) | . as \$rec | select([.[] | select(type == \"string\") | ascii_downcase] | any(contains(\$q))) | $EXFILT" \
          "$jl" 2>/dev/null | grep -c '"id"')
        if [ "$hits" -gt 0 ]; then
          echo ""
          echo "── JSONL matches in $base ($hits) ──"
          jq -rc --arg q "$QL" \
            "select(.id) | . as \$rec | select([.[] | select(type == \"string\") | ascii_downcase] | any(contains(\$q))) | $EXFILT | \"  [\(.id)] class=\(.class // \"?\")  source=\(.source_pack // \"?\")  \(.title // .name // \"\")\"" \
            "$jl" 2>/dev/null | head -10
          while IFS= read -r row; do
            rid=$(echo "$row" | jq -r '.id' 2>/dev/null)
            spack=$(echo "$row" | jq -r '.source_pack // "?"' 2>/dev/null)
            rtype="${base%s}"
            log_retrieval "search" "$QUERY" "$rtype" "$rid" "$spack"
          done < <(jq -c --arg q "$QL" "select(.id) | . as \$rec | select([.[] | select(type == \"string\") | ascii_downcase] | any(contains(\$q))) | $EXFILT" "$jl" 2>/dev/null | head -10)
        fi
      done
    fi
    ;;
  registry)
    REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    SUB="${1:-show}"
    case "$SUB" in
      --stats|stats) python3 "$REPO_ROOT/scripts/build-registry.py" --stats ;;
      --rebuild|rebuild) python3 "$REPO_ROOT/scripts/build-registry.py" ;;
      show|"")
        REG="$REPO_ROOT/brain/registry/assets.jsonl"
        if [ -f "$REG" ]; then
          echo "  registry: $REG"
          echo "  rows:     $(wc -l < "$REG" | tr -d ' ')"
          echo "  types:    $(python3 -c "import json,collections; c=collections.Counter(); [c.update([json.loads(l)['type']]) for l in open('$REG')]; print(dict(c))")"
        else
          echo "(registry not built yet — run: brain.sh registry --rebuild)"
        fi
        ;;
      *) echo "usage: brain.sh registry [show|--stats|--rebuild]"; exit 2 ;;
    esac
    ;;
  recall-class)
    CLS="${1:-}"; [ -n "$CLS" ] || { echo "usage: brain.sh recall-class <class>"; exit 2; }
    LI="$BRAIN/lesson-index.md"
    LSN="$BRAIN/lessons.md"
    [ -f "$LSN" ] || { echo "(no lessons file yet)"; exit 0; }
    echo "═══ BRAIN RECALL-CLASS: $CLS ═══"
    # Extract keyword-set for this class from the index (rows like: class|kw1,kw2,kw3)
    KWS=""
    if [ -f "$LI" ]; then
      KWS=$(awk -F'|' -v c="$CLS" '$1==c{print $2}' "$LI" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$')
    fi
    if [ -z "$KWS" ]; then
      # fallback: raw class-name grep (no early exit — JSONL block runs below regardless)
      echo "(class '$CLS' not in $LI — falling back to raw grep for prose)"
      grep -iE "\b$CLS\b" "$LSN" 2>/dev/null | tail -20 || true
    else
      # Build a case-insensitive extended regex from the keyword set
      RE=$(printf '%s\n' "$KWS" | sed 's/[][^$.*/\\]/\\&/g' | paste -sd'|' -)
      echo "── keywords: $(printf '%s' "$KWS" | tr '\n' ',' | sed 's/,$//; s/,/, /g') ──"
      echo ""
      grep -iE -- "$RE" "$LSN" | tail -25
      echo ""
    fi
    echo "(class '$CLS' has payload file: $BRAIN/payloads/$CLS.txt if present)"
    if [ -f "$BRAIN/payloads/$CLS.txt" ]; then
      echo "   payload count: $(wc -l < "$BRAIN/payloads/$CLS.txt" | tr -d ' ') lines in $BRAIN/payloads/$CLS.txt"
    fi
    # ── JSONL atomic records for this class — patterns first (actionable), then lessons ──
    if command -v jq >/dev/null 2>&1; then
      EXFILT="$(_exclude_filter)"
      [ -n "$EXCLUDE_PACKS" ] && echo "" && echo "  (A/B eval: excluding packs [$EXCLUDE_PACKS])"
      if [ -f "$PATTERNS_JL" ]; then
        echo ""
        echo "── Patterns (JSONL, class=$CLS) — actionable {precondition → action} triggers ──"
        while IFS= read -r row; do
          [ -z "$row" ] && continue
          echo "$row" | jq -r '"  ● [\(.id)] \(.name)\n      IF: \(.precondition)\n      DO: \(.action)\n      source: \(.source_pack) — \(.evidence)"' 2>/dev/null
          rid=$(echo "$row" | jq -r '.id' 2>/dev/null)
          spack=$(echo "$row" | jq -r '.source_pack' 2>/dev/null)
          log_retrieval "recall-class" "$CLS" "pattern" "$rid" "$spack"
        done < <(jq -c --arg c "$CLS" "select(.id) | select(.class == \$c) | $EXFILT" "$PATTERNS_JL" 2>/dev/null)
      fi
      if [ -f "$LESSONS_JL" ]; then
        echo ""
        echo "── Lessons (JSONL, class=$CLS) — contextual facts ──"
        while IFS= read -r row; do
          [ -z "$row" ] && continue
          echo "$row" | jq -r '"  ○ [\(.id)] \(.title)\n      \(.capability_effect)\n      source: \(.source_pack) — \(.evidence)"' 2>/dev/null
          rid=$(echo "$row" | jq -r '.id' 2>/dev/null)
          spack=$(echo "$row" | jq -r '.source_pack' 2>/dev/null)
          log_retrieval "recall-class" "$CLS" "lesson" "$rid" "$spack"
        done < <(jq -c --arg c "$CLS" "select(.id) | select(.class == \$c) | $EXFILT" "$LESSONS_JL" 2>/dev/null)
      fi
    fi
    ;;
  stats)
    echo "═══ BRAIN STATS ═══"
    echo "targets known:   $(ls "$BRAIN/targets"/*.md 2>/dev/null | wc -l | tr -d ' ')"
    echo "global lessons:  $(grep -c '^- ' "$BRAIN/lessons.md" 2>/dev/null || echo 0) prose  ·  $(jq -sr '[.[] | select(.id)] | length' "$LESSONS_JL" 2>/dev/null || echo 0) atomic (JSONL)"
    echo "patterns:        $(jq -sr '[.[] | select(.id)] | length' "$PATTERNS_JL" 2>/dev/null || echo 0) atomic (JSONL)"
    echo "tools learned:   $(grep -c '^- ' "$BRAIN/tools.md" 2>/dev/null || echo 0) prose  ·  $(jq -sr '[.[] | select(.id)] | length' "$TOOLS_JL" 2>/dev/null || echo 0) atomic (JSONL)"
    echo "payload classes: $(ls "$BRAIN/payloads"/*.txt 2>/dev/null | wc -l | tr -d ' ') ($(cat "$BRAIN/payloads"/*.txt 2>/dev/null | wc -l | tr -d ' ') probes)"
    echo "integrated packs: $(jq -sr '[.[] | select(.pack)] | length' "$PACK_INDEX_JL" 2>/dev/null || echo 0) / $(ls -d packs/*/ 2>/dev/null | wc -l | tr -d ' ')"
    echo "retrievals logged: $([ -f "$TELEMETRY_JL" ] && wc -l < "$TELEMETRY_JL" | tr -d ' ' || echo 0)"
    echo "location:        $BRAIN"
    ;;
  *) echo "usage: brain.sh {recall|recall-class|search|registry|note|finding|exhausted|learn|tool|payload|stats} ..."
     echo ""
     echo "  JSONL SPOTs (queried by recall-class, search, stats):"
     echo "    lessons: $LESSONS_JL"
     echo "    patterns: $PATTERNS_JL"
     echo "    tools:    $TOOLS_JL"
     echo "    packs:    $PACK_INDEX_JL"
     echo "    telemetry: $TELEMETRY_JL"
     exit 2;;
esac
