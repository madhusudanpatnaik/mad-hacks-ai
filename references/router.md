# Router — load-on-CLASSIFY asset map

**Why this file exists:** so you load *only what this mission needs*, not the whole reference tree. `SKILL.md` keeps just the law (`doctrine`) + the loop (`pipeline`) always-resident. On CLASSIFY you read *this file* + your one family block, and pull deeper docs per vuln class only when that class comes up.

---

## Overlap pick-order (READ ONCE — resolves the "same class, 4 places" problem)

Four repos each teach the common web classes. They are **complementary depth, not duplicates**. Load in this order and STOP as soon as you can act — don't load all four:

1. **`brain/payloads/<class>.txt`** — ALWAYS first. Curated, deduped, fastest. Names available via `brain.sh recall`.
2. **Dispatch the `<class>-hunter` agent** — it executes the probes and pulls its own depth. For most classes this is all you need.
3. **Depth, only if the agent stalls or you're driving manually — pick ONE:**
   - `packs/cyberstrike/attack-<class>/SKILL.md` — curl PoC + `chains_with`/`severity_boost` (best for **escalation chains**). 16 dirs; exact names in the class table (note `attack-idor-automation`, `attack-request-smuggling`).
   - `packs/claude-bughunter/disclosed-reports/hunt-<class>.md` — H1 disclosed-report $ patterns (best in **bug-bounty mode**). Subset of 24 classes only — the table's **CBH** flag marks which exist (no xxe/race/subdomain/info-disc here).
   - `packs/strix/skills-internal/vulnerabilities/` — methodology depth: parser differentials, bypass matrices, IMDSv2/DNS-rebind (best when **the obvious probe was blocked**). Filenames are descriptive + underscored (`sql_injection.md`, `authentication_jwt.md`, `path_traversal_lfi_rfi.md`, `race_conditions.md`) — `ls` to pick; not every class has one (no cors/graphql).
   - `references/payloads-all-the-things-index.md` → extract from `pat-full.tar.gz` — exotic/last-resort payloads.

Rule of thumb: **payload + agent** covers 90% of engagements. Reach for a playbook only for chaining, bounty-pattern-matching, or bypass.

---

## Family → assets (load your ONE block on CLASSIFY)

| Family | Recon | Knowledge packs | Primary agents | Family-specific depth |
|--------|-------|-----------------|----------------|----------------------|
| **web_api** | `recon.sh` → `web-scan.sh` | owasp-wstg, owasp-api-top10, cwe-top25, cisa-kev | t3-recon → t3-scanner → per-class `*-hunter` → t3-verifier | `references/tech-stack-playbooks.md` (on stack detect); `packs/cyberstrike/WEB/` = 125-skill WSTG completeness checklist |
| **code_supply_chain** | `code-audit.sh` | slsa, cwe-top25, osv | js-analyzer, info-disclosure, `sast-*` chain | `packs/cyberstrike/cicd-attacks/` |
| **cloud_infra** | `cloud-audit.sh` | cisa-kev, cwe-top25 | cloud-recon, config-auditor | `packs/cyberstrike/{cloud,k8s}-assessment/`; post-exploit: `packs/cyberstrike/{aws,azure,gcp,k8s}-postexploit/` (scope permitting) |
| **ai_red_team / agent_warfare** | manual + `frontier-lanes.md` | owasp-llm-top10, mitre-atlas, nist-ai-rmf | llm-ai-hunter | `packs/ai-pentesting/LLM01..10.md` (OWASP LLM depth); `packs/cyberstrike/llm-security/`; `packs/strix/skills-internal/vulnerabilities/{llm_prompt_injection,agentic_system_security}.md` |
| **smart_contract** | `contract-audit.sh` | cwe-top25 | web3-auditor | `references/ctf-techniques.md` (contract lane) |
| **crypto_secrets** | `code-audit.sh` | — | info-disclosure | `references/ctf-techniques.md` (crypto/stego lanes) |
| **reverse_binary** | `binary-audit.sh` | — | `sast-*` chain | `references/ctf-techniques.md` (pwn/RE lanes) |
| **reporting_remediation** | — | epss, cisa-kev, cwe-top25 | t3-reporter | `references/report-template.md` + `scripts/sarif-export.py` |

Full family directives (ask-up-front, evidence contract, escalation rules): `references/mission-families.md` — read only your family's ~40-line block.

---

## Vuln class → assets (web_api; pull the row when the class comes up)

