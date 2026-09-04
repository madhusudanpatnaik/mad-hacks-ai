#!/usr/bin/env bash
# engagement-state.sh — first-class target state model for every engagement.
#
# Generalizes what CDC's .cdc/<target>/ already prototypes to ALL engagements
# (bug-bounty / pentest / research / CTF). intelligence-recall reads these files
# to bias retrieval by what you've observed, tested, exhausted, and hypothesized.
#
# Layout under .engagement/<slug>/:
#   TECHNOLOGY.md    — inferred stack: framework, hosting, CDN, defaults
#   OBSERVED.md      — raw ground-truth observations (append-only)
#   TESTED.md        — hypotheses tested (append-only)
#   EXHAUSTED.md     — dead vectors as STRUCTURED records
#                       {class, vector, variant, evidence, timestamp, confidence}
#                       hunters skip these; router deprioritizes them
#   HYPOTHESES.md    — active hypothesis queue (ordered by expected value)
#   EVIDENCE.jsonl   — evidence ledger with epistemic status per record:
#                       {observation, evidence, interpretation, hypothesis,
#                        test, result, conclusion, epistemic_status, confidence}
#   LOG.md           — append-only timeline (every state transition)
#
# All doctrine gates (deadangle Verified/Inferred/Assumed) live here.
#
# Usage (subcommands):
#   engagement-state.sh init <target> [--tech "stack description"]
#   engagement-state.sh observe    <target> "<what you literally saw>"
#   engagement-state.sh tested     <target> "<hypothesis>" "<result>"
#   engagement-state.sh exhausted  <target> <class> <vector> <variant> "<why>"
#   engagement-state.sh hypothesis <target> add "<hypothesis>" [--priority high|medium|low]
#   engagement-state.sh hypothesis <target> list
#   engagement-state.sh evidence   <target> add --observation "..." --evidence "..." --interpretation "..." [--epistemic OBSERVED|DERIVED|INFERRED|HYPOTHESIS] [--confidence HIGH|MEDIUM|LOW]
#   engagement-state.sh recall     <target>            # full dump for hunter briefings
#   engagement-state.sh log        <target> "<message>"
#   engagement-state.sh list                           # every known engagement + last-touched

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CMD="${1:-}"; TARGET="${2:-}"
[ -n "$CMD" ] || { sed -n '1,30p' "$0"; exit 2; }

