# CDC Harness — Concurrent Divergent-Cognition Vulnerability-Research Loop

`/cdc-research <target> --goal "…" --deployment "…" [--mode bug-bounty|pentest|research] [--visibility greybox|blackbox|whitebox] [--soft-budget-tokens 600000] [--hard-budget-tokens 1000000]`

**Not `/mad-hunt`.** `/mad-hunt` is *bounty enumeration* — sweep the known-vuln catalog against a bug-bounty target under scope + policy. **CDC is *vulnerability research*** — hunt novel primitives against a specific system, chain them until you meet a defined starting-privilege → impact goal, adversarially validate every step, and refuse to stop at the first primitive. Different loop, different exit condition.

**Operates in three modes** (same loop, different hunter briefings + report shape):

| Mode | Default visibility | Payload safety | Report | Scope |
|---|---|---|---|---|
| **bug-bounty** | blackbox | Safe-PoC only (R1–R11) | Platform-ready draft (H1/Bugcrowd/Intigriti) | `scope.py` hard-gate |
| **pentest** (red team) | greybox | RoE-defined | Executive + technical writeup | RoE document |
| **research** (default) | greybox | Operator-defined | Technical writeup + brain capture | `.t3mp3st/SCOPE.md` |

**Greybox is the default visibility** because doctrine points 7–9 (runtime inspection, dependency-source reading, realistic-config verification) presuppose source + a runnable target. **Blackbox is supported as a documented degraded mode** — every finding whose runtime inspection was substituted with doc-reading is tagged `inspection_degraded=true` in the verdict and flagged in the report.

The state directory `.cdc/<target>/` is persistent, resumable, and human-inspectable. Every state transition is a bash call to `scripts/cdc-state.sh` (`scope.sh` / `brain.sh` house style).

---

## 0. The 10 doctrine points (non-negotiable)

1. **Parallel, distinct families.** At any moment ≥3 exploit families are ACTIVE and assigned. Two agents on the same family = wasted breadth.
2. **Anti-convergence.** If ≥2 active agents are heading toward the same primitive, the root splits them — one keeps going, the other pivots to a NEGLECTED family. Convergence tempts everyone; resist.
3. **Blocked paths stay blocked.** A path enters `BLOCKED.md` with (path, why, evidence-file, at-what-privilege). Every hunter reads `BLOCKED.md` before probing — no repeats.
4. **Hypothesis rotation on a clock.** Every N minutes (default 20), the root scans `NEGLECTED.md` and launches at least one new hypothesis in a family with the OLDEST `last_tested`. Starvation is a bug.
5. **Adversarial validation is independent.** The agent that proved a finding never validates it. The validator's job is to DISPROVE — different reasoning path, different tooling, oracle-grounded evidence.
6. **Root continuously synthesizes.** After each primitive lands, the root reprioritizes: challenge the assumption behind the strongest lead, promote a neglected family, redirect the weakest agent.
7. **No shortcuts via patches / CVEs / diffs.** Do NOT rely on git history, changelogs, CVE databases, or "the patched version diff shows…" as the *proof*. Those are hints, never oracles. Truth = an actual exploit that fires against a realistic runtime.
8. **Chain until impact, not until primitive.** A single primitive (e.g. "path reflection") is a step, not a finding. Keep chaining validated primitives until the concrete **starting-privilege → impact** goal is reached (or the chain is provably impossible under the deployed configuration).
9. **Inspect the runtime.** When behavior depends on the framework, DB engine, library version, or a dependency's internals — READ THE DEPENDENCY SOURCE. `go doc`, `pip show -f`, `npm view`, `pnpm ls`, `bundle info`, `find / -path '*<pkg>*.py'`, or a debugger against the running process. Documentation is a hypothesis; runtime is the oracle.
10. **Realistic, common configuration.** The chain must work in the deployment shape >50% of users run — default settings, common hosting (Nginx/Apache/Cloudflare/AWS Fargate), stock libraries. A chain that requires an exotic misconfig is a footnote, not a finding.

