# mad-Hacks_ai

A **single-folder, keyless offensive-security toolkit for Claude Code.** This session is the backbone — no API keys, no server, no second bill. It runs a full kill-chain (recon → weaponize → exploit → verify → report) over real system tools, under a strict authorization + evidence + anti-fabrication doctrine, backed by a **persistent brain that compounds** across engagements and every repo you feed it.

Distilled from **T3MP3ST** (AGPL-3.0) + **shuvonsec/claude-bug-bounty**. Folded in: **xalgorix** (Apache-2.0 · autonomous-pentest methodology), **hahwul/dalfox** v3 (MIT · Rust XSS scanner with native OOB + MCP), **Rifteo/skills** (MIT · 38-skill peer library — 2 doctrine promotions, 10 on-demand attack lanes), and the **CoffinXP / Lostsec** writeup corpus. Attribution/licenses in `packs/`.

## Three entry points

```
/mad-hacks <target-or-task>           general operator mode — full kill chain, doctrine-gated
/mad-hunt  <target> [--auto]          autonomous bug-bounty spine (exhaustion contract)
/cdc-research <target> --goal "…"     Concurrent Divergent-Cognition vuln research
                       --deployment "…"   (parallel families, chain-until-impact, no CVE shortcuts)
                       [--mode bug-bounty|pentest|research]
```

- **`/mad-hacks`** — the general operator skill. Loads `SKILL.md`, routes assets on CLASSIFY via `references/router.md` (3-tier lazy load — doctrine + loop always resident, family block on CLASSIFY, per-class assets on demand).
- **`/mad-hunt`** — the bounty spine: scope-gate → policy preamble → per-host surface probe A–J → surface × payout-ranked specialist hunters (≥25 attempts/class) → 7-Q + `t3-verifier` REFUTE gate → `chain-builder` escalation → platform-ready draft. Adaptive-throttle, never auto-submits, never creates accounts. Loop spec: `references/mad-hunt.md`.
- **`/cdc-research`** — different loop: hunt novel primitives, adversarially validate every one, refuse to stop at the first primitive, chain until a defined starting-privilege → impact goal is met. Three modes (bug-bounty / pentest / research), greybox default, blackbox as documented degraded mode. Layered halting: soft budget → FINAL_PUSH · 3-tick plateau tripwire · hard budget · operator interrupt. Spec: `references/cdc-harness.md`. State manager: `scripts/cdc-state.sh`.

## Layout

```
mad-Hacks_ai/            ← symlinked to ~/.claude/skills/mad-hacks (the /mad-hacks skill)
├── SKILL.md             operator entry point + coverage map + toolkit table
├── CLAUDE.md            orchestrator / dispatch rules / hard rules
├── commands/            /mad-hunt · /cdc-research   (symlinked into ~/.claude/commands/)
├── workflows/           cdc-verify.js   (parallel adversarial verify pass — structured schemas)
├── references/          router (load-on-CLASSIFY asset map) · doctrine · pipeline · operators ·
│   └── prompts/         arsenal · mission-families · runbooks · frontier-lanes · knowledge-packs ·
│                        vuln-playbooks · payload-arsenal · report-template · tech-stack-playbooks ·
│                        cdc-harness · mad-hunt · hunt-xss · hunt-registration · hunt-session ·
│                        hunt-cache-deception · wordpress-recon · recon-oneliners ·
│                        dalfox-guide · xalgorix-methodology · rifteo-skills-catalog ·
│                        deadangle · engagement-handoff · burp-integration
│                        prompts/ = verbatim recipe library (8 operator system prompts + more)
├── scripts/             brain · scope · scope.py · preamble.py · preflight · recon · web-scan ·
│                        surface-probe · xss-surface · code-audit · cloud-audit · mobile-audit ·
│                        binary-audit · contract-audit · report · oob · cdc-state ·
│                        ingest · optimize · reinstall-packs ·
│                        build-writeup-corpus · refresh-writeup-feeds   (keyless)
├── brain/               persistent memory: lesson-index · lessons.md · tools.md ·
│                        payloads/<class>.txt (37 files) · targets/  (gitignored)
├── wordlists/           deduped: params · sensitive-files · content-discovery · raft · api-endpoints ·
│                        common · onelistforall.txt.gz
├── tools/               scanner scripts extracted from ingested repos
├── agents/              t3-{recon,scanner,exploiter,verifier,reporter}  (symlinked into ~/.claude/agents/)
├── packs/               attribution + methodology from ingested repos
│                        (writeups/ · cyberstrike/ · strix/ · claude-bughunter/ · ai-pentesting/ ·
│                         payloads-all-the-things/ · lostfuzzer/ · t3mp3st/  — all tracked)
│                        (xalgorix/ · dalfox/ · rifteo-skills/  — externally cloned, .gitignored;
│                         provenance + rehydration recipe in packs/UPSTREAM.md)
├── .cdc/                per-target CDC harness working state (gitignored)
└── engagements/         per-target working evidence (gitignored)
```

## Doctrine (non-negotiable — every run)

