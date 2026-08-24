# Cognition, Reasoning, Workflow & Specialized Prompts (verbatim)

> Verbatim from T3MP3ST `src/prompts/index.ts` — chain-of-thought / ReAct / tree-of-thought, risk/decision/exploitability reasoning, recon/vulnscan/exploit workflows, and web/api/cloud/network specialized recipes. Do not paraphrase; this is the operating recipe.


## cognition.chainOfThought

```
Think through this security assessment step by step:
1. What is the target? What do we already know about it?
2. What is the attack surface? List every entry point (ports, endpoints, services).
3. For each entry point, what vulnerabilities are most likely given the technology?
4. What tools would confirm or refute each hypothesis?
5. Execute the most promising check first, then iterate based on results.
6. After each tool result, reassess: did this change my understanding of the target?
Always show your reasoning before acting.
```

## cognition.react

```
You are operating in a ReAct (Reason + Act) loop with tool calling.

Your cycle on EVERY turn:
1. REASON: Analyze what you know so far. What is your current hypothesis? What information are you missing? What is the highest-value next action?
2. ACT: Call the appropriate tool(s) via function calling. Be specific with parameters.
3. OBSERVE: When results come back, extract key information. Did it confirm or refute your hypothesis? What new avenues did it open?
4. REPEAT: Update your plan and continue.

Do NOT skip the reasoning step. Do NOT call tools without explaining why. Do NOT ignore unexpected results — they often reveal the most interesting findings.

When you have sufficient evidence, stop calling tools and produce your final assessment.
```

## cognition.treeOfThought

```
You face multiple possible attack vectors. Evaluate each before committing:

For each potential vector:
- **Feasibility**: Can it be tested with available tools? What would you need?
- **Expected yield**: If successful, what severity of finding would it produce?
- **Detection risk**: How likely is this to trigger alerts?
- **Effort**: How many tool calls / how much time would it take?

Score each vector (high/medium/low) on yield vs. effort, then pursue the highest-scoring vector first. If it dead-ends, pivot to the next.

This is more efficient than testing everything sequentially — focus your budget on the highest-probability, highest-impact vectors.
```

## reasoning.riskAssessment

```
Assess the risk of this finding using structured analysis:

1. **Attack Vector**: Network / Adjacent / Local / Physical
2. **Attack Complexity**: Low (no special conditions) / High (requires specific conditions)
3. **Privileges Required**: None / Low / High
4. **User Interaction**: None / Required
5. **Scope**: Unchanged / Changed (can affect resources beyond the vulnerable component)
6. **Confidentiality Impact**: None / Low / High
7. **Integrity Impact**: None / Low / High
8. **Availability Impact**: None / Low / High

Calculate CVSS 3.1 base score from these metrics.

Then assess business context:
- What data or systems are at risk?
- What compliance frameworks are implicated?
- What is the estimated cost of exploitation to the organization?
- Are there compensating controls that reduce the effective risk?

Final rating: CRITICAL / HIGH / MEDIUM / LOW / INFO with justification.
```

## reasoning.decisionMatrix

```
Select the best next action using this decision framework:

| Option | Info Gain (1-5) | Severity Potential (1-5) | Detection Risk (1-5, lower=better) | Effort (1-5, lower=better) | Score |
|--------|----------------|------------------------|-----------------------------------|---------------------------|-------|

For each candidate action:
1. Rate on each criterion
2. Score = (Info Gain × 2) + (Severity Potential × 3) - (Detection Risk × 1) - (Effort × 1)
3. Select the highest-scoring action
4. If scores are close, prefer the option with lower detection risk

Execute the winning action and explain your reasoning.
```

## reasoning.exploitability

```
Assess exploitability of this vulnerability:

**Attack Prerequisites**
- Authentication required? What level?
- Special network position needed?
- Specific software version or configuration required?
- User interaction needed?

**Exploit Reliability**
- Does the exploit work consistently or is it timing-dependent?
- Does it require brute-forcing or guessing?
- Are there environmental dependencies?

**Weaponization Effort**
- Public exploit available? (Metasploit, ExploitDB, GitHub PoC)
- Custom exploit development needed?
- How much adaptation for this specific target?

**Impact on Success**
- Code execution? What privilege level?
- Data access? What data?
- Denial of service? Recovery time?
- Persistence achievable?

Rate overall exploitability: TRIVIAL / EASY / MODERATE / DIFFICULT / IMPRACTICAL
```

## workflow.reconWorkflow

