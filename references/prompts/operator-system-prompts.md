# Operator System Prompts (index)

> Verbatim T3MP3ST operator prompts from the upstream `src/prompts/index.ts`. The full 129 KB monolith that used to live here was split into per-operator files for token efficiency (~8× smaller per-agent load) — each `t3-*` agent loads only its own slice. The bodies in the `op-*.md` files are the exact former monolith content; **load only the one you need.** (Full monolith preserved compressed at `packs/t3mp3st/operator-system-prompts.md.gz` for archival.)

| Operator | File | Role (one-line) |
|---|---|---|
| recon | `op-recon.md` | Map the target attack surface: hosts, services, tech, entry points, exposed data. |
| scanner | `op-scanner.md` | Vulnerability assessment + severity classification of the recon surface. |
| exploiter | `op-exploiter.md` | Weaponize/prove vulnerabilities with authorized, reversible PoCs. |
| infiltrator | `op-infiltrator.md` | Gain access / establish foothold (usually out of scope — confirm first). |
| exfiltrator | `op-exfiltrator.md` | Demonstrate data-access impact, minimally, then stop. |
| ghost | `op-ghost.md` | OPSEC / evasion / cleanup discipline. |
| coordinator | `op-coordinator.md` | Decision framework routing work across operators. |
| analyst | `op-analyst.md` | Synthesize confirmed findings into the final report. |

## Also in `references/prompts/`
| File | Purpose |
|---|---|
| `general-system-prompt.md` | Base system prompt shared across operators. |
| `general-replan-prompt.md` | Re-plan template (REFLECT / pivot). |
| `the-fixer-system-prompt.md` | Remediation/fix operator (pairs with `op-analyst.md`). |
| `doctrine-full.md` | Full Plinian doctrine (long form; `references/doctrine.md` is the working law). |
| `reasoning-and-workflow-prompts.md` | Cognition / reasoning / workflow templates. |
| `best-practice-rubric.md` | Quality rubric for operator output. |
