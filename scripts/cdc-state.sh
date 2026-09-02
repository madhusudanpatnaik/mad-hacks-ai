#!/usr/bin/env bash
# cdc-state.sh — filesystem state manager for the CDC harness (see references/cdc-harness.md)
#
# Keyless. System tools only. Idempotent writes. Every state file is markdown so an
# operator can `less` it mid-run and see exactly what the swarm knows.
#
# Usage:
#   cdc-state.sh init      <target> --goal "unauth→RCE" --deployment "…"
#   cdc-state.sh family    <target> assign <family> <agent>
#   cdc-state.sh family    <target> tick    <family>              # timestamp last activity
#   cdc-state.sh family    <target> list                         # print families + last_tick
#   cdc-state.sh hyp       <target> add <family> "<hypothesis>"
#   cdc-state.sh hyp       <target> status <id> <active|blocked|confirmed>
#   cdc-state.sh primitive <target> add <family> "<name>" "<repro>" <evidence_file>
#   cdc-state.sh chain     <target> set   "<step1>||<step2>||<step3>"
#   cdc-state.sh chain     <target> show
#   cdc-state.sh blocked   <target> add <family> "<path>" "<why>" [evidence_file]
#   cdc-state.sh blocked   <target> show
#   cdc-state.sh verdict   <target> add <finding_id> <CONFIRMED|DISPROVED|INCONCLUSIVE> "<reason>" [evidence]
#   cdc-state.sh neglected <target>                              # print families overdue for new hypothesis
#   cdc-state.sh recall    <target>                              # print full state (goal, deployment, families, primitives, chain, blocked, verdicts, log tail)
#   cdc-state.sh log       <target> "<message>"                  # append to LOG.md
#
# State root: .cdc/<slug>/  (created in CWD)

set -uo pipefail

CMD="${1:-}"; shift || true
TARGET="${1:-}"; shift || true

if [ -z "$CMD" ] || [ -z "$TARGET" ] && [ "$CMD" != "" ]; then
  sed -n '1,20p' "$0"; exit 2
fi

# ─── helpers ────────────────────────────────────────────────
slug(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9.-' '-' | sed 's/^-//; s/-$//'; }
TS(){ date -u +%Y-%m-%dT%H:%M:%SZ; }
SLUG="$(slug "$TARGET")"
ROOT=".cdc/$SLUG"
GOAL="$ROOT/GOAL.md"
DEPLOY="$ROOT/DEPLOYMENT.md"
FAM="$ROOT/FAMILIES.md"
HYP="$ROOT/HYPOTHESES.md"
PRIM="$ROOT/PRIMITIVES.md"
CHAIN="$ROOT/CHAIN.md"
BLK="$ROOT/BLOCKED.md"
VER="$ROOT/VERDICTS.md"
LOG="$ROOT/LOG.md"
EVI="$ROOT/evidence"
MODE_FILE="$ROOT/MODE.md"
BUDGET_FILE="$ROOT/BUDGET.md"
INTERRUPT_FILE="$ROOT/INTERRUPT"

log_append(){ printf -- '- [%s] %s\n' "$(TS)" "$1" >> "$LOG"; }

require_init(){
  [ -d "$ROOT" ] || { echo "cdc: not initialized for '$TARGET'. Run: cdc-state.sh init '$TARGET' --goal '…' --deployment '…'" >&2; exit 3; }
}

# ─── init ───────────────────────────────────────────────────
if [ "$CMD" = "init" ]; then
  GOAL_TXT=""
  DEPLOY_TXT=""
  MODE_TXT="research"
  SOFT_BUDGET="600000"
  HARD_BUDGET="1000000"
  VISIBILITY="greybox"
  while [ $# -gt 0 ]; do
    case "$1" in
      --goal)                GOAL_TXT="${2:-}"; shift 2;;
      --deployment)          DEPLOY_TXT="${2:-}"; shift 2;;
      --mode)                MODE_TXT="${2:-}"; shift 2;;
      --visibility)          VISIBILITY="${2:-}"; shift 2;;
      --soft-budget-tokens)  SOFT_BUDGET="${2:-}"; shift 2;;
      --hard-budget-tokens)  HARD_BUDGET="${2:-}"; shift 2;;
      *) shift;;
    esac
  done
  [ -n "$GOAL_TXT" ]   || { echo "cdc init: --goal required (e.g. 'unauth → RCE on API host')" >&2; exit 2; }
  [ -n "$DEPLOY_TXT" ] || { echo "cdc init: --deployment required (e.g. 'Next.js 14 App Router on Vercel, Postgres, Cloudflare, default config')" >&2; exit 2; }
  case "$MODE_TXT" in bug-bounty|pentest|research) : ;; *) echo "cdc init: --mode must be bug-bounty|pentest|research (got '$MODE_TXT')" >&2; exit 2;; esac
  case "$VISIBILITY" in greybox|blackbox|whitebox) : ;; *) echo "cdc init: --visibility must be greybox|blackbox|whitebox (got '$VISIBILITY')" >&2; exit 2;; esac

  mkdir -p "$ROOT" "$EVI"
  cat > "$GOAL" <<EOF
