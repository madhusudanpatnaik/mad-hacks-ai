# EXTRACTION — `claude-bughunter`

- **Marker:** `.vendored` (mad-hacks-curated bughunter methodology fork; used via router)
- **First mined:** initial mad-hacks build; heavily folded into brain (~20 prose lessons + 3 tools attributed as CBH/shuvonsec via grep `brain/lessons.md`)
- **Normalized:** 2026-09-08 (marker-only pass; atomic-record extraction deferred until per-target retrieval telemetry justifies which of the ~20 prose lessons are worth atomization)

## Rationale — why this pack is in the harness

Curated bughunter methodology library — 24 disclosed-report pattern docs (`hunt-<class>.md` per vuln class), the pack that supplied a large portion of mad-hacks's initial lessons.md content. Actively routed via `references/router.md` (CBH column in the vuln-class table — flag whether a disclosed-report pattern exists per class).

## Extracted lessons

None as atomic JSONL yet — ~20 prose lessons currently live in `brain/lessons.md`. Atomization decision deferred to the next batch: run per-class recall telemetry for 30 days, atomize only the top-10 by retrieval-hit rate. (Per user directive: measure impact, not fold count.)

## Extracted patterns

None as atomic JSONL yet — same reasoning.

## Extracted tools

None. CBH-native tools (`autopilot`, `hunt`) are hollow SKILL.md files whose runtime doesn't exist here; mad-hacks replaced them with `/mad-hunt` (see `IMPROVEMENTS.md`).

## Extracted payloads

Payload contributions from CBH's disclosed reports were folded into `brain/payloads/<class>.txt` during initial build; attribution is grep-recoverable via the prose lessons in `brain/lessons.md`.

## Router integration

- `references/router.md` — cited in the vuln-class table's `CBH` column (flag column indicating a disclosed-report pattern doc exists at `packs/claude-bughunter/disclosed-reports/hunt-<class>.md`)

## Notes / next re-mining

- Await 30-day retrieval-telemetry window to identify which prose lessons are actually surfaced during hunts; atomize the top hits.
- If upstream URL becomes tracked (currently .vendored), move to UPSTREAM.md and remove .vendored marker.
