# CyberStrike Integration

**Source:** github.com/CyberStrikeus/CyberStrike
**Date:** 2026-08-23
**Type:** AI pentest agent platform (Claude Code skill format)
**Extracted:** Offensive skills only (skipped CIS_benchmarks, NIST, mitre_attack, mitre_attack_ics, mitre_attack_mobile)

## Extracted Skill Categories

| Category | Directory | Files | Description |
|----------|-----------|-------|-------------|
| WEB (OWASP WSTG 4.2) | `WEB/OWASP_WSTG_4.2/` | 125 skills | Full OWASP Web Security Testing Guide — input validation, session, auth, client-side, business logic, API, crypto, error handling, config |
| Attack Playbooks | `attack-*/` | 16 dirs | Focused offensive playbooks with phased methodology + curl PoCs |
| Post-Exploitation | `*-postexploit/` | 7 dirs | AWS, Azure, GCP, K8s, Linux, macOS, Windows post-exploitation guides |
| Specialized Offense | various | 8 dirs | LLM security, Kerberos, eBPF, CI/CD, cloud/K8s assessment, AD security, recon methodology |

### Attack Playbooks (16)

| Skill | Maps to T3MP3ST Phase | CWE |
|-------|-----------------------|-----|
| attack-ssrf | WEAPONIZE / EXPLOIT | CWE-918 |
| attack-jwt | WEAPONIZE / EXPLOIT | CWE-287, CWE-347 |
| attack-cors | WEAPONIZE | CWE-942 |
| attack-ssti | EXPLOIT | CWE-1336 |
| attack-xxe | EXPLOIT | CWE-611 |
| attack-cache-poison | EXPLOIT | CWE-444 |
| attack-host-header | WEAPONIZE / EXPLOIT | CWE-644 |
| attack-idor-automation | EXPLOIT | CWE-639 |
| attack-open-redirect | WEAPONIZE | CWE-601 |
| attack-prototype-pollution | EXPLOIT | CWE-1321 |
| attack-race-condition | EXPLOIT | CWE-362 |
| attack-rate-limit-bypass | WEAPONIZE | CWE-770 |
| attack-request-smuggling | EXPLOIT | CWE-444 |
| attack-subdomain-takeover | RECON / EXPLOIT | CWE-284 |
| attack-websocket | EXPLOIT | CWE-1385 |
| attack-graphql | WEAPONIZE / EXPLOIT | CWE-200 |

### Post-Exploitation (7)

| Skill | Maps to T3MP3ST Phase |
|-------|-----------------------|
| aws-postexploit | POST-EXPLOIT |
| azure-postexploit | POST-EXPLOIT |
| gcp-postexploit | POST-EXPLOIT |
| k8s-postexploit | POST-EXPLOIT |
| linux-postexploit | POST-EXPLOIT |
| macos-postexploit | POST-EXPLOIT |
| windows-postexploit | POST-EXPLOIT |

### Specialized Offense (8)

| Skill | Maps to T3MP3ST Phase |
|-------|-----------------------|
| llm-security | WEAPONIZE / EXPLOIT (frontier-lanes: AI/LLM) |
| kerberos-attacks | EXPLOIT (AD environments) |
| ebpf-attacks | EXPLOIT / POST-EXPLOIT |
| cicd-attacks | EXPLOIT (supply chain) |
| cloud-assessment | RECON / WEAPONIZE |
| k8s-assessment | RECON / WEAPONIZE |
| ad-security | RECON / EXPLOIT (Active Directory) |
| recon-methodology | RECON |

### Standalone Files

- `SKILL_GUIDE.md` — CyberStrike skill authoring guide
- `T1558.003_kerberoasting_DEMO.md` — Kerberoasting attack demo (MITRE ATT&CK T1558.003)

## Skill Format

Each skill uses YAML frontmatter with: `name`, `description`, `category`, `version`, `author`, `tags`, `tech_stack`, `cwe_ids`, `chains_with`, `prerequisites`, `severity_boost`. Body follows phased testing methodology with bash/curl examples. Compatible with T3MP3ST operator dispatch.

## T3MP3ST Pipeline Mapping

| T3MP3ST Phase | CyberStrike Sources |
|---------------|---------------------|
| RECON | `recon-methodology`, `attack-subdomain-takeover`, `cloud-assessment`, `k8s-assessment`, `ad-security` |
| WEAPONIZE | `WEB/OWASP_WSTG_4.2/*` (125 skills), `attack-*` playbooks (16), `llm-security` |
| EXPLOIT | All `attack-*` playbooks, `kerberos-attacks`, `ebpf-attacks`, `cicd-attacks` |
| VERIFY | Skill `chains_with` + `severity_boost` fields enable chain validation |
| POST-EXPLOIT | 7 `*-postexploit` guides (AWS/Azure/GCP/K8s/Linux/macOS/Windows) |
| REPORT | CWE IDs in frontmatter feed SARIF export + STRIDE mapping |

## Total: 156 offensive skills extracted (125 WEB + 16 attack + 7 postexploit + 8 specialized)
