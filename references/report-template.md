# Finding & Report Template

Every result must harden into this. No finding ships without an evidence artifact you actually captured (VERIFY gate). One file per finding under `./.t3mp3st/<target>/findings/`.

## Finding schema
```
ID:            F-001
Title:         <concise, specific — vuln + where>
Severity:      info | low | medium | high | critical
CVSS:          <vector + score, if scored>
CWE:           CWE-XXX
Confidence:    confirmed | probable | hypothesis
Affected:      <exact URL / host / file:line / resource ID>
MITRE:         <Txxxx technique(s)>

Summary:       <what it is, one paragraph>

Evidence:
  - EV-1: <command run>
          <raw output excerpt — redact secrets/PII/tokens>
          (saved: .t3mp3st/<target>/evidence/EV-1.txt)

Reproduction:  <exact, minimal, deterministic steps>

Impact:        <concrete, demonstrated — not theoretical. What can an attacker
                actually do, and what's the blast radius?>

Remediation:   <specific fix, not "add validation">

Retest:        <acceptance criteria — how to confirm the fix closed it>

Uncertainty:   <what you did NOT verify; residual risk>
```

## Rules
- **Confirmed** requires evidence you can point to in a saved artifact. Otherwise it's **hypothesis** + the next safe test.
- **Impact must be demonstrated**, not asserted. "Could lead to RCE" without a PoC is a hypothesis.
- **Redact** secrets/tokens/PII — reference them ("a valid session cookie was returned") without pasting values.
- **Severity honesty** — don't inflate. A reflected value with a CSP that blocks it is not a clean XSS; say so.
- Chain low-severity feeders (info disclosure, open redirect, CORS) into the higher-impact outcome they enable, and score the chain.

## Report structure (engagement)
1. **Executive summary** — plain-language risk, top findings, overall posture.
2. **Scope & authorization** — targets, dates, rules of engagement, the receipt that authorized it.
3. **Methodology** — phases run, tools used, what was and wasn't tested.
4. **Findings** — each per the schema above, ordered by severity.
5. **Remediation roadmap** — prioritized, with retest criteria.
6. **Appendix** — evidence index (EV-* → artifact paths), tool versions, timeline.

Traceability end-to-end: objective → scope → actions → evidence → finding → fix → retest.
