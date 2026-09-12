# EXTRACTION — `payloads-all-the-things`

- **Upstream:** `https://github.com/swisskyrepo/PayloadsAllTheThings` (MIT; ingested as `pat-full.tar.gz` archive)
- **Marker:** `.internal` (payload archive, not a routing class — extracted on-demand)
- **First mined:** initial clone; normalized 2026-09-08

## Rationale — why this pack is in the harness

swisskyrepo/PayloadsAllTheThings — the largest general-purpose offensive payload/technique reference. Kept here as `pat-full.tar.gz` for archive-friendliness (avoids inflating the repo with 64+ per-class dirs of prose). Extracted on-demand per vuln class when the mad-hacks-native `brain/payloads/<class>.txt` doesn't cover an exotic case (last-resort payload lookup, as noted in `references/router.md:17`). Best-in-class for uncommon/legacy vulnerability classes where recent maintenance is thin.

## Extracted lessons

| Brain record | Class | Title | Source |
|---|---|---|---|
| `brain/lessons.jsonl:L-pat-01` | `workflow` | PayloadsAllTheThings is the last-resort payload lookup — extract from archive per class | `packs/payloads-all-the-things/pat-full.tar.gz` + `references/router.md:17` |

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-pat-01` | `workflow` | Hunting a vuln class where `brain/payloads/<class>.txt` is thin OR the vuln class is exotic/legacy → `tar -xzf packs/payloads-all-the-things/pat-full.tar.gz -C /tmp/pat --wildcards '*<class>*'` then grep for payloads. 48 attributions in brain/lessons.md already reference this pack's contributions |

## Extracted tools

None. PayloadsAllTheThings is a payload archive, not a runtime tool.

## Extracted payloads

Substantial contributions already folded into `brain/payloads/<class>.txt` during initial mining — 48 attributions in `brain/lessons.md` reference this pack (grep `payloads-all-the-things\|PayloadsAllTheThings\|PAT` in `brain/lessons.md`). The tarball is preserved for on-demand extraction of classes not yet folded.

## Router integration

Marked `.internal` — the pack is referenced from `references/router.md:17` under the on-demand payload extraction row, not as a routing class of its own.

## Notes / next re-mining

- Pin snapshot SHA at next re-hydrate (currently only date-tracked: 2026-09-08).
- Refresh the `pat-full.tar.gz` snapshot quarterly — upstream PAT is one of the most-updated payload repos.
- Consider auditing whether the 48 pack-attributed prose lessons in `brain/lessons.md` need atomization (per user directive: measure impact first, atomize based on retrieval-hit rate).