---

## 1. Architecture (the loop)

```
                ┌───────────────────────────────────────────────────────────┐
                │                    /cdc-research entry                    │
                │  scope + goal + starting privilege + realistic deploy     │
                └───────────────────────────────────────────────────────────┘
                                          │
                                          ▼
                          ┌───────────────────────────────┐
                          │  Root (this Claude session)   │
                          │  reads .cdc/<target>/ state   │
                          │  synthesizes / reprioritizes  │
                          └───────────────────────────────┘
                     ┌──────────────┼──────────────┬──────────────┐
                     ▼              ▼              ▼              ▼
              ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐
              │ Family A  │  │ Family B  │  │ Family C  │  │ Family D  │
              │ hunter    │  │ hunter    │  │ hunter    │  │ hunter    │
              │  (XSS)    │  │  (SSRF)   │  │  (IDOR)   │  │ (deserial)│
              └───────────┘  └───────────┘  └───────────┘  └───────────┘
                     │              │              │              │
                     ▼              ▼              ▼              ▼
             primitives reported to root → PRIMITIVES.md (family-tagged)
                     │
                     ▼
              root picks the highest-impact primitive → dispatch CHAINER
              chainer builds candidate chain toward GOAL
                     │
                     ▼
              INDEPENDENT VERIFIER (different agent, different reasoning path)
                     │
             ┌───────┴────────┐
             │                │
         disproved       confirmed (evidence artifact)
             │                │
             ▼                ▼
       BLOCKED.md   VERDICTS.md  → is the chain long enough to reach GOAL?
                                        ┌──── no ────┐
                                        │            ▼
                                        │       return to primitives loop
                                        └── yes ─► REPORT
                     ▲
                     │  (every N min) root scans NEGLECTED.md → dispatch
                     │              a NEW hypothesis on the oldest family
                     └───────────────────────────────────────────────────
```

---

## 2. State files (`.cdc/<target>/`)

| File | Contents | Owner |
|---|---|---|
| `GOAL.md` | Starting-privilege → impact goal, in one sentence. e.g. "*Anonymous internet attacker → OS shell on the API host*". | Operator (set at init) |
| `DEPLOYMENT.md` | The *realistic, common* deployment being targeted (versions, hosting, defaults). This is what the chain must work against. | Operator (set at init) |
| `FAMILIES.md` | Table of active families + owner + last_tick. `xss│hunterA│2026-08-25T04:20Z` | `cdc-state.sh family` |
| `HYPOTHESES.md` | One row per hypothesis. `[FAMILY][age][last-tested][status:active|blocked|confirmed] short description` | `cdc-state.sh hyp` |
| `PRIMITIVES.md` | Confirmed low-level building blocks with the exact reproducer. `[family] primitive_name — repro cmd — evidence file` | `cdc-state.sh primitive` |
| `CHAIN.md` | Current chain-in-progress: ordered list of primitives assembled toward GOAL. | `cdc-state.sh chain` |
| `BLOCKED.md` | Dead paths + reason. Read by every hunter before probing. | `cdc-state.sh blocked` |
| `VERDICTS.md` | Independent verifier outcomes per finding: CONFIRMED / DISPROVED / INCONCLUSIVE + evidence link. | `cdc-state.sh verdict` |
| `NEGLECTED.md` | Auto-computed: families with `last_tick > 20 min ago`. Root scans this on every tick. | derived |
| `LOG.md` | Append-only timeline of every dispatch, primitive, blocked, verdict, chain-update. | auto |

The state manager (`scripts/cdc-state.sh`) provides atomic subcommands for every write. All state files are markdown so an operator can `less` them mid-run.

---

## 3. The loop, step by step

### Init (once per target)
```bash
bash scripts/cdc-state.sh init <target> --goal "unauth → RCE" --deployment "Next.js 14 App Router on Vercel Edge, Postgres, Cloudflare fronted, default config"
```
This writes `GOAL.md` + `DEPLOYMENT.md` + empty state files, and stamps `LOG.md`.

