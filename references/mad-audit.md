# /mad-audit — invariant-driven sliced auditing

The `/mad-hunt` sibling for depth-oriented work. Where `/mad-hunt` is a
class-focused BOUNTY sweep (surface × payout × exhaustion contract),
`/mad-audit` is a THREAT-MODEL-DRIVEN audit: convert the target into a
system-context + threat-model + invariants, split into small slices,
dispatch 2-6 hunters per slice with slice-scoped context, verify with the
inverted-framing verifier, record every rejection as negative memory,
update the threat model, next slice.

## Why this exists

The existing mad-hacks brain is a strong retrieval subsystem (SQLite FTS5
+ optional FAISS + state-as-filter + 6,879 writeups + 33 payload classes
+ 110 lessons + 55 portable hunters). But retrieval is only half the
audit — the other half is **compressing the target into a set of testable
security questions**. That compression is what the threat model does, and
what `/mad-hunt` explicitly does NOT do.

The article "needle in the haystack" (devansh) makes the same point:
more knowledge does NOT mean more context. Active Claude context should
stay small (~10% persistent scaffolding, 60-80% slice exploration, 20-30%
verification). The mad-hacks brain is the "10,000 documents"; the
sliced-audit control plane is the "3-10 memories per slice" that keeps
active context small.

## The control plane

Six YAML files, all at `.audit/` in the CWD of the engagement. The YAML
is authoritative; `scripts/audit-slice.sh` is a thin CLI over it. All six
are diffable in git and recoverable after Claude compaction.

