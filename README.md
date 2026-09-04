# mad-Hacks_ai

A **single-folder, keyless offensive-security toolkit for Claude Code.** This session is the backbone — no API keys, no server, no second bill. It runs a full kill-chain (recon → weaponize → exploit → verify → report) over real system tools, under a strict authorization + evidence + anti-fabrication doctrine, backed by a **persistent brain that compounds** across engagements and every repo you feed it.

Distilled from **T3MP3ST** (AGPL-3.0) + **shuvonsec/claude-bug-bounty**. Folded in: **xalgorix** (Apache-2.0 · autonomous-pentest methodology), **hahwul/dalfox** v3 (MIT · Rust XSS scanner with native OOB + MCP), **Rifteo/skills** (MIT · 38-skill peer library — 2 doctrine promotions, 10 on-demand attack lanes), **mazen160/secrets-patterns-db** (1610 curated secret regexes, wired via `scripts/secrets-scan.sh`), **bikini/exploitarium** (39 POC folders across 12 CVEs), **moscovium-mc/CloudRip** (CF origin discovery), **shadowsock5/Poc** (72 vendor CVE POC dirs), **devanshbatham/Awesome-Bugbounty-Writeups** (600 curated writeups across 16 classes, 130 net-new URLs folded into writeup corpus), and the **CoffinXP / Lostsec** writeup corpus. Attribution/licenses in `packs/`.

---

## Three entry points

```
/mad-hacks <target-or-task>           general operator mode — full kill chain, doctrine-gated
/mad-hunt  <target> [--auto]          autonomous bug-bounty spine (exhaustion contract)
/cdc-research <target> --goal "…"     Concurrent Divergent-Cognition vuln research
                       --deployment "…"   (parallel families, chain-until-impact, no CVE shortcuts)
                       [--mode bug-bounty|pentest|research]
```

- **`/mad-hacks`** — general operator. Loads `SKILL.md`, routes assets via `references/router.md` (3-tier lazy load).
- **`/mad-hunt`** — bounty spine: scope-gate → surface probe A–J → surface × payout-ranked specialists (≥25 attempts/class) → 7-Q + `t3-verifier` REFUTE gate → `chain-builder` escalation → platform-ready draft. Loop: `references/mad-hunt.md`.
- **`/cdc-research`** — novel-vuln loop with chain-until-impact + layered halting (soft budget · plateau tripwire · hard budget · operator interrupt). Spec: `references/cdc-harness.md`. State: `scripts/cdc-state.sh`.

---

## The intelligence layer (the part that makes it get smarter)

The canonical **file-brain** is the source of truth. Sitting on top of it:

```
    ┌──────────────────────────────────────┐
    │        SOURCE (canonical)            │
    │  references · scripts · tools ·      │
    │  brain/{lessons,tools,payloads} ·    │
    │  packs · agents · engagements        │
    └──────────────┬───────────────────────┘
                   │
                   ▼
    ┌──────────────────────────────────────┐
    │        REGISTRY (regenerable)        │  scripts/build-registry.py
    │  brain/registry/assets.jsonl (265)   │  common schema per asset:
    │  brain/registry/assets.db (SQLite    │    id · type · title · description ·
    │                    FTS5 / BM25)      │    capabilities · classes · technologies ·
    │  brain/registry/assets.faiss         │    prerequisites · commands · outputs ·
    │      (optional, opt-in)              │    provenance · epistemic_status · confidence
    └──────────────┬───────────────────────┘
                   │
                   ▼
    ┌──────────────────────────────────────┐
    │      INTELLIGENCE ROUTER              │  scripts/intelligence-recall.sh
    │      (Reciprocal Rank Fusion, k=60)   │
    │                                       │
    │    lex (FTS5)                         │  BM25-ranked, stdlib-only
    │  + sem (FAISS, if installed)          │  MiniLM cosine
    │  + writeups (6.7k row MCP corpus)     │  SQLite keyword
    │  + target (.engagement/<t>/ state)    │  observed / tested / exhausted
    │  ═════════════════════════════════    │
    │    fused, deduplicated, ranked        │
    └──────────────┬───────────────────────┘
                   │
                   ▼
    ┌──────────────────────────────────────┐   scripts/engagement-state.sh
    │      ENGAGEMENT STATE                 │   .engagement/<slug>/
    │   TECHNOLOGY · OBSERVED · TESTED ·    │   EXHAUSTED.md as structured
    │   EXHAUSTED · HYPOTHESES ·            │   [class][vector][variant] records
    │   EVIDENCE.jsonl (epistemic ternary)  │   deadangle: OBSERVED/DERIVED/INFERRED/HYPOTHESIS
    └──────────────┬───────────────────────┘
                   │
                   ▼
    ┌──────────────────────────────────────┐
    │       SPECIALIST HUNTERS              │  19 agents, all wired to:
    │  xss / ssrf / idor / rce / ssti /     │  1. ToolSearch(burp,dalfox)
    │  oauth / cors / csrf / xxe / sqli /   │  2. intelligence-recall.sh
    │  open-redirect / subdomain-takeover / │  3. engagement-state.sh recall
    │  race / business-logic / graphql /    │  4. probe → capture back:
    │  file-upload / info-disclosure /      │       observe / tested /
    │  cloud-recon / config-auditor         │       exhausted / evidence / learn
    └──────────────────────────────────────┘

    optional cache: brain-sync-ruflo.sh --from-registry
    exports the registry with provenance.last_verified so ruflo staleness
    is detectable at query time. Toolkit still works if ruflo disappears.
```