### Family partition
The operator picks ≥3 initial families based on the target surface + goal. Guidance:

| Goal type | Seed families |
|---|---|
| unauth → RCE | ssrf, deserial, ssti, rce, file-upload, prototype-pollution |
| user → admin ATO | idor, auth-bypass, mass-assignment, oauth, session-mgmt |
| tenant → cross-tenant read | idor, auth-bypass, cache-deception, api-abuse |
| any → cred/token theft | xss, ssrf, cors, open-redirect, cache-deception |

Assign each family a hunter agent via `router.md`. Record in `FAMILIES.md`:
```bash
bash scripts/cdc-state.sh family <target> assign ssrf ssrf-hunter
bash scripts/cdc-state.sh family <target> assign idor idor-hunter
bash scripts/cdc-state.sh family <target> assign xss xss-hunter
bash scripts/cdc-state.sh family <target> assign deserial rce-hunter
```

### Per-family dispatch (parallel)
Every hunter's task briefing MUST include:
1. `GOAL.md` verbatim (they must know the impact goal to prioritize)
2. `DEPLOYMENT.md` verbatim (they must not fabricate primitives that only work in exotic configs)
3. `BLOCKED.md` verbatim (do not re-probe dead paths)
4. Report every primitive with `cdc-state.sh primitive` — do NOT synthesize chains, do NOT write the report. **You produce primitives; the root chains.**
5. **Runtime > docs.** If your primitive depends on a library's parsing behavior, extract that library's source (`pip show -f`, `go doc -all`, `npm view`, or read from the running container) and cite the exact code path.
6. Return a structured JSON envelope: `{family, primitive_name, repro_cmd, evidence_path, prereqs, impact_shape}`.

### Synthesis (root tick — every ~5 primitives OR every 20 min)
The root:
1. Reads `PRIMITIVES.md`, `CHAIN.md`, `NEGLECTED.md`.
2. **Anti-convergence check:** if ≥2 hunters are pursuing the same primitive shape (same param, same sink, same auth level), the root reassigns the weaker one to the oldest family in `NEGLECTED.md`.
3. **Assumption challenge:** picks the strongest lead, writes down its load-bearing assumption ("*I assume the JSON parser accepts trailing commas*"), and dispatches a targeted probe to break that assumption.
4. **Chain candidate:** picks 2-3 confirmed primitives that could compose, drafts a candidate chain in `CHAIN.md`, dispatches the **chain-builder** agent (`references/router.md` chain-builder row) to walk it end-to-end.
5. **New hypothesis on oldest family:** picks the family whose `last_tick` is oldest and dispatches a fresh hypothesis into that family.

### Independent adversarial validation (per finding)
Every proposed chain node enters `VERDICTS.md` via a **different** agent than the one that produced it. That agent's task briefing:
1. "Your job is to DISPROVE this finding. Default to DISPROVED unless the evidence is oracle-grounded."
2. Re-run the reproducer from a clean state.
3. Check the primitive works against `DEPLOYMENT.md`'s realistic config — NOT just against a debug/dev toggle.
4. Verify the impact claim by producing the impact directly (read the file, exec the command, retrieve the token, cross the tenant boundary) — no theatrical "would allow" verbs.
5. Explicitly reject any evidence that leans on git history, changelogs, CVE IDs, or patched-version diffs.
6. Return `{status: CONFIRMED|DISPROVED|INCONCLUSIVE, evidence_path, refutation_reason}`.

### Chain-until-impact
The loop only exits when either:
- `CHAIN.md`'s current chain has an independently-CONFIRMED terminal node that MEETS `GOAL.md`, OR
- Every family has exhausted (all hypotheses either confirmed-and-composed, blocked, or in a chain that plateaued), AND the current best chain has been adversarially proven to be insufficient for `GOAL.md`. Then: report negative-result with the chain-so-far.

