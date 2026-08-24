# Arsenal

Two layers: **built-in primitives** (T3MP3ST implemented these in JS; in skill mode you do them with real system tools) and **external adapters** (73, run the named binary). Always check the execution mode before running. `scripts/preflight.sh` reports which binaries are actually installed.

## Execution modes
- `safe_command` — run directly, in scope.
- `receipt_required` — active/intrusive; **get explicit user confirmation of scope for this target first.**
- `catalog_only` / `import_only` — **do not execute in skill mode.** Reference only; hand to the user.

## Risk ladder
`local_read` < `passive` < `active` < `intrusive` < `credential` < `dangerous`. Escalate only with evidence + authorization.

---

## Built-in primitives → how to run them here
| Primitive | Real-tool equivalent |
|-----------|----------------------|
| dns_lookup / reverse_dns | `dig +short <h> ANY`, `dig -x <ip>` |
| whois_lookup | `whois <domain>` |
| subdomain_enum | `subfinder -d <d> -silent` (or cert-transparency via curl to crt.sh) |
| subdomain_takeover_check | resolve CNAME + fingerprint dangling target |
| http_request / curl_request | `curl -sSik <url>` |
| header_analysis | `curl -sI <url>` → inspect security headers |
| technology_detect / version_detect | `whatweb`, `httpx -tech-detect`, banner from `curl -I` |
| robots_txt_fetch | `curl -s <url>/robots.txt` |
| api_endpoint_discovery / content_discovery | `katana`, `ffuf`, `gobuster`, waybackurls |
| port_scan / nmap_scan | `nmap -sV --top-ports 100 --open <h>` |
| ssl_scan | `testssl.sh <host:443>` or `openssl s_client` |
| cors_check / csp_analysis / cookie_analysis / clickjacking_test / http_methods_test | crafted `curl` requests + header inspection |
| nuclei_scan | `nuclei -u <url> -severity medium,high,critical -jsonl` |
| sqli_scan / xss_scan / ssti_test / lfi_test / open_redirect_test | manual payloads via curl; escalate to `sqlmap`/`dalfox` (receipt) |
| jwt_decode / base64_decode / url_encode | local decode (no network) |
| hash_crack | `john`/`hashcat` (credential, receipt) |
| cve_lookup | search NVD/OSV for detected version |

## External adapters (73)

### core / local_read (safe)
`file`

### osint — passive
whois `[receipt]`, subfinder `[receipt]`, amass `[receipt]`, waybackurls `[safe]`

### dns — passive
dig `[receipt]`, host `[receipt]`, dnsx `[safe]`

### network — active `[receipt_required]`
nmap `-sV --top-ports 100 --open`, naabu `-top-ports 100`

### web — active `[receipt_required]` (sqlmap = intrusive; wafw00f = safe/passive)
curl, httpx, katana, ffuf, gobuster, feroxbuster, nikto, dalfox, sqlmap, whatweb, wafw00f `[safe]`

### vulnerability — active `[receipt_required]`
nuclei `-u <url> -severity medium,high,critical -jsonl`

### supply_chain — local_read (safe)
semgrep `scan --config auto --json .`, syft, grype, osv-scanner

### secrets — local_read (safe)
gitleaks `detect --source . --redact`, trufflehog `filesystem . --json`

### cloud — mostly active `[receipt_required]` (checkov = safe; pacu = catalog_only)
checkov `[safe]`, prowler, scout, cloudfox, pmapper, aws/az/gcloud (read enum), **pacu `[catalog_only]`**

### container — local_read (safe)
trivy `fs --format json .`

### smart_contract — local_read (safe; cast = active)
slither, myth, echidna, forge, solhint, cast `[receipt]`

### crypto — local_read/active
openssl `[safe]`, testssl.sh `[safe]`, john `[credential/receipt]`, hashcat `[credential/receipt]`

### fuzzing — local_read (safe)
radamsa, afl-fuzz

### mobile — local_read (safe; objection/drozer intrusive; frida catalog_only)
apktool, jadx, apkleaks, mobsfscan, class-dump, objection `[receipt]`, drozer `[receipt]`, **frida `[catalog_only]`**

### reverse — local_read (safe; gdb active)
r2, ghidra(analyzeHeadless), objdump, checksec, strings, readelf, binwalk, gdb `[receipt]`

### forensics — local_read (safe)
exiftool, yara

### credentials / post_exploitation — DO NOT RUN in skill mode
hydra `[catalog_only]`, bloodhound `[import_only]`, msfconsole `[catalog_only]`

---

## Install hints
Most Go/PDTM tools: `go install` or the ProjectDiscovery installer. Python tools: `pipx install`. Homebrew covers many (`brew install nmap nuclei semgrep gitleaks trufflehog ...`). `scripts/preflight.sh` prints exactly what's present vs missing on this box so you never fake a run against a tool you don't have.
