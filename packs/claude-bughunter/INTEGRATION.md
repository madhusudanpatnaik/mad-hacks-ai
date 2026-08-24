# Claude-BugHunter × T3MP3ST Integration Map

Source: https://github.com/elementalsouls/Claude-BugHunter (MIT, v2.1.0)
Author: Sachin Sharma | Ingested: 2026-08-22
Assets: 83 skills, 15 commands, 681 disclosed-report patterns, engine (Python)

## T3MP3ST Pipeline ↔ CBH Skill Mapping

| T3MP3ST Phase | CBH Skills | CBH Commands |
|---|---|---|
| **CLASSIFY** | `bb-methodology`, `redteam-mindset` | `/scope` |
| **SCOPE** | `bug-bounty`, `recon-scope-triage` | `/scope`, `/surface` |
| **RECON** | `web2-recon`, `offensive-osint`, `osint-methodology`, `bb-local-toolkit` | `/recon` |
| **WEAPONIZE** | `hunt-dispatch` (auto-router), `security-arsenal` (payloads) | `/hunt --vuln-class <X>` |
| **EXPLOIT** | 58 `hunt-*` skills (per vuln class) | `/hunt`, `/chain` |
| **VERIFY/REFUTE** | `triage-validation` (7-Question Gate), `evidence-hygiene` | `/validate`, `/triage` |
| **REPORT** | `report-writing`, `bugcrowd-reporting`, `redteam-report-template` | `/report` |
| **REFLECT** | `mid-engagement-ir-detection` | `/autopilot --autonomous` |

## Hunt Skills by Vuln Class (58)

### Web Application (Core)
hunt-xss (174 reports) | hunt-sqli (12) | hunt-ssrf (15) | hunt-idor (26) | hunt-rce (67)
hunt-ssti | hunt-csrf (15) | hunt-cors (19) | hunt-xxe (10) | hunt-lfi (31)
hunt-file-upload | hunt-open-redirect (28) | hunt-host-header (16) | hunt-nosqli (14)
hunt-ldap (8) | hunt-html-injection | hunt-clickjacking | hunt-dom (17)

### Auth / Session
hunt-oauth (19) | hunt-jwt-crypto | hunt-saml | hunt-session (18)
hunt-auth-bypass (12) | hunt-brute-force (33) | hunt-mfa-bypass
hunt-forgot-password | hunt-captcha-bypass | hunt-ato

### Business Logic / Race
hunt-business-logic (12) | hunt-race-condition (12) | hunt-exceptional-conditions

### API / Protocol
hunt-graphql (12) | hunt-grpc (6) | hunt-http-smuggling | hunt-websocket (11)
hunt-cache-poison (10) | hunt-api-misconfig | hunt-shadow-api | hunt-spa-api
hunt-fintech-graphql

### Framework-Specific
hunt-springboot (16) | hunt-nodejs (24) | hunt-nextjs (19) | hunt-laravel (14)
hunt-aspnet (1) | hunt-deserialization (22) | hunt-sharepoint (1)

### Infrastructure / Cloud
hunt-k8s (13) | hunt-cloud-misconfig | hunt-subdomain (15) | hunt-tls-network (9)
hunt-cicd (18) | hunt-source-leak (31) | hunt-ntlm-info (1)

### AI / LLM
hunt-llm-ai | hunt-rag-vector

### Enterprise Platform Attack Matrices
m365-entra-attack | okta-attack | vmware-vcenter-attack | enterprise-vpn-attack
supply-chain-attack-recon | cloud-iam-deep | apk-redteam-pipeline | ios-redteam-pipeline

## Disclosed Reports Reference (packs/claude-bughunter/disclosed-reports/)
24 vuln-class compilations with exact H1 report IDs, payout ranges, bypass techniques, and chain templates.

## Engine (packs/claude-bughunter/engine/)
Python modules: agent.py, engine.py, memory.py, osint.py, recon.py, scope.py, skill_map.py, state.py

## OSINT References (packs/claude-bughunter/osint-references/)
15 reference docs: probes-and-wordlists, secret-patterns, secret-validators, dork-corpus, identity-fabric, recon-techniques, breach-and-credentials, saas-public-surfaces, sector-notes, severity-matrix, specialized-osint, tooling-install, helpers-and-automation, people-osint, recon-stack

## Verification Transcripts (packs/claude-bughunter/verification/)
Real engagement transcripts: Juice Shop, Jenkins CVE, Apache CVE, Spring CVE, SSTI/OAuth/FileUpload, SAML/MFA/XXE, JWT/GraphQL/Race, HTTP Smuggling/Cache Poison, LLM/ATO, Cloud/LocalStack, Playwright browser execution, hardened-lab discipline

## How to Use

### From T3MP3ST (primary)
The kill chain runs as before. CBH skills auto-load by topic when Claude detects the vuln class. The `t3-*` subagents remain the orchestrator — CBH skills are the knowledge layer beneath them.

### Direct CBH Commands
```
/hunt target.com                           # auto-detect + hunt
/hunt target.com --vuln-class ssrf         # targeted class
/recon target.com                          # discovery phase
/chain                                     # chain builder (describe bug A)
/validate                                  # 7-Question Gate
/triage                                    # triage + severity
/report                                    # generate report
/autopilot target.com --autonomous         # full autonomous mode
/surface                                   # attack surface analysis
/scope                                     # scope management
/intel                                     # threat intelligence
/token-scan                                # secret/token scanning
/remember                                  # brain persistence
/memory-gc                                 # memory cleanup
/web3-audit                                # smart contract audit
```

### Brain Integration
CBH lessons, payloads, and tools are recorded in T3MP3ST brain:
- `brain.sh recall` pulls CBH-sourced lessons alongside T3MP3ST's own
- Payloads merged into brain/payloads/ (855 new SSRF payloads from OSINT probes)
- 6 key methodology lessons captured from CBH's OOB gates, triage validation, and attribution rules
