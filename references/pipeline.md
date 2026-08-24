# The Self-Running Pipeline — "the kill chain runs itself"

This is the loop T3MP3ST automates and that **you** now run by hand. It mirrors the harness's own scripts: `decompose.mjs → cli-hunt/wild-hunt → verify-finding.mjs → refute-finding.mjs → disclosure-gen.mjs`. Nothing becomes a finding until it survives VERIFY **and** REFUTE.

```
CLASSIFY → SCOPE(gate) → DECOMPOSE → RECON → WEAPONIZE → EXPLOIT(probe)
                                                    │
                                          candidate finding
                                                    ▼
                                         VERIFY (evidence-grounded?)
                                                    ▼
                                    REFUTE (adversarially disprove it)
                                                    ▼
                              survives? → FINDING → REPORT/DISCLOSE → RETEST
                              fails?    → drop or downgrade to hypothesis
        └────────────────── REFLECT every ~5 iterations, re-plan ──────────────┘
```

## Stage by stage

### 1. CLASSIFY
Map the target/task to a mission family (`mission-families.md`). Load that family's starter directive, operator pack, runbook, and recommended knowledge packs.

### 2. SCOPE (hard gate)
Run `scripts/preflight.sh <target>`. No active tooling without a scope receipt. See `doctrine.md §Authorization`.

### 3. DECOMPOSE (blind master-builder)
Break the objective into focused sub-tasks so you don't ask one prompt to "find all bugs" (that hallucinates). One hypothesis per probe. Track sub-tasks in `./.t3mp3st/<target>/plan.md`. This is what `decompose.mjs` does — the SAST skill's decomposed-reasoning principle.

### 4. RECON
Run the family runbook's map/scope phases. Web: `scripts/recon.sh`. Code/cloud/mobile/binary: the local_read scanners from `arsenal.md`. Output: a **surface map** artifact.

### 5. WEAPONIZE
Turn the surface map into ranked candidate vulns. Match each surface element to a vuln class (below) and the tool/payload that would confirm it. Separate *discovery* from *confirmation*.

### 6. EXPLOIT (one reversible probe at a time)
Fire the minimal probe that would prove/disprove the hypothesis. `receipt_required` tools pause for user OK. Capture raw output to `./.t3mp3st/<target>/evidence/EV-N.txt`.

### 7. VERIFY (gate — from `verify-finding.mjs`)
A candidate is real only if the proof appears in **actual captured tool output**. Grep the evidence artifact for it. No artifact → not a finding. No fabricated "Executed…" lines, ever.

### 8. REFUTE (adversarial gate — from `refute-finding.mjs`)
Now try to **kill** your own finding. Ask: is there a benign explanation? A control that blocks it (CSP, WAF, auth)? Is the impact theoretical? Default to "refuted" if uncertain. Only findings that survive refutation ship. (This is the dast/sast devil's-advocate discipline.)

### 9. REPORT / DISCLOSE
Survivors → `report-template.md`. For OSS/coordinated disclosure, produce a redacted PoC + remediation + retest criteria (`disclosure-gen.mjs` shape).

### 10. REFLECT (every ~5 iterations)
Locked on one hypothesis? Evidence stale? Missing a modality (a whole surface unscanned)? Re-plan. Dead ends sharpen the map.

---

## Vuln-class coverage (what to hunt, by family)

**web_api** — IDOR/BOLA, broken auth & session, SQLi, XSS (reflected/stored/DOM/mXSS), SSRF, SSTI, RCE/command-injection, XXE, open redirect, CORS misconfig, CSRF, file-upload, race conditions, business-logic bypass, mass assignment, GraphQL introspection/authz, JWT/OAuth/OIDC/SAML flaws, security-header/cookie/TLS config, info disclosure (.git/.env/stack traces/actuator), subdomain takeover.

**code_supply_chain** — source sinks (taint: entry→dangerous op), hardcoded secrets, vulnerable deps (OSV/CVE), typosquat/dependency-confusion, CI/CD trust, SLSA/scorecard gaps, insecure deserialization, path traversal.

**cloud_infra** — IAM over-permission & privesc paths, public storage (S3/blob/GCS), exposed metadata/SSRF-to-IMDS, IaC misconfig (checkov/trivy), key exposure, network exposure.

**ai_red_team / agent_warfare** — see `frontier-lanes.md`: prompt injection (direct + indirect/RAG), tool-abuse, memory/vector poisoning, output-handling injection, ASCII smuggling, MCP/model-server exposure, agent command-injection, browser-tool privilege collapse, identity handoff, data egress, wallet/signing boundary. Map to OWASP LLM Top 10 + MITRE ATLAS.

**smart_contract** — reentrancy, access-control, oracle/price manipulation, integer issues, unchecked calls (slither/myth/echidna/forge).

**crypto_secrets** — weak crypto, exposed keys/tokens, hash cracking (owned material only), cert/TLS weaknesses.

**reverse_binary** — unsafe copy / format string / command-injection / integer-overflow sinks in decompiled output (r2/ghidra/checksec/binwalk); CTF pwn on owned/lab binaries only.

**reporting_remediation** — vuln prioritization (EPSS × KEV × CWE-25 × asset value), fix plans, retest criteria, non-technical summaries.
