# mad-Hacks_ai — Keyless Offensive-Security Operations Base

**You (this Claude Code session) are the backbone.** No API keys, no server, no second bill. You run a full kill-chain — recon → weaponize → exploit → verify → report — driving real system tools over Bash, under a strict authorization + evidence + anti-fabrication doctrine, backed by a **persistent brain that compounds** across engagements and every repo you feed in.

> Single source of truth. This folder IS the toolkit and IS the `/mad-hacks` skill (symlinked to `~/.claude/skills/mad-hacks`). The `t3-*` operator subagents live in `agents/` (symlinked into `~/.claude/agents/`).

## How to operate — always
For any offensive-security task (pentest, bug bounty, CTF, source/cloud/mobile/binary/AI review):

```
/mad-hacks <target-or-task>
```

That loads `SKILL.md`, which pulls only the `references/` docs a given mission needs — routed via `references/router.md` (the load-on-CLASSIFY asset map; see SKILL.md §0's 3-tier lazy-load model). For real engagements, act as coordinator and dispatch the operator swarm via the Task tool.

**Bug bounty (autonomous):** `/mad-hunt <target> [--auto]` — the exhaustion-contract hunt spine: scope.py gate → policy preamble → per-host surface probe A–I → surface×payout-ranked specialist hunters (≥25 attempts/class) → 7-Q + `t3-verifier` validation → `chain-builder` escalation → platform-native ready-to-submit drafts. Adaptive-throttle, never auto-submits, never creates accounts. Loop spec: `references/mad-hunt.md`.

## The loop (this is what makes it get smarter)
```
brain recall ─► classify family ─► SCOPE gate ─► t3-recon ─► t3-scanner
                                                        │ (fan out per candidate/class)
                                                        ▼
                                                   t3-exploiter ──confirm──► t3-verifier (adversarial: try to kill it)
                                                                                  │ survivors only
                                                                                  ▼
                                                                             t3-reporter ─► report.md ─► brain capture
```
- **Recall first:** `bash scripts/brain.sh recall <target>` — prior findings, exhausted vectors, lessons, payload classes.
- **Capture last:** `t3-reporter` writes confirmed findings + lessons back to the brain.

## Folder layout
| Dir | Holds |
|-----|-------|
| `SKILL.md` | operator entry point + coverage map |
| `references/` | **router** (load-on-CLASSIFY asset map) · doctrine · pipeline · operators · arsenal · mission-families · runbooks · frontier-lanes · knowledge-packs · payloads · vuln-playbooks · payload-arsenal · report-template · tech-stack-playbooks · dedup-methodology · stride-mapping · scan-modes · tool-guides · ctf-techniques · writeups-index · burp-integration · edge-case-hunting · payloads-all-the-things-index · **prompts/** (verbatim recipe library) |
| `scripts/` | `brain.sh · scope.sh · scope.py · preamble.py · preflight.sh · recon.sh · web-scan.sh · surface-probe.sh · code-audit.sh · report.sh · ingest.sh · optimize.sh` (keyless, system tools) |
| `commands/` | `mad-hunt.md` — the `/mad-hunt` autonomous bug-bounty entry point (symlinked into `~/.claude/commands/`) |
| `brain/` | persistent memory: `payloads/<class>.txt`, `lessons.md`, `tools.md`, `targets/<host>.md` |
| `wordlists/` | deduped wordlists (`params`, `sensitive-files`, `api-endpoints`, `raft-medium-dirs`, `common`, `onelistforall.txt.gz`) — per-class payloads live in `brain/payloads/` |
| `tools/` | scanner scripts extracted from ingested repos |
| `agents/` | `t3-{recon,scanner,exploiter,verifier,reporter}.md` operator subagents |
| `packs/` | attribution + raw methodology/reports from ingested repos (auto-compressed) |
| `engagements/` | per-target working evidence |

## Non-negotiable rules (every run)
1. **Authorization first.** `bash scripts/scope.sh init <target>` then `scripts/preflight.sh <target>`. A tool working or a host answering is **not** consent — authorization comes only from the engagement contract.
2. **Execution modes.** `safe_command` → run. `receipt_required` (nmap, nuclei, ffuf, sqlmap, curl-vs-target…) → pause for explicit user OK. `catalog_only`/`import_only` (msfconsole, pacu, frida, hydra) → **never run here**; hand to the user.
3. **VERIFY** — real only if it appears in captured tool output. **REFUTE** — try to disprove before it ships. No fabricated output/flags/"Executed…" lines.
4. **Redact** secrets/PII. **Absolute stops** apply regardless of scope (no credential entry, data deletion, fund movement, destructive payloads on the user's behalf).

## Feeding in new repos / methodologies / reports (it compounds)
```
bash scripts/ingest.sh <repo-or-file>      # classify + propose merges (read-only)
# then fold reusable assets:
bash scripts/brain.sh payload <class> <file>   # wordlists/payloads → brain (deduped)
bash scripts/brain.sh tool "<name> — <use>"    # new tools learned
bash scripts/brain.sh learn "<heuristic>"      # reusable lessons
bash scripts/optimize.sh                        # keep storage lean
```
Reports/methodology docs land in `packs/`; `optimize.sh` compresses large ones. See `references/extending.md`.

## Intelligence layer (optional)
The native file-brain is the spine (keyless, portable, in this folder). To add cross-engagement semantic recall + pattern-learning, bridge the brain into **ruflo** memory (`scripts/brain-sync-ruflo.sh`, opt-in). Do **not** use ruflo's swarm — the `t3-*` subagents are the orchestrator.

---
*Derived from T3MP3ST (AGPL-3.0) + shuvonsec/claude-bug-bounty. Attribution + licenses in `packs/`. Authorized use only.*