Payload = `brain/payloads/<file>.txt`. Agent = dispatch target. CS = CyberStrike playbook exists. Strix = methodology doc exists. CBH = disclosed-report pattern exists.

| Class | Payload file | Agent | Depth available |
|-------|-------------|-------|-----------------|
| SSRF | `ssrf` | ssrf-hunter | CS · Strix · CBH — blind→OOB gate (see lessons) |
| SQLi | `sqli` | sqli-hunter | Strix · CBH · `sqlmap` guide in `tool-guides.md` |
| XSS | `xss` + `xss-waf-bypass` | xss-hunter | Strix · CBH — **browser-verify before ship** |
| SSTI | `ssti` | ssti-hunter | CS · Strix · CBH — runtime-vs-parse distinguisher |
| RCE / cmd-inj | `rce` + `cmdi` | rce-hunter | Strix · CBH |
| LFI / path traversal | `lfi` | (manual) | Strix(path_traversal_lfi_rfi) · CBH — chains to RCE / source-leak |
| XXE | `xxe` | xxe-hunter | CS · Strix |
| IDOR / BOLA / privesc | `idor` | idor-hunter · privilege-escalation | CS(attack-idor-automation) · Strix(idor, broken_function_level_authorization) · CBH |
| Open redirect | `redirect` + `open-redirect` | open-redirect | CS · Strix · CBH |
| CORS | `cors` | cors-hunter | CS · CBH |
| CSRF | `csrf` | csrf-hunter | Strix · CBH |
| JWT / OAuth / SAML | `oauth` + `saml` | oauth-hunter | CS(attack-jwt) · Strix · CBH(oauth,saml) · `ctf-techniques.md` |
| Auth bypass / MFA / session | `brute-force` + `mfa-bypass` + `session` | auth-tester | Strix(weak_password_detection, authentication_jwt) · CBH · brute-force→CS(attack-rate-limit-bypass) · **`references/hunt-session.md` (14-check ladder)** |
| **Registration / signup abuse** | (checklist-driven) + `mass-assignment-json.md` | (manual → mass-assign to `business-logic` / `privilege-escalation`) | **`references/hunt-registration.md` (22-check taxonomy)** |
| **Cache deception** | `cache-deception` | (manual, curl-driven) | **`references/hunt-cache-deception.md`** — distinct from cache-poison (which is upstream/downstream server poisoning) |
| GraphQL | `graphql` | graphql-audit | CS · CBH |
| Race condition | `business-logic` | race-condition | CS · Strix |
| Req smuggling | `http-smuggling` | (manual) | CS · Strix · CBH · `ctf-techniques.md` |
| Cache poison | `cache-poison` | (manual) | CS · CBH · (adjacent: `references/hunt-cache-deception.md`) |
| Host header | `host-header` | (manual) | CS · CBH · `writeups-index.md` |
| Prototype pollution | (manual) | (manual) | CS · Strix |
| File upload | `file-upload` | file-upload | Strix · CBH |
| Deserialization | `deserialization` | (rce-hunter) | Strix · CBH |
| NoSQLi / LDAPi | `nosqli` / `ldapi` / `ldap` | (sqli-hunter) | Strix · CBH · `vuln-playbooks.md` |
| Subdomain takeover | (recon) | subdomain-takeover | CS · Strix |
| Mass assignment | `mass-assignment-json.md` (16 payload buckets) | business-logic | Strix · **`references/hunt-registration.md` §21** — huge SaaS-tier / role-escalation vector |
| Info disclosure | `sensitive-files` | info-disclosure | Strix — feeder, must chain |

Hidden-param discovery (feeds IDOR/SSRF/LFI): `params` payload + arjun/x8. 403 walls: `vuln-playbooks.md#403-bypass`.

---

## On-demand references (named here; do NOT preload)