Otherwise: **do not stop at the first primitive.** A primitive is a step; a chain to impact is the finding.

---

## 4. Anti-shortcut discipline (the CVE trap)

Reflex temptations to REFUSE:
| Shortcut | Refuse because |
|---|---|
| "CVE-XXXX-YYYY covers this" | CVEs describe classes; they do not prove *this deployment* is exploitable. Reproduce it. |
| "The changelog says a fix was added to file X in commit Y" | A changelog is a hint, not an oracle. Test the pre-fix code path or reproduce on the pre-fix release. |
| "The patch diff shows the vulnerable code was `foo(untrusted)`" | You've read one narrative. Confirm the reachable call path from your starting privilege. |
| "Vuln DB says this endpoint is IDOR-prone" | Vuln DB is prior art; check THIS instance under THIS auth model. |
| "The framework docs warn about X" | Docs are best-effort; runtime behavior overrules them. |

Instead:
- Read the actual dependency source (`pip show -f`, `go doc -all`, `find -path '*<lib>*'`).
- Attach a debugger / add prints / snapshot the container.
- Reproduce the primitive from your starting privilege on a clean instance of `DEPLOYMENT.md`.

---

## 4b. Dispatch mechanics (hybrid — locked)

CDC uses a **hybrid** of the Task tool and the Workflow tool. Neither alone fits the shape:

### Hunters (produce primitives): **Task tool, batched in ONE message**

Family hunters are long-lived and iterative — they probe → observe → refine → probe again. That is Task's model, not Workflow's. **Critical:** the root MUST batch all family dispatches into a single message with N `Agent` tool_use blocks. Multiple `Agent` calls in one message run in parallel background; sequential dispatches serialize and violate doctrine point 1.

```
# ONE message, N Agent tool_use blocks
Agent({subagent_type:"ssrf-hunter",  prompt:"[GOAL][DEPLOYMENT][BLOCKED][envelope-contract]…"})
Agent({subagent_type:"idor-hunter",  prompt:"…"})
Agent({subagent_type:"rce-hunter",   prompt:"…"})   # for deserial family
Agent({subagent_type:"xss-hunter",   prompt:"…"})
```

Every hunter's briefing includes `GOAL.md` + `DEPLOYMENT.md` + `BLOCKED.md` verbatim + the mode rider from `MODE.md`. Every hunter is instructed to return a **structured JSON envelope** — root parses via `cdc-state.sh envelope <target> '<json>'` which lands it in `PRIMITIVES.md` and auto-resets the plateau counter.

### Verifiers (independently disprove primitives): **Workflow tool, schema-constrained parallel pass**

Adversarial validators are short-lived, structured, and highly parallel. Given N primitives, `workflows/cdc-verify.js` fans out N verifier agents concurrently with the `VERDICT_SCHEMA` (CONFIRMED|DISPROVED|INCONCLUSIVE + refutation_reason + oracle_evidence + inspection_degraded). The workflow enforces DISPROVED-by-default and mode-specific riders (bug-bounty safe-PoC, pentest RoE, research greybox-full).

```
Workflow({ name:'cdc-verify', args:{ target, mode, visibility, goal, deployment,
                                     blocked_paths_md, primitives:[…] } })
```

Root then writes each verdict to `VERDICTS.md` via `cdc-state.sh verdict add`.

### Chain-builder (compose primitives → chain): **Task tool (single agent)**

The `chain-builder` agent is iterative — walk a candidate chain end-to-end. Task tool, one instance.

### Impact-check (final): **Workflow tool** (schema-constrained pass/fail on GOAL)

When a chain's terminal node reaches CONFIRMED, root fires a final impact-check workflow that structurally answers *"does this chain, executed as written, produce the impact stated in GOAL.md?"* — pass/fail with evidence path.

---

## 4c. Halting condition (layered — locked)

