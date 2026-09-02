# rifteo-skills-catalog — 38-skill inventory, gap analysis, load-on-demand map

**Source:** [github.com/Rifteo/skills](https://github.com/Rifteo/skills) (MIT, © 2026 Rifteo). Full clone at [`packs/rifteo-skills/`](../packs/rifteo-skills/) — 38 documented skills, upstream npm CLI `@rifteo/skills` for installation into any AI-agent runtime (Claude Code, Cursor, Windsurf, Gemini CLI, etc.).

**Why folded in:** Rifteo is a **peer methodology library** targeting the same domain as mad-hacks. Instead of re-writing what they already wrote well, we (a) keep the full corpus verbatim in `packs/rifteo-skills/`, (b) map each skill onto our existing coverage, (c) load specific skills on-demand from `packs/rifteo-skills/<skill>/SKILL.md` when a mission needs a capability we don't natively have. This doc is the pointer index.

**Not adopted (deliberately):** the npm CLI (`@rifteo/skills`) — we operate keyless. Operators who want the CLI can `npm install -g @rifteo/skills` separately; it does not affect our loop.

---

## The rule (how to use this catalog)

1. When your mission needs a capability, look up the row.
2. If the "mad-hacks native" column is filled → **use ours** (we've tuned it — router + brain + preamble wiring).
3. If the "mad-hacks native" column says **GAP** → load `packs/rifteo-skills/<skill>/SKILL.md` verbatim for the methodology; treat it as a T3 reference.
4. **Overlapping skills** — do NOT overwrite our version. Rifteo may offer a different angle worth cross-referencing (noted in the row's "notes" column).

---

## 1. Attack lanes we already have (Rifteo cross-reference)

| Rifteo skill | Our native | Notes |
|---|---|---|
| `xss-hunter` | `~/.claude/agents/xss-hunter.md` + `references/hunt-xss.md` + `brain/payloads/xss-by-context.md` + dalfox v3 | Ours is deeper (dalfox v3 MCP integration, 10 sub-techniques, 2024–2026 CVE catalog, xss-surface.sh probe) |
| `ssrf-hunter` | `ssrf-hunter` agent + `brain/payloads/ssrf.txt` + `scripts/oob.sh` | Both are complete. Rifteo's covers cloud metadata theft; ours covers coffinxp OOB attribution discipline. Cross-load Rifteo when protocol-handler abuse comes up. |
| `ssti-hunter` | `ssti-hunter` agent + Strix depth | Comparable. Rifteo's sandbox-escape ladder is a good secondary reference. |
| `idor-hunter` | `idor-hunter` agent + `references/hunt-registration.md` §21 | Ours has multi-tenant / org_id focus. Rifteo's is more general multi-account. |
| `js-analyzer` | `js-analyzer` agent | Comparable. |
| `ai-llm-hunter` | `llm-ai-hunter` agent + `packs/ai-pentesting/` | Ours covers OWASP LLM Top 10 v2025 + Agentic AI Top 10. Rifteo's is a tighter general methodology. |
| `xxe-phantom` | `xxe-hunter` agent + `brain/payloads/xxe.txt` (102 payloads) | Rifteo's has explicit **file-read + blind-OOB + SSRF-chain** methodology — cross-load when the target has XML endpoints. |
| `ctf-writeup` | `references/ctf-techniques.md` | Ours is per-lane technique checklist; Rifteo's is post-solve writeup generator. **Complementary — use both.** |

---

## 2. GAP-FILLERS — capabilities we don't natively have (adopt on-demand)

| Class | Rifteo skill | Load path | Fold into router row? |
|---|---|---|---|
| **Active Directory attack** (Kerberoasting, ACL abuse, DCSync, AD CS ESC1-ESC8, NTLM relay) | `ad-breach` | `packs/rifteo-skills/ad-breach/SKILL.md` | ✅ New router row — new attack family |
| **Android APK static analysis** (apktool + jadx + MASVS mapping) | `droid-recon` | `packs/rifteo-skills/droid-recon/SKILL.md` | ✅ Extends `mobile-audit.sh` |
| **Clickjacking / UI redressing** (frame protection detection, JS frame-busting bypass, drag-and-drop, OAuth consent variants) | `clickjacking-hunter` | `packs/rifteo-skills/clickjacking-hunter/SKILL.md` | ✅ New router row |
| **HTTP Parameter Pollution** (server-side + client-side HPP, WAF bypass via parameter splitting, OAuth/payment/access-control abuse) | `hpp-hunter` | `packs/rifteo-skills/hpp-hunter/SKILL.md` | ✅ New router row |
| **JWT attacks (dedicated)** (alg:none, RS256→HS256 confusion, weak-secret brute, kid/jku/jwk injection, claim tampering) | `jwt-cracker` | `packs/rifteo-skills/jwt-cracker/SKILL.md` | Extends `oauth-hunter` row |
| **Open redirect + OAuth code theft chaining** (30+ bypass techniques, allowlist bypass, phishing escalation) | `redirect-forge` | `packs/rifteo-skills/redirect-forge/SKILL.md` | Extends `open-redirect` row |
| **Nuclei template generation** (auth strategies, matcher selection, OOB detection, multi-step flows) | `nuclei-template-writer` | `packs/rifteo-skills/nuclei-template-writer/SKILL.md` | New tool row |
| **CVE exploitability lookup** (searchsploit, Vulners, MSF, weaponized exploit refs) | `check-exploit` | `packs/rifteo-skills/check-exploit/SKILL.md` | New tool row |
| **CVSS v3.1 scoring reasoning** (metric inference from context) | `cvss-scorer` | `packs/rifteo-skills/cvss-scorer/SKILL.md` | Fold into `report-template.md` |
| **Vuln PoC builder** (deterministic reproducer, false-positive elimination) | `vuln-diagnose` | `packs/rifteo-skills/vuln-diagnose/SKILL.md` | Complements `t3-verifier` — cross-load when a candidate needs a full reproducer |

---

## 3. Doctrine / process extensions (adopt as add-ons)

| Discipline | Rifteo skill | Why it improves mad-hacks |
|---|---|---|
| **Verified / Inferred / Assumed labeling** — a ternary honesty gate before delivery. "What would destroy this conclusion if I was wrong?" | `deadangle` | **Adopted — see [`references/deadangle.md`](deadangle.md).** Extends our binary CONFIRMED/REFUTED to the ternary the doctrine actually needs. Used by t3-verifier + CDC verify pass + every specialist hunter before shipping a finding. |
| **Session-state save/restore** — HANDOFF.md at the end of a session so the next agent starts without asking questions | `engagement-handoff` | **Adopted — see [`references/engagement-handoff.md`](engagement-handoff.md).** Complements `.t3mp3st/<target>/` evidence dir with a compact continuation memo. |
| **Red-team mindset** — attacker-perspective framing for any engagement type | `redmind` | Load on `/mad-hunt` or `/cdc-research pentest` mode start; complements `references/mission-families.md` red-team block |
| **High-severity-first hunting** — POC-or-kill for High/Critical before Low/Medium | `high-severity-hunter` | Complements `references/mad-hunt.md` surface×payout ranking |
| **Effort × impact prioritization** — economist-attack, shape order-of-testing | `economist-attack` | Complements our writeups-corpus per-class prevalence + top-bounty exemplars |
| **Stealth mode** — passive-first, blend with legitimate traffic, avoid detection | `less-noise-attack` | Complements `mad-hunt.md` adaptive throttle for red-team engagements requiring EDR/SOC evasion |
| **Safety mode** — read-only where possible, no full-impact exercise | `less-aggressive-attack` | Complements `references/production-safety.md` R1–R11; explicit user opt-in |
| **Scope interview** — capture target, RoE, auth, deliverables into a structured brief | `scope-grill` | Complements `scripts/scope.sh init`; use it BEFORE `scope.sh` to elicit the fields |
| **Attack-surface mapping** — every entry point + trust boundary before testing | `attack-surface` | Complements `scripts/recon.sh` + `scripts/surface-probe.sh`; load when starting an engagement in pentest/research mode |
| **Compressed output mode** — strip filler, keep CVEs/payloads/CVSS/findings exact | `caveman` | Utility. Load when the operator says "tl;dr", "just the findings", "keep it short". |

---

## 4. Governance / reporting layer (new capability — pentest + audit engagements)

For **pentest** / **red-team** / **compliance-audit** engagements (i.e. NOT bug-bounty), the following Rifteo skills add a governance layer we did not have:

| Skill | Purpose | Load path |
|---|---|---|
| `bugbounty-reporter` | H1/Bugcrowd/Intigriti platform-ready draft | `packs/rifteo-skills/bugbounty-reporter/SKILL.md` |
| `pentest-report` | Client-ready pentest report (exec summary + risk table + findings + recs) | `packs/rifteo-skills/pentest-report/SKILL.md` |
| `finding-writer` | Raw notes → structured finding | `packs/rifteo-skills/finding-writer/SKILL.md` |
| `risk-assessor` | Likelihood × Impact + CIA + CVSS correlation + SLA-bound urgency | `packs/rifteo-skills/risk-assessor/SKILL.md` |
| `remediation-planner` | Step-by-step fix plan with effort estimates | `packs/rifteo-skills/remediation-planner/SKILL.md` |
| `compliance-gap-analyzer` | Aggregate findings mapped to ISO/NIST/PCI/OWASP controls, classify + prioritize gaps | `packs/rifteo-skills/compliance-gap-analyzer/SKILL.md` |
| `control-lookup` | ISO 27001 / NIST CSF / PCI-DSS v4 / OWASP control ID lookup + cross-framework mapping | `packs/rifteo-skills/control-lookup/SKILL.md` |

**Mode wiring:** `/cdc-research --mode pentest` and `/cdc-research --mode research` should reference this layer at report-assembly time; `/mad-hunt` (bug-bounty mode) doesn't need it.

---

## 5. Specialty skills (situational)

| Skill | When to use | Load path |
|---|---|---|
| `hexstrike-forge` | Target has a HexStrike-AI MCP server available — 5-phase methodology with triage gates + parallel execution + tool failure recovery | `packs/rifteo-skills/hexstrike-forge/SKILL.md` |
| `find-skills` | Meta — search the Rifteo catalog for a topic. Redundant with this doc; use this catalog first. | — |
| `skill-benchmark` | Author-side quality check on a SKILL.md across 50+ agents. Only relevant if writing a new skill for the Rifteo repo. | — |

---

## 6. Load-on-demand recipe

The catalog above says "load `packs/rifteo-skills/<skill>/SKILL.md`" for each gap-filler. Concrete pattern for the operator:

```bash
# From within a hunter dispatch / CDC tick — when you hit a class we don't natively cover:
cat ~/.claude/skills/mad-hacks/packs/rifteo-skills/<skill>/SKILL.md

# Or grep just the actionable section:
awk '/^## /{p=($0 ~ /Method|Procedure|Steps|Payloads/)} p' \
  ~/.claude/skills/mad-hacks/packs/rifteo-skills/<skill>/SKILL.md
```

Do NOT install the Rifteo npm package into the mad-hacks agent tree unless you deliberately want dual specialist hunters (ours + theirs). Loading their SKILL.md as a reference is the mad-hacks way.

---

## 7. Attribution + License

- Repo: [github.com/Rifteo/skills](https://github.com/Rifteo/skills)
- License: MIT (see `packs/rifteo-skills/LICENSE`)
- Copyright: © 2026 Rifteo
- Ingested at: 2026-09-02 (shallow clone, `--depth 1`, 38 skills)
- What we copied: nothing modified. Full clone kept for on-demand SKILL.md loading. Two skills promoted to first-class references (`deadangle.md`, `engagement-handoff.md`) with attribution. All other skills consulted on-demand from `packs/rifteo-skills/<skill>/SKILL.md`.
