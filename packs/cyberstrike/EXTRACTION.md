# EXTRACTION — `cyberstrike`

- **Marker:** `.vendored` (curated in-repo, no discovered external upstream URL)
- **First mined:** initial mad-hacks build; normalized 2026-09-08

## Rationale — why this pack is in the harness

CyberStrike is a 157-directory attack playbook library — the largest structured attack-technique corpus in the harness. Categories include: WEB (125-skill WSTG completeness checklist), ad-security, attack-cache-poison, attack-cors, attack-graphql, attack-host-header, attack-idor-automation, cicd-attacks, cloud-assessment, k8s-assessment, {aws,azure,gcp,k8s}-postexploit, llm-security, and per-class attack-<class> dirs. Heavily referenced from `references/router.md`'s CS-flag column.

## Extracted lessons

None as atomic JSONL records — the pack's value is retrieval-time depth per class, and it's cross-referenced from the vuln-class table in `references/router.md` (each class row's `CS` flag indicates a CyberStrike playbook exists). Atomizing 157 dir summaries would bloat the brain without adding retrieval action beyond what the router already provides.

## Extracted patterns

None. Retrieval pattern is: when a vuln-class hunter runs, check `references/router.md` for a `CS` flag → load `packs/cyberstrike/attack-<class>/SKILL.md`. This pattern is already codified in mad-hunt's HUNT LOOP and router logic; adding a redundant JSONL PAT- record would just duplicate.

## Extracted tools

None. CyberStrike is a methodology library, not a runtime tool.

## Extracted payloads

Payload contributions from CyberStrike's per-class dirs were folded into `brain/payloads/<class>.txt` during initial build. Attribution grep-recoverable via prose lessons in `brain/lessons.md` (7 attributed to cyberstrike).

## Router integration

- `references/router.md` — CS-flag column across the vuln-class table; also cited in family blocks (web_api, cloud_infra) for depth pointers

## Notes / next re-mining

- If upstream URL is discovered (previous ingest source), add to `packs/UPSTREAM.md` and remove `.vendored` marker.
- Consider auditing whether all 7 CyberStrike-attributed prose lessons in `brain/lessons.md` need atomization (defer to 30-day retrieval-telemetry window per user directive: measure impact, not fold count).