Without a cap, "chain-until-impact" is non-terminating when the target isn't exploitable. Four tiers:

1. **Soft budget** (default `600000` tokens; configurable at init via `--soft-budget-tokens`). When `SPENT ≥ soft`, root enters **FINAL_PUSH** mode: stops launching new hypotheses, freezes NEGLECTED-family rotation, and directs all remaining budget at composing strongest confirmed primitives into candidate chains. Any confirmed chain that reaches GOAL still exits normally.
2. **Diminishing-returns tripwire** (parallel). Three consecutive ticks with zero new primitives across all families → root writes `PLATEAU` marker to `LOG.md` and enters final-push mode early. This catches genuine exhaustion before we hit budget.
3. **Hard budget** (default `1000000` tokens; `--hard-budget-tokens`). When `SPENT ≥ hard`, root forces graceful exit and dispatches `t3-reporter` with `--negative-result` (tagged `BUDGET_EXHAUSTED` or `PLATEAU` based on which trigger fired).
4. **Operator interrupt** — always available. `bash scripts/cdc-state.sh interrupt <target> set "<reason>"` writes `.cdc/<target>/INTERRUPT`. Root checks the flag at the top of every tick; presence → immediate graceful exit with current state.

State manager surfaces this via `cdc-state.sh budget <target> check` which returns one of `HEALTHY | FINAL_PUSH | PLATEAU | HARD_STOP`. The root branches on that string at every tick.

**Token-axis is default** (not wall-clock) because tokens map directly to Claude's actual constraint and the operator can walk away without losing progress.

## 5. Wiring to the existing swarm

- **Hunters:** dispatch per family via `references/router.md` (xss-hunter, ssrf-hunter, idor-hunter, rce-hunter, ssti-hunter, oauth-hunter, business-logic, mass-assignment via `hunt-registration.md`, etc.). Every hunter loads its methodology from the router table.
- **Verifier:** `t3-verifier` agent (`~/.claude/agents/t3-verifier.md`) is the adversarial validator. Its briefing is the DISPROVE contract in § 3.
- **Chainer:** `chain-builder` agent walks primitives into chains, feeding candidate chains back to the root for verifier dispatch.
- **Brain:** every CONFIRMED primitive → `bash scripts/brain.sh finding <target> "…"`. Every BLOCKED path → `bash scripts/brain.sh exhausted <target> "…"`. Every reusable lesson → `bash scripts/brain.sh learn "…"`.
- **Doctrine:** the gates in `references/doctrine.md` apply here unchanged — authorization, VERIFY/REFUTE, anti-fabrication, secrets-are-evidence-not-loot, absolute stops.

## 6. Exit conditions

**Success:** `VERDICTS.md` contains a CONFIRMED chain whose terminal node meets `GOAL.md` under `DEPLOYMENT.md`. Root dispatches `t3-reporter` with the chain + evidence.

**Negative result:** every family exhausted, best chain adversarially confirmed insufficient. Root dispatches `t3-reporter` with a *negative-result report* — what was tried, what was blocked, what was validated, what the gap is. Negative results are useful; do not fabricate a "finding" to fill the gap.

**Operator interrupt:** the operator can `cat .cdc/<target>/*.md` any time. The state IS the memo.

## 7. Evidence directory

All artifacts under `.cdc/<target>/evidence/` — one file per primitive / verdict. Files referenced by path from `PRIMITIVES.md` and `VERDICTS.md`. Redact secrets before writing (`references/doctrine.md`).

## 8. Not-to-do list

- Do not run all hunters against the same low-hanging path. That's convergence.
- Do not accept a primitive as "the finding". A primitive is a step.
- Do not accept a CVE, patch diff, or changelog as proof of exploitability HERE.
- Do not stop after the first CONFIRMED primitive. Keep chaining.
- Do not skip the DEPLOYMENT.md constraint. A chain that needs `debug=true` in prod is not a finding.
- Do not let the same agent produce AND validate a finding. Independence is the point.
