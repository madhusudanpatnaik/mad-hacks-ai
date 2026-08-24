# Finding Deduplication Methodology

Smart dedup gate for the VERIFY phase. Prevents duplicate findings from polluting reports.
Adapted from Strix dedup module (Apache-2.0).

## When to Apply
- t3-verifier: before confirming a finding, check against all previously confirmed findings
- t3-reporter: before adding a finding to the report, dedup against existing report items
- brain.sh: before recording a new finding, check against target's prior findings

## SAME vulnerability (IS a duplicate)
- Same root cause (e.g. "missing input validation" not just "SQL injection")
- Same affected component/endpoint/file (exact match or clear overlap)
- Same exploitation method or attack vector
- Would be fixed by the same code change/patch
- Titles worded differently but same underlying issue
- PoC uses different payloads but exploits same issue
- One report more thorough than another

## NOT duplicates (different findings even if similar)
- Different endpoints with same vulnerability type (e.g., SQLi in /login vs /search)
- Different parameters in same endpoint (e.g., XSS in 'name' vs 'comment')
- Different root causes (e.g., stored XSS vs reflected XSS in same field)
- Different severity levels due to different impact
- One is authenticated, other is unauthenticated
- Same CVE but different package/ecosystem
- Same package but different CVE

## Dependency-CVE Dedup Rules
- Same CVE + same package + same ecosystem = DUPLICATE
- Same CVE + same package + missing ecosystem = DUPLICATE (conservative)
- Same CVE + different package = NOT duplicate
- Same package + different CVE = NOT duplicate
- Same CVE + same package + different manifest path = NOT duplicate (two consumers)

## Comparison Fields (priority order)
1. `endpoint` + `method` — exact location
2. `cwe` / `cve` — weakness/vulnerability identity
3. `technical_analysis` — root cause details
4. `poc_description` — exploitation method
5. `impact` — what damage it causes
6. `title` + `description` — general info (least reliable, most stochastic)

## Decision Rule
Focus on the technical root cause, not surface-level similarities. Ask: **would fixing one also fix the other?** If yes → duplicate. When uncertain, lean towards NOT duplicate (false negatives are cheaper than false positives in reporting).

## Fingerprinting (for SARIF cross-run dedup)
Primary fingerprint: `rule_id | uri:file | line:N | route:METHOD /endpoint`
Class fingerprint: `rule_id | class:vulnerability-keyword` (survives file renames)

## Usage in T3MP3ST
```
# Before confirming a finding in t3-verifier:
# 1. Compare candidate against all confirmed findings in .t3mp3st/<target>/findings/
# 2. Apply the SAME/NOT rules above
# 3. If duplicate: merge evidence into existing finding, skip new entry
# 4. If not duplicate: proceed to REFUTE gate
```
