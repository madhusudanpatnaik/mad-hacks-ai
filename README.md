# mad-Hacks_ai

A **single-folder, keyless offensive-security toolkit for Claude Code.** This session is the backbone — no API keys, no server, no second bill. It runs a full kill-chain (recon → weaponize → exploit → verify → report) over real system tools, under a strict authorization + evidence + anti-fabrication doctrine, backed by a **persistent brain that compounds** across engagements and every repo you feed it.

Distilled from **T3MP3ST** (AGPL-3.0) + **shuvonsec/claude-bug-bounty**. Attribution/licenses in `packs/`.

## Use it
From a Claude Code session:
```
/mad-hacks <target-or-task>
```
`CLAUDE.md` in this folder is the orchestrator — run engagements from here. It dispatches the `t3-*` operator subagents through the kill chain with recall-first / capture-last memory.

## Layout (single source of truth)
```
mad-Hacks_ai/            ← symlinked to ~/.claude/skills/mad-hacks (the /mad-hacks skill)
├── SKILL.md             operator entry point + coverage map
├── CLAUDE.md            orchestrator / dispatch rules / hard rules
├── references/          doctrine · pipeline · operators · arsenal · mission-families ·
│   └── prompts/         runbooks · frontier-lanes · knowledge-packs · payloads ·
│                        vuln-playbooks · payload-arsenal · report-template · extending
│                        prompts/ = verbatim recipe library (8 operator system prompts + more)
├── scripts/             brain · scope · preflight · recon · web-scan · code-audit ·
│                        report · ingest · optimize · brain-sync-ruflo   (keyless)
├── brain/               persistent memory: payloads/<class>.txt · lessons.md · tools.md · targets/
├── wordlists/           deduped: params · sensitive-files · content-discovery · raft · api-endpoints
├── tools/               scanner scripts extracted from ingested repos
├── agents/              t3-{recon,scanner,exploiter,verifier,reporter}  (symlinked into ~/.claude/agents)
├── packs/               attribution + raw methodology/reports (auto-compressed by optimize.sh)
└── engagements/         per-target working evidence
```

## Installed arsenal (keyless, on this machine)
**Recon/DNS:** nmap · subfinder · amass · dnsx* · waybackurls · dig · whois
**Web:** curl · httpx · ffuf · gobuster · nikto · wafw00f · arjun (hidden params)
**Vuln/scan:** nuclei · semgrep · osv-scanner
**Secrets/crypto:** gitleaks · trufflehog · openssl · testssl.sh
**OOB:** interactsh-client (confirm blind SSRF/XXE/SQLi/RCE)
`scripts/preflight.sh <target>` prints live availability. Active tools are `receipt_required` — used only with confirmed scope.

## Feed it more (it gets smarter)
```bash
bash scripts/ingest.sh <repo-or-file>          # classify + propose merges (read-only)
bash scripts/brain.sh payload <class> <file>   # wordlists/payloads → brain (deduped)
bash scripts/brain.sh tool  "<name> — <use>"   # new tools learned
bash scripts/brain.sh learn "<heuristic>"      # reusable lessons
bash scripts/optimize.sh [--aggressive]        # keep storage lean (dedupe/compress)
```
Methodology docs & reports go in `packs/`; `optimize.sh` compresses large ones. Full guide: `references/extending.md`.

## Optional: ruflo intelligence layer
`scripts/brain-sync-ruflo.sh` exports the brain for **ruflo** semantic memory (fuzzy cross-engagement recall + pattern-learning). Memory only — the `t3-*` subagents remain the orchestrator. The native file-brain works standalone; ruflo is an upgrade, not a dependency.

## Authorized use only
Point it only at systems you own or have explicit written permission to test. `scripts/scope.sh` records the receipt; `preflight.sh` gates on it. A tool working is never consent.
