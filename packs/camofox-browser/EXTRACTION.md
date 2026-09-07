# EXTRACTION — `camofox-browser`

- **Upstream:** `https://github.com/jo-inc/camofox-browser` @ `e5a36f5cd0332fde6597de474329a308a53a0716` (MIT, 9.5k stars, active — updated 2026-09-07)
- **First mined:** 2026-09-08 (this pass)
- **Extractor:** confirmed missing-runtime for browser-stealth-agent + browser-verifier during PR #2 review

## Rationale — why this pack is in the harness

**The missing runtime.** PR #1 (`agents/: rewire 35 ingested-agent dead paths...`) deleted `browser-stealth-agent` and `browser-verifier` because their runtime dependency `$CLAUDE_PROJECT_DIR/tools/camofox_ctl.sh` did not exist. It turns out **jo-inc/camofox-browser IS that runtime** — same name, same port 9377, same accessibility-snapshot + ref-based REST API, same Camoufox (C++-patched Firefox) underneath. The earlier agents used the wrong control-script path (`camofox_ctl.sh`); the actual project uses `npm start` from the repo root.

This PR restores both agents wired to the correct runtime.

Camoufox patches Firefox at the C++ level to spoof `navigator.webdriver`, WebGL, `navigator.hardwareConcurrency`, AudioContext, screen geometry, WebRTC — invisible to JavaScript-based bot detection because the lies are in place before JS runs. Bypasses Cloudflare, Akamai, DataDome, PerimeterX, Google bot management, and most Turnstile widgets.

## Extracted lessons

| Brain record | Class | Title | Source |
|---|---|---|---|
| `brain/lessons.jsonl:L-cfx-01` | `cloudflare-bypass` | camofox-browser IS the stealth-browser runtime (was phantom in PR#1) | `packs/camofox-browser/README.md` |

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-cfx-01` | `cloudflare-bypass` | Target returns CF/Akamai/DataDome/Turnstile challenge OR client-side finding needs browser verification → dispatch `browser-stealth-agent` (drives `packs/camofox-browser/` at `:9377` via REST) |
| `PAT-cfx-02` | `xss` | Reflected/stored/DOM XSS finding needs proof of execution (not just reflection) → dispatch `browser-verifier` (mandatory browser oracle before shipping; ~90% of curl-reflected XSS fails browser execution due to CSP/framework escaping/context mismatch) |

## Extracted tools

| ID | Name | Purpose | Install |
|---|---|---|---|
| `T-camofox-browser` | camofox-browser | Anti-detection browser server for AI agents (Camoufox + REST + MCP + OpenAPI) | `cd packs/camofox-browser && npm install && npm start` (server at :9377) |

`execution_mode: receipt_required` — touches external targets when driven; needs operator authorization per `.t3mp3st/SCOPE.md`.

## Extracted payloads

None. camofox-browser is a runtime, not a payload archive. XSS payloads it renders come from `brain/payloads/xss.txt` + `xss-waf-bypass.txt`.

## Router integration

- `references/router.md` — cloudflare-bypass row (implicit — via retrieval `brain.sh recall-class cloudflare-bypass`; complements `PAT-cr-01` CloudRip origin-IP discovery)

## Restored agents (rewired to this pack)

- `agents/hunters/browser-stealth-agent.md` — 156 lines; drives camofox-browser REST for CF-protected recon + XSS verification + evidence capture. Rewired to lifecycle via `curl /health` + `( cd packs/camofox-browser && nohup npm start ... )` — no more phantom `camofox_ctl.sh`.
- `agents/hunters/browser-verifier.md` — 211 lines; mandatory client-side finding oracle. Rewired same lifecycle pattern. Detection ladder (dialog → DOM marker → OOB) now references `brain/payloads/xss.txt` + `xss-waf-bypass.txt` instead of the phantom `rules/payloads.md`.

## Notes / next re-mining

- Upstream is very active (9.5k stars, weekly updates). Re-mine monthly to catch new REST endpoints or MCP server changes.
- `packs/camofox-browser/AGENTS.md` (22KB) is the operator SPOT — do NOT copy its content into brain; agents read it on-demand from the pack.
- The pack ships an MCP server (`packs/camofox-browser/mcp/`). If a Claude Code session registers it, agents can use MCP tools directly instead of REST. Register: `claude mcp add camofox -- node packs/camofox-browser/mcp/index.js` (verify path with `ls packs/camofox-browser/mcp/` after rehydrate).
- Complementary to `PAT-cr-01` (CloudRip subdomain scan for origin IPs): they attack different CF surfaces. CloudRip = find unprotected origin; camofox = defeat WAF on protected origin. Run both.
