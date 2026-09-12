# EXTRACTION — `AILA`

- **Upstream:** `https://github.com/project-lambda-zero/AILA` @ `ae50589ff301b23ab501594737d47cf775ca694a`
- **First mined:** 2026-09-05 (initial clone) · **Re-mined:** 2026-09-08 (normalized to JSONL)
- **Extractor:** shallow-pack raise-the-floor pass

## Rationale — why this pack is in the harness

AILA is a full-stack modular AI security platform (Python/FastAPI + Postgres+pgvector + ARQ/Redis + React 19 pnpm workspace). We do NOT adopt it as a runtime — mad-hacks is keyless. What we borrow is the **target archetype**: when hunting AI security platforms in the wild, AILA's architecture (module-boundary auth, per-module frontends mounted at `/modules/<id>/frontend/`, SSE event streams, LLM-based request routing) IS the attack surface map. Modules frequently miss instance-level RBAC — that's a distinct IDOR class this pack teaches us to look for.

## Extracted lessons

| Brain record | Class | Title | Source |
|---|---|---|---|
| `brain/lessons.jsonl:L-aila-01` | `ai-platform` | AILA architecture archetype — modular AI security platform | `packs/AILA/CLAUDE.md:1-40` |

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-aila-01` | `ai-platform` | Target is AILA-shaped → enumerate module IDs from extension registry; test cross-tenant IDOR on `/api/modules/<id>/*` |

## Extracted payloads

None. AILA is an application, not a payload archive.

## Extracted tools

None. Not adopted as a runtime — Claude Code IS the reasoning engine per mad-hacks doctrine.

## Router integration

- `references/router.md` — pack listed under Rifteo/xalgorix-style "adopted from" note; primary access is via retrieval (`brain.sh recall-class ai-platform`)

## Notes / next re-mining

- If AILA adds new modules under `src/aila/modules/`, re-mine to check if new module categories introduce new attack primitives (e.g., a "cloud" module might introduce SSRF surfaces the pattern above should catch).
- Consider extracting AILA's own hunt taxonomy (its `modules/vulnerability/` code) as a reference — deferred until we hunt an AILA-shaped target and validate the taxonomy is worth folding.