| Need | Load |
|------|------|
| One-liner recon arsenal (subs→urls→params→per-class filters) | `references/recon-oneliners.md` (CoffinXP master checklist) |
| Target runs WordPress | `references/wordpress-recon.md` (wpscan + admin-ajax + oEmbed SSRF + plugin CVE catalog) |
| Coverage checklist against a 22-phase methodology + independent-verifier patterns | `references/xalgorix-methodology.md` (adopted from Apache-2.0 xalgorix repo — clone at `packs/xalgorix/`) |
| Novel-vulnerability research on a codebase / system (not bounty enumeration — chain-until-impact with adversarial validation) | `references/cdc-harness.md` via `/cdc-research <target>` |
| XSS lane scanner — dalfox v3 (Rust, MIT). Native `--blind-oob` (interactsh) + MCP stdio 6-tool server + SARIF/JSONL output. **Prefer over hand-rolled curl loops for XSS scan/mining/blind.** Local install may be v2 (Go); v3 upgrade recipe + full CLI/MCP contract in the guide. | `references/dalfox-guide.md` (clone at `packs/dalfox/`) |
| **Peer methodology library** — Rifteo Skills (MIT, 38 skills). Inventory + gap analysis + when-to-use-which for every skill vs our native coverage. Points to `packs/rifteo-skills/<skill>/SKILL.md` for on-demand loading. | `references/rifteo-skills-catalog.md` |
| **Verified / Inferred / Assumed labeling** — doctrine extension for the VERIFY/REFUTE gate. Load before shipping any finding, chain, or severity call. | `references/deadangle.md` |
| **Session-state save/restore** — write HANDOFF.md at end-of-session so the next agent continues without asking questions. | `references/engagement-handoff.md` |
| **Active Directory attack lane** (Kerberoasting, ACL abuse, DCSync, AD CS ESC1-ESC8, NTLM relay, BloodHound) | `packs/rifteo-skills/ad-breach/SKILL.md` (on-demand) |
| **Android APK static analysis** (apktool + jadx + OWASP MASVS mapping) — extends `scripts/mobile-audit.sh` | `packs/rifteo-skills/droid-recon/SKILL.md` (on-demand) |
| **Clickjacking / UI redressing** (frame protection detection, JS frame-busting bypass, drag-and-drop, OAuth consent variants) | `packs/rifteo-skills/clickjacking-hunter/SKILL.md` (on-demand) |
| **HTTP Parameter Pollution (HPP)** (server/client-side HPP, WAF bypass via param splitting, OAuth/payment/access-control abuse) | `packs/rifteo-skills/hpp-hunter/SKILL.md` (on-demand) |
| **JWT attacks (dedicated cracker)** (alg:none, RS256→HS256 confusion, weak-secret brute, kid/jku/jwk injection, claim tampering) | `packs/rifteo-skills/jwt-cracker/SKILL.md` (on-demand) |
| **Nuclei template generation** from a finding or HTTP request/response pair | `packs/rifteo-skills/nuclei-template-writer/SKILL.md` (on-demand) |
| **CVE exploitability lookup** (searchsploit / Vulners / MSF / weaponized exploit refs) | `packs/rifteo-skills/check-exploit/SKILL.md` (on-demand) |
| **CVSS v3.1 scoring** (metric inference from context, one sharp Q if ambiguity would change severity) | `packs/rifteo-skills/cvss-scorer/SKILL.md` (on-demand) |
| **Governance / audit layer** (compliance-gap-analyzer, control-lookup, risk-assessor, remediation-planner) — for pentest / audit / red-team engagements, NOT bug-bounty | see `references/rifteo-skills-catalog.md` §4 |
| Tool has an execution mode I must check | `references/arsenal.md` |
| Prod / bug-bounty rules of engagement | `references/production-safety.md` |
| Detected a specific stack (Firebase/Django/K8s/…) | `references/tech-stack-playbooks.md` |
| Finding might duplicate a prior one | `references/dedup-methodology.md` |
| Tagging findings for exec/coverage report | `references/stride-mapping.md` |
| Calibrating scan depth (quick/standard/deep) | `references/scan-modes.md` |
| CTF / AD-Kerberos / container / firmware | `references/ctf-techniques.md` (index → one checklist) |
| A practitioner writeup for this exact bug | `references/writeups-index.md` (index → one writeup) |
| Run an autonomous bug-bounty hunt (web/API) | `references/mad-hunt.md` via `/mad-hunt <target>` (scope-gated exhaustion loop) |
| Study top disclosed-bounty writeups for a class before hunting it | `brain/writeups-corpus.md` (6.4k writeups distilled per class + top exemplars) |
| Pull fresh writeups / where disclosures live | `references/writeup-sources.md` (feeds + on-demand recipe) |
| Naming/prioritizing a finding to a standard | `references/knowledge-packs.md` |
| Burp MCP is connected | `references/burp-integration.md` |
| Fuzz/property/mutation methodology | `references/edge-case-hunting.md` |
| Assembling the final report | `references/report-template.md` |
| Verbatim operator recipe | `references/prompts/op-<operator>.md` |
