# mad-Hacks_ai — Improvements Log

Running record of optimizations. Newest first. Each entry: what changed, why, measured impact.

## /mad-hunt — autonomous bug-bounty spine — 2026-08-23

Output of a full grill-me design session. Resolved the toolkit's biggest latent tension: **three parallel orchestration layers** (t3-* kill-chain, CBH `/autopilot`+`/hunt`, router-dispatched specialist agents) with a shared brain but no shared spine. Grilled decisions (locked): north star = **bug bounty**; spine = autopilot's exhaustion methodology as a **thin adapter**; posture = **adaptive-throttle**; budget = **surface×payout-weighted, ≥25 floor**; reports = **platform-native**; **never auto-submit / never create accounts**.

**Key finding that reshaped the build:** CBH's `/autopilot` + `/hunt` are installed as **hollow SKILL.md files** — their entire runtime scaffold (`rules/hunting.md`, `rules/mistakes.md`, `tools/brain.py`, `scope.yaml`, `policy.md`) does not exist in this environment and can't be scaffolded. But mad-hacks already has a working equivalent of every piece, and both dispatch the *same* specialist hunter agents. So instead of adopting a broken spine, we built one that runs autopilot's methodology on mad-hacks plumbing.

**Built (net-new, small):**
- `scripts/scope.py` — deterministic deny-wins / default-deny scope gate; reads `.t3mp3st/SCOPE.md` via `--md` (parses `## In scope`/`## Out of scope`), exit-code gates automation. Ported from the archived CBH `engine/scope.py`; self-test PASS; suffix-confusion guards verified.
- `scripts/preamble.py` — extracts the POLICY PREAMBLE (program, traffic header, rate cap, ticked prohibits, chaining, prod-mode) + `PLATFORM=` from SCOPE.md; injected into every hunter dispatch. Verified against a filled mock.
- `scripts/surface-probe.sh` — the C/F/G/H/I gap probes (cache-deception, HTTP/2 desync, subdomain-takeover, Cloudflare, SPA/hash seeds) that complement `recon.sh`+`web-scan.sh` (A/B/D/E). Smoke-run against example.com produced real seeds.
- `references/mad-hunt.md` — the orchestrator loop (the durable spec + runbook).
- `commands/mad-hunt.md` → symlinked to `~/.claude/commands/mad-hunt.md` — the `/mad-hunt` entry point.

**Reused (everything else):** `brain.sh`, `scope.sh`, `recon.sh`, `web-scan.sh`, `router.md`, the 12 specialist hunters, `t3-verifier`, `chain-builder`, `t3-reporter`, `poc-builder`, `quality-check`, `writeups-corpus`, `production-safety`, `vuln-playbooks`, `payloads`.

**Verification:** scope.py self-test + live SCOPE.md IN/OUT gating (exit codes) ✓ · preamble extraction + platform detection ✓ · surface-probe end-to-end ✓ · 30/30 referenced scripts/agents/references resolve · both python scripts compile · bash syntax clean · `/mad-hunt` registered as a command. Wired into SKILL.md §1b, router on-demand table, CLAUDE.md (operate + folder map), brain.

---

## Multi-agent precision audit + fixes — 2026-08-23

Ran a 7-dimension read-only audit workflow over the whole toolkit (dead pointers, stale counts, prompts monolith, CBH double-tree, agent loading, router coverage), then verified + applied the safe findings. 40 findings; 22 acted on.

**Applied:**
- **Prompts monolith retired.** `references/prompts/operator-system-prompts.md` was a 126 KB unreferenced full duplicate of the 8 `op-*.md` splits (nothing loaded it; verified splits=1525 lines ⊇ monolith=1506). Replaced with a 24-line index (**126 KB → 1.8 KB**); full copy archived at `packs/t3mp3st/operator-system-prompts.md.gz` (15 KB).
- **Router coverage gaps closed.** Added 2 missing class rows — **LFI/path-traversal** (had `lfi.txt` 1468 lines + Strix + CBH but no route) and **Auth bypass/MFA/session** (had 3 payloads + the dedicated `auth-tester` agent, which was routed nowhere). Surfaced `privilege-escalation` agent on the IDOR/BOLA row. Added the missing CBH flag to 4 rows (JWT/OAuth/SAML, Req-smuggling, Host-header, NoSQLi/LDAPi) — under-claims that hid available H1 $-pattern depth. All 17 new asset paths verified to resolve.
- **t3-scanner + t3-exploiter wired into the router.** Scanner now reads one family block + per-class rows instead of loading `pipeline.md`'s flat class list; exploiter looks the candidate's class up once for the curated payload + depth pick-order. (t3-recon/verifier/reporter left unchanged — audit confirmed already optimal for their pre-classify / class-agnostic roles.)
- **Dead external paths fixed.** `/Users/we45/youtube/T3MP3ST` (SKILL.md ×2) and `/Users/we45/youtube/claude-bug-bounty/...` (vuln-playbooks.md) no longer exist → repointed to clone-instruction / in-repo `wordlists/raft-medium-dirs.txt`.
- **Stale counts corrected.** SKILL.md: CyberStrike 156→**157** (was silently dropping 9 assessment/recon dirs), CBH 58→**24** hunt patterns (contradicted router), PAT 72→**64** classes. stride-mapping "60+"→**55**. frontier-lanes dead family `social_osint`→`agent_warfare` (only 9 families exist). extending.md `rules/`→"(create on first use)".
- **CLAUDE.md de-staled.** Now describes the lazy 3-tier load model (was "loads SKILL.md + references/" = the retired load-everything model) and lists `router.md` + the 10 newer reference docs in the folder map. wordlists/ row corrected (`content-discovery` lives in brain/, not wordlists/).