Every specialist hunter's Preflight preamble runs the same 3-step boot: ToolSearch → intelligence-recall → engagement-state recall, then probes, then writes results back. **The file tree remains authoritative; the registry is a regenerable index; the router hides where knowledge lives from the agents.**

---

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
│                        engagement-state · build-registry · build-embeddings ·
│                        intelligence-recall · build-writeup-corpus · refresh-writeup-feeds ·
│                        brain-sync-ruflo · reinstall-packs · ingest · optimize   (keyless)
├── brain/               persistent memory:
│   ├── lesson-index.md      class → keyword-set for recall-class
│   ├── lessons.md           append-only global heuristics (60+)
│   ├── tools.md             tools learned (30+)
│   ├── payloads/            per-class libraries (37 files, 19k+ probes)
│   ├── targets/             per-target memory (gitignored)
│   └── registry/            REGENERABLE machine-readable index (gitignored)
│       ├── assets.jsonl         265 rows, common schema
│       ├── assets.db            SQLite FTS5 (BM25) lexical index
│       ├── assets.faiss         optional FAISS semantic index
│       └── assets.embed-map.jsonl
├── wordlists/           deduped: params · sensitive-files · content-discovery · raft · api-endpoints ·
│                        common · onelistforall.txt.gz
├── tools/               scanner scripts extracted from ingested repos (48 files, all registry-indexed)
├── agents/              t3-{recon,scanner,exploiter,verifier,reporter}  (symlinked into ~/.claude/agents/)
├── packs/               attribution + methodology from ingested repos
│                        (writeups/ · cyberstrike/ · strix/ · claude-bughunter/ · ai-pentesting/ ·
│                         payloads-all-the-things/ · lostfuzzer/ · t3mp3st/  — all tracked)
│                        (xalgorix/ · dalfox/ · rifteo-skills/  — externally cloned, .gitignored;
│                         provenance + rehydration recipe in packs/UPSTREAM.md)
├── .engagement/         per-target state (gitignored) — TECHNOLOGY / OBSERVED / TESTED /
│                        EXHAUSTED / HYPOTHESES / EVIDENCE.jsonl / LOG
├── .cdc/                per-target CDC harness working state (gitignored)
└── engagements/         per-target working evidence (gitignored)
```

---

## Doctrine (non-negotiable — every run)

1. **Authorization first.** `bash scripts/scope.sh init <target>` then `scripts/preflight.sh <target>`. A tool working or a host answering is **not** consent — authorization comes only from the engagement contract.
2. **Execution modes.** `safe_command` → run. `receipt_required` (nmap, nuclei, ffuf, sqlmap, curl-vs-target, dalfox scan) → pause for explicit user OK. `catalog_only`/`import_only` (msfconsole, pacu, frida, hydra) → **never run here** — hand to the user.
3. **VERIFY + REFUTE.** Real only if it appears in captured tool output. `t3-verifier` emits a mandatory visible verdict card with the **Verified / Inferred / Assumed ternary** (`references/deadangle.md`) — a CONFIRMED verdict whose claims are majority-Inferred/Assumed is grounds for DOWNGRADED.
4. **Redact** secrets/PII. **Absolute stops** apply regardless of scope (no credential entry, data deletion, fund movement, destructive payloads on the user's behalf).
5. **No CVE / patch-diff / changelog shortcuts** as proof. Reproduce against the realistic deployment. Read dependency source when behavior depends on it — runtime is oracle, docs are hypothesis.

---

## Installed arsenal (keyless, on this machine)

**Recon/DNS:** nmap · subfinder · amass · dnsx · waybackurls · dig · whois · katana · gau · asnmap · chaos
**Web:** curl · httpx-toolkit · ffuf · gobuster · nikto · wafw00f · arjun · dalfox v2 (v3 upgrade recommended — `brew install dalfox`)
**Vuln/scan:** nuclei · semgrep · osv-scanner
**Secrets/crypto:** gitleaks · trufflehog · openssl · testssl.sh
**OOB:** interactsh-client — wrapped by [`scripts/oob.sh`](scripts/oob.sh) (per-target ledger, seed/fire/poll/attribute)
**Report:** pandoc / cmark / python-docx / weasyprint / wkhtmltopdf — whichever is present ([`scripts/report.sh build-{html,docx,pdf,all}`](scripts/report.sh))
**Optional (semantic retrieval):** `pip3 install faiss-cpu sentence-transformers` — unlocks FAISS layer in `intelligence-recall.sh`

`scripts/preflight.sh <target>` prints live availability. Active tools are `receipt_required` — used only with confirmed scope.

---

## Retrieval status — LIVE vs OPTIONAL (honest labels)

| Layer | Status | Baseline (against `tests/intelligence/queries.jsonl`) |
|---|---|---|
| SQLite FTS5 / BM25 lexical | **LIVE** — stdlib only, ships with every clone | MRR **0.530**, R@10 **0.562** |
| RRF fusion (lex + writeups + target) | **LIVE** — via `intelligence-recall.sh` (phase 1) | MRR **0.549**, R@10 **0.625** |
| Security-vocabulary query expansion | **LIVE** — zero-threshold fallback, tight OR pool | rescues `synonym` (R@10 0→0.700) + `tech-cross` (MRR 0→0.750) |
| **State-as-filter (audit correction #7)** | **LIVE** — phase 2 of the router: exhausted-class demote (0.4×) + hypothesis-alignment boost (+0.15 × median × signal) applied after RRF | `--state-filter=on\|off\|auto`; 37/37 state adversarial tests |
| Engagement state (target memory) | **LIVE** — `.engagement/<t>/` (OBSERVED / TESTED / EXHAUSTED / HYPOTHESES / EVIDENCE) | 37/37 state adversarial tests pass (was 9/9) |
| Evidence ledger + epistemic ternary | **LIVE** — `EVIDENCE.jsonl` | Verified/Inferred/Assumed labels never silently upgrade |
| FAISS + sentence-transformers semantic | **OPTIONAL** — `pip3 install faiss-cpu sentence-transformers` + `python3 scripts/build-embeddings.py` | Not measured until enabled |
| Ruflo semantic cache | **OPTIONAL** — `brain-sync-ruflo.sh --from-registry` + ruflo MCP | Provenance-tagged; toolkit works without it |
| Registry (`brain/registry/`) | **REGENERABLE — do not hand-edit** — regenerated from source by `build-registry.py`; canonical remains the file tree | 265 rows across 6 asset types |

Per-category MRR (RRF, 2026-09-04 v2): direct **0.676** · synonym **0.578** · tech-cross **0.750** · ambiguous **0.357** · indirect **0.125**.

**The retrieval suite (`tests/intelligence/`) freezes these numbers.** Every future router change is compared numerically, not "looks good on toy queries." The suite has caught two bad tunes already (blind expansion regressed MRR −30%, threshold-<5 fallback regressed MRR −6%) and validated the good ones (zero-threshold expansion +28%, state-as-filter refactor +17%). Per-category floors are now hardcoded — any category regressing >5% below baseline fails the suite.

## MCP integration (auto-detected)

- **Burp Suite MCP** — every specialist hunter runs `ToolSearch("burp proxy repeater intruder collaborator")` at dispatch; if present, Repeater = primary probe channel + Collaborator = primary OOB backend. Register: `claude mcp add burp ...` (recipe: [`references/burp-integration.md`](references/burp-integration.md)).
- **dalfox v3 MCP** — 6-tool stdio server (`scan_with_dalfox`, `get_results_dalfox`, `list_scans_dalfox`, `cancel_scan_dalfox`, `delete_scan_dalfox`, `preflight_dalfox`). `xss-hunter` prefers when loaded. Register: `claude mcp add dalfox -- dalfox mcp`. Guide: [`references/dalfox-guide.md`](references/dalfox-guide.md).
- **writeup-search MCP** — search 6,749-row corpus (23 CoffinXP full-body + 6,554 pentester.land + 172 fresh RSS). See "Writeup corpus" below.
- **bounty-platforms MCP** — H1/Bugcrowd/Immunefi/YesWeHack scope + policy + hacktivity + submit + draft-report tools.
- **ruflo MCP (optional cache)** — after `bash scripts/brain-sync-ruflo.sh --from-registry`, use `mcp__ruflo__memory_import_claude` to populate a semantic cache namespaced `"mad-hacks"`. Provenance timestamps make staleness detectable. **Never a source of truth**; the file-brain is.

---

## An effective run (concrete)

```bash
# 0. Authorization
bash scripts/scope.sh init <target>
bash scripts/preflight.sh <target>