# CDC Goal — $TARGET

**Starting privilege → Impact:**

> $GOAL_TXT

Every chain proposed must meet this goal in the deployment described in DEPLOYMENT.md.
A single primitive is not enough; the harness only exits on success when the terminal
node of an independently-CONFIRMED chain reaches this impact.

*Set: $(TS)*
EOF

  cat > "$DEPLOY" <<EOF
# CDC Deployment — $TARGET

**Realistic, commonly deployed configuration this chain must work against:**

> $DEPLOY_TXT

If a candidate primitive requires an exotic configuration, debug toggle, or
non-default library version, it is not a finding — it is a footnote.

*Set: $(TS)*
EOF

  : > "$FAM"; echo "# CDC Families — $TARGET"                >> "$FAM"; echo ""                                       >> "$FAM"; echo "family|agent|last_tick" >> "$FAM"; echo "------|-----|---------" >> "$FAM"
  : > "$HYP"; echo "# CDC Hypotheses — $TARGET"              >> "$HYP"; echo ""                                       >> "$HYP"
  : > "$PRIM"; echo "# CDC Primitives — $TARGET (confirmed)" >> "$PRIM"; echo ""                                      >> "$PRIM"
  : > "$CHAIN"; echo "# CDC Chain in progress — $TARGET"     >> "$CHAIN"; echo ""                                     >> "$CHAIN"; echo "_(no chain yet)_" >> "$CHAIN"
  : > "$BLK"; echo "# CDC Blocked paths — $TARGET"           >> "$BLK"; echo ""                                       >> "$BLK"; echo "Every hunter reads this before probing." >> "$BLK"; echo "" >> "$BLK"
  : > "$VER"; echo "# CDC Verdicts — $TARGET"                >> "$VER"; echo ""                                       >> "$VER"
  : > "$LOG"; echo "# CDC Log — $TARGET"                     >> "$LOG"; echo ""                                       >> "$LOG"

  # ── MODE.md — controls hunter briefing shape + report style
  cat > "$MODE_FILE" <<EOF
# CDC Mode — $TARGET

**mode**: $MODE_TXT
**visibility**: $VISIBILITY

## Mode contract (what shifts based on this)

