# Scan Mode Strategies

Three depth tiers for security testing. Select based on time budget, asset criticality, and engagement type.
Adapted from Strix scan modes (Apache-2.0).

## Quick Mode (30 min – 2 hours)

**Use when**: PR review, pre-deployment gate, CI/CD pipeline, time-boxed check.

### Scope
- Changed files/endpoints only (diff-scoped when possible)
- Top-10 vulnerability classes
- No recursive crawling

### Methodology
1. **Surface scan**: security headers, TLS config, exposed endpoints
2. **Hot spots**: auth endpoints, file upload, user input reflection
3. **Known CVEs**: dependency versions against NVD/KEV
4. **OWASP Top 10**: one probe per category on exposed endpoints

### Exit criteria
- All OWASP Top 10 categories checked
- No open critical/high findings
- Headers/TLS baseline captured

---

## Standard Mode (2 – 8 hours)

**Use when**: sprint-cadence security review, new feature assessment, moderate-risk target.

### Scope
- Full application surface
- All user roles tested
- API + web interface

### Methodology
1. **Full recon**: subdomain enum, content discovery, tech fingerprinting
2. **Auth testing**: all auth flows, session management, RBAC verification
3. **Injection suite**: SQLi, XSS, SSTI, command injection across all params
4. **Business logic**: state machine violations, privilege boundaries
5. **API testing**: BOLA/IDOR, mass assignment, rate limiting
6. **Known vulns**: full dependency audit, CVE cross-reference

### Exit criteria
- All endpoints tested with all applicable vuln classes
- All user roles exercised
- Business logic flows mapped and tested
- Dependency audit complete

---

## Deep Mode (8+ hours, multi-day)

**Use when**: annual pentest, critical asset, bug bounty, compliance requirement.

### Scope
- Everything in standard, plus:
- Source code review (whitebox when available)
- Infrastructure and cloud config
- Third-party integrations
- Background jobs and async processing
- Multi-step attack chains

### Methodology

#### Phase 1: Exhaustive Recon
**Whitebox** (source available):
- Map every file, module, code path
- AST analysis: semgrep, ast-grep, gitleaks, trufflehog, trivy
- Trace entry points from HTTP handlers to database queries
- Document all auth mechanisms and access control model
- Identify all serialization/deserialization points
- Review file handling: upload, download, processing
- Check all dependency versions against CVE databases

**Blackbox** (no source):
- Exhaustive subdomain enumeration with multiple sources
- Full port scanning across all services
- Complete content discovery with multiple wordlists
- API discovery via docs, JavaScript analysis, fuzzing
- Map all user roles with different account types
- Document rate limiting, WAF rules, security controls

#### Phase 2: Business Logic Deep Dive
- User flows: document every step of every workflow
- State machines: map all transitions
- Trust boundaries: identify where privilege changes hands
- Invariants: what rules should the app always enforce
- Implicit assumptions: what might be violated
- Multi-step attack surfaces: functionality abuse
- Third-party integration mapping

#### Phase 3: Chained Exploitation
- Chain findings for maximum impact
- Test trust boundary crossings
- Race condition probing on state-changing operations
- Multi-step privilege escalation
- Cross-service token/credential reuse
- SSRF → metadata → cloud API → lateral movement

#### Phase 4: Validation & Reporting
- Adversarial self-validation (VERIFY/REFUTE gates)
- Finding deduplication (dedup-methodology.md)
- STRIDE classification (stride-mapping.md)
- SARIF export (sarif-export.py)
- CWE/CVSS/OWASP mapping
- Remediation roadmap by priority

### Exit criteria
- Source code fully reviewed (whitebox)
- All attack chains explored to maximum depth
- Every finding has adversarial validation
- Complete STRIDE coverage
- Executive + technical report delivered
- SARIF artifact generated for CI integration

---

## Mode Selection Matrix

| Factor | Quick | Standard | Deep |
|--------|-------|----------|------|
| Time budget | < 2h | 2–8h | 8h+ |
| Asset criticality | Low | Medium | High/Critical |
| Engagement type | CI/CD, PR | Sprint review | Annual pentest |
| Source access | Not needed | Optional | Preferred |
| Report depth | Checklist | Findings + remediation | Full pentest report |
| SARIF output | Optional | Recommended | Required |
| STRIDE coverage | Partial | Good | Complete |

## Integration with T3MP3ST Pipeline
The scan mode determines depth at each pipeline phase:
- **RECON**: quick=surface, standard=full, deep=exhaustive+whitebox
- **WEAPONIZE**: quick=top-10, standard=all-classes, deep=all+chaining
- **EXPLOIT**: quick=1-probe, standard=thorough, deep=multi-vector+chains
- **VERIFY**: quick=basic, standard=adversarial, deep=multi-voter adversarial
- **REPORT**: quick=checklist, standard=findings, deep=full pentest report+SARIF
