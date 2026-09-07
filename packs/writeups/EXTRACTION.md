# EXTRACTION — `writeups`

- **Marker:** `.vendored` + `.internal` (mad-hacks-curated writeups corpus, sourced from CoffinXP + pentester.land + others)
- **First mined:** ongoing (regularly refreshed by `scripts/refresh-writeup-feeds.sh` + `scripts/build-writeup-corpus.sh`)
- **Normalized:** 2026-09-08 (marker-only; corpus lives in `brain/writeups-corpus.md`, not as atomic records)

## Rationale — why this pack is in the harness

Curated writeups corpus — the raw pack contains full-body writeups (23 CoffinXP + 6,554 pentester.land metadata pointers with bug classes + bounty amounts). Consolidated into `brain/writeups-corpus.md` (the queryable form, ~6.4k writeups distilled per class + top exemplars) which is the canonical retrieval SPOT for writeup lookups.

## Extracted lessons

None as atomic JSONL — the corpus IS the extraction (as prose in `brain/writeups-corpus.md`). Atomizing 6.4k writeups into individual JSONL records would explode the brain size without adding retrieval action; retrieval works via grep against the corpus file per class.

## Extracted patterns

None. Corpus-based lookup pattern is embedded in `references/mad-hunt.md §4 HUNT LOOP` ("before every dispatch: pull the class's top corpus exemplar (brain/writeups-corpus.md) for technique").

## Extracted tools

None. `scripts/refresh-writeup-feeds.sh` + `scripts/build-writeup-corpus.sh` are mad-hacks-native corpus maintainers, not pack tools.

## Extracted payloads

None. Payloads mined from writeups are folded into `brain/payloads/<class>.txt` deduped.

## Router integration

Marked `.internal` — referenced from `references/mad-hunt.md` and every hunter's dispatch preamble ("pull top corpus exemplar"), but not a routing class.

## Notes / next re-mining

- Feeds refreshed daily-to-weekly by `refresh-writeup-feeds.sh`. Watch for feed schema changes upstream (CoffinXP, pentester.land) — cited in the refresh script's comments.
- 11 recently-compressed writeup files sit uncommitted in `packs/writeups/` from a prior optimize.sh pass; commit them in a separate housekeeping PR (not this integration work).