# list is target-less
if [ "$CMD" = "list" ]; then
  ROOT="$REPO/.engagement"
  [ -d "$ROOT" ] || { echo "  (no engagements initialized yet)"; exit 0; }
  echo "── engagements (${ROOT#$REPO/}) ──"
  for d in "$ROOT"/*/; do
    [ -d "$d" ] || continue
    slug=$(basename "$d")
    last=$(stat -f %Sm -t %Y-%m-%dT%H:%M:%SZ "$d/LOG.md" 2>/dev/null || echo "?")
    exhausted=$(grep -c '^- ' "$d/EXHAUSTED.md" 2>/dev/null || echo 0)
    hyp=$(grep -c '^- ' "$d/HYPOTHESES.md" 2>/dev/null || echo 0)
    printf "  %-32s  last_touched=%s  exhausted=%d  hypotheses=%d\n" "$slug" "$last" "$exhausted" "$hyp"
  done
  exit 0
fi

[ -n "$TARGET" ] || { echo "usage: engagement-state.sh $CMD <target> ..."; exit 2; }

slug(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9.-' '-' | sed 's/^-//; s/-$//'; }
TS(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
SLUG=$(slug "$TARGET")
ROOT="$REPO/.engagement/$SLUG"
TECH="$ROOT/TECHNOLOGY.md"
OBS="$ROOT/OBSERVED.md"
TESTED="$ROOT/TESTED.md"
EXH="$ROOT/EXHAUSTED.md"
HYP="$ROOT/HYPOTHESES.md"
EVI="$ROOT/EVIDENCE.jsonl"
LOG="$ROOT/LOG.md"

log_append(){ printf -- '- [%s] %s\n' "$(TS)" "$1" >> "$LOG"; }

require_init(){
  [ -d "$ROOT" ] || { echo "engagement-state: not initialized for '$TARGET'. Run: engagement-state.sh init '$TARGET'" >&2; exit 3; }
}

shift 2 || true

# ─── init ───────────────────────────────────────────────────
if [ "$CMD" = "init" ]; then
  TECH_TXT=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --tech) TECH_TXT="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done

  mkdir -p "$ROOT"

  cat > "$TECH" <<EOF
# Technology stack — $TARGET

**Inferred stack:** ${TECH_TXT:-_(unknown — update as you observe)_}

## Framework / language
_(update as you observe — Node.js? Django? Rails? Next.js? Spring? Laravel?)_

## Hosting / infra
_(AWS / GCP / Azure / Fargate / Vercel / Cloudflare / on-prem?)_

## Data layer
_(Postgres / MySQL / Mongo / DynamoDB / Redis?)_

## Front-of-house
_(CDN? WAF? edge-runtime?)_

## Auth model
_(JWT? session-cookie? OAuth+PKCE? SAML? mTLS?)_

*Set: $(TS)*
EOF

  : > "$OBS";    echo "# Observed — $TARGET"     >> "$OBS"; echo "" >> "$OBS"
  : > "$TESTED"; echo "# Tested — $TARGET"       >> "$TESTED"; echo "" >> "$TESTED"
  : > "$EXH";    { echo "# Exhausted vectors — $TARGET"; echo ""; echo "Every specialist hunter reads this before probing. **Do not re-test these.**"; echo ""; echo "Format: \`- [ts] [class] [vector] [variant] — why exhausted — evidence\`"; echo ""; } >> "$EXH"
  : > "$HYP";    { echo "# Hypotheses — $TARGET (ordered by expected value)"; echo ""; } >> "$HYP"
  : > "$EVI"
  : > "$LOG";    { echo "# Log — $TARGET"; echo ""; } >> "$LOG"
  log_append "init: engagement bootstrap  target=$TARGET"
  [ -n "$TECH_TXT" ] && log_append "tech: $TECH_TXT"

  echo "✓ engagement initialized: $ROOT"
  echo "  next: engagement-state.sh observe $TARGET '...'"
  exit 0
fi

# every other subcommand requires init
require_init

case "$CMD" in

  # ─── observe: append a raw observation ────────────────────
  observe)
    TXT="${1:-}"; [ -n "$TXT" ] || { echo "usage: observe <target> \"<what you literally saw>\""; exit 2; }
    printf -- '- [%s] %s\n' "$(TS)" "$TXT" >> "$OBS"
    log_append "observe: $TXT"
    echo "✓ observed"
    ;;

  # ─── tested: append a tested hypothesis + result ──────────
  tested)
    HYPT="${1:-}"; RES="${2:-}"; [ -n "$HYPT" ] && [ -n "$RES" ] || { echo "usage: tested <target> \"<hypothesis>\" \"<result>\""; exit 2; }
    printf -- '- [%s] **hypothesis:** %s  →  **result:** %s\n' "$(TS)" "$HYPT" "$RES" >> "$TESTED"
    log_append "tested: $HYPT -> $RES"
    echo "✓ tested recorded"
    ;;

  # ─── exhausted: structured dead-vector record ─────────────
  exhausted)
    CLS="${1:-}"; VEC="${2:-}"; VAR="${3:-}"; WHY="${4:-}"
    [ -n "$CLS" ] && [ -n "$VEC" ] && [ -n "$VAR" ] && [ -n "$WHY" ] \
      || { echo "usage: exhausted <target> <class> <vector> <variant> \"<why>\" [evidence_path]"; exit 2; }
    EVIP="${5:-}"
    # Canonicalize class/vector/variant tokens at WRITE time so the router's
    # exhausted-class set-intersection cannot silently miss due to casing /
    # underscore / space drift ('SSRF' vs 'ssrf', 'auth_session' vs 'auth-session').
    # Reader-side normalization exists too (defense in depth), but writing canonical
    # form keeps EXHAUSTED.md self-consistent when grepped by humans or other tools.
    canonicalize(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr '_ ' '--' | sed 's/-\{2,\}/-/g; s/^-//; s/-$//'; }
    CLS=$(canonicalize "$CLS")
    VEC=$(canonicalize "$VEC")
    VAR=$(canonicalize "$VAR")
    printf -- '- [%s] [%s] [%s] [%s] — %s%s\n' "$(TS)" "$CLS" "$VEC" "$VAR" "$WHY" \
      "$([ -n "$EVIP" ] && printf ' — evidence: %s' "$EVIP")" >> "$EXH"
    log_append "exhausted: [$CLS/$VEC/$VAR] $WHY"
    echo "✓ exhausted recorded — hunters will skip this vector"
    ;;

  # ─── hypothesis: add / list ───────────────────────────────
  hypothesis|hyp)
    SUB="${1:-list}"; shift || true
    case "$SUB" in
      add)
        TXT="${1:-}"; PRIO="MEDIUM"
        shift || true
        while [ $# -gt 0 ]; do
          case "$1" in
            --priority) PRIO=$(printf '%s' "${2:-MEDIUM}" | tr '[:lower:]' '[:upper:]'); shift 2 ;;
            *) shift ;;
          esac
        done
        [ -n "$TXT" ] || { echo "usage: hypothesis <target> add \"<hypothesis>\" [--priority high|medium|low]"; exit 2; }
        printf -- '- [%s] [%s] %s\n' "$(TS)" "$PRIO" "$TXT" >> "$HYP"
        log_append "hypothesis add ($PRIO): $TXT"
        echo "✓ hypothesis added ($PRIO)"
        ;;
      list|show|"")
        cat "$HYP"
        ;;
      *) echo "hypothesis subcommands: add | list" >&2; exit 2 ;;
    esac
    ;;

  # ─── evidence: append a structured evidence-ledger row ────
  evidence)
    SUB="${1:-}"; shift || true
    case "$SUB" in
      add)
        OBS_TXT=""; EVI_TXT=""; INT_TXT=""; HYP_TXT=""; TEST_TXT=""; RES_TXT=""; CONC_TXT=""
        EP="INFERRED"; CONF="MEDIUM"
        while [ $# -gt 0 ]; do
          case "$1" in
            --observation)    OBS_TXT="${2:-}"; shift 2 ;;
            --evidence)       EVI_TXT="${2:-}"; shift 2 ;;
            --interpretation) INT_TXT="${2:-}"; shift 2 ;;
            --hypothesis)     HYP_TXT="${2:-}"; shift 2 ;;
            --test)           TEST_TXT="${2:-}"; shift 2 ;;
            --result)         RES_TXT="${2:-}"; shift 2 ;;
            --conclusion)     CONC_TXT="${2:-}"; shift 2 ;;
            --epistemic)      EP=$(printf '%s' "${2:-INFERRED}" | tr '[:lower:]' '[:upper:]'); shift 2 ;;
            --confidence)     CONF=$(printf '%s' "${2:-MEDIUM}" | tr '[:lower:]' '[:upper:]'); shift 2 ;;
            *) shift ;;
          esac
        done
        case "$EP" in OBSERVED|DERIVED|INFERRED|HYPOTHESIS) : ;;
          *) echo "--epistemic must be OBSERVED|DERIVED|INFERRED|HYPOTHESIS" >&2; exit 2 ;;
        esac
        case "$CONF" in HIGH|MEDIUM|LOW) : ;;
          *) echo "--confidence must be HIGH|MEDIUM|LOW" >&2; exit 2 ;;
        esac
        [ -n "$OBS_TXT" ] || { echo "evidence add: --observation required (raw ground-truth)"; exit 2; }
        # export → subprocess env; avoids all bash heredoc-interpolation hazards
        export OBS_TXT EVI_TXT INT_TXT HYP_TXT TEST_TXT RES_TXT CONC_TXT EP CONF EVI
        python3 <<'PY'
import json, os, datetime
row = {
  "ts": datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z",
  "observation":      os.environ.get("OBS_TXT",""),
  "evidence":         os.environ.get("EVI_TXT",""),
  "interpretation":   os.environ.get("INT_TXT",""),
  "hypothesis":       os.environ.get("HYP_TXT",""),
  "test":             os.environ.get("TEST_TXT",""),
  "result":           os.environ.get("RES_TXT",""),
  "conclusion":       os.environ.get("CONC_TXT",""),
  "epistemic_status": os.environ.get("EP","INFERRED"),
  "confidence":       os.environ.get("CONF","MEDIUM"),
}
row = {k: v for k, v in row.items() if v}
with open(os.environ["EVI"], "a") as f:
    f.write(json.dumps(row) + "\n")
PY
        log_append "evidence add: $EP/$CONF — $OBS_TXT"
        echo "✓ evidence ledger row appended [$EP / $CONF]"
        ;;
      list|show|"")
        [ -s "$EVI" ] && python3 -c "
import json, sys
for line in open('$EVI'):
    line = line.strip()
    if not line: continue
    r = json.loads(line)
    print(f\"── {r['ts']}  [{r['epistemic_status']} / {r['confidence']}]\")
    for k in ('observation','evidence','interpretation','hypothesis','test','result','conclusion'):
        if r.get(k): print(f\"  {k:14s}  {r[k]}\")
" || echo "  (no evidence recorded yet)"
        ;;
      *) echo "evidence subcommands: add | list" >&2; exit 2 ;;
    esac
    ;;

  # ─── recall: full engagement dump for hunter briefings ────
  recall)
    echo "═══ ENGAGEMENT RECALL: $TARGET ═══"
    for f in "$TECH" "$OBS" "$TESTED" "$EXH" "$HYP"; do
      echo ""
      echo "──── $(basename "$f") ────"
      cat "$f"
    done
    if [ -s "$EVI" ]; then
      echo ""
      echo "──── EVIDENCE.jsonl ($( wc -l < "$EVI" | tr -d ' ') entries) ────"
      python3 -c "
import json
for line in open('$EVI'):
    line = line.strip()
    if not line: continue
    r = json.loads(line)
    print(f'  [{r[\"ts\"]}]  [{r[\"epistemic_status\"]}/{r[\"confidence\"]}]  {r.get(\"observation\",\"\")[:80]}')"
    fi
    echo ""
    echo "──── LOG (tail 15) ────"
    tail -15 "$LOG"
    ;;

  # ─── log: append a raw log line ───────────────────────────
  log)
    MSG="${1:-}"; [ -n "$MSG" ] || { echo "usage: log <target> \"<message>\""; exit 2; }
    log_append "$MSG"
    ;;

  *)
    sed -n '1,30p' "$0"; exit 2
    ;;
esac
