# EXTRACTION — `strix`

- **Upstream:** `https://github.com/usestrix/strix` (Apache-2.0; ingested 2026-08-23; SHA pin pending re-hydrate)
- **First mined:** 2026-08-23; normalized 2026-09-08
- **Existing extraction:** `packs/strix/INTEGRATION.md` — mad-hacks-side integration map (SARIF exporter, CWE→STRIDE, tech-stack playbooks, dedup methodology, scan modes → all folded natively to `references/` and `scripts/`)

## Rationale — why this pack is in the harness

usestrix/strix is an open-source AI pentesting agent framework — 9 consumer skills, 70+ internal knowledge packs, SARIF 2.1.0 exporter, dedup engine, API spec parser. mad-hacks ingested its high-leverage assets natively (see `packs/strix/INTEGRATION.md` — SARIF at `scripts/sarif-export.py`, CWE→STRIDE at `references/stride-mapping.md`, tech-stack playbooks at `references/tech-stack-playbooks.md`, dedup at `references/dedup-methodology.md`, scan modes at `references/scan-modes.md`). The pack is retained for the deeper `skills-internal/vulnerabilities/*.md` methodology docs (loaded on-demand per class row in `references/router.md`).

## Extracted lessons

| Brain record | Class | Title | Source |
|---|---|---|---|
| `brain/lessons.jsonl:L-strix-01` | `workflow` | strix ingested-assets pipeline — SARIF + CWE→STRIDE + tech playbooks + dedup + scan modes are native | `packs/strix/INTEGRATION.md` |

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-strix-01` | `workflow` | Vuln-class hunt needs methodology depth beyond `brain/lessons.md` + CBH's `hunt-<class>.md` → load `packs/strix/skills-internal/vulnerabilities/<class>.md` on demand (parser differentials, bypass matrices, IMDSv2/DNS-rebind) |

## Extracted tools

None as new records. strix's native tooling (LiteLLM adapter, hypothesis-based fuzz, agentic loop) is not adopted here — mad-hacks is keyless. The SARIF exporter was ported to `scripts/sarif-export.py` (native, not tracked as a pack tool).

## Extracted payloads

None. Payload contributions folded to `brain/payloads/` during initial mining; per-class methodology docs remain in-pack for on-demand load.

## Router integration

- `references/router.md` — Strix flag column in vuln-class table (parser differentials, bypass matrices depth); also cited in per-family blocks (web_api, cloud_infra, ai_red_team)

## Notes / next re-mining

- Pin upstream SHA at next re-hydrate (currently only date-tracked: 2026-08-23).
- New strix skills-internal docs (e.g. new vuln classes) → update router.md's Strix-flag column when they land.