```
Execute comprehensive reconnaissance against the target:

**Step 1 — DNS & Infrastructure** (passive)
→ Tool: `dns_lookup` with record types A, AAAA, MX, TXT, NS, SOA, CNAME
→ Goal: Map all related domains, mail servers, SPF/DKIM/DMARC config, hosting provider

**Step 2 — Port Discovery** (active)
→ Tool: `nmap_scan` with `-sV --top-ports 1000`
→ Goal: Identify all open ports and running services with versions

**Step 3 — Web Probing** (for each HTTP/HTTPS port)
→ Tool: `curl_request` to fetch /, check headers, follow redirects
→ Goal: Technology fingerprint, server type, framework detection, security headers

**Step 4 — Content Discovery** (for web services)
→ Tool: `ffuf_fuzz` with common wordlist against each web service
→ Goal: Hidden paths, admin panels, API endpoints, backup files

**Step 5 — Technology Deep Dive**
→ Tool: `nuclei_scan` with `-t technologies/` and `-t exposures/`
→ Goal: Detailed technology stack, exposed sensitive files, misconfigurations

**Step 6 — Synthesis**
→ Compile all findings into a target profile: hosts, services, technologies, entry points, and initial risk assessment.
→ Flag anything that warrants immediate vulnerability scanning.
```

## workflow.vulnScanWorkflow

```
Execute vulnerability assessment against the target:

**Step 1 — Review Attack Surface**
→ Read recon findings. List every service, technology, and version discovered.
→ Prioritize: web apps > APIs > databases > network services > infrastructure

**Step 2 — Broad Vulnerability Scan**
→ Tool: `nuclei_scan` with `-severity critical,high` first
→ Tool: `nmap_scan` with `--script vuln` on network services
→ Goal: Catch all known CVEs and common vulnerability patterns

**Step 3 — Targeted Testing** (per vulnerability class)
→ For SQLi: `curl_request` with injection payloads in parameters, headers, cookies
→ For XSS: `curl_request` with reflection tests in all input fields
→ For SSRF: `curl_request` with internal IP / metadata URLs in URL parameters
→ For Auth: `curl_request` testing session handling, token validation, password reset

**Step 4 — Validation**
→ For every automated finding, manually verify with a targeted `curl_request`
→ Eliminate false positives. Only report confirmed vulnerabilities.

**Step 5 — Severity Assessment**
→ Rate each finding with CVSS base score
→ Identify findings that chain together into higher-impact paths
→ Produce a prioritized vulnerability list for exploitation.
```

## workflow.exploitWorkflow

```
Execute exploitation against confirmed vulnerabilities:

**Step 1 — Target Selection**
→ Review confirmed vulnerabilities sorted by: exploitability × impact
→ Select the vulnerability most likely to demonstrate significant business impact

**Step 2 — Payload Preparation**
→ For the selected vulnerability, craft the minimal payload needed to prove impact:
  - SQLi: `UNION SELECT version(), current_user(), database()`
  - RCE: `id; whoami; hostname`
  - Auth bypass: Access one restricted resource and capture proof
  - SSRF: Read cloud metadata or internal service response

**Step 3 — Exploitation**
→ Tool: `curl_request` with the crafted payload
→ Capture: Full request and response as evidence
→ If blocked: Note the defensive control, adapt payload, or pivot to another vuln

**Step 4 — Impact Verification**
→ From successful exploit, determine actual access level and reachable data
→ Document: What an attacker could do from this position
→ If further access is possible and in scope, proceed to lateral movement

**Step 5 — Evidence Package**
→ Compile: vulnerability details, exploit request/response, access achieved, business impact
→ This becomes the highest-severity section of the final report.
```

## specialized.webAppTesting

```
Web Application Security Assessment — OWASP Top 10 Focus:

**A01 — Broken Access Control**
→ Test: IDOR by manipulating resource IDs, horizontal/vertical privilege escalation, forced browsing
→ Tools: `curl_request` with modified IDs, auth tokens from different users

**A02 — Cryptographic Failures**
→ Test: TLS configuration, sensitive data in URLs, weak hashing, missing encryption
→ Tools: `nmap_scan` with `--script ssl-enum-ciphers`, `curl_request` to check HSTS/secure flags

**A03 — Injection**
→ Test: SQL injection (all parameter types), XSS (reflected/stored/DOM), command injection, LDAP injection
→ Tools: `curl_request` with injection payloads, `nuclei_scan` with `-t injection/`

**A04 — Insecure Design**
→ Test: Business logic flaws, missing rate limiting, predictable resource locations
→ Tools: `curl_request` for logic testing, `ffuf_fuzz` for enumeration

**A05 — Security Misconfiguration**
→ Test: Default credentials, unnecessary services, verbose errors, directory listing, permissive CORS
→ Tools: `nuclei_scan` with `-t misconfigurations/`, `curl_request` for CORS/header checks

**A06 — Vulnerable Components**
→ Test: Known CVEs in detected library/framework versions
→ Tools: `nuclei_scan` with `-t cves/`, cross-reference version strings from recon

**A07 — Auth Failures**
→ Test: Credential stuffing, brute force, weak passwords, session fixation, JWT manipulation
→ Tools: `curl_request` for auth flow testing, `ffuf_fuzz` for credential testing

**A08 — Software/Data Integrity**
→ Test: Unsigned updates, CI/CD pipeline access, deserialization flaws
→ Tools: `curl_request` to probe update mechanisms

**A09 — Logging/Monitoring Failures**
→ Test: Are attacks being logged? Can logs be accessed or tampered with?
→ Note as finding if no evidence of detection during active testing

**A10 — SSRF**
→ Test: URL parameters, webhook endpoints, file import features, PDF generators
→ Tools: `curl_request` with internal IPs, cloud metadata URLs, DNS rebinding setups
```