# 1. Engagement state — capture what you know before probing
bash scripts/engagement-state.sh init <target> --tech "Next.js 14 App Router on Vercel Edge, Postgres, Cloudflare, defaults"
bash scripts/engagement-state.sh observe <target> "webhook /api/hook accepts url= param"
bash scripts/engagement-state.sh hypothesis <target> add "SSRF via redirect chain to internal ELB" --priority high

# 2. Intelligence router — single query surface
bash scripts/intelligence-recall.sh "webhook ssrf redirect chain" --target <target> --class ssrf --limit 12
# Returns: fused lexical + semantic + writeups + target-memory bundle
# (agents call this instead of the old 3-way brain.sh chain)

# 3. Pick the right entry point
/mad-hunt <target>          # bounty
/cdc-research <target>      # research
# (both drive specialist hunters whose Preflight preambles auto-run steps 2+3)

# 4. Blind classes seed OOB attribution
bash scripts/oob.sh seed <target> ssrf webhook-url-param

# 5. Capture back (mandatory after every dispatch)
bash scripts/engagement-state.sh evidence <target> add \
    --observation "server responded 500 'connection refused' on http://169.254.169.254" \
    --evidence "evidence/ssrf-imds.txt" \
    --interpretation "backend can reach IMDS host but v1 is blocked" \
    --hypothesis "IMDSv2 enabled — need token flow" \
    --epistemic DERIVED --confidence HIGH
