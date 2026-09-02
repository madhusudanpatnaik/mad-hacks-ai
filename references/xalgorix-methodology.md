# xalgorix-methodology — 22-phase coverage checklist + adopted design patterns

**Source:** [github.com/xalgorix/xalgorix](https://github.com/xalgorix/xalgorix) (Apache-2.0). Full clone at `packs/xalgorix/` — Go+TS autonomous pentest orchestrator, LLM-driven, external-tool wrapper. We are not running xalgorix here; we **borrow its methodology + design patterns** for our keyless file-brain.

## Why fold this in
Xalgorix's core claim — *"Most scanners detect. Xalgorix proves."* — is the same doctrine as our VERIFY + REFUTE gates. Its 22-phase methodology is a completeness checklist we can measure our own coverage against, and its **independent-verifier** pattern maps onto `t3-verifier`.

## The 22 phases (coverage map)

| # | xalgorix phase | mad-hacks coverage | Gap? |
|--:|----------------|---------------------|:---:|
| 1 | Reconnaissance | `scripts/recon.sh` + `references/recon-oneliners.md` | ✓ |
| 2 | Manual vulnerability discovery | `references/pipeline.md` (WEAPONIZE) + operator loop | ✓ |
| 3 | Directory and file discovery | `wordlists/raft-medium-dirs.txt`, `sensitive-files.txt` + ffuf/dirsearch in `recon-oneliners.md` | ✓ |
| 4 | CORS and cookie analysis | `scripts/web-scan.sh` (D + E) + `cors-hunter` agent | ✓ |
| 5 | Authentication and session testing | `references/hunt-session.md` (14 checks) + `auth-tester`/`oauth-hunter` | ✓ |
| 6 | Injection testing | `sqli-hunter`, `rce-hunter`, `ssti-hunter`, `xss-hunter` + `brain/payloads/{sqli,rce,cmdi,xss,ssti}.txt` | ✓ |
| 7 | SSRF testing | `ssrf-hunter` + `brain/payloads/ssrf.txt` + writeup depth | ✓ |
| 8 | IDOR and broken access control | `idor-hunter` + `privilege-escalation` + `references/router.md` | ✓ |
| 9 | API and GraphQL testing | `graphql-audit` agent + `brain/payloads/graphql.txt` | ✓ |
| 10 | File upload testing | `file-upload` agent + `brain/payloads/file-upload.txt` | ✓ |
| 11 | Deserialization and RCE | `rce-hunter` + Strix `packs/strix/skills-internal/vulnerabilities/` + React2Shell CVE in `hunt-xss.md` | ✓ |
| 12 | Race conditions and business logic | `race-condition` + `business-logic` agents + `brain/payloads/business-logic.txt` | ✓ |
| 13 | Subdomain takeover | `subdomain-takeover` + `scripts/surface-probe.sh` (G) | ✓ |
| 14 | Open redirect testing | `open-redirect` + `brain/payloads/{redirect,open-redirect}.txt` | ✓ |
| 15 | Email security testing (SPF/DKIM/DMARC/relay) | — | **GAP** — no dedicated agent; add SPF/DKIM/DMARC probe |
| 16 | Cloud and infrastructure | `cloud-recon` + `packs/cyberstrike/{aws,azure,gcp,k8s}-postexploit/` + `references/router.md` cloud_infra row | ✓ |
| 17 | WebSocket testing | — | **GAP** — no WS agent; adjacent: `references/hunt-xss.md` postMessage sub-technique |
| 18 | CMS-specific testing | `references/wordpress-recon.md` (WordPress) | Partial — WP ✓, no Drupal/Joomla/Ghost yet |
| 19 | Broken link hijacking + content spoofing | Adjacent to `subdomain-takeover` | Partial — no dedicated broken-link agent |
| 20 | Exploit verification | `t3-verifier` agent + `references/pipeline.md` REFUTE gate | ✓ (strong) |
| 21 | Novel vulnerability discovery | — | **GAP** — this is what `references/cdc-harness.md` addresses |
| 22 | Final report | `t3-reporter` + `references/report-template.md` + `scripts/report.sh` | ✓ |

**Coverage:** 18/22 solid, 4 gaps (email, WebSocket, non-WP CMS, novel-discovery). Novel-discovery is filled by our CDC harness (`references/cdc-harness.md`).

## Adopted design patterns

### 1. Independent verifier before "reported"
Xalgorix runs a separate agent to *re-exploit* every candidate finding before it's included in the report. This is exactly `t3-verifier`'s job. Our `mad-hunt.md` already enforces this; the CDC harness enforces it too (§ Adversarial validation).

### 2. Weak-evidence rejection at report time
Xalgorix's `internal/tools/reporting` rejects weak evidence, dedups findings, and preserves strong evidence. Our `t3-reporter` performs the same guard; ensure `references/report-template.md`'s evidence contract is enforced.

### 3. Selectable methodology phases
Their Web UI lets an operator pick a subset of phases for a focused engagement. Our equivalent: dispatch specific hunters via `router.md` class rows; the CDC harness lets an operator pass `--families xss,ssrf,idor` for a focused divergent search.

### 4. Skills-as-knowledge-modules
xalgorix's `internal/tools/skills` package loads per-capability skill docs on demand. Our `references/router.md` + T2/T3 lazy-load model is the same pattern; keep it that way.

### 5. Runtime-only automation controls
`XALGORIX_RATE_RPS`, `XALGORIX_RATE_BURST`, `XALGORIX_USE_PROXY` — adaptive throttle. Our `mad-hunt.md` § "Adaptive throttle" already codifies this; keep the ceiling honored by every hunter.

## Not adopted (deliberately)

- **LLM API key requirement.** Xalgorix needs a provider key (`XALGORIX_LLM`, `XALGORIX_API_KEY`). Our doctrine is keyless — the Claude Code session IS the reasoning engine. We do not require an external LLM provider or a running dashboard.
- **Dashboard / Web UI.** Xalgorix runs a full React dashboard at `:9137`. We operate through the CLI + file brain. Cheap, portable, no second bill.
- **Full Go binary vendoring.** We do not compile xalgorix here. `packs/xalgorix/` is a reference clone only.

## Attribution + License

- **Repo:** [xalgorix/xalgorix](https://github.com/xalgorix/xalgorix)
- **License:** Apache License 2.0 (see `packs/xalgorix/LICENSE`)
- **Ingested at:** 2026-08-25 (shallow clone, `--depth 1`)
- **What we copied:** methodology (22 phases, mapped above), design patterns (verifier, weak-evidence reject, phase selection, skills-as-modules). Nothing else was ported — no Go source, no LLM adapters, no dashboard, no CLI.
