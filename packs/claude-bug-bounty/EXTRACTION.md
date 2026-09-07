# EXTRACTION — `claude-bug-bounty`

- **Marker:** `.vendored` + `.internal` (mad-hacks-native, not routed as an attack class)
- **Provenance:** CBH parent framework — see `IMPROVEMENTS.md` L9 for the migration narrative
- **First mined:** with the initial mad-hacks build; normalized 2026-09-08 (marker-only, no atomic records)

## Rationale — why this pack is in the harness

This is a **hollow parent pack** — CBH's `/autopilot` + `/hunt` skills ship as SKILL.md files whose runtime scaffold (rules/, brain.py, scope.yaml) doesn't exist here. mad-hacks was built as its keyless replacement. The pack is retained as historical context, not as knowledge to fold. See `IMPROVEMENTS.md` L9 for the full "why we didn't adopt the CBH spine" story.

## Extracted lessons

None. The historical migration narrative is in `IMPROVEMENTS.md` — that's a documentation artifact, not a queryable brain record.

## Extracted patterns

None.

## Extracted tools

None.

## Extracted payloads

None.

## Router integration

Marked `.internal` — deliberately not in router.md. Not an attack class.

## Notes / next re-mining

Consider deletion at a future cleanup pass. Pack has no live knowledge and IMPROVEMENTS.md preserves the historical claim about why CBH wasn't adopted.