| File | Written by | Loaded per hunter dispatch |
|---|---|---|
| `system-context.yaml` | operator | yes (~1KB) |
| `threat-model.yaml` | operator + slice-planner | yes (~1KB) |
| `invariants.yaml` | operator + slice-planner | yes (only the slice's) |
| `slices.yaml` | slice-planner | yes (only the current slice) |
| `progress.yaml` | audit-slice.sh state transitions | no |
| `decisions.yaml` | verifier-strict | yes (only DEC entries for this slice's invariants) |

Templates live at `references/audit-schemas/*.yaml`. `audit-slice.sh
init` copies them into `.audit/`.

## The loop

```
recon (existing recon.sh + web-scan.sh)
    ↓
audit-slice.sh init <target>          → scaffolds .audit/*.yaml
    ↓
operator fills system-context.yaml    → 1 paragraph + trust boundaries +
                                        crown jewels + attackers
    ↓
Agent(slice-planner)                  → reads recon + system-context,
                                        writes threat-model + invariants +
                                        initial slices
    ↓
┌─── loop until no slice with status=planned ────────┐
│                                                    │
│   audit-slice.sh next                              │
│      → returns highest-priority planned slice      │
│                                                    │
│   audit-slice.sh start <slice_id>                  │
│      → status planned → active                     │
│                                                    │
│   audit-hunt.sh <slice_id>                         │
│      → scores every hunter in manifest.json        │
│        (3-dim: attack-surface + invariant-coverage │
│         + dependency-availability)                 │
│      → picks top 2-6                               │
│      → prints dispatch plan; operator invokes      │
│        Agent() with AUDIT_SLICE=<id> in env        │
│                                                    │
│   [hunters run with slice-scoped context]          │
│   [candidates go to Agent(verifier-strict)]        │
│                                                    │
│   Agent(verifier-strict) per candidate             │
│      → inverted framing: candidate is presumed     │
│        FALSE, disprove it                          │
│      → structured verdict: reachability,           │
│        attacker_control, invariant_violation,      │
│        exploitability, impact                      │
│      → decision: CONFIRMED | REJECTED |            │
│        INCONCLUSIVE                                │
│                                                    │
│   audit-slice.sh decision <slice> <verdict>        │
│      → writes decisions.yaml row                   │
│      → rejected candidates become negative memory  │
│      → confirmed candidates fall through to        │
│        report.sh import-evidence + finding file    │
│                                                    │
│   audit-slice.sh complete <slice_id>               │
│      → status active → complete                    │
│      → updates progress.yaml aggregate             │
│                                                    │
│   (if the slice discovered something that changes  │
│    the model, operator edits threat-model.yaml     │
│    and adds new slices — audit-slice next picks    │
│    them up on the next iteration)                  │
│                                                    │
└────────────────────────────────────────────────────┘
    ↓
report.sh build                       → assembles finding files + evidence
```

## Slice size

A slice should be small enough that the article's technique works.
Concretely:

- 1 trust boundary
- 1-5 invariants
- Named entry points (URL patterns, function names, file paths)
- 2-6 hunters after scoring

Too big:
```
name: "Authentication"
```

Right-sized:
```
name: "JWT verification of bearer tokens at /api middleware"
entry_points: [GET /api/users/:id, ...]
files: [src/auth/jwt.ts, src/middleware/auth.ts]
invariants: [INV-001, INV-002, INV-003]
```

## Hunter scoring (3-dim)

`scripts/audit-hunt.sh` scores every hunter in `agents/manifest.json`
against the slice using three dimensions, each 0.0 to 1.0:

1. **Attack-surface match** — `|slice.attack_surface ∩ hunter.supported_classes| / |slice.attack_surface|`
2. **Invariant coverage** — same intersection, but against the classes hinted by each of `slice.invariants[].classes` in `invariants.yaml`
3. **Dependency availability** — `hunter.requires_scripts` + `hunter.requires_references` all resolvable in the repo

Ranked, top 2-6 dispatched. `slice.preferred_hunters` breaks ties toward
operator intent. This prevents the new dispatcher from degenerating into
a smaller version of the old swarm.

## The verifier contract

`agents/operators/verifier-strict.md` enforces:

> You are not a second hunter. The candidate is presumed FALSE. Your job
> is to find the missing assumption, guard, unreachable path,
> sanitization, environmental restriction, or other reason the claim
> does not hold. Only after attempting to disprove it should you evaluate
> whether exploitation can be demonstrated.

Required output shape:

```yaml
verification:
  reachability: true|false
  attacker_control: true|false
  invariant_violation: true|false
  exploitability: true|false
  impact: true|false
decision: CONFIRMED | REJECTED | INCONCLUSIVE
evidence: [...]
```

No free-form "looks valid" — the runner rejects unshaped output.

## Context accounting (measurable)

Every hunter dispatch appends to `progress.yaml` under `runs[].context_accounting`:

```yaml
persistent_scaffolding_tokens: 3200      # system-context + threat-model
slice_context_tokens: 1800                # this slice's yaml block
memory_tokens: 4200                       # intelligence-recall top-K
code_exploration_tokens: 26000            # actual file reads / probes
verification_tokens: 6800
```

Then the aggregate ratio is auditable: are we spending tokens on
exploration (target: 60-80%) or on scaffolding (target: <15%)?

## `/mad-audit` vs `/mad-hunt`

```
/mad-hunt <target>
    = bounty sweep. class-focused. exhaustion contract.
      55 hunters dispatched by surface × payout ranking.
      broad recall via intelligence-recall.sh.

/mad-audit <target>
    = invariant-driven audit. threat-model-focused.
      2-6 hunters per slice via 3-dim scoring.
      targeted recall via intelligence-recall.sh --slice <id>.
      strict verifier with inverted framing.
      negative memory in decisions.yaml.
```

Same 55 hunters, same brain, same retrieval — different dispatcher and
different context envelope.

## What this commit does NOT add (deferred)

- Ruflo / Postgres / pgvector — the existing SQLite FTS5 is working; add
  infra only when a specific query pattern proves it's needed.
- Cross-encoder rerank — would probably lift indirect-category retrieval;
  measure indirect MRR gap first.
- Auto-promotion of `decisions.lesson` into `brain/lessons.md` — the
  `promoted_to_brain_lesson` flag exists in the schema; the promotion
  script comes with real usage.
- Slice dependency graph solver — `slice.depends_on` is honored but not
  visualized; a dot-graph emitter is trivial to add later.

The point of this commit is to demonstrate the sliced-audit shape
without infrastructure investment. Everything above the retrieval layer
can iterate freely.
