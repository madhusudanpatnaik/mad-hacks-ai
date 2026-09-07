# EXTRACTION — `secrets-patterns-db`

- **Upstream:** `https://github.com/mazen160/secrets-patterns-db` @ `24984df1a3f78475132ed183cebce4452b601161`
- **First mined:** initial clone (undated); normalized to JSONL 2026-09-08
- **Extractor:** shallow-pack raise-the-floor pass

## Rationale — why this pack is in the harness

The largest open-source database of secret-detection regex — 1610+ patterns, all ReDoS-safe, categorized by confidence, format-agnostic (feeds both trufflehog and gitleaks). We do not maintain our own secret regexes; this pack is the SPOT. Wired into the harness via `scripts/secrets-scan.sh` wrapper which uses pre-generated configs in `brain/registry/secrets-rules/` (883 high-confidence subset when `--high-only`).

## Extracted lessons

| Brain record | Class | Title | Source |
|---|---|---|---|
| `brain/lessons.jsonl:L-spdb-01` | `secrets` | secrets-patterns-db is the SPOT for secret-detection regex | `packs/secrets-patterns-db/README.md:1-15` |

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-spdb-01` | `secrets` | Scanning code/file drop for secrets → run `scripts/secrets-scan.sh` (uses this DB); avoid raw gitleaks/trufflehog with default rules |

## Extracted tools

None. `scripts/secrets-scan.sh` is a native mad-hacks wrapper (not a pack tool). Trufflehog and gitleaks are already in the arsenal (`references/arsenal.md`), also not pack tools.

## Extracted payloads

None. Regexes are detection patterns, not attack payloads. The 883 high-confidence rules are pre-generated to `brain/registry/secrets-rules/` at build time — they're consumed by the scanners, not folded into `brain/payloads/`.

## Router integration

- `references/router.md` — secrets scanning is covered via the `scripts/secrets-scan.sh` line at the bottom of the router; retrieval via `brain.sh recall-class secrets`

## Notes / next re-mining

- The upstream DB grows regularly. Re-mine every 90 days to refresh `brain/registry/secrets-rules/` via `scripts/secrets-scan.sh --rebuild-rules`.
- Do NOT hand-write secret regexes here or elsewhere in mad-hacks — upstream any new patterns to the DB.