| Mode        | Default visibility | Payload safety           | Report shape                                      | Scope check       |
|-------------|--------------------|--------------------------|---------------------------------------------------|-------------------|
| bug-bounty  | blackbox           | Safe-PoC only (R1–R11)   | Platform-ready draft (H1/Bugcrowd/Intigriti)      | scope.py hard-gate |
| pentest     | greybox            | RoE-defined              | Executive + technical writeup                     | RoE document       |
| research    | greybox            | Operator-defined         | Technical writeup + brain capture                 | \`.t3mp3st/SCOPE.md\` |

If **mode=bug-bounty** and **visibility=blackbox**, doctrine points 7–9 (runtime inspection) degrade to
"docs + framework fingerprint" and every finding is tagged \`INSPECTION_DEGRADED\` in the verdict.
If **mode=pentest** or **mode=research** with **visibility=greybox** or **whitebox**, doctrine points 7–9
apply in full: read dependency source, spin the local instance, attach a debugger.

*Set: $(TS)*
EOF

  # ── BUDGET.md — token accounting + plateau counter
  cat > "$BUDGET_FILE" <<EOF
# CDC Budget — $TARGET

soft_budget_tokens|$SOFT_BUDGET
hard_budget_tokens|$HARD_BUDGET
spent_tokens|0
consecutive_empty_ticks|0
last_updated|$(TS)

## Thresholds

- **≤ soft_budget**: HEALTHY — full CDC loop (parallel families + hypothesis rotation)
- **> soft_budget**: FINAL_PUSH — root stops launching new hypotheses; focuses budget on composing strongest primitives into chains
- **≥ 3 consecutive empty ticks** (no new primitives across all families): PLATEAU — enter final push early
- **> hard_budget**: HARD_STOP — force graceful exit with negative-result report
EOF

  # ── INTERRUPT — flag file (absent = running, present = stop-requested)
  # do not create; presence is the signal

  log_append "init: mode=$MODE_TXT visibility=$VISIBILITY goal=\"$GOAL_TXT\"  deployment=\"$DEPLOY_TXT\"  soft=$SOFT_BUDGET  hard=$HARD_BUDGET"
  echo "✓ CDC state initialized at $ROOT"
  echo "  mode: $MODE_TXT  |  visibility: $VISIBILITY  |  soft/hard budget: ${SOFT_BUDGET}/${HARD_BUDGET} tokens"
  echo "  next: cdc-state.sh family $TARGET assign <family> <agent>   (do this for ≥3 distinct families)"
  exit 0
fi

# every other command needs state
require_init

# ─── family ─────────────────────────────────────────────────
if [ "$CMD" = "family" ]; then
  SUB="${1:-}"; shift || true
  case "$SUB" in
    assign)
      F="${1:-}"; A="${2:-}"
      [ -n "$F" ] && [ -n "$A" ] || { echo "usage: cdc-state.sh family <t> assign <family> <agent>" >&2; exit 2; }
      # remove any existing row for this family, then append
      grep -v "^${F}|" "$FAM" > "$FAM.new" 2>/dev/null || cp "$FAM" "$FAM.new"
      mv "$FAM.new" "$FAM"
      printf '%s|%s|%s\n' "$F" "$A" "$(TS)" >> "$FAM"
      log_append "family assign: $F → $A"
      echo "✓ $F → $A"
      ;;
    tick)
      F="${1:-}"; [ -n "$F" ] || { echo "usage: family <t> tick <family>" >&2; exit 2; }
      TMP="$FAM.new"; awk -F'|' -v f="$F" -v ts="$(TS)" 'BEGIN{OFS="|"} /^[a-z]/ && $1==f {$3=ts} {print}' "$FAM" > "$TMP" && mv "$TMP" "$FAM"
      log_append "family tick: $F"
      ;;
    list|show|"")
      cat "$FAM"
      ;;
    *) echo "family subcommands: assign|tick|list" >&2; exit 2;;
  esac
  exit 0
fi

# ─── hypothesis ─────────────────────────────────────────────
if [ "$CMD" = "hyp" ]; then
  SUB="${1:-}"; shift || true
  case "$SUB" in
    add)
      F="${1:-}"; H="${2:-}"
      [ -n "$F" ] && [ -n "$H" ] || { echo "usage: hyp <t> add <family> \"<hypothesis>\"" >&2; exit 2; }
      ID="H$(date -u +%y%m%d%H%M%S)"
      printf -- "- **[%s][%s][active][created:%s][last_tested:%s]** %s\n" "$ID" "$F" "$(TS)" "$(TS)" "$H" >> "$HYP"
      log_append "hyp add: [$F] $H  ($ID)"
      echo "✓ $ID"
      ;;
    status)
      ID="${1:-}"; ST="${2:-}"
      [ -n "$ID" ] && [ -n "$ST" ] || { echo "usage: hyp <t> status <id> <active|blocked|confirmed>" >&2; exit 2; }
      TMP="$HYP.new"; awk -v id="$ID" -v st="$ST" -v ts="$(TS)" '{
        if (index($0,"["id"]")>0) { sub(/\[active\]|\[blocked\]|\[confirmed\]/,"["st"]"); sub(/\[last_tested:[^]]*\]/,"[last_tested:"ts"]") }
        print
      }' "$HYP" > "$TMP" && mv "$TMP" "$HYP"
      log_append "hyp status: $ID → $ST"
      ;;
    show|list|"") cat "$HYP" ;;
    *) echo "hyp subcommands: add|status|list" >&2; exit 2;;
  esac
  exit 0
fi

# ─── primitive ──────────────────────────────────────────────
if [ "$CMD" = "primitive" ]; then
  SUB="${1:-}"; shift || true
  case "$SUB" in
    add)
      F="${1:-}"; N="${2:-}"; R="${3:-}"; E="${4:-}"
      [ -n "$F" ] && [ -n "$N" ] && [ -n "$R" ] || { echo "usage: primitive <t> add <family> \"<name>\" \"<repro>\" [evidence_file]" >&2; exit 2; }
      ID="P$(date -u +%y%m%d%H%M%S)"
      printf -- "\n### %s — [%s] %s\n**Repro:** \`%s\`\n**Evidence:** %s\n**At:** %s\n" "$ID" "$F" "$N" "$R" "${E:-(none)}" "$(TS)" >> "$PRIM"
      # auto-tick the family
      TMP="$FAM.new"; awk -F'|' -v f="$F" -v ts="$(TS)" 'BEGIN{OFS="|"} /^[a-z]/ && $1==f {$3=ts} {print}' "$FAM" > "$TMP" && mv "$TMP" "$FAM"
      log_append "primitive add: [$F] $N  ($ID)"
      echo "✓ $ID"
      ;;
    show|list|"") cat "$PRIM" ;;
    *) echo "primitive subcommands: add|show" >&2; exit 2;;
  esac
  exit 0
fi

# ─── chain ──────────────────────────────────────────────────
if [ "$CMD" = "chain" ]; then
  SUB="${1:-}"; shift || true
  case "$SUB" in
    set)
      CH="${1:-}"; [ -n "$CH" ] || { echo "usage: chain <t> set \"step1||step2||step3\"" >&2; exit 2; }
      : > "$CHAIN"
      echo "# CDC Chain in progress — $TARGET (updated $(TS))" >> "$CHAIN"
      echo "" >> "$CHAIN"
      i=1
      IFS='|'
      # shellcheck disable=SC2086
      set -- $(printf '%s' "$CH" | sed 's/||/ /g')
      IFS=' '
      # simple split — use || literally in the input
      python3 - <<PY >> "$CHAIN"
chain = """$CH""".split('||')
for i, step in enumerate(chain, 1):
    print(f"{i}. {step.strip()}")
PY
      log_append "chain set: $CH"
      echo "✓ chain updated"
      ;;
    show|list|"") cat "$CHAIN" ;;
    *) echo "chain subcommands: set|show" >&2; exit 2;;
  esac
  exit 0
fi

# ─── blocked ────────────────────────────────────────────────
if [ "$CMD" = "blocked" ]; then
  SUB="${1:-}"; shift || true
  case "$SUB" in
    add)
      F="${1:-}"; P="${2:-}"; W="${3:-}"; E="${4:-}"
      [ -n "$F" ] && [ -n "$P" ] && [ -n "$W" ] || { echo "usage: blocked <t> add <family> \"<path>\" \"<why>\" [evidence]" >&2; exit 2; }
      printf -- "- **[%s] %s** — why: %s%s\n" "$F" "$P" "$W" "$( [ -n "$E" ] && printf ' — evidence: %s' "$E" )" >> "$BLK"
      log_append "blocked add: [$F] $P — $W"
      echo "✓ blocked"
      ;;
    show|list|"") cat "$BLK" ;;
    *) echo "blocked subcommands: add|show" >&2; exit 2;;
  esac
  exit 0
fi

# ─── verdict ────────────────────────────────────────────────
if [ "$CMD" = "verdict" ]; then
  SUB="${1:-}"; shift || true
  case "$SUB" in
    add)
      FID="${1:-}"; ST="${2:-}"; RE="${3:-}"; EV="${4:-}"
      [ -n "$FID" ] && [ -n "$ST" ] && [ -n "$RE" ] || { echo "usage: verdict <t> add <finding_id> <CONFIRMED|DISPROVED|INCONCLUSIVE> \"<reason>\" [evidence]" >&2; exit 2; }
      case "$ST" in CONFIRMED|DISPROVED|INCONCLUSIVE) : ;; *) echo "status must be CONFIRMED|DISPROVED|INCONCLUSIVE" >&2; exit 2;; esac
      printf -- "\n### %s — %s (at %s)\n**Reason:** %s\n**Evidence:** %s\n" "$FID" "$ST" "$(TS)" "$RE" "${EV:-(none)}" >> "$VER"
      log_append "verdict: $FID → $ST"
      echo "✓ verdict recorded"
      ;;
    show|list|"") cat "$VER" ;;
    *) echo "verdict subcommands: add|show" >&2; exit 2;;
  esac
  exit 0
fi

# ─── neglected ──────────────────────────────────────────────
if [ "$CMD" = "neglected" ]; then
  # families whose last_tick > 20 min ago (or never ticked)
  NOW=$(date -u +%s)
  echo "# Neglected families (last_tick > 20 min ago) — $(TS)"
  echo ""
  # skip header lines: those without '|' in a data-like pattern
  awk -F'|' 'NF==3 && $1!~/^(family|-)/{print}' "$FAM" | while IFS='|' read -r F A T; do
    # macOS date parse
    LAST=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$T" +%s 2>/dev/null || echo 0)
    DIFF=$(( NOW - LAST ))
    if [ "$DIFF" -gt 1200 ]; then
      MINS=$(( DIFF / 60 ))
      printf -- "- **%s** (owner: %s) — last_tick %s min ago  → dispatch new hypothesis\n" "$F" "$A" "$MINS"
    fi
  done
  exit 0
fi

# ─── recall ─────────────────────────────────────────────────
if [ "$CMD" = "recall" ]; then
  echo "═══════════════ CDC RECALL: $TARGET ═══════════════"
  for f in "$GOAL" "$DEPLOY" "$FAM" "$PRIM" "$CHAIN" "$BLK" "$VER"; do
    echo ""; echo "──────────── $(basename "$f") ────────────"; cat "$f"
  done
  echo ""; echo "──────────── LOG (tail) ────────────"; tail -30 "$LOG"
  exit 0
fi

# ─── log ────────────────────────────────────────────────────
if [ "$CMD" = "log" ]; then
  MSG="${1:-}"; [ -n "$MSG" ] || { echo "usage: log <target> \"<message>\"" >&2; exit 2; }
  log_append "$MSG"
  exit 0
fi

# ─── mode ───────────────────────────────────────────────────
if [ "$CMD" = "mode" ]; then cat "$MODE_FILE"; exit 0; fi

# ─── budget ─────────────────────────────────────────────────
if [ "$CMD" = "budget" ]; then
  SUB="${1:-check}"; shift || true
  SOFT=$(awk -F'|' '/^soft_budget_tokens\|/{print $2}' "$BUDGET_FILE")
  HARD=$(awk -F'|' '/^hard_budget_tokens\|/{print $2}' "$BUDGET_FILE")
  SPENT=$(awk -F'|' '/^spent_tokens\|/{print $2}' "$BUDGET_FILE")
  EMPTY=$(awk -F'|' '/^consecutive_empty_ticks\|/{print $2}' "$BUDGET_FILE")
  case "$SUB" in
    spent)
      ADD="${1:-}"; [ -n "$ADD" ] || { echo "usage: budget <t> spent <tokens>" >&2; exit 2; }
      NEW=$(( SPENT + ADD ))
      TMP="$BUDGET_FILE.new"
      awk -F'|' -v n="$NEW" -v ts="$(TS)" 'BEGIN{OFS="|"} /^spent_tokens\|/{$2=n; print; next} /^last_updated\|/{$2=ts; print; next} {print}' "$BUDGET_FILE" > "$TMP" && mv "$TMP" "$BUDGET_FILE"
      log_append "budget spent: +$ADD (total: $NEW / $HARD)"
      echo "spent: $NEW / hard $HARD"
      ;;
    empty)
      # increment consecutive-empty-tick counter (called when a tick yields no new primitives)
      N=$(( EMPTY + 1 ))
      TMP="$BUDGET_FILE.new"
      awk -F'|' -v n="$N" 'BEGIN{OFS="|"} /^consecutive_empty_ticks\|/{$2=n; print; next} {print}' "$BUDGET_FILE" > "$TMP" && mv "$TMP" "$BUDGET_FILE"
      log_append "budget empty-tick: consecutive=$N"
      echo "consecutive_empty_ticks: $N"
      ;;
    reset-empty)
      # called when a tick yields at least one new primitive
      TMP="$BUDGET_FILE.new"
      awk -F'|' 'BEGIN{OFS="|"} /^consecutive_empty_ticks\|/{$2=0; print; next} {print}' "$BUDGET_FILE" > "$TMP" && mv "$TMP" "$BUDGET_FILE"
      log_append "budget empty-tick counter reset"
      ;;
    check|"")
      # decide state: HARD_STOP | FINAL_PUSH | PLATEAU | HEALTHY
      if   [ "$SPENT" -ge "$HARD" ]; then echo "HARD_STOP"
      elif [ "$SPENT" -ge "$SOFT" ]; then echo "FINAL_PUSH"
      elif [ "$EMPTY" -ge 3 ];       then echo "PLATEAU"
      else                                 echo "HEALTHY"
      fi
      ;;
    show)
      cat "$BUDGET_FILE"
      ;;
    *) echo "budget subcommands: spent <n> | empty | reset-empty | check | show" >&2; exit 2;;
  esac
  exit 0
fi

# ─── interrupt ──────────────────────────────────────────────
if [ "$CMD" = "interrupt" ]; then
  SUB="${1:-check}"; shift || true
  case "$SUB" in
    set)
      REASON="${1:-manual-stop}"
      printf 'requested_at|%s\nreason|%s\n' "$(TS)" "$REASON" > "$INTERRUPT_FILE"
      log_append "OPERATOR-INTERRUPT: $REASON"
      echo "✓ interrupt flag set — root will exit at next tick check"
      ;;
    check|"")
      if [ -f "$INTERRUPT_FILE" ]; then echo "STOP"; cat "$INTERRUPT_FILE"; else echo "GO"; fi
      ;;
    clear)
      rm -f "$INTERRUPT_FILE"
      log_append "interrupt flag cleared"
      echo "✓ cleared"
      ;;
    *) echo "interrupt subcommands: set [reason] | check | clear" >&2; exit 2;;
  esac
  exit 0
fi

# ─── envelope ───────────────────────────────────────────────
# Parses a structured JSON envelope from a hunter and lands it as a PRIMITIVE (via the primitive add path).
# Usage:
#   cdc-state.sh envelope <target> '<json-envelope>'
# Envelope shape (all fields required except evidence_path):
#   {"family":"ssrf","primitive_name":"webhook-oob","repro_cmd":"curl -X POST …","evidence_path":".cdc/…/evidence/x.txt","prereqs":"authenticated user","impact_shape":"internal HTTP read","hunter_agent":"ssrf-hunter"}
if [ "$CMD" = "envelope" ]; then
  JSON="${1:-}"; [ -n "$JSON" ] || { echo "usage: envelope <target> '<json>'" >&2; exit 2; }
  command -v python3 >/dev/null || { echo "envelope requires python3" >&2; exit 4; }
  python3 - "$JSON" <<'PY' > "$ROOT/.env.tmp" || { rm -f "$ROOT/.env.tmp"; echo "envelope: invalid JSON" >&2; exit 5; }
import json, sys
try:
    e = json.loads(sys.argv[1])
except Exception as ex:
    print("PARSE_ERROR:" + str(ex), file=sys.stderr); sys.exit(2)
req = ["family","primitive_name","repro_cmd"]
missing = [k for k in req if not e.get(k)]
if missing:
    print("MISSING:" + ",".join(missing), file=sys.stderr); sys.exit(3)
print(e["family"])
print(e["primitive_name"])
print(e["repro_cmd"])
print(e.get("evidence_path",""))
print(e.get("prereqs",""))
print(e.get("impact_shape",""))
print(e.get("hunter_agent",""))
PY
  # read parsed lines and delegate to `primitive add` semantics
  { IFS= read -r F; IFS= read -r N; IFS= read -r R; IFS= read -r E; IFS= read -r PR; IFS= read -r IM; IFS= read -r HA; } < "$ROOT/.env.tmp"
  rm -f "$ROOT/.env.tmp"
  ID="P$(date -u +%y%m%d%H%M%S)"
  printf -- '\n### %s — [%s] %s\n**Repro:** `%s`\n**Prereqs:** %s\n**Impact shape:** %s\n**Hunter:** %s\n**Evidence:** %s\n**At:** %s\n' \
    "$ID" "$F" "$N" "$R" "${PR:-(none)}" "${IM:-(none)}" "${HA:-(unknown)}" "${E:-(none)}" "$(TS)" >> "$PRIM"
  # auto-tick the family + reset empty-tick counter (this is a genuine primitive landing)
  TMP="$FAM.new"; awk -F'|' -v f="$F" -v ts="$(TS)" 'BEGIN{OFS="|"} /^[a-z]/ && $1==f {$3=ts} {print}' "$FAM" > "$TMP" && mv "$TMP" "$FAM"
  TMP="$BUDGET_FILE.new"
  awk -F'|' 'BEGIN{OFS="|"} /^consecutive_empty_ticks\|/{$2=0; print; next} {print}' "$BUDGET_FILE" > "$TMP" && mv "$TMP" "$BUDGET_FILE"
  log_append "envelope: [$F] $N  ($ID)  hunter=$HA"
  echo "✓ $ID  [$F] $N"
  exit 0
fi

echo "cdc-state: unknown command '$CMD'"; sed -n '1,30p' "$0"; exit 2
