---
description: "Invariant-driven sliced audit. Sibling to /mad-hunt. Threat-model → invariants → small slices → 2-6 hunters per slice → strict verifier with inverted framing → negative-memory ledger → next slice. Small active context by design (per references/mad-audit.md doctrine). Usage: /mad-audit <target-or-repo>"
---

Invariant-driven audit on: **$ARGUMENTS**

You are the /mad-audit orchestrator. Read `~/.claude/skills/mad-hacks/references/mad-audit.md` in full FIRST, then execute the loop.

## Hard preconditions (before ANY packet leaves the machine)

1. Scope + preflight — same as /mad-hunt:
   `bash scripts/scope.sh init <target>` if no `.t3mp3st/SCOPE.md`
   `python3 scripts/scope.py --md .t3mp3st/SCOPE.md <target>` MUST print IN-SCOPE
   `python3 scripts/preamble.py --md .t3mp3st/SCOPE.md` (inject preamble into every dispatch)

2. Audit control plane — NEW:
   `bash scripts/audit-slice.sh init <target>` scaffolds `.audit/`
   Read `.audit/system-context.yaml` and FILL IT MANUALLY — the audit is
   only useful if the system context reflects reality. Do NOT auto-populate;
   the operator's answers to "what does this system do" are the compression
   layer.

## The loop (per references/mad-audit.md)

Once system-context is filled, run in order:

**Phase A — planning (one pass, then iterate):**

- `Agent({subagent_type: 'slice-planner', prompt: "target=$ARGUMENTS; recon=.t3mp3st/$ARGUMENTS/recon/*"})` — writes threat-model + invariants + slices to `.audit/*.yaml`. Slice-planner will refuse to work if system-context.yaml is still template.

**Phase B — per-slice execution loop (until `audit-slice.sh next` returns "no eligible"):**

```
bash scripts/audit-slice.sh next                       # returns S-XXXX-NNN
bash scripts/audit-slice.sh start S-XXXX-NNN           # planned → active
bash scripts/audit-hunt.sh S-XXXX-NNN                  # prints dispatch plan
# for each hunter in the dispatch plan, in parallel:
Agent({subagent_type: '<hunter>', prompt: "AUDIT_SLICE=S-XXXX-NNN; target=$ARGUMENTS; slice=<inline slice yaml>"})
# collect candidates from each hunter's output.
# for each candidate:
Agent({subagent_type: 'verifier-strict', prompt: "candidate=<...>; slice=S-XXXX-NNN"})
# for each verdict:
bash scripts/audit-slice.sh decision S-XXXX-NNN <VERDICT> "<claim>" "<reason>" "<evidence>"
bash scripts/audit-slice.sh complete S-XXXX-NNN        # active → complete
# CONFIRMED candidates auto-flow into report via:
bash scripts/report.sh build $ARGUMENTS                # picks up EVIDENCE.jsonl too
```

**Phase C — model update (as findings land):**

If a slice discovers something that CHANGES the threat model (new endpoint, new bucket, new bypass class), edit `.audit/threat-model.yaml` + add new invariants + add new slices. `audit-slice.sh next` will pick up the newly-planned slices automatically on the next iteration.

## Never (in addition to /mad-hunt's absolute stops)

- Never spawn 10+ hunters at once. If `audit-hunt.sh` returns 6 candidates the max is 6, and lower is usually better.
- Never accept a candidate for report without a verifier-strict verdict on it.
- Never mark a slice complete while there are unresolved candidates. Either resolve them (decision) or defer to a new slice + `audit-slice.sh skip <slice> "deferred to S-YYYY"`.
- Never dump the full 6,879-row writeup corpus into hunter context. Every hunter's Preflight uses `intelligence-recall.sh --slice <id>` which top-K's to slice-relevant items only.

## Difference from /mad-hunt

| | `/mad-hunt` | `/mad-audit` |
|---|---|---|
| Dispatch pattern | class-focused, exhaustion contract, 55 hunters | slice-focused, 2-6 hunters per slice via 3-dim scoring |
| Retrieval query | class + target keywords, broad | slice attack_surface + invariant classes, narrow (via `--slice`) |
| Verifier framing | validator (7-Question Gate) | strict inverter (candidate is presumed FALSE) |
| Memory | brain/lessons.md + engagement-state | brain + engagement-state + `.audit/decisions.yaml` (negative memory) |
| Reporting | platform-native drafts (H1/Bugcrowd) | .t3mp3st/target/report.md (audit-shaped) |

Use `/mad-hunt` for bounty exhaustion. Use `/mad-audit` for depth-oriented reviews (source-audit engagements, novel-vuln research, security-review pull requests).

## The end state

When `audit-slice.sh next` returns "no eligible slice":
- `audit-slice.sh status` shows all slices in `complete` or `skipped`
- `report.sh build $ARGUMENTS` produces the final report (CONFIRMED findings from decisions.yaml → F-*.md)
- Present the operator with: (a) final report; (b) `.audit/decisions.yaml` for the negative-memory ledger; (c) `progress.yaml` context-accounting ratios; (d) list of REJECTED candidates that could be promoted to `brain/lessons.md` as reusable negative memory.
