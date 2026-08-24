# Knowledge Packs — authoritative references to ground findings

T3MP3ST's 14 `RESOURCE_PACKS`: standards/catalogs you cite to make findings credible and prioritized. Pull the ones your mission family recommends (see `mission-families.md`). Use them to name the weakness (CWE/CAPEC), map the tactic (ATT&CK/ATLAS), and prioritize (KEV/EPSS).

| Pack | What it is | Pull it when |
|------|-----------|--------------|
| **owasp-wstg** | OWASP Web Security Testing Guide | web_api — methodology + test IDs for each check |
| **owasp-api-top10-2023** | OWASP API Security Top 10 | API targets — BOLA, broken auth, mass assignment, etc. |
| **owasp-llm-top10** | OWASP Top 10 for LLM Applications | ai_red_team — name LLM01–LLM10 in findings |
| **mitre-attack-enterprise** | MITRE ATT&CK Enterprise | map every action to a tactic/technique (Txxxx) |
| **mitre-atlas** | MITRE ATLAS (adversarial AI) | ai_red_team / agent_warfare tactic mapping |
| **cwe-top25-2025** | CWE Top 25 weaknesses | assign a CWE to each finding; prioritize |
| **capec** | CAPEC attack patterns | describe the attack mechanism precisely |
| **cisa-kev** | CISA Known-Exploited-Vulns catalog | is this CVE actively exploited? → severity bump |
| **first-epss** | FIRST EPSS exploit-probability API | prioritize CVEs by likelihood of exploitation |
| **nvd-cve-api** | NVD CVE API 2.0 | look up CVE detail/CVSS for a detected version |
| **cve-list-v5** | Official CVE List v5 | canonical CVE records |
| **openssf-scorecard** | OpenSSF Scorecard | code_supply_chain — repo security posture |
| **slsa-framework** | SLSA supply-chain levels | code_supply_chain — build/release trust gaps |
| **nist-ai-rmf** | NIST AI Risk Management Framework | ai_red_team — governance/defensive framing |

## Prioritization formula (reporting_remediation)
Rank findings by: **KEV membership** (actively exploited → top) → **EPSS score** (exploit probability) → **CVSS/impact** → **CWE-Top-25 presence** → **asset value / blast radius**. Cite the pack for each factor so the ranking is defensible, not vibes.

## How to actually pull them here
No server/API keys needed for the open catalogs: query via `curl` (NVD API, EPSS API, crt.sh) or reference the offline standard by ID (OWASP WSTG test IDs, CWE numbers, ATT&CK technique IDs, CAPEC IDs). Redact any secrets encountered; never send target data to third-party endpoints not named in scope.
