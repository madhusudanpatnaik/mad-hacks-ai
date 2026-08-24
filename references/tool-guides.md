# Tool Usage Guides

Quick-reference for offensive tools used in the T3MP3ST pipeline. Extracted from Strix tooling skills (Apache-2.0) and T3MP3ST arsenal. Each tool shows: what it does, when to use it, key commands, and common pitfalls.

## HTTP Probing & Discovery

### httpx (ProjectDiscovery)
**Use**: fast HTTP probing, tech fingerprinting, status code filtering
```bash
# Probe a list of hosts
echo "target.com" | httpx -silent -status-code -title -tech-detect -follow-redirects

# Filter for specific status codes
cat hosts.txt | httpx -mc 200,301,302,403 -o alive.txt

# Extract specific headers
echo "target.com" | httpx -silent -H "Cookie: session=abc" -match-string "admin"

# Content discovery with custom wordlist
httpx -l urls.txt -path "/api/v1/users" -mc 200
```
**Pitfalls**: `-follow-redirects` can leave scope; `-rate-limit` to avoid WAF blocks.

### katana (ProjectDiscovery)
**Use**: web crawling, JS parsing, endpoint extraction, form discovery
```bash
# Crawl with headless browser
katana -u https://target.com -jc -d 3 -o endpoints.txt

# JS-only parsing (no active crawling)
katana -u https://target.com -jc -jsluice -d 1 -headless

# Filter for specific patterns
katana -u https://target.com -f "url" -ef "css,png,jpg" -d 5
```
**Pitfalls**: `-d` depth >5 can spiral; use `-ef` to exclude static assets.

---

## Reconnaissance

### subfinder (ProjectDiscovery)
**Use**: passive subdomain enumeration from multiple sources
```bash
# Basic enumeration
subfinder -d target.com -silent -o subs.txt

# With all sources
subfinder -d target.com -all -silent | httpx -silent -o alive-subs.txt

# Multiple domains
subfinder -dL domains.txt -silent -o all-subs.txt
```
**Pitfalls**: needs API keys in `~/.config/subfinder/provider-config.yaml` for full coverage.

### naabu (ProjectDiscovery)
**Use**: fast port scanning, SYN/CONNECT scan, service detection
```bash
# Top 1000 ports
naabu -host target.com -top-ports 1000 -silent

# Full port range on specific host
naabu -host target.com -p - -rate 1000 -silent

# Pipe to httpx for web service discovery
naabu -host target.com -top-ports 1000 -silent | httpx -silent
```
**Pitfalls**: SYN scan needs root; use `-rate` to avoid triggers; `receipt_required` in T3MP3ST.

### nmap
**Use**: detailed port/service scanning, version detection, script scanning
```bash
# Service version detection
nmap -sV -sC -oA scan target.com

# Specific ports with scripts
nmap -p 80,443,8080 -sV --script=http-enum,http-headers target.com

# UDP scan (slow, targeted)
nmap -sU -p 53,161,500 target.com
```
**Pitfalls**: `receipt_required` — always confirm scope before scanning. UDP is slow; target specific ports.

---

## Fuzzing & Content Discovery

### ffuf (Fast web fuzzer)
**Use**: directory/file discovery, parameter fuzzing, virtual host discovery
```bash
# Directory discovery
ffuf -u https://target.com/FUZZ -w wordlist.txt -mc 200,301,302,403

# Parameter fuzzing
ffuf -u "https://target.com/api?FUZZ=value" -w params.txt -mc 200

# POST data fuzzing
ffuf -u https://target.com/login -X POST -d "user=admin&pass=FUZZ" -w passwords.txt

# Virtual host discovery
ffuf -u https://target.com -H "Host: FUZZ.target.com" -w subs.txt -fs 4242

# Rate-limited fuzzing
ffuf -u https://target.com/FUZZ -w wordlist.txt -rate 50 -mc 200
```
**Pitfalls**: `-fs` to filter by size; `-fc` to filter by status; `-rate` to avoid WAF; `receipt_required`.

---

## Vulnerability Scanning

