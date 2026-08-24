# Hunt-class index (from claude-bughunter)

Reference library at: `~/.claude/skills/mad-hacks/references/claude-bughunter/`

**Slash commands** (namespaced): `/cbh:autopilot`, `/cbh:chain`, `/cbh:hunt`, `/cbh:intel`, `/cbh:memory-gc`, `/cbh:pickup`, `/cbh:recon`, `/cbh:remember`, `/cbh:report`, `/cbh:scope`, `/cbh:surface`, `/cbh:token-scan`, `/cbh:triage`, `/cbh:validate`, `/cbh:web3-audit`

## 58 hunt-* skills

| Skill | Description (from SKILL.md) | Disclosed-report library |
|---|---|---|
| `hunt-api-misconfig` | Hunt API security misconfiguration — mass assignment, prototype pollution, HTTP verb tampering. Mass assignment: send {is_admin:true, role:admin, verified:tru | — |
| `hunt-aspnet` | Hunt ASP.NET-specific surface — ViewState deserialization (signed-only vs encrypted), machineKey recovery, dual-parser MAC-bypass anti-pattern, request-valida | — |
| `hunt-ato` | Hunt account takeover taxonomy — 9 distinct paths to ATO, plus chains. Paths: (1) password reset flaws (host-header injection redirects token, predictable/num | — |
| `hunt-auth-bypass` | Hunting skill for auth bypass vulnerabilities. Built from 12 public bug bounty reports across SAML XSW / parser-differential (GitHub Enterprise CVE-2025-25291/2 | — |
| `hunt-brute-force` | Hunt Missing/Weak Rate Limiting — login brute force, OTP/2FA brute force (10^6 keyspace), password-reset-token brute, credential stuffing, username/email enum | `docs/disclosed-reports/hunt-brute-force.md` |
| `hunt-business-logic` | Hunting skill for business logic vulnerabilities. Built from 12 public bug bounty reports. Covers coupon-race-stacking (Instacart, Stripe, Reverb), negative-qua | `docs/disclosed-reports/hunt-business-logic.md` |
| `hunt-cache-poison` | Hunting skill for cache poison vulnerabilities. Built from 10 public bug bounty reports including X-Forwarded-Host poisoning, X-HTTP-Method-Override / GCS cache | `docs/disclosed-reports/hunt-cache-poison.md` |
| `hunt-captcha-bypass` | Hunt CAPTCHA Bypass — 6 distinct patterns: (1) CAPTCHA field simply omitted from the request (server-side validation absent), (2) CAPTCHA token replayed from  | — |
| `hunt-cicd` | Hunt CI/CD pipeline vulnerabilities — GitHub Actions workflow injection (pull_request_target Pwnrequest + ${{ }}-into-shell), self-hosted runner poisoning, OI | — |
| `hunt-clickjacking` | Hunt Clickjacking — missing X-Frame-Options / CSP frame-ancestors lets an attacker embed the target page in an invisible iframe and trick victims into clickin | — |
| `hunt-cloud-misconfig` | Hunt cloud / infrastructure misconfigurations. AWS: public S3 buckets (s3:GetObject anonymous), permissive bucket policies (PutObjectAcl public-write), exposed  | — |
| `hunt-cors` | Hunt CORS Misconfiguration — origin-reflection with credentials, null-origin trust, subdomain-regex bypass (unanchored vs unescaped-dot vs prefix-only), pre-f | `docs/disclosed-reports/hunt-cors.md` |
| `hunt-csrf` | Hunting skill for csrf vulnerabilities. Built from 15 public bug bounty reports including modern variants — SameSite=Lax sibling-subdomain bypass (Argo CD CVE | `docs/disclosed-reports/hunt-csrf.md` |
| `hunt-deserialization` | Hunt Insecure Deserialization — Java gadget chains (ysoserial), PHP object injection (phpggc), Python pickle RCE, .NET BinaryFormatter, Ruby Marshal.load, JND | `docs/disclosed-reports/hunt-deserialization.md` |
| `hunt-dispatch` | Skill-set loader for /hunt orchestrator. Fingerprints the target, picks the right platform attack skills, and loads the Red Team or WAPT skill set. Use when /hu | — |
| `hunt-dom` | Hunt client-side DOM vulnerabilities — DOM Clobbering (overwrite JS globals via HTML injection), PostMessage hijacking (missing origin check), Service Worker  | — |
| `hunt-exceptional-conditions` | Hunt mishandling of exceptional conditions — feed an endpoint malformed/unexpected input (wrong type, broken JSON, oversized field, null byte) and make it fai | — |
| `hunt-file-upload` | Hunt file upload bugs — RCE via webshell, XSS via SVG/HTML, SSRF via XXE in DOCX, path traversal via filename. Bypass tables (10 techniques): double extension | `docs/disclosed-reports/hunt-file-upload.md` |
| `hunt-fintech-graphql` | Hunt fintech-specific GraphQL vulnerabilities: money-movement mutations (transfers, redemptions, withdrawals, card top-ups), ledger/balance/portfolio query IDOR | — |
| `hunt-forgot-password` | Hunt Forgot Password / Account Recovery Authentication Flaws — 5 distinct patterns: (1) username enumeration via different responses for valid vs invalid emai | — |
| `hunt-graphql` | Hunting skill for graphql vulnerabilities. Built from 12 public bug bounty reports across IDOR via node() / GID, mutation IDOR including AI/LLM features, cross- | `docs/disclosed-reports/hunt-graphql.md` |
| `hunt-grpc` | Hunt gRPC vulnerabilities — server reflection enabled (enumerate all services/methods), missing authentication / metadata-stripping on internal endpoints, pla | — |
| `hunt-host-header` | Hunt Host Header Injection — password reset poisoning → ATO, web cache poisoning via unkeyed Host/X-Forwarded-Host, routing-based SSRF (Host picks upstream  | `docs/disclosed-reports/hunt-host-header.md` |
| `hunt-html-injection` | Hunt HTML Injection — user-supplied input is rendered as raw HTML in the response without sanitisation, allowing an attacker to inject arbitrary HTML tags (bu | — |
| `hunt-http-smuggling` | Hunt HTTP request smuggling (CL.TE, TE.CL, H2.CL, H2.TE). Cause: front-end proxy and back-end server disagree on where one request ends and the next begins (Con | `docs/disclosed-reports/hunt-http-smuggling.md` |
| `hunt-idor` | Hunting skill for idor vulnerabilities. Built from 26 public bug bounty reports. Use when hunting idor on any target. | `docs/disclosed-reports/hunt-idor.md` |
| `hunt-jwt-crypto` | Hunt JWT cryptographic failures — alg:none signature-stripping and RS256→HS256 key-confusion that let an attacker forge a token for any identity (e.g. an ad | — |
| `hunt-k8s` | Hunt Kubernetes & Docker — API anonymous access, kubelet 10250 exec (SPDY/WebSocket, NOT plain POST) and the simpler /run primitive, etcd 2379 unauth, dashboa | — |
| `hunt-laravel` | Hunt Laravel specific vulnerabilities — Debug mode leakage (APP_DEBUG=true exposes full stack trace + env vars), Laravel Telescope/Horizon dashboard unauthori | — |
| `hunt-ldap` | Hunt LDAP Injection and XPath Injection — authentication bypass, blind char-by-char attribute exfiltration, AD user/group enumeration, XML-store XPath bypass. | `docs/disclosed-reports/hunt-ldap.md` |
| `hunt-lfi` | Hunt Local File Inclusion (LFI), Remote File Inclusion (RFI), and Path Traversal — /etc/passwd read, log poisoning → RCE, PHP filter-chain RCE (no upload ne | `docs/disclosed-reports/hunt-lfi.md` |
| `hunt-llm-ai` | Hunt LLM/AI feature bugs — prompt injection, indirect injection, exfiltration via tool-use/markdown, ASCII smuggling, agentic AI security (OWASP Agentic Apps  | — |
| `hunt-mfa-bypass` | Hunt MFA / 2FA bypass — 7 distinct patterns. (1) MFA not enforced on sensitive endpoints (password change, email change accept without MFA challenge), (2) MFA | `docs/disclosed-reports/hunt-mfa-bypass.md` |
| `hunt-misc` | Hunting skill for misc vulnerabilities. Built from 225 public bug bounty reports. Use when hunting misc on any target. | — |
| `hunt-nextjs` | Hunt Next.js specific vulnerabilities — Server Actions arbitrary function execution, Middleware auth bypass via static asset paths, ISR cache poisoning, Image | — |
| `hunt-nodejs` | Hunt Node.js specific vulnerabilities — Prototype Pollution → RCE chains (lodash/merge/assign), Express trust proxy misconfiguration, child_process/eval inj | — |
| `hunt-nosqli` | Hunt NoSQL Injection — MongoDB operator injection ($where, $regex, $gt, $ne), CouchDB, Redis command injection, auth bypass via NoSQLi, data dump. Use when ta | `docs/disclosed-reports/hunt-nosqli.md` |
| `hunt-ntlm-info` | Hunt NTLM/Negotiate information disclosure on internet-reachable IIS/SharePoint/Exchange. Anonymous NTLM Type-2 challenge capture leaks NetBIOS domain, internal | — |
| `hunt-oauth` | Hunting skill for oauth vulnerabilities. Built from 19 public bug bounty reports. Use when hunting oauth on any target. | `docs/disclosed-reports/hunt-oauth.md` |
| `hunt-open-redirect` | Hunt Open Redirect — all types including low-impact, chained to OAuth token theft → ATO, phishing chains. URL parameter manipulation, JavaScript redirect, m | `docs/disclosed-reports/hunt-open-redirect.md` |
| `hunt-race-condition` | Hunting skill for race condition vulnerabilities. Built from 12 public bug bounty reports including modern HTTP/2 single-packet attack cases (James Kettle DEF C | — |
| `hunt-rag-vector` | Hunt vector-store / embedding-layer weaknesses in RAG pipelines (OWASP LLM08 Vector and Embedding Weaknesses) — persistent corpus poisoning that survives acro | — |
| `hunt-rce` | Hunting skill for rce vulnerabilities. Built from 67 public bug bounty reports. Use when hunting rce on any target. | `docs/disclosed-reports/hunt-rce.md` |
| `hunt-saml` | Hunt SAML / SSO attacks. Patterns: XML Signature Wrapping (XSW) — modify Assertion while keeping Signature valid by relocating signed element, comment injecti | `docs/disclosed-reports/hunt-saml.md` |
| `hunt-session` | Hunt Session Management vulnerabilities — session fixation (no regeneration on login), insufficient invalidation on logout / password-change / email-change, p | `docs/disclosed-reports/hunt-session.md` |
| `hunt-shadow-api` | Hunt shadow / zombie / undocumented API surface (OWASP API9 Improper Inventory Management) — enumerate the full API version history (v1/v2/beta/legacy paths,  | — |
| `hunt-sharepoint` | Hunt Microsoft SharePoint Server (2013/2016/2019/Subscription Edition) on-prem farms — anonymous endpoint enumeration, version disclosure, legacy SOAP login b | — |
| `hunt-source-leak` | Hunt source code and build artifact leakage — JavaScript source maps (.js.map) reconstructing TypeScript/ES6 source, Swagger/OpenAPI JSON endpoint discovery,  | — |
| `hunt-spa-api` | Discover a single-page-app's hidden backend API from its public JS bundle, then test that API for broken access control / missing authentication. One of the hig | — |
| `hunt-springboot` | Hunt Spring Boot specific vulnerabilities — Actuator endpoints (heapdump, env, loggers, mappings, shutdown), Spring Expression Language (SpEL) injection → R | — |
| `hunt-sqli` | Hunting skill for sqli vulnerabilities. Built from 12 public bug bounty reports including modern NoSQL injection (Rocket.Chat CVE-2021-22911 MongoDB $regex, Mon | `docs/disclosed-reports/hunt-sqli.md` |
| `hunt-ssrf` | Hunting skill for ssrf vulnerabilities. Built from 15 public bug bounty reports including AWS metadata SSRF (HackerOne $25k Analytics PDF, Shopify Exchange $25k | `docs/disclosed-reports/hunt-ssrf.md` |
| `hunt-ssti` | Hunt server-side template injection (SSTI) across Jinja2 (Flask/Django), Twig (Symfony), Freemarker (Java), ERB (Rails), Spring, Velocity, Mako, Thymeleaf, Smar | `docs/disclosed-reports/hunt-ssti.md` |
| `hunt-subdomain` | Hunting skill for subdomain takeover vulnerabilities. Includes modern provider fingerprints — Microsoft Azure DevOps `cloudapp.azure.com` regional-pool re-iss | — |
| `hunt-tls-network` | Hunt TLS/SSL and DNS misconfigurations — missing HSTS (downgrade attack), weak cipher suites, expired/invalid certificates, mTLS bypass, missing SPF/DKIM/DMAR | — |
| `hunt-websocket` | Hunt WebSocket vulnerabilities — Cross-Site WebSocket Hijacking (CSWSH), missing/weak Origin validation on the WS handshake, no per-message authentication, me | — |
| `hunt-xss` | Hunting skill for xss vulnerabilities. Built from 174 public bug bounty reports. Use when hunting xss on any target. For markup injection that reflects raw HTML | `docs/disclosed-reports/hunt-xss.md` |
| `hunt-xxe` | Hunting skill for xxe vulnerabilities. Built from 10 public bug bounty reports including SVG-upload XXE, Office-doc (PPTX/DOCX) XXE, SOAP XXE, SAML AssertionCon | — |

## 25 supporting skills

| Skill | Description |
|---|---|
| `apk-redteam-pipeline` | End-to-end Android APK red-team pipeline — automated APK acquisition (Play Store + apkpure + apkmirror fallback), jadx decompilation, secret/URL/JWT/Firebase  |
| `bb-local-toolkit` | Local-tooling companion to the bug-bounty orchestrator — carries the SAME complete bug-bounty workflow, but reach for THIS variant when you also need to resol |
| `bb-methodology` | Use at the START of any bug bounty hunting session, when switching targets, or when feeling lost about what to do next. Master orchestrator that combines the 5- |
| `bug-bounty` | Complete bug bounty workflow — recon (subdomain enumeration, asset discovery, fingerprinting, HackerOne scope, source code audit), pre-hunt learning (disclose |
| `bugcrowd-reporting` | Bugcrowd-specific reporting tactics complementing report-writing: VRT category search-and-fallback strategy when no exact match exists, manual severity override |
| `cloud-iam-deep` | Cloud IAM red-team attack chain across AWS, Azure, GCP — focused on EXTERNAL exploitation paths and post-credential-discovery privilege analysis. Covers IAM e |
| `enterprise-vpn-attack` | External SSL VPN / remote-access appliance attack matrix — Cisco ASA/AnyConnect, Fortinet FortiGate/FortiOS, Citrix NetScaler/ADC, Palo Alto GlobalProtect, Pu |
| `evidence-hygiene` | Evidence-capture and PoC-redaction discipline for bug-bounty submissions: cookie redaction protocol (which fields to mask, Preview annotation / Burp panel hidin |
| `ios-redteam-pipeline` | End-to-end iOS red-team pipeline — IPA acquisition (App Store extraction, TestFlight, enterprise/ad-hoc sideload), class-dump/Hopper/Ghidra static analysis, I |
| `m365-entra-attack` | Microsoft 365 / Entra ID red-team attack chain — current 2026 reality. AADSTS code reference, user enumeration vectors (with hardening status), Smart Lockout  |
| `meme-coin-audit` | Meme coin and token security audit — rug pull detection (honeypot, hidden mint, fee manipulation, LP lock bypass), Solana SPL token analysis (freeze authority |
| `mid-engagement-ir-detection` | Methodology for detecting client SOC patches, attacker activity, and security-state changes that occur DURING a red-team engagement — and converting those obs |
| `offensive-osint` | Operational arsenal for authorized external red-team and bug-bounty recon. Concrete probes, wordlists, regexes, dorks, curl one-liners for: subdomain enum, Grap |
| `okta-attack` | Okta-as-IdP red-team attack chain — tenant discovery, user enumeration (multiple vectors), authentication flow analysis (factors enumeration, push-notificatio |
| `osint-methodology` | Comprehensive OSINT methodology for external red-team operations and authorized attack-surface assessments. Covers the 5-stage recon pipeline (seed discovery, a |
| `recon-scope-triage` | Triage ASM/recon output for ownership before testing — separate the target's real assets from namespace-collision noise. Automated recon keyword-matches on th |
| `redteam-mindset` | Red-team operator discipline — the mindset corrections that separate offensive testing from defensive WAPT. Built from authorized red-team work where conserva |
| `redteam-report-template` | Client-facing red-team deliverable format — codifies the Subject / Observations / Description / Impact / Recommendation / PoC structure used for external red- |
| `report-writing` | Bug bounty report writing for H1/Bugcrowd/Intigriti/Immunefi — report templates, human tone guidelines, impact-first writing, CVSS 3.1 scoring, title formula, |
| `security-arsenal` | Security payloads, bypass tables, wordlists, gf pattern names, always-rejected bug list, and conditionally-valid-with-chain table. Use when you need specific pa |
| `supply-chain-attack-recon` | External recon for software supply-chain attack surface — package-namespace squatting candidates, dependency-confusion vulnerabilities, GitHub Actions injecti |
| `triage-validation` | Finding validation before writing any report — 7-Question Gate (all 7 questions), 4 pre-submission gates, always-rejected list, conditionally valid with chain |
| `vmware-vcenter-attack` | VMware vSphere / vCenter Server external attack matrix — version fingerprinting, the high-impact CVE chain (CVE-2021-21972 vRealize unauth file upload, CVE-20 |
| `web2-recon` | Web2 recon pipeline — subdomain enumeration (subfinder, Chaos API, assetfinder), live host discovery (dnsx, httpx), URL crawling (katana, waybackurls, gau), d |
| `web3-audit` | Smart contract security audit — 10 DeFi bug classes (accounting desync, access control, incomplete path, off-by-one, oracle, ERC4626, reentrancy, flash loan,  |

## Extracted probes per class (populated by ingest 2026-08-21)

- `brain/payloads/api-endpoints.txt` — 298 probes
- `brain/payloads/brute-force.txt` — 32 probes
- `brain/payloads/business-logic.txt` — 14 probes
- `brain/payloads/cache-poison.txt` — 38 probes
- `brain/payloads/content-discovery.txt` — 4750 probes
- `brain/payloads/cors.txt` — 35 probes
- `brain/payloads/csrf.txt` — 34 probes
- `brain/payloads/deserialization.txt` — 17 probes
- `brain/payloads/file-upload.txt` — 40 probes
- `brain/payloads/graphql.txt` — 53 probes
- `brain/payloads/host-header.txt` — 19 probes
- `brain/payloads/http-smuggling.txt` — 6 probes
- `brain/payloads/idor.txt` — 45 probes
- `brain/payloads/ldap.txt` — 14 probes
- `brain/payloads/lfi.txt` — 32 probes
- `brain/payloads/mfa-bypass.txt` — 28 probes
- `brain/payloads/nosqli.txt` — 26 probes
- `brain/payloads/oauth.txt` — 23 probes
- `brain/payloads/open-redirect.txt` — 33 probes
- `brain/payloads/params.txt` — 6453 probes
- `brain/payloads/rce.txt` — 61 probes
- `brain/payloads/saml.txt` — 35 probes
- `brain/payloads/sensitive-files.txt` — 109 probes
- `brain/payloads/session.txt` — 17 probes
- `brain/payloads/sqli.txt` — 67 probes
- `brain/payloads/ssrf.txt` — 46 probes
- `brain/payloads/ssti.txt` — 72 probes
- `brain/payloads/xss-waf-bypass.txt` — 84 probes
- `brain/payloads/xss.txt` — 36 probes
