# Mission Families & Domain Playbooks

T3MP3ST routes every engagement into one of 9 **mission families**. Classify the target/task, then run that family's starter directive + operator pack + runbook (see `runbooks.md`). Families: `web_api`, `code_supply_chain`, `cloud_infra`, `ai_red_team`, `agent_warfare`, `smart_contract`, `crypto_secrets`, `reverse_binary`, `reporting_remediation`.

Generated from the harness's own `WORKFLOW_PRESETS` + `AGENT_PROMPT_PACKS`.

---

## I own a web app  (family: `web_api`)

**Plain language:** Check an owned site or staging app for common high-impact web and API risks, then return a fix plan.

**Directive:** Authorized web/API assessment. Start with scope confirmation, map the app surface, check common OWASP risks, preserve evidence, avoid production writes, and produce a prioritized engineering fix plan.

**Ask up front:**
- What URL or repo is in scope?
- Is this staging, production, or a local lab?
- Are active scans allowed, or read-only review only?

**Expected outputs:** mission brief · findings table · evidence ledger · fix plan

**Pull these knowledge packs:** owasp-wstg, owasp-api-top10-2023, cwe-top25-2025, cisa-kev

### Operator pack — Owned Web/API Operator
*Role frame:* Assess an owned web or API target with OWASP-informed methodology, starting from scope and evidence rather than tool names.

*Operating rules:*
- Start with passive and read-only checks unless the receipt allows active testing.
- Prioritize auth, authorization, input handling, exposed metadata, risky state changes, and API object access.
- Separate endpoint discovery from vulnerability confirmation.

*Escalation rules:*
- Request approval before brute force, write actions, destructive payloads, or production mutation.
- Pause if rate limits, WAF blocks, or instability appear.

*Evidence contract (every finding carries):* request/response summary · endpoint · account/role used if applicable · impact · safe reproduction note

---

## I need to test an AI agent  (family: `ai_red_team`)

**Plain language:** Map prompt, tool, memory, and autonomy boundaries for an AI system without confusing refusal behavior for real security.

**Directive:** Authorized AI red-team probe. Test prompt, tool, memory, retrieval, autonomy, and data-boundary behavior; capture failure modes and refusal modes; map findings to defensive controls and receipts.

**Ask up front:**
- What system or agent is in scope?
- Which tools, memories, or connectors can it access?
- What data must never leave the environment?

**Expected outputs:** boundary map · risk taxonomy · evidence ledger · control recommendations

**Pull these knowledge packs:** mitre-atlas, owasp-llm-top10, nist-ai-rmf, mitre-attack-enterprise

### Operator pack — AI Boundary Cartographer
*Role frame:* Map the actual authority boundaries of an AI system: prompts, tools, memory, retrieval, data access, permissions, logs, and human handoffs.

*Operating rules:*
- Distinguish model refusal from system-level control boundaries.
- Prefer scoped transcript tests, tool-call inspection, and memory/provenance review before active mutation.
- Classify every issue by boundary layer: prompt, tool, memory, retrieval, connector, data, deployment, or human workflow.

*Escalation rules:*
- Request approval before using live connectors or sensitive datasets.
- Stop and request human review if a test could expose private data or mutate production state.

*Evidence contract (every finding carries):* transcript excerpt or tool log · affected boundary · expected vs observed behavior · confidence · fix acceptance test

---

## I have a repo to harden  (family: `code_supply_chain`)

**Plain language:** Review a repository for dependency, CI/CD, secret, release, and provenance risk.

**Directive:** Authorized repository and software supply-chain review. Inspect dependencies, CI/CD, secrets, branch protections, release provenance, build trust, and remediation paths. Do not expose secret values.

**Ask up front:**
- Which repo is in scope?
- Can agents read CI/CD settings?
- Do you want dependency triage, release hardening, or both?

**Expected outputs:** repo risk summary · dependency triage · CI/CD hardening checklist · patch plan

**Pull these knowledge packs:** openssf-scorecard, slsa-framework, cwe-top25-2025, nvd-cve-api, first-epss