bash scripts/engagement-state.sh exhausted <target> ssrf url_parameter direct-metadata "IMDSv1 blocked — v2 token flow required"
bash scripts/brain.sh learn "IMDSv2 blocked → probe v2 token flow via PUT before assuming SSRF is dead"

# 6. End-of-session
# write .t3mp3st/<target>/HANDOFF.md per references/engagement-handoff.md
bash scripts/refresh-writeup-feeds.sh        # optional — pull fresh RSS entries
bash scripts/build-registry.py               # optional — refresh the index if you added lessons/tools
```

---

## Writeup corpus (`writeup-search` MCP data source)

```bash
bash scripts/build-writeup-corpus.sh          # base corpus: 23 CoffinXP + 6,554 pentester.land
bash scripts/refresh-writeup-feeds.sh         # +11 RSS feeds (PortSwigger/Datadog/samcurry/Medium tags/…)
                                              # dedupes on source URL, cron-friendly, --dry-run flag
pkill -f mcp-writeup-server                   # Claude Code auto-respawns w/ fresh DB (or /mcp reconnect)
```

Corpus lives at `~/.local/share/pentest-writeups/metadata.db` (SQLite). Tools available after reconnect: `search_writeups` (keyword search across full text + metadata), `search_techniques` (per-class technique packs), `search_payloads` (context-organized payload pack + mutation matrix + detection ladder), `get_writeup`. Source catalog: [`references/writeup-sources.md`](references/writeup-sources.md). **The intelligence router queries this alongside the registry.**

---

## Feed it more (it compounds)

```bash
bash scripts/ingest.sh <repo-or-file>          # classify + propose merges (read-only)
bash scripts/brain.sh recall <target>          # target-specific memory
bash scripts/brain.sh recall-class <class>     # class-relevant lessons
bash scripts/brain.sh search "<query>"         # NEW — hybrid registry search (uses FTS5)
bash scripts/brain.sh registry [--rebuild]     # NEW — registry ops
bash scripts/brain.sh payload <class> <file>   # wordlists/payloads → brain (deduped)
bash scripts/brain.sh tool "<name> — <use>"    # tools learned
bash scripts/brain.sh learn "<heuristic>"      # reusable lessons — every hunter auto-pulls
bash scripts/optimize.sh [--aggressive]        # keep storage lean
```

Methodology docs & reports go in `packs/`. Externally-cloned packs (xalgorix/dalfox/rifteo-skills/secrets-patterns-db/exploitarium/CloudRip/Poc/Awesome-Bugbounty-Writeups) are gitignored — rehydrate on a fresh clone via `bash scripts/reinstall-packs.sh` (upstream URLs + pinned commits in `packs/UPSTREAM.md`).

---

## Session handoff (end-of-day)

Write `.t3mp3st/<target>/HANDOFF.md` per [`references/engagement-handoff.md`](references/engagement-handoff.md) — under 100 lines, findings-by-id, coverage tested/skipped/partial, open threads, ordered next-steps. Next session opens with `cat HANDOFF.md` + `bash scripts/engagement-state.sh recall <target>`.

---

## Authorized use only

Point it only at systems you own or have explicit written permission to test. `scripts/scope.sh` records the receipt; `preflight.sh` gates on it. A tool working is never consent.