### nuclei (ProjectDiscovery)
**Use**: template-based vulnerability scanning, CVE detection, misconfig checks
```bash
# Default templates
nuclei -u https://target.com -o results.txt

# Specific templates/tags
nuclei -u https://target.com -t cves/ -severity critical,high
nuclei -u https://target.com -tags oast,ssrf,redirect

# Multiple targets
nuclei -l urls.txt -t exposures/ -o exposed.txt

# Custom template
nuclei -u https://target.com -t custom-template.yaml

# Rate limited
nuclei -u https://target.com -rl 50 -c 10
```
**Pitfalls**: `-rl` for rate limiting; `-severity` to focus; some templates are intrusive — `receipt_required`.

### semgrep
**Use**: static analysis (SAST), pattern matching, taint tracking
```bash
# Auto-detect language and run default rules
semgrep --config auto /path/to/code

# Security-focused rules
semgrep --config "p/security-audit" /path/to/code

# Specific language
semgrep --config "p/python" /path/to/code

# Custom rule
semgrep --config custom-rule.yaml /path/to/code -o results.json --json

# OWASP rules
semgrep --config "p/owasp-top-ten" /path/to/code
```
**Pitfalls**: `--config auto` is noisy; use focused rulesets. Large repos: `--max-target-bytes` and `--timeout`.

---

## SQL Injection

### sqlmap
**Use**: automated SQL injection detection and exploitation
```bash
# Test a URL parameter
sqlmap -u "https://target.com/page?id=1" --batch --level 3 --risk 2

# Test POST data
sqlmap -u "https://target.com/login" --data "user=admin&pass=test" --batch

# With authentication
sqlmap -u "https://target.com/api?id=1" --cookie "session=abc" --batch

# Database enumeration (after confirmed injection)
sqlmap -u "https://target.com/page?id=1" --dbs --batch
sqlmap -u "https://target.com/page?id=1" -D dbname --tables --batch

# Tamper scripts for WAF bypass
sqlmap -u "https://target.com/page?id=1" --tamper=space2comment,between --batch
```
**Pitfalls**: `--batch` for non-interactive; `--level 3 --risk 2` for thorough; `receipt_required`. Never `--os-shell` or `--os-pwn` without explicit authorization.

---

## HTTP Testing

### hurl (HTTP testing DSL)
**Use**: declarative HTTP request sequences, API testing, assertion chains
```hurl
# Simple GET with assertions
GET https://target.com/api/users
HTTP 200
[Asserts]
header "Content-Type" contains "json"
jsonpath "$.users" count > 0

# POST with body
POST https://target.com/api/login
Content-Type: application/json
{"username": "admin", "password": "test"}
HTTP 200
[Captures]
token: jsonpath "$.token"

# Use captured token
GET https://target.com/api/admin
Authorization: Bearer {{token}}
HTTP 403
```
**Pitfalls**: great for reproducible test sequences; less flexible than curl for ad-hoc probing.

### hypothesis (Python property-based testing)
**Use**: fuzz testing with intelligent input generation, edge-case discovery
```python
from hypothesis import given, strategies as st

@given(st.text(min_size=1, max_size=1000))
def test_input_handling(user_input):
    response = send_request(user_input)
    assert response.status_code != 500
    assert "stack trace" not in response.text.lower()

@given(st.integers(min_value=-2**31, max_value=2**31))
def test_numeric_params(value):
    response = api_call(id=value)
    assert response.status_code in (200, 400, 404)
```
**Pitfalls**: generates many requests; use `@settings(max_examples=100)` to bound.

---

## Pipeline Mapping

| T3MP3ST Phase | Primary Tools | Secondary |
|---------------|--------------|-----------|
| **RECON** | subfinder, httpx, naabu, katana | nmap (receipt_required) |
| **WEAPONIZE** | nuclei, semgrep, ffuf | web-scan.sh |
| **EXPLOIT** | sqlmap, hurl, curl, Burp MCP | hypothesis |
| **VERIFY** | httpx, curl, Burp MCP | browser (for client-side) |
| **REPORT** | sarif-export.py, report.sh | — |
