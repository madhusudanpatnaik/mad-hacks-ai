# EXTRACTION — `dalfox`

- **Upstream:** `https://github.com/hahwul/dalfox` @ `7bb684fdf48959d10c6a6ac24d4a190361c58c8f` (MIT)
- **First mined:** initial clone; prose extraction at `references/dalfox-guide.md`
- **Normalized:** 2026-09-08

## Rationale — why this pack is in the harness

dalfox v3 (Rust rewrite) is best-in-class for XSS scan/mining/blind. Native `--blind-oob` (interactsh), MCP stdio 6-tool server, SARIF/JSONL output. Superior to hand-rolled curl loops for XSS work. References/dalfox-guide.md is the prose extraction (mad-hacks-side interpretation); this manifest normalizes to atomic records.

## Extracted lessons

| Brain record | Class | Title | Source |
|---|---|---|---|
| `brain/lessons.jsonl:L-df-01` | `xss` | dalfox v3 supersedes v2 — Rust rewrite with MCP + native blind-OOB | `references/dalfox-guide.md` |

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-df-01` | `xss` | About to hand-roll curl loops for XSS scan/mining → use dalfox v3 via `references/dalfox-guide.md` recipes |

## Extracted tools

| ID | Name | Purpose |
|---|---|---|
| `T-dalfox-v3` | dalfox v3 | XSS scan/mine/blind with native `--blind-oob`, MCP stdio, SARIF/JSONL |

## Extracted payloads

None as new payload sets — dalfox's built-in payload catalog is consumed via the CLI, not folded to `brain/payloads/`. XSS-specific `brain/payloads/xss.txt` + `xss-waf-bypass.txt` remain the mad-hacks payload source.

## Router integration

- `references/router.md` — dalfox row + `references/dalfox-guide.md` mentioned as the on-demand playbook

## Notes / next re-mining

- Watch upstream for v3 CLI/MCP schema changes; update `references/dalfox-guide.md` when they land.
- v2 (Go) still receives security backports on the `v2` branch — do not remove.