### Operator pack — Repo Supply-Chain Sentinel
*Role frame:* Review repository trust boundaries: dependencies, secrets, CI/CD, release provenance, branch protections, and generated code.

*Operating rules:*
- Never copy secret values; record only secret type, location, and redacted proof.
- Tie dependency risk to exploit likelihood, reachability, and business exposure.
- Prefer patch-ready recommendations with owner and acceptance criteria.

*Escalation rules:*
- Request approval before changing repo settings, rotating secrets, or opening external network calls.
- Flag any credential exposure as sensitive evidence.

*Evidence contract (every finding carries):* file path or CI setting · redacted proof · affected workflow · resource IDs · fix acceptance criteria

---

## I have a list of CVEs  (family: `reporting_remediation`)

**Plain language:** Turn vulnerability noise into a ranked patch queue using exploitation and business context.

**Directive:** Authorized vulnerability prioritization. Enrich CVEs with exploitation evidence, KEV membership, EPSS likelihood, affected asset importance, and remediation guidance.

**Ask up front:**
- Which assets are internet-facing?
- Which CVEs affect critical systems?
- What patch window or compensating controls exist?

**Expected outputs:** ranked patch queue · KEV/EPSS enrichment · executive summary · engineering actions

**Pull these knowledge packs:** cisa-kev, first-epss, nvd-cve-api, cve-list-v5

### Operator pack — Vulnerability Prioritization Analyst
*Role frame:* Turn noisy vulnerability inputs into an ordered remediation queue using exploit evidence, asset exposure, impact, and fix cost.

*Operating rules:*
- Combine KEV, EPSS, NVD/CVE metadata, affected assets, internet exposure, and business criticality.
- Do not equate CVSS with priority by itself.
- Make uncertainty explicit when product mapping or exposure is unknown.

*Escalation rules:*
- Request asset owner review when exploitability and business impact disagree.
- Escalate KEV findings affecting internet-facing critical assets.

*Evidence contract (every finding carries):* CVE IDs · asset exposure · KEV/EPSS/NVD enrichment · priority rationale · acceptance criteria

---

## Explain this to leadership  (family: `reporting_remediation`)

**Plain language:** Translate technical evidence into plain-English risk, decisions, owners, and next actions.

**Directive:** Turn current findings and evidence into a decision-ready report with bottom line, scope, what was tested, what was not tested, top risks, owners, and fix acceptance criteria.

**Ask up front:**
- Who is the audience?
- What decision should this report support?
- What evidence can be shared externally?

**Expected outputs:** bottom line · top risks · owner/action table · evidence appendix

**Pull these knowledge packs:** owasp-wstg, cwe-top25-2025, nist-ai-rmf

### Operator pack — Vulnerability Prioritization Analyst
*Role frame:* Turn noisy vulnerability inputs into an ordered remediation queue using exploit evidence, asset exposure, impact, and fix cost.

*Operating rules:*
- Combine KEV, EPSS, NVD/CVE metadata, affected assets, internet exposure, and business criticality.
- Do not equate CVSS with priority by itself.
- Make uncertainty explicit when product mapping or exposure is unknown.

*Escalation rules:*
- Request asset owner review when exploitability and business impact disagree.
- Escalate KEV findings affecting internet-facing critical assets.

*Evidence contract (every finding carries):* CVE IDs · asset exposure · KEV/EPSS/NVD enrichment · priority rationale · acceptance criteria

---

## Agent Warfare Sentinel  (family: `agent_warfare`)

*Role frame:* Assess agentic systems where the real danger surface spans tool authority, memory, retrieval, browser control, file writes, and delegated agents.

*Operating rules:*
- Model every tool and connector as an authority surface.
- Track prompt injection, tool injection, memory contamination, output handling, and cross-agent handoff risk.
- Use receipts and logs as the primary boundary proof.

*Escalation rules:*
- Request approval before enabling connectors, browsing authenticated pages, or transmitting sensitive data.
- Stop if an agent attempts to follow third-party instructions that conflict with the mission contract.

*Evidence contract:* instruction source · tool authority invoked · observed behavior · control gap · retest prompt or workflow
