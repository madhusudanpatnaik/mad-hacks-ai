# Burp Suite MCP — integration into the workflow

When a **Burp Suite MCP** is connected, it becomes the **primary HTTP channel** for web/API work — it beats raw `curl` for the exact things this toolkit cares about: full request/response **evidence**, single-request **Repeater** probes (the literal embodiment of "one reversible probe at a time"), and the **real authenticated surface** as browsed through the proxy.

## Discover the Burp tools at runtime
The Burp MCP tool names vary by server (PortSwigger official vs community). At the start of a web engagement, discover them:
```
ToolSearch("burp proxy repeater intruder scanner sitemap collaborator")
```
Load whatever it exposes — typically: send-HTTP-request / Repeater, proxy-history, sitemap, passive/active scan, Intruder, Collaborator (OOB), URL/HTML encode-decode. **Prefer these over `curl`/`httpx` when present.** If none load, Burp isn't connected — fall back to the system-tool scripts.

## Where Burp plugs into the kill chain
| Stage | Burp capability | Why it wins | Prod-safety |
|---|---|---|---|
| **Recon** | proxy history + sitemap | The *real* app surface incl. authenticated flows, XHR/APIs the crawler misses | passive — safe (R-ok) |
| **Weaponize** | **passive scan** of proxy history | Candidates with zero added traffic | passive — **safe on prod** |
| **Weaponize** | active scan / Intruder | Deep coverage | ⚠️ R1/R9: throttle hard, and **many bounty programs ban automated scanning** — gate on program policy |
| **Exploit** | **Repeater** (send one request) | One crafted request, see response, change one variable — perfect single-probe PoC + captured evidence | safe when hand-driven |
| **Exploit** | Collaborator | OOB confirmation for blind SSRF/XXE/SQLi (alt to interactsh) | safe |
| **Verify** | Repeater replay | Re-send the exact request → prove reproducibility to the verifier | safe |
| **Report** | raw request/response | **Client-ready evidence** — copy the full HTTP exchange (redact secrets/PII) into the finding | — |

## Doctrine still governs Burp
- **SCOPE gate first.** Set Burp's target scope to the authorized hosts; only send in-scope requests. A tool being available is not consent.
- **Execution modes still apply:** Repeater single requests = the safe path. **Intruder / active scan = `receipt_required`** (throttle: low thread count, resource-pool delay) and blocked if the program prohibits automated scanning (see `production-safety.md` R1/R9).
- **VERIFY/anti-fabrication:** save the actual Burp request/response as the evidence artifact under `./.t3mp3st/<target>/evidence/`. Never paraphrase a response you didn't capture.
- **Safe-PoC catalog** (`production-safety.md`) is unchanged — Repeater is how you *deliver* the benign PoC (`alert(document.domain)` reflection, one canary IDOR record, `id` for cmd-inj), not a licence to weaponize.

## Evidence capture pattern
For each confirmed finding, export from Burp:
1. The **request** (method, path, headers, body — redact auth tokens/PII).
2. The **response** (status, key headers, the proof snippet).
3. Save to `evidence/EV-N.txt`; reference it in the finding. This raw exchange is what makes triage fast and the client trust the result.

## Connect it (if not already)
Burp MCP isn't part of this toolkit — it's an MCP server you run against your Burp instance. Add it to your Claude Code session (`claude mcp add …` or `.mcp.json`), restart, then it appears to `ToolSearch("burp")`. The toolkit auto-prefers it once present.

## This machine — verified working config
```bash
claude mcp add burp -- /opt/homebrew/opt/openjdk/bin/java \
  -jar /Users/we45/.BurpSuite/mcp-proxy/mcp-proxy-all.jar \
  --sse-url http://127.0.0.1:9876
```
- **Use Homebrew OpenJDK**, NOT the Burp-bundled java — the bundled one is SIGKILLed (exit 137) by macOS when run standalone → "Failed to connect".
- Burp's SSE endpoint is **root `/`** (`text/event-stream`), not `/sse`.
- Prereq: Burp Suite running + the **MCP Server** BApp enabled, listening on `127.0.0.1:9876`.
- Live tool set (27): `send_http1_request`/`send_http2_request`, `create_repeater_tab[_http2]`, `get_proxy_http_history[_regex]`, `get_proxy_websocket_history[_regex]`, `get_scanner_issues`, `generate_collaborator_payload`, `get_collaborator_interactions`, `send_to_intruder`, `set_proxy_intercept_state`, `url_encode`/`decode`, `base64_encode`/`decode`, `get/set_active_editor_contents`, options getters/setters.
