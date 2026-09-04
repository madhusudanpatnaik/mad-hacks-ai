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
BRAIN="$HOME/.claude/skills/mad-hacks/brain"
mkdir -p "$BRAIN/targets" "$BRAIN/payloads"
TS(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
slug(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's#[^a-z0-9._-]#_#g'; }
CMD="${1:-}"; shift || true

case "$CMD" in
  recall)
    T="${1:-}"; [ -n "$T" ] || { echo "usage: brain.sh recall <target>"; exit 2; }
    F="$BRAIN/targets/$(slug "$T").md"
    echo "═══ BRAIN RECALL: $T ═══"
    if [ -f "$F" ]; then cat "$F"; else echo "(no prior memory for this target — fresh engagement)"; fi
    echo; echo "── Relevant global lessons ──"
    if [ -f "$BRAIN/lessons.md" ]; then
      grep -iE "$(printf '%s' "$T" | sed 's#[^a-zA-Z0-9]#|#g')|always|never|gotcha" "$BRAIN/lessons.md" 2>/dev/null | tail -15 || true
      echo "(full: $BRAIN/lessons.md)"
    else echo "(none yet)"; fi
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
    # Delegate the actual lexical search to build-registry.py (uses same code path)
    python3 "$REPO_ROOT/scripts/build-registry.py" --search "$QUERY" 2>&1 | \
      awk 'BEGIN{p=0} /^── search/{p=1} p'
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
      # fallback: raw class-name grep
      echo "(class '$CLS' not in $LI — falling back to raw grep)"
      grep -iE "\b$CLS\b" "$LSN" | tail -20
      exit 0
    fi
    # Build a case-insensitive extended regex from the keyword set
    RE=$(printf '%s\n' "$KWS" | sed 's/[][^$.*/\\]/\\&/g' | paste -sd'|' -)
    echo "── keywords: $(printf '%s' "$KWS" | tr '\n' ',' | sed 's/,$//; s/,/, /g') ──"
    echo ""
    grep -iE -- "$RE" "$LSN" | tail -25
    echo ""
    echo "(class '$CLS' has payload file: $BRAIN/payloads/$CLS.txt if present)"
    if [ -f "$BRAIN/payloads/$CLS.txt" ]; then
      echo "   payload count: $(wc -l < "$BRAIN/payloads/$CLS.txt" | tr -d ' ') lines in $BRAIN/payloads/$CLS.txt"
    fi
    ;;
  stats)
    echo "═══ BRAIN STATS ═══"
    echo "targets known:   $(ls "$BRAIN/targets"/*.md 2>/dev/null | wc -l | tr -d ' ')"
    echo "global lessons:  $(grep -c '^- ' "$BRAIN/lessons.md" 2>/dev/null || echo 0)"
    echo "tools learned:   $(grep -c '^- ' "$BRAIN/tools.md" 2>/dev/null || echo 0)"
    echo "payload classes: $(ls "$BRAIN/payloads"/*.txt 2>/dev/null | wc -l | tr -d ' ') ($(cat "$BRAIN/payloads"/*.txt 2>/dev/null | wc -l | tr -d ' ') probes)"
    echo "location:        $BRAIN"
    ;;
  *) echo "usage: brain.sh {recall|recall-class|search|registry|note|finding|exhausted|learn|tool|payload|stats} ..."; exit 2;;
esac
