# Operators & Kill Chain

8 operator archetypes across a 7-phase kill chain (from `src/operators/index.ts`). You embody whichever the current phase needs. MITRE ATT&CK tactics/techniques included for reporting.

## Kill-chain order
`RECON → WEAPONIZE → DELIVER → EXPLOIT → INSTALL → C2 → ACTIONS`

| Phase | Meaning |
|-------|---------|
| RECON | Gather intelligence about the target |
| WEAPONIZE | Prepare exploits & payloads (scan → pick) |
| DELIVER | Deliver exploit to target |
| EXPLOIT | Trigger the vulnerability |
| INSTALL | Establish foothold / lateral (usually out of scope) |
| C2 | Command & control / coordination (usually out of scope) |
| ACTIONS | Objectives on target: prove impact, then analyze & report |

## The 8 operators

### 1. Reconnaissance Operator — phase RECON — TA0043
OSINT, network discovery, asset enumeration. Posture: passive first, then active with a receipt.
Tools: `dns_lookup reverse_dns whois_lookup subdomain_enum subdomain_takeover_check nmap_scan port_scan network_trace version_detect robots_txt_fetch cidr_expand technology_detect http_request curl_request header_analysis api_endpoint_discovery`
Techniques: T1595 T1592 T1589 T1590 T1591

### 2. Vulnerability Scanner — phase WEAPONIZE — TA0007
Find vulns & misconfigs. Map the surface, don't fire blind.
Tools: `nuclei_scan ssl_scan cors_check csp_analysis clickjacking_test cookie_analysis http_methods_test open_redirect_test port_scan version_detect technology_detect api_endpoint_discovery header_analysis`
Techniques: T1046 T1082 T1083 T1087

### 3. Exploitation Specialist — phases DELIVER + EXPLOIT — TA0001/TA0002
Execute exploits, achieve initial access. One reversible probe at a time; `receipt_required` tools need user OK.
Tools: `sqli_scan xss_scan ssti_test lfi_test open_redirect_test nuclei_scan ffuf_fuzz dir_bruteforce api_endpoint_discovery http_methods_test password_spray hash_crack base64_decode url_encode jwt_decode`
Techniques: T1190 T1133 T1078 T1059

### 4. Lateral Movement Specialist — phase INSTALL — TA0008/TA0004
Priv-esc, lateral movement, credential access. **Confirm this is in scope — most engagements stop before here.**
Tools: `hash_crack password_spray jwt_decode cookie_analysis network_trace nmap_scan sqli_scan lfi_test cve_lookup`
Techniques: T1021 T1078 T1068 T1548

### 5. Data Exfiltration Specialist — phase ACTIONS — TA0009/TA0010
Prove data access **minimally** to demonstrate impact, then stop. Never bulk-extract real data.
Tools: `http_request curl_request api_endpoint_discovery dir_bruteforce jwt_decode cookie_analysis lfi_test sqli_scan cve_lookup`
Techniques: T1041 T1048 T1567 T1560

### 6. Persistence Specialist (Ghost) — phases INSTALL + C2 — TA0003/TA0005
Persistence, evasion, cleanup. **Almost always out of scope for authorized testing** — reference only unless explicitly contracted.
Techniques: T1547 T1053 T1136 T1070

### 7. Mission Coordinator — phase C2 — TA0011
Orchestration, task management, decisions. In solo-operator mode this is *you* sequencing the phases and keeping the map.

### 8. Security Analyst — phase ACTIONS — (reporting)
Analyze findings, assess risk, write the report. Every finding → confidence, evidence IDs, remediation, retest criteria. See `report-template.md`.

## Phase → operator map
- RECON → recon
- WEAPONIZE → scanner, exploiter
- DELIVER/EXPLOIT → exploiter
- INSTALL → infiltrator, ghost
- C2 → coordinator, ghost
- ACTIONS → exfiltrator, analyst

## White-box / non-web missions
The same doctrine applies to source review, IaC, mobile, and binaries — swap the arsenal category (see `arsenal.md`): `semgrep/gitleaks/trufflehog/osv-scanner` for code, `checkov/trivy/prowler` for cloud, `apktool/jadx/mobsfscan` for mobile, `r2/ghidra/checksec/binwalk` for binaries. Recon becomes "map the codebase / manifest / IaC"; exploit becomes "prove the sink is reachable with a PoC."