1. **Authorization first.** `bash scripts/scope.sh init <target>` then `scripts/preflight.sh <target>`. A tool working or a host answering is **not** consent — authorization comes only from the engagement contract.
2. **Execution modes.** `safe_command` → run. `receipt_required` (nmap, nuclei, ffuf, sqlmap, curl-vs-target, dalfox scan) → pause for explicit user OK. `catalog_only`/`import_only` (msfconsole, pacu, frida, hydra) → **never run here** — hand to the user.
3. **VERIFY + REFUTE.** Real only if it appears in captured tool output. `t3-verifier` emits a mandatory visible verdict card with the **Verified / Inferred / Assumed ternary** ([`references/deadangle.md`](references/deadangle.md)) — a CONFIRMED verdict whose claims are majority-Inferred/Assumed is grounds for DOWNGRADED.
4. **Redact** secrets/PII. **Absolute stops** apply regardless of scope (no credential entry, data deletion, fund movement, destructive payloads on the user's behalf).
5. **No CVE / patch-diff / changelog shortcuts** as proof. Reproduce against the realistic deployment. Read dependency source when behavior depends on it — runtime is oracle, docs are hypothesis.

## Installed arsenal (keyless, on this machine)

**Recon/DNS:** nmap · subfinder · amass · dnsx · waybackurls · dig · whois · katana · gau · asnmap · chaos
**Web:** curl · httpx-toolkit · ffuf · gobuster · nikto · wafw00f · arjun · dalfox v2 (v3 upgrade recommended — `brew install dalfox`)
**Vuln/scan:** nuclei · semgrep · osv-scanner
**Secrets/crypto:** gitleaks · trufflehog · openssl · testssl.sh
**OOB:** interactsh-client — wrapped by [`scripts/oob.sh`](scripts/oob.sh) (per-target ledger, seed/fire/poll/attribute)
**Report:** pandoc / cmark / python-docx / weasyprint / wkhtmltopdf — whichever is present ([`scripts/report.sh build-{html,docx,pdf,all}`](scripts/report.sh))
`scripts/preflight.sh <target>` prints live availability. Active tools are `receipt_required` — used only with confirmed scope.

## MCP integration (auto-detected)

- **Burp Suite MCP** — every specialist hunter runs `ToolSearch("burp proxy repeater intruder collaborator")` at dispatch; if present, Repeater becomes the primary probe channel + Collaborator the primary OOB backend. Register: `claude mcp add burp ...` (recipe: [`references/burp-integration.md`](references/burp-integration.md)).
- **dalfox v3 MCP** — 6-tool stdio server (`scan_with_dalfox`, `get_results_dalfox`, `list_scans_dalfox`, `cancel_scan_dalfox`, `delete_scan_dalfox`, `preflight_dalfox`). `xss-hunter` prefers it when loaded. Register: `claude mcp add dalfox -- dalfox mcp`. Guide: [`references/dalfox-guide.md`](references/dalfox-guide.md).
- **writeup-search MCP** — search 6,749-row corpus of practitioner writeups + disclosed-bounty pointers. See below for corpus builder.

## Writeup corpus (`writeup-search` MCP data source)

```bash
bash scripts/build-writeup-corpus.sh          # base corpus: 23 CoffinXP + 6,554 pentester.land
bash scripts/refresh-writeup-feeds.sh         # +11 RSS feeds (PortSwigger/Datadog/samcurry/Medium tags/…)
                                              # dedupes on source URL, cron-friendly, --dry-run flag
pkill -f mcp-writeup-server                   # Claude Code auto-respawns w/ fresh DB (or /mcp reconnect)
```

Corpus lives at `~/.local/share/pentest-writeups/metadata.db` (SQLite). Tools available after reconnect: `search_writeups` (keyword search across full text + metadata), `search_techniques` (per-class technique packs), `search_payloads` (context-organized payload pack + mutation matrix + detection ladder), `get_writeup`. Source catalog: [`references/writeup-sources.md`](references/writeup-sources.md).

## Feed it more (it compounds)

```bash
bash scripts/ingest.sh <repo-or-file>          # classify + propose merges (read-only)
bash scripts/brain.sh recall <target>          # target-specific memory (prior findings, exhausted vectors)
bash scripts/brain.sh recall-class <class>     # class-relevant lessons (auto-selected via brain/lesson-index.md)
bash scripts/brain.sh payload <class> <file>   # wordlists/payloads → brain (deduped)
bash scripts/brain.sh tool  "<name> — <use>"   # new tools learned
bash scripts/brain.sh learn "<heuristic>"      # reusable lessons — every specialist hunter auto-pulls these
bash scripts/optimize.sh [--aggressive]        # keep storage lean (dedupe/compress)
```

Every specialist hunter (xss-hunter, ssrf-hunter, idor-hunter, rce-hunter, ssti-hunter, oauth-hunter, cors-hunter, csrf-hunter, xxe-hunter, sqli-hunter, open-redirect, subdomain-takeover, race-condition, business-logic, graphql-audit, file-upload, info-disclosure, cloud-recon, config-auditor) has a **Preflight — connect the swarm** preamble that: (1) `ToolSearch("burp")` for MCP autodetect, (2) `brain.sh recall-class <class>` for lesson auto-pull, (3) blind classes (ssrf/xxe/sqli/rce/ssti) also seed `scripts/oob.sh` for attribution-safe callback loops.

Methodology docs & reports go in `packs/`. Externally-cloned packs (xalgorix/dalfox/rifteo-skills) are gitignored — rehydrate on a fresh clone via `bash scripts/reinstall-packs.sh` (upstream URLs + pinned commits in `packs/UPSTREAM.md`).

## Session handoff (end-of-day)

Write `.t3mp3st/<target>/HANDOFF.md` following the template in [`references/engagement-handoff.md`](references/engagement-handoff.md) — under 100 lines, findings-by-id, coverage tested/skipped/partial, open threads, ordered next-steps specific enough to run without additional context. Next session opens with `cat HANDOFF.md` + `brain.sh recall`.

## Optional: ruflo intelligence layer

`scripts/brain-sync-ruflo.sh` exports the brain for **ruflo** semantic memory (fuzzy cross-engagement recall + pattern-learning). Memory only — the `t3-*` subagents remain the orchestrator. The native file-brain works standalone; ruflo is an upgrade, not a dependency.

## Authorized use only

Point it only at systems you own or have explicit written permission to test. `scripts/scope.sh` records the receipt; `preflight.sh` gates on it. A tool working is never consent.
