# EXTRACTION — `OmniRoute`

- **Upstream:** `https://github.com/diegosouzapw/OmniRoute` @ `ba597b631d22d85e56db6982f24b7d1ebe238df9` (branch `release/v3.8.51`, MIT, 62.9k stars, active — updated 2026-09-08)
- **First mined:** 2026-09-09
- **Extractor:** target-archetype pass (AI-gateway class)
- **Marker:** `.internal` — target archetype, not a routed attack class of its own; retrieved via LLM/AI-gateway hunts

## Rationale — why this pack is in the harness

OmniRoute is a Next.js 16 + TypeScript **AI gateway** that routes to 352 LLM providers (150+ free tiers, 1200+ models) through one endpoint, with quota-aware auto-fallback, RTK/Caveman token compression, MCP + A2A support, and a full dashboard. It ships **as a service**, which directly conflicts with the mad-hacks keyless doctrine — we do NOT adopt it as a runtime.

What we DO extract: **the target-archetype**. When hunting an AI-gateway target in the wild (any multi-provider LLM routing service — commercial or self-hosted), OmniRoute's architecture is a template of the attack surface: quota accounting, provider identity/credential vault, prompt-routing logic, streaming pipeline, MCP + A2A endpoints, dashboard authz. Same shape as the `L-aila-01`/`PAT-aila-01` archetype pair for AI-security-platform targets — but for the *gateway* class specifically.

## Extracted lessons

| Brain record | Class | Title | Source |
|---|---|---|---|
| `brain/lessons.jsonl:L-omr-01` | `llm-ai` | AI-gateway archetype — Next.js + 352-provider fan-out, quota vault, MCP/A2A | `packs/OmniRoute/AGENTS.md` + `packs/OmniRoute/README.md` |

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-omr-01` | `llm-ai` | Target detected as AI-gateway (multi-provider LLM routing, `/dashboard/free-tiers`, `/mcp`, `/api/providers`, or per-provider dashboards) → enumerate providers via `/api/providers` or the dashboard's free-tiers view; test cross-provider quota bypass (spoof `x-provider-hint`), prompt-routing bypass (force expensive-model path), credential-vault IDOR on `/api/keys/*`, MCP/A2A auth confusion (`/mcp/*` vs `/a2a/*` scope drift), dashboard tenant IDOR |

## Extracted tools

None. OmniRoute is a runtime service, not a utility we adopt (doctrine: mad-hacks is keyless, Claude Code IS the reasoning engine — running our own LLM router would violate that).

## Extracted payloads

None. Not a payload archive.

## Router integration

Marked `.internal` — target-archetype pack, routed via the LLM/AI-gateway class rather than a direct router row. Retrieval via `brain.sh recall-class llm-ai` will surface `L-omr-01` + `PAT-omr-01` alongside AI-platform records (AILA archetype).

## Notes / next re-mining

- Pack is 301MB on disk (13,237 files, Next.js 16 monorepo). Contents are `.gitignore`d; rehydrate with `bash scripts/reinstall-packs.sh` (URL+SHA pinned in `packs/UPSTREAM.md`).
- If a bounty program lands with an AI-gateway target, re-mine to extract specific endpoint patterns (`/api/providers/[id]/quota`, `/api/keys`, `/mcp/tools/list`, etc.) into more precise patterns.
- Complements `L-aila-01`/`PAT-aila-01` (AI-security-platform archetype) — together they cover the two dominant "AI infra as a target" shapes: security platform + LLM gateway.
- **Doctrine drift risk:** if a future contributor tries to *use* OmniRoute as an LLM proxy for mad-hacks itself, that violates keyless doctrine. This pack is knowledge only.
