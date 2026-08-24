# PayloadsAllTheThings Index

Source: github.com/swisskyrepo/PayloadsAllTheThings
Archive: packs/payloads-all-the-things/pat-full.tar.gz
Ingested: 2026-08-23

## Vuln-Class Directory Map

| PAT Directory | Description | Hunt Skill / Playbook |
|---|---|---|
| API Key Leaks | API key patterns, secret detection regexes | hunt-info-disclosure |
| Account Takeover | ATO techniques, password reset, session hijack | hunt-ato |
| Brute Force Rate Limit | Rate limiting bypass, credential stuffing | hunt-brute-force |
| Business Logic Errors | Logic flaws, price manipulation, workflow bypass | hunt-business-logic |
| CORS Misconfiguration | Origin reflection, null origin, credentialed CORS | hunt-cors |
| CRLF Injection | Header injection, HTTP response splitting | hunt-misc |
| CSS Injection | CSS exfiltration, data theft via style injection | hunt-misc |
| CSV Injection | Formula injection in spreadsheet exports | hunt-misc |
| CVE Exploits | Known CVE exploit references | hunt-misc |
| Clickjacking | UI redressing, frame-based attacks | hunt-clickjacking |
| Client Side Path Traversal | Client-side path manipulation | hunt-dom |
| Command Injection | OS command injection, shell metachar abuse | hunt-rce |
| Cross-Site Request Forgery | CSRF token bypass, SameSite abuse | hunt-csrf |
| DNS Rebinding | DNS rebinding for SSRF/auth bypass | hunt-ssrf |
| DOM Clobbering | DOM property overwrite via HTML injection | hunt-dom |
| Denial of Service | ReDoS, resource exhaustion, algorithmic complexity | hunt-misc |
| Dependency Confusion | Package manager namespace attacks | hunt-misc |
| Directory Traversal | Path traversal, LFI, file read primitives | hunt-lfi |
| Encoding Transformations | Encoding bypass techniques | hunt-misc |
| External Variable Modification | PHP register_globals, variable override | hunt-misc |
| File Inclusion | LFI/RFI, PHP wrappers, log poisoning | hunt-lfi |
| Google Web Toolkit | GWT deserialization, RPC abuse | hunt-deserialization |
| GraphQL Injection | Introspection, batching, injection in GraphQL | hunt-graphql |
| HTTP Parameter Pollution | Duplicate param abuse, parser differentials | hunt-misc |
| Headless Browser | SSRF/XSS via headless browser services | hunt-ssrf |
| Hidden Parameters | Parameter discovery techniques | hunt-misc |
| Insecure Deserialization | Java/PHP/Python/Ruby/Node deserialization RCE | hunt-deserialization |
| Insecure Direct Object References | IDOR, BOLA, horizontal/vertical access | hunt-idor |
| Insecure Management Interface | Exposed admin panels, debug endpoints | hunt-info-disclosure |
| Insecure Randomness | Predictable tokens, weak PRNG | hunt-session |
| Insecure Source Code Management | .git/.svn/.hg exposure | hunt-source-leak |
| JSON Web Token | JWT alg:none, key confusion, kid injection | hunt-jwt-crypto |
| Java RMI | Java RMI deserialization, registry attacks | hunt-deserialization |
| LDAP Injection | LDAP filter injection, auth bypass | hunt-ldap |
| LaTeX Injection | LaTeX command execution, file read | hunt-rce |
| Mass Assignment | Object property overwrite via API binding | hunt-misc |
| Methodology and Resources | General methodology, wordlists, resources | recon-methodology |
| NoSQL Injection | MongoDB/CouchDB injection, operator abuse | hunt-nosqli |
| OAuth Misconfiguration | OAuth redirect, token theft, PKCE bypass | hunt-oauth |
| ORM Leak | ORM query manipulation, data extraction | hunt-sqli |
| Open Redirect | URL redirect bypass, login flow abuse | hunt-open-redirect |
| Prompt Injection | LLM prompt injection, jailbreak | hunt-llm-ai |
| Prototype Pollution | JS prototype chain pollution, RCE chains | hunt-dom |
| Race Condition | TOCTOU, double-spend, parallel abuse | hunt-race-condition |
| Regular Expression | ReDoS, regex bypass techniques | hunt-misc |
| Request Smuggling | HTTP/1.1 & HTTP/2 smuggling, CL.TE/TE.CL | hunt-http-smuggling |
| Reverse Proxy Misconfigurations | Nginx/Apache path confusion, ACL bypass | hunt-misc |
| SAML Injection | SAML assertion manipulation, XSW attacks | hunt-saml |
| SQL Injection | Union, blind, error-based, time-based SQLi | hunt-sqli |
| Server Side Include Injection | SSI directive injection | hunt-rce |
| Server Side Request Forgery | SSRF to cloud metadata, internal services | hunt-ssrf |
| Server Side Template Injection | Jinja2/Twig/Velocity/Freemarker SSTI to RCE | hunt-ssti |
| Tabnabbing | Reverse tabnabbing via target=_blank | hunt-misc |
| Type Juggling | PHP loose comparison, magic hash | hunt-auth-bypass |
| Upload Insecure Files | Unrestricted upload, webshell, polyglot files | hunt-file-upload |
| Virtual Hosts | VHost enumeration, host header routing | hunt-host-header |
| Web Cache Deception | Cache poisoning, path confusion | hunt-cache-poison |
| Web Sockets | WebSocket hijacking, CSWSH, injection | hunt-websocket |
| XPATH Injection | XPath query injection, auth bypass | hunt-misc |
| XS-Leak | Cross-site information leaks | hunt-dom |
| XSLT Injection | XSLT processor abuse, file read, RCE | hunt-rce |
| XSS Injection | Reflected/stored/DOM XSS, filter bypass, CSP bypass | hunt-xss |
| XXE Injection | XML external entity, OOB XXE, blind XXE | hunt-xxe |
| Zip Slip | Archive path traversal during extraction | hunt-lfi |