**CBH double-tree dedup — DONE (2026-08-23):** independently recomputed the byte-identical set (hash intersection): exactly **57** references-side files have a byte-identical twin in `packs/` (685 KB); **137** references-side files are unique and were kept. Verified no jekyll build exists in the workflow (docs/ is read as markdown, so symlinks are safe) and nothing loads the references-side copies as files. Replaced the 57 with **relative symlinks to their `packs/` canonical twins** (packs = canonical per CLAUDE.md's raw-archive role, and the live router already reads only `packs/`). Result: zero content loss, every path still resolves for markdown/skill readers, `references/claude-bughunter/` 3.2 MB → 2.4 MB, 57 symlinks / 0 broken, content re-verified byte-identical. Made it **repeatable**: extended `scripts/optimize.sh` cross-file dedup to also scan `packs/` + `references/` (packs listed first → stays canonical; `-type f` skips existing symlinks → idempotent), so future re-ingests auto-dedup. Total footprint 34 MB → 32 MB across this + the monolith retirement.

---

## Precision + usage optimization — lazy-load router — 2026-08-23

After 4 repos ingested across two sessions (Strix, CyberStrike, AI-penetration-testing, PayloadsAllTheThings — 156+70+58 skills, 18.8k payload lines, 25 references), the front door had rotted: `SKILL.md §0` said "read these 16 first (always active)."

**Problem (measured):**
- **~15.4k tokens loaded on EVERY run** before a single packet leaves — most irrelevant to any one mission (a web test preloaded `ctf-techniques`, `edge-case-hunting`, `writeups-index`, `frontier-lanes`, `knowledge-packs`).
- **No class→asset router.** SSRF was taught in 4 places (brain payload, CyberStrike attack-ssrf, Strix ssrf, CBH hunt-ssrf), JWT in 5 — with nothing saying which to use or how they compose.
- **Stale front door.** None of the 4 ingested repos were wired into SKILL.md routing.

**Fix:**
- **New `references/router.md`** (1.25k tokens, loaded once on CLASSIFY) — the single map: family→assets + vuln-class→{brain payload, agent, depth-doc}, and a **pick-order that resolves the 4-repo overlap** (payload → agent → one playbook for chaining/bounty/bypass). All 4 ingested repos wired in.
- **`SKILL.md §0` rewritten** from a flat 16-item "always active" dump into 3 tiers: **T1 always-resident** = `doctrine` + `pipeline` only; **T2 on-classify** = `router` + one family block + prod-safety; **T3 per-class** = everything else, indexed in router, pulled on demand.
- CLASSIFY step (`§1b`) now points at the router.

**Measured impact:**
- Up-front context (before classify): **15,448 → 3,866 tokens = 75% reduction.**
- Fully mission-ready (classified + family + router + prod-safety): **6,693 tokens = 57% lighter**, and every token loaded is now mission-relevant.
- No content deleted — all 25 references + 10 packs intact, just loaded when needed.

---

## Batch ingest — writeups + payloads + lostfuzzer — 2026-08-11

Folded in a batch of methodology writeups, payload lists, and a tool.
- **22 practitioner bug-bounty writeups** → `packs/writeups/` (media/tracking HTML stripped, `AIza` keys + a demo session-token **redacted**; gitleaks-scanned). Indexed in `references/writeups-index.md`. Topics: open-redirect, CRLF, host-header injection, blind-XSS/pastejacking, sqlmap/ghauri WAF-bypass, web-cache-deception, WordPress, s3-recon, punycode/IDN ATO, Swagger-UI XSS, GitHub/CT recon, 5-min workflow, Grafana path-traversal chain (CVE-2025-4123), React2Shell RCE (CVE-2025-55182), mass-assignment, auth/session.
- **+ distilled `google-gemini-api-key-abuse.md`** technique (redacted) for the exposed-API-key → impact chain.
- **Payloads:** `xss-waf-bypass` (84) → brain; `onelistforall` (774k) → `wordlists/onelistforall.txt.gz` (gzipped 12 MB→5 MB, decompress on demand — mega-list is last-resort, curated brain classes first).
- **Tool:** `lostfuzzer.sh` (gau + nuclei DAST automation) → `tools/`.
- **Safety:** redacted embedded API keys + demo token; skipped the stray `node_modules/graphemer` lib (irrelevant).
- Recorded in brain (+3 lessons, +2 tools); optimized (gzip); folder 14 M → **7.7 M**.

---

## Optimization pass 4 — 2026-08-11 — full family tooling

### ✅ Binary/RE + Smart-contract family scripts (last 2 untooled families)
- `binary-audit.sh` — keyless **static** RE: `file`/`readelf` identity, `checksec` protections, sink-function detection (system/exec/strcpy/sprintf/gets/memcpy…), interesting strings, `binwalk` firmware layout, `objdump` main() disasm. **Never executes the target** (execution = active/receipt_required, lab only).
- `contract-audit.sh` — keyless **static** Solidity: `slither` (→ solhint → grep fallback for reentrancy / access-control / delegatecall / selfdestruct / tx.origin / unchecked). No on-chain tx, no signing.
- Both tested (reentrancy pattern caught in fallback; /bin/ls sink scan clean).

### ✅ Installed RE/contract tools
- **checksec, binwalk** (RE), **slither** (Solidity) — joining r2/objdump/strings/readelf.
- **Arsenal now 32 keyless tools across all 9 families.** Every mission family now has real tooling (was 5/9 → 9/9).

---

## Repo ingest — reverse-skill — 2026-08-11

Folded in **zhaoxuya520/reverse-skill** (MIT) — a 41-module CTF/technique library (225 methodology docs).
- **Extracted:** 41 technique checklists → `packs/reverse-skill/techniques/<name>.md` (184 KB) + attribution/LICENSE.
- **Indexed:** `references/ctf-techniques.md` maps each technique → family (web/AD/container/cloud/mobile/RE/forensics/AI) → doc, for on-demand load (no context bloat).
- **Covers new ground:** AD cert abuse, Kerberos delegation, LSASS ticket material, relay/coercion, DPAPI chains, k8s control-plane, kernel/container escape, firmware layout, request smuggling, GraphQL/RPC drift, JWT claim confusion, OAuth/OIDC chains, SSRF metadata pivot, stego, pcap, reverse-pwn, prompt-injection.
- Recorded in brain (tool + lesson); wired into SKILL.md; storage optimized; clone removed.

---

## Optimization pass 3 — 2026-08-11

### ✅ 1. Parallelized `web-scan.sh`
- 6 independent probes (CORS, methods, redirect, exposure, WAF, TLS) now run concurrently, each writing its own candidate fragment; merged in deterministic order (no append races).
- **Impact:** wall-clock bounded by the slowest probe (TLS/testssl), not the sum. Header-derived candidates computed locally. Verified correct output on scanme.nmap.org.

### ✅ 2. New family scripts — cloud + mobile coverage
- `cloud-audit.sh` — keyless IaC/cloud-config misconfig (checkov → trivy → grep fallback) + secrets. Static only, no live cloud, no creds.
- `mobile-audit.sh` — keyless APK static analysis: apktool decompile + manifest misconfig (debuggable/allowBackup/cleartext/exported) + mobsfscan + secrets/endpoints/cleartext.
- Both degrade gracefully; wired into SKILL.md toolkit table.

### ✅ 3. Installed cloud/mobile tools
- **checkov, trivy** (IaC misconfig), **apktool** (APK decompile) — joining mobsfscan. Arsenal now spans web/recon/code/cloud/mobile families. (jadx skipped — apktool covers decompile.)

### ✅ 4. PATH-hardened scripts
- `recon.sh` / `web-scan.sh` / `cloud-audit.sh` / `mobile-audit.sh` export `~/go/bin` + `~/.local/bin` so go/pipx tools resolve regardless of invocation context.

---

## Optimization pass 2 — 2026-08-11

### ✅ 1. Parallelized `recon.sh`
- **Before:** DNS → whois → subdomains → HTTP → tech ran sequentially (wall-clock = sum; whois/subfinder/http-timeouts stack up).
- **After:** the 5 independent passive lookups each background to their own file, then join; report prints in deterministic order.
- **Impact:** wall-clock = slowest single lookup, not the sum. Measured **~4s** end-to-end on scanme.nmap.org (was easily 15–30s worst-case with timeouts). Also added `naabu` to the active port scan.

### ✅ 2. Enhanced `optimize.sh` — cross-file dedup + hardening
- **Added:** cross-file pass that hashes every real file in `wordlists/` + `brain/payloads/` and **symlinks byte-identical duplicates** — auto-catches dups when future repos are ingested. Collapsed 4 brain↔wordlist dupes into symlinks (~11k duplicate lines removed).
- **Fixed (bug):** per-file dedup now **skips symlinks** (`[ -L ]`) — previously it re-materialized symlinked files into real copies every run (churn + circular-link risk). Now **idempotent**: verified two consecutive runs produce no new links, all data intact, zero broken symlinks.

### ✅ 3. Doctrine de-duplication
- `doctrine.md` (distilled, read every run) now cross-links `prompts/doctrine-full.md` (verbatim archive); no paragraph duplicated between them.

### ⏸ 4. ruflo memory consolidation — deferred (honest)
- Only ~17 entries; `memory_consolidate`/`neural_patterns` add little at this scale and risk over-merging distinct lessons. Semantic recall already verified working. Revisit once several real engagements have populated the store.

---

## Optimization pass 1 — 2026-08-11

Goal: reduce per-agent token load, remove duplication/dead weight, automate the memory loop, close tool gaps.

### ✅ 1. Per-operator prompt split (token efficiency) — DONE
- **Before:** every `t3-*` subagent read `operator-system-prompts.md` = **129 KB / 1,506 lines** (all 8 prompts) to use its ~16 KB slice.
- **After:** split into 8 `references/prompts/op-<operator>.md` (~15–17 KB each). Agents repointed to their own file.
- **Impact:** **~8× smaller prompt-load per agent dispatch** (129 KB → ~16 KB). (Update 2026-08-23: the 129 KB monolith was a redundant unreferenced full copy, not an index — now genuinely replaced by a ~20-line index linking the 8 splits; full copy archived at `packs/t3mp3st/operator-system-prompts.md.gz`.)

### ✅ 2. Automation via Claude Code hooks — DONE
- **Added:** `.claude/settings.json` in the folder.
  - `SessionStart` → prints brain stats + recall reminder (brain.sh + ruflo semantic search) into context.
  - `Stop` → auto `brain-sync-ruflo.sh` (refresh export) + `optimize.sh` (dedupe/compress).
- **Impact:** memory + storage stay fresh with zero manual steps when working from the folder.

### ✅ 3. Kill exact wordlist duplication — DONE
- **Before:** `wordlists/common.txt` == `brain/payloads/content-discovery.txt`, byte-identical (4,750 lines) — stored twice.
- **After:** `common.txt` is now a symlink to the brain copy. `ffuf -w wordlists/common.txt` still works. Saved the dup.

### ✅ 4. Triage `tools/cbb/` — DONE
- **Before:** 56 scripts / 816 KB copied unaudited.
- **After:** 47 standalone-runnable kept (flattened into `tools/`), 9 framework-coupled dropped (manifest in `tools/.cbb-dropped-manifest.txt`). **816 KB → 652 KB.**

### ✅ 5. Close recon tool gaps — DONE
- Installed **katana** (crawl), **dnsx** (DNS), **naabu** (fast ports), **dalfox** (XSS confirm) via Go; cache auto-cleaned.
- **Arsenal now 22/22 keyless tools installed.** Both bin dirs (`~/go/bin`, `~/.local/bin`) confirmed on PATH → scripts find everything.

---
## Pass 1 result
- Per-agent prompt-load **~8× smaller**; storage duplication removed; `tools/` trimmed 816→652 KB; automation hooks live; arsenal complete (22 tools); disk 661 Mi → **5.5 Gi** free.
- Folder still ~2 MB. Brain 11,613 probes / 6 lessons / 9 tool notes; ruflo 16 vector entries.

## Candidates for pass 2 (not yet done)
- Merge `doctrine.md` (distilled) + `prompts/doctrine-full.md` (verbatim) overlap → cross-link, keep one canonical.
- Parallelize `recon.sh` DNS/whois/HTTP calls (wall-clock).
- Enrich ruflo entries + run `mcp__ruflo__memory_consolidate` / `neural_patterns` once more engagement data exists.
- Auto-dedupe wordlists cross-file (common ⊂ raft check) in `optimize.sh`.

---
### Baseline (before pass 1)
- Single folder: 2.0 MB · 13 references · 10 scripts · 5 t3-* agents · brain 11,613 probes · ruflo 15 vector entries.
- Keyless arsenal: 18 tools installed.