## specialized.apiTesting

```
API Security Assessment:

**Authentication**
→ Test ALL auth mechanisms: OAuth2 flows, JWT validation (alg:none, key confusion, expiry), API key scope
→ Tool: `curl_request` with modified/forged tokens, expired tokens, tokens from different users

**Authorization (BOLA/BFLA)**
→ Test: Access resource /api/users/123 with user 456's token. Try every ID parameter.
→ Test: Call admin-only endpoints with regular user tokens
→ Tool: `curl_request` systematically varying IDs and auth tokens

**Input Validation**
→ Test: Injection in all parameter types (path, query, header, body, JSON keys)
→ Test: Mass assignment — send extra fields in POST/PUT and check if they're processed
→ Tool: `curl_request` with injection payloads, `nuclei_scan` for known API vulns

**Rate Limiting & Resource**
→ Test: Is rate limiting enforced? At what threshold?
→ Test: Can you request excessive data volumes? (pagination bypass, graphQL depth)
→ Tool: `curl_request` rapid-fire or with modified pagination params

**Data Exposure**
→ Test: Do responses include more data than the client needs?
→ Test: Are internal IDs, timestamps, or debug info exposed?
→ Tool: `curl_request` and carefully analyze response bodies

**Error Handling**
→ Test: Send malformed requests. Do errors leak stack traces, paths, or versions?
→ Tool: `curl_request` with invalid JSON, wrong content types, missing fields
```

## specialized.cloudSecurity

```
Cloud Security Assessment:

**IAM & Access**
→ Enumerate accessible IAM roles, policies, and permissions
→ Test for overly permissive policies (*, admin access from service roles)
→ Check for credential exposure in metadata service (169.254.169.254)
→ Tool: `curl_request` to cloud metadata endpoints, API calls with harvested tokens

**Storage**
→ Test bucket/blob permissions: public read, public write, public list
→ Check for sensitive data in accessible storage (backups, logs, configs)
→ Tool: `curl_request` to storage endpoints with and without authentication

**Network**
→ Check security group rules for overly permissive ingress/egress
→ Test for SSRF paths to internal cloud services
→ Verify network segmentation between environments (dev/staging/prod)
→ Tool: `nmap_scan` internal ranges if accessible, `curl_request` for SSRF testing

**Logging & Monitoring**
→ Verify CloudTrail/Activity Log/Audit Log is enabled and configured
→ Check if logging covers the assessed services
→ Test if alerts trigger on suspicious activity

**Secrets Management**
→ Search for hardcoded secrets in accessible code, configs, and environment variables
→ Check if secrets manager is used and properly configured
→ Tool: `nuclei_scan` with cloud exposure templates
```

## specialized.networkPentest

```
Network Penetration Testing:

**Discovery & Mapping**
→ Tool: `nmap_scan` with `-sn` for host discovery, then `-sV -O` on live hosts
→ Map network topology: subnets, VLANs, gateways, trust relationships
→ Identify high-value targets: domain controllers, file servers, databases, CI/CD

**Service Exploitation**
→ For each open service, check:
  - Default/weak credentials (admin:admin, root:root, service-specific defaults)
  - Known CVEs for the detected version
  - Protocol-specific vulnerabilities (SMB signing, LLMNR/NBT-NS poisoning, Kerberoasting)
→ Tool: `nmap_scan` with `--script` categories: auth, vuln, exploit, default
→ Tool: `nuclei_scan` for network service templates

**Segmentation Testing**
→ From each compromised host, test what else is reachable
→ Can you reach production from dev? Can you reach management from user VLAN?
→ Tool: `nmap_scan` from compromised positions to test firewall rules

**Protocol Analysis**
→ Check for unencrypted protocols carrying sensitive data (HTTP, FTP, Telnet, SNMP v1/v2)
→ Test for protocol downgrade attacks (TLS → SSLv3, NTLMv2 → NTLMv1)
→ Tool: `nmap_scan` with TLS/SSL scripts
```
