---
description: CDC vulnerability-research harness. Multi-agent parallel-family loop with anti-convergence, hypothesis rotation, blocked-path memory, independent adversarial validation, chain-until-impact. Distinct from /mad-hunt (bounty enumeration). Usage — /cdc-research <target> [--goal "unauth→RCE"] [--families xss,ssrf,idor]
---

# /cdc-research — Concurrent Divergent-Cognition harness

Target / task: **$ARGUMENTS**

You (this Claude Code session) are the **root orchestrator**. Read `~/.claude/skills/mad-hacks/references/cdc-harness.md` in full — it is the loop, the doctrine, and the exit conditions. This command wires you into it.

## What this is (and is not)

CDC is **vulnerability research** — you must chain novel primitives until you meet a concrete starting-privilege → impact goal, adversarially validate each step, and refuse to accept a single primitive as "the finding". It is **not** `/mad-hunt` (that's bounty-catalog exhaustion) and it is **not** `/mad-hacks` alone (that's the general operator skill).

## Non-negotiable doctrine (from `references/cdc-harness.md` §0)

1. Parallel, distinct families (≥3 active at all times).
2. Anti-convergence — split agents that trend toward the same primitive.
3. Blocked paths stay blocked (`.cdc/<target>/BLOCKED.md`).
4. Hypothesis rotation on a clock — every ~20 min, launch a new hypothesis in the oldest neglected family.
5. Adversarial validation is **independent** — never let the producer validate their own finding.
6. Root synthesizes continuously (challenge assumptions, reprioritize, redirect).
7. **No CVE / changelog / patch-diff shortcuts.** Reproduce in a realistic runtime.
8. **Chain-until-impact.** A primitive is a step; keep going until GOAL is met.
9. Inspect the runtime — read dependency source, framework internals, DB engine behavior.
10. Realistic, common configuration — a chain that needs debug=true is a footnote.

## Boot sequence

```bash
# 1. Doctrine + scope + goal
cat ~/.claude/skills/mad-hacks/references/doctrine.md          # authorization, VERIFY/REFUTE, absolute stops
bash ~/.claude/skills/mad-hacks/scripts/scope.sh init <target>
bash ~/.claude/skills/mad-hacks/scripts/preflight.sh <target>

# 2. CDC state — GOAL, DEPLOYMENT, and MODE are mandatory
bash ~/.claude/skills/mad-hacks/scripts/cdc-state.sh init <target> \
     --goal       "<starting-priv → impact, one sentence>" \
     --deployment "<realistic common config: framework, versions, hosting, defaults>" \
     --mode       "<bug-bounty|pentest|research>" \
     --visibility "<greybox|blackbox|whitebox>"   # optional; default greybox for pentest/research, blackbox for bug-bounty
     # optional: --soft-budget-tokens 600000  --hard-budget-tokens 1000000

# 3. Recall prior knowledge on this target
bash ~/.claude/skills/mad-hacks/scripts/brain.sh recall <target>
bash ~/.claude/skills/mad-hacks/scripts/cdc-state.sh recall <target>
```

**Mode-specific rider added to every hunter briefing** (auto-derived from `MODE.md`):
- **bug-bounty**: safe-PoC discipline (`references/production-safety.md` R1–R11). Never destructive on live target. OOB variants preferred over impact-in-place. Report shape is platform-ready draft.
- **pentest / red team**: RoE-bound. Impact must be demonstrated within engagement's RoE. Report shape is executive + technical.
- **research**: greybox/whitebox full doctrine. Reproduce against local instance. Read dependency source when behavior depends on it. Report shape is technical writeup + brain capture.

## Family partition (do this before ANY dispatch)

Pick ≥3 exploit families that plausibly reach GOAL. Assign each a hunter agent from `references/router.md`. Record:

```bash
bash scripts/cdc-state.sh family <target> assign ssrf     ssrf-hunter
bash scripts/cdc-state.sh family <target> assign idor     idor-hunter
bash scripts/cdc-state.sh family <target> assign deserial rce-hunter
bash scripts/cdc-state.sh family <target> assign xss      xss-hunter
```

Seed suggestions by goal type in `references/cdc-harness.md` §3 "Family partition".

## The tick loop (repeat)

**Every tick, BEFORE anything else, check gates:**
```bash
STATE=$(bash scripts/cdc-state.sh interrupt <target> check)
if [ "$STATE" != "GO" ]; then
  # operator asked to stop → dispatch t3-reporter with current state and exit
  <dispatch t3-reporter --negative-result --reason "operator-interrupt">
  exit
fi
BUDGET=$(bash scripts/cdc-state.sh budget <target> check)
case "$BUDGET" in
  HARD_STOP)   <dispatch t3-reporter --negative-result --reason budget-exhausted> ; exit ;;
  PLATEAU)     PHASE="FINAL_PUSH"   # skip hypothesis rotation, focus on chain composition
               log "PLATEAU detected — entering final-push mode" ;;
  FINAL_PUSH)  PHASE="FINAL_PUSH" ;;
  HEALTHY)     PHASE="DIVERGE" ;;
esac
```

### 1. Dispatch hunters — BATCH INTO ONE MESSAGE

For every active family (from `FAMILIES.md`), dispatch a hunter subagent. **Critical: all family dispatches go in ONE assistant message with N `Agent` tool_use blocks.** Sequential dispatches serialize and violate doctrine point 1. Every hunter's briefing must include:

1. `GOAL.md` + `DEPLOYMENT.md` + `BLOCKED.md` verbatim.
2. Mode rider derived from `MODE.md` (bug-bounty safe-PoC / pentest RoE / research greybox-full).
3. Structured-envelope contract: return `{family, primitive_name, repro_cmd, evidence_path, prereqs, impact_shape, hunter_agent}` — one envelope per primitive found.
4. "Runtime > docs" reminder — inspect libs/framework/dependency source directly when behavior depends on it. Do NOT rely on CVE / changelog / patch-diff as proof.

As each hunter returns, root parses each envelope:
```bash
bash scripts/cdc-state.sh envelope <target> '{"family":"ssrf","primitive_name":"webhook-oob",...}'
# auto-lands in PRIMITIVES.md, ticks the family, resets plateau counter
```

If NO family produced a new envelope on this tick:
```bash
bash scripts/cdc-state.sh budget <target> empty   # increment plateau counter
```

### 2. Synthesize + reprioritize

```bash
bash scripts/cdc-state.sh recall <target>
bash scripts/cdc-state.sh neglected <target>
```

- **Anti-convergence:** if ≥2 hunters trended toward the same primitive shape (same param + sink + auth level), reassign the weaker one to the oldest family in `neglected`.
- **Assumption challenge:** pick strongest lead → name its load-bearing assumption → dispatch a targeted probe to break it.
- **Chain draft** (only if `PHASE=FINAL_PUSH` or ≥2 CONFIRMED primitives exist in different families):
  ```bash
  bash scripts/cdc-state.sh chain <target> set "primitive_A || primitive_B || primitive_C → impact"
  # then Task-dispatch chain-builder to walk it end-to-end
  ```
- **Hypothesis rotation** (skip if `PHASE=FINAL_PUSH`): for each family in `neglected`, launch a fresh hypothesis:
  ```bash
  bash scripts/cdc-state.sh hyp <target> add <family> "hypothesis in one sentence"
  ```

### 3. Independent adversarial validation — via the cdc-verify Workflow

For every primitive that hasn't yet been verdict-checked, call the parallel verify workflow:

```
Workflow({ name:'cdc-verify', args:{
  target,
  mode:      "<bug-bounty|pentest|research>",
  visibility:"<greybox|blackbox|whitebox>",
  goal:      "<verbatim GOAL.md>",
  deployment:"<verbatim DEPLOYMENT.md>",
  blocked_paths_md: "<verbatim BLOCKED.md>",
  primitives: [<the primitives to verify, structured>]
}})
```

Workflow fans out N verifier agents (`t3-verifier`) in parallel, each with the DISPROVE-by-default contract from `references/cdc-harness.md` §4b, returns an array of structured verdicts. Root writes each:

```bash
bash scripts/cdc-state.sh verdict <target> add P<id> CONFIRMED "reason" evidence/…
bash scripts/cdc-state.sh verdict <target> add P<id> DISPROVED "reason" evidence/…
```

### 4. Block dead paths

Every DISPROVED primitive with a durable refutation goes into `BLOCKED.md`:
```bash
bash scripts/cdc-state.sh blocked <target> add <family> "<path/pattern>" "<refutation reason>" evidence/…
```
Every future hunter briefing includes the updated BLOCKED.md.

### 5. Budget accounting + log

```bash
# Root estimates tokens spent this tick (agent count × avg tokens/agent from workflow diagnostics).
bash scripts/cdc-state.sh budget <target> spent <tokens>
bash scripts/cdc-state.sh log <target> "tick complete — <n> primitives, <k> verdicts, PHASE=$PHASE"
```

## Exit conditions (four)

1. **Success** — CHAIN.md's terminal node has an independently-CONFIRMED verdict AND meets GOAL.md's impact under DEPLOYMENT.md. Dispatch `t3-reporter` with the full chain + evidence. Mode determines report shape:
   - bug-bounty → platform-ready draft
   - pentest → executive + technical writeup
   - research → technical writeup + brain capture (`brain.sh finding` + `brain.sh learn`).
2. **HARD_STOP (budget exhausted)** — `budget check` returns `HARD_STOP`. Dispatch `t3-reporter --negative-result --reason "budget-exhausted"` with what was tried, blocked, validated, and the gap. Do NOT fabricate a finding.
3. **PLATEAU (diminishing returns)** — `budget check` returned `PLATEAU` and final-push produced no CONFIRMED chain. Dispatch `t3-reporter --negative-result --reason "plateau"` with the same shape as (2), plus the plateau-detector's evidence (which ticks were empty, which families are mapped).
4. **Operator interrupt** — `interrupt check` returns `STOP`. Dispatch `t3-reporter --negative-result --reason "operator-interrupt"` with current state and the operator's stated reason.

**Do not** invent a "we might have found something" narrative to avoid a negative-result exit. Negative results are useful. `t3-reporter` supports them explicitly.

## Refuse

- CVE says vulnerable → **still reproduce it here.**
- Patch diff shows the fix → **still confirm the pre-fix path is reachable at your starting privilege on DEPLOYMENT.**
- Docs warn about X → docs are hypothesis; runtime is oracle.
- One primitive worked → keep chaining until GOAL.
- Same agent producing + validating → split them; independence is the point.

## Cross-references

- Full spec: `~/.claude/skills/mad-hacks/references/cdc-harness.md`
- Doctrine: `~/.claude/skills/mad-hacks/references/doctrine.md`
- Router (per-class asset map): `~/.claude/skills/mad-hacks/references/router.md`
- 22-phase coverage checklist: `~/.claude/skills/mad-hacks/references/xalgorix-methodology.md`
- Recon arsenal: `~/.claude/skills/mad-hacks/references/recon-oneliners.md`