## Extracted Payloads

Key payload files extracted to `brain/payloads/`:

| File | Lines | Source PAT Directory |
|---|---|---|
| sqli.txt | 1144 | SQL Injection/Intruder/*.txt |
| xss.txt | 1592 | XSS Injection/Intruders/*.txt |
| ssrf.txt | 1072 | Server Side Request Forgery/*.md |
| ssti.txt | 309 | Server Side Template Injection/Intruder/ssti.fuzz + *.md |
| cmdi.txt | 496 | Command Injection/Intruder/*.txt |
| lfi.txt | 1468 | Directory Traversal/Intruder/*.txt (excl dotdotpwn) |
| xxe.txt | 102 | XXE Injection/Intruders/*.txt |
| nosqli.txt | 27 | NoSQL Injection/Intruder/*.txt |
| ldapi.txt | 59 | LDAP Injection/Intruder/*.txt |
| redirect.txt | 305 | Open Redirect/Intruder/*.txt |

## Loading Payloads On Demand

To load a specific vuln class's full documentation from the archive:

```bash
# Extract a single vuln class
tar xzf packs/payloads-all-the-things/pat-full.tar.gz -C /tmp/pat-extract "SQL Injection/"

# List available classes
tar tzf packs/payloads-all-the-things/pat-full.tar.gz | grep -oP '^\./[^/]+/' | sort -u

# Extract all Intruder payload lists
tar xzf packs/payloads-all-the-things/pat-full.tar.gz -C /tmp/pat-extract --wildcards '*/Intruder*/*.txt' '*/Intruders*/*.txt'

# Read a specific README
tar xzf packs/payloads-all-the-things/pat-full.tar.gz -C /tmp/pat-extract "./Command Injection/README.md"
```
