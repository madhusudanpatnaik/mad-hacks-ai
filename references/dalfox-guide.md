# dalfox-guide — v3 operator guide

**Source:** [github.com/hahwul/dalfox](https://github.com/hahwul/dalfox) (MIT, © 2020 hahwul). Full clone at [`packs/dalfox/`](../packs/dalfox/) — Rust v3.2.2, edition 2024. Ships its own `skills/dalfox/` agent bundle upstream — we borrow the methodology + integration patterns; nothing is compiled here.

**Why dalfox joins the mad-hacks XSS lane:** v3 is not just a scanner. It ships a **native OAST/interactsh integration** (`--blind-oob`) and a **6-tool MCP stdio server** — both of which we would otherwise wrap ourselves. When dalfox is present, prefer it over hand-rolled `curl` + `scripts/oob.sh` loops for the XSS class.

---

## 0. Version discipline (READ FIRST — installed vs upstream)

| Path | Version | Language | Why it matters |
|------|--------|----------|----------------|
| `/Users/we45/go/bin/dalfox` (installed) | **v2.13.0** | Go | Legacy v2 branch. Pipe syntax is `... | dalfox pipe`. Get-only OAST via `-b`. No MCP. |
| `packs/dalfox/` (upstream, this ingest) | **v3.2.2** | Rust (edition 2024) | v3 rewrite. Pipe syntax is `... | dalfox scan`. Native OAST (`--blind-oob`) with interactsh backend. Native MCP stdio server. New output formats (jsonl, sarif, toml). |

**Recommended upgrade path:**
```bash
brew uninstall --force dalfox 2>/dev/null || true
brew install dalfox                              # macOS/Linux, tracks v3 upstream
# or nix flakes:  nix run github:hahwul/dalfox
```
After upgrade, `dalfox --version` should report v3.x. All v2 `dalfox pipe` recipes in `references/recon-oneliners.md` continue to work (hidden `pipe`/`url`/`file` compat commands stay), but the canonical v3 form is `dalfox scan` for all input modes with auto-detection.

**Doctrine gate:** `receipt_required` (active). Same execution mode as v2 — send only with confirmed scope, honor program rate limits, throttle with `--rate-limit`.

---

## 1. Subcommands (canonical v3 map)

| Sub | Purpose | Prod-safety |
|---|---|---|
| `scan` | The scanner. Auto-detects: single URL, file path, stdin pipe, or raw HTTP. **No subcommand at all defaults to `scan`.** | `receipt_required` |
| `server` | Async scan API server (axum). Queue-based, cancellable. In-memory jobs. | Local-only; do not expose |
| `payload` | Emit / inspect payloads (canonical + generated + remote providers). | `safe_command` |
| `mcp` | **MCP stdio server** — 6 tools for agent orchestration. See §4. | `safe_command` (stdio) |
| `completion` | Emit shell completions (`bash`/`zsh`/`fish`/`powershell`/`elvish`). | `safe_command` |
| hidden compat | `url`, `file`, `pipe` — routes to `scan`. `man` — emits roff. | as above |

**Exit codes (`ScanOutcome`):** `0` = clean · `1` = findings · `2` = error. Wire these into your dispatch script.

---

## 2. The scan flags that matter

Copy-paste operator recipes for the XSS lane:

```bash
# 1. Single URL, WAF-adaptive, blind XSS via native OAST, streaming JSON findings
dalfox scan 'https://target/search?q=FUZZ' \
  --inject-marker FUZZ \
  --blind-oob \
  --waf-min-confidence 0.8 \
  --format jsonl --stream-findings --output findings.jsonl

# 2. File mode (urls.txt), custom payload set, POC as curl commands
dalfox scan urls.txt \
  --custom-payload brain/payloads/xss-waf-bypass.txt \
  --poc-type curl \
  --format markdown --output report.md

# 3. Pipe from gau/katana into dalfox (v3 canonical: `scan`, not `pipe`)
echo target.com | gau | dalfox scan --format jsonl --stream-findings --include-all

# 4. Custom injection point in header, authenticated
dalfox scan https://target/api/search \
  -H 'Authorization: Bearer $TOKEN' \
  -H 'X-Search: FUZZ' --inject-marker FUZZ \
  --format sarif --output findings.sarif

# 5. Raw HTTP file (Burp request export), method preserved
dalfox scan raw-request.http --format json --output findings.json

# 6. Preflight-only (no attack payloads — safe recon, honored on prod)
dalfox scan 'https://target/search?q=FUZZ' --dry-run
```

**Non-obvious flags** (from `src/cmd/scan/args.rs`):
- `--baseline-mode` — establish response baseline before probing (kills false positives from dynamic pages)
- `--waf-min-confidence <0..1>` — WAF fingerprint confidence gate; below this, dalfox skips WAF-aware payload generation
- `--rate-limit / -r` (alias `--rl`) — outbound RPS ceiling; **use this on bounty targets**
- `--workers` / `--max-concurrent-targets` / `--max-targets-per-host` — bounded concurrency (never unbounded async fan-out — enforced in code)
- `--custom-payload <file>` — swap in our per-context payloads (`brain/payloads/xss-by-context.md` extracts, or `xss.txt`)
- `--remote-wordlists <urls>` — comma-separated URLs to fetch payload lists at start; process-cached via `OnceLock`
- `--include-request` / `--include-response` / `--include-all` — attach the raw HTTP exchange to findings; **`--include-all` is the mad-hacks default for evidence-grade output**
- `--stream-findings` — emit findings live as they land (pairs with `--format jsonl` for pipe-into-something)
- `--poc-type {plain|curl|httpie|http-request}` — copy-pasteable PoC format for the report
- `--dry-run` — preflight only; **use as your first probe on any new target**

Full CLI reference: `dalfox --help` after upgrade, or [dalfox.hahwul.com/reference/cli/](https://dalfox.hahwul.com/reference/cli/).

---

## 3. Native OOB (`--blind-oob`) — supersedes `scripts/oob.sh` for the XSS lane

`packs/dalfox/src/oob/` is a **first-class subsystem** with an `interactsh` submodule. What `dalfox scan --blind-oob` does automatically:

1. Registers with the ProjectDiscovery interactsh mesh — default order: `oast.pro`, `oast.live`, `oast.site`, `oast.online`, `oast.fun`, `oast.me`.
2. Mints a **unique callback host per injected payload**.
3. Injects the blind-XSS payload with that host as the callback (same shape as `-b`).
4. Polls the OAST server, decrypts interactions, and **correlates each callback back to the exact (target, param, payload) that triggered it**.
5. Reports the correlation in findings — no manual ledger, no `attribute` step.

**When to use dalfox's OOB vs our `scripts/oob.sh`:**
- **XSS lane** (`xss-hunter` dispatch) → **dalfox `--blind-oob`** always. It's built for XSS blind-callback shapes and correlation is automatic.
- **Non-XSS blind classes** (SSRF/XXE/SQLi/RCE) → **`scripts/oob.sh`** — those don't have an injection pipeline built in the same way.

**Flags:**
- `--blind-oob` — enable OAST; auto-picks a server from `DEFAULT_SERVERS`
- `--blind-oob-server <domain>` — pin a specific OAST host (self-hosted interactsh: `--blind-oob-server oob.internal.example`)
- `--blind-oob-secret <token>` — auth token for a self-hosted server
- `--blind-oob-wait <sec>` — seconds to keep draining callbacks after the scan's last request (default: something conservative; extend for slow-fire triggers)

**The doctrine rule stays:** server echoing your callback URL in an error message is NOT confirmation. Only actual OAST DNS+HTTP interactions count. Dalfox's registry enforces this by only emitting findings on real callbacks.

---

## 4. MCP stdio server — **6-tool integration**

`dalfox mcp` starts a JSON-RPC stdio server exposing 6 tools. Register it in the operator's own Claude Code session and it auto-appears in `ToolSearch("dalfox")` — same pattern as Burp MCP.

**Registration:**
```bash
claude mcp add dalfox -- dalfox mcp
# then confirm at the top of any hunter dispatch:
ToolSearch("dalfox")
```

**The 6 tools (from `src/mcp/mod.rs`):**

| Tool | Purpose | Blocking / async |
|---|---|---|
| `scan_with_dalfox` | Start an XSS scan on a target URL. `wait=true` returns the same shape as `get_results_dalfox` in one call (preferred for short scans). `wait=false` returns immediately with a `scan_id` to poll. | Async, cancellable |
| `get_results_dalfox` | Fetch status + results by `scan_id`. Includes polling hints. | Async |
| `list_scans_dalfox` | List all tracked scans + statuses (queued/running/done/error/cancelled). | Sync |
| `cancel_scan_dalfox` | Cancel a queued or running scan. Real cancellation via `AtomicBool` checked in scan loops. | Sync |
| `delete_scan_dalfox` | Remove a completed scan from the retention window. | Sync |
| `preflight_dalfox` | Analyze target WITHOUT attack payloads — parameter discovery + impact estimate. **Use this on new targets before firing anything.** Bounded concurrency (`MAX_PREFLIGHT_CONCURRENCY`) with at-capacity backpressure. | Async |

**Doctrine mapping:**
- `preflight_dalfox` → `safe_command` (no payloads sent)
- `scan_with_dalfox` → `receipt_required` (real payloads; honor program scope + rate)
- `cancel_scan_dalfox` / `delete_scan_dalfox` → `safe_command`

**Progress fields returned by all scan tools:** `params_total`, `params_tested`, `requests_sent`, `findings_so_far` — track them in `t3-scanner` / `xss-hunter` dispatch briefings so the operator sees live progress.

---

## 5. Output formats + POC types

**Formats** (`--format`): `plain` · `json` · `jsonl` · `markdown` · `sarif` · `toml`.
- Machine-readable formats (`json`/`jsonl`/`sarif`/`toml`) **auto-suppress the banner** — stdout stays parseable.
- Pair `jsonl` + `--stream-findings` for line-per-finding streaming into a `while read` loop.
- `sarif` folds directly into GitHub code-scanning + most SAST dashboards.

**POC types** (`--poc-type`): `plain` · `curl` · `httpie` · `http-request`.
- `curl` — for pentest reports, copy-paste reproducible
- `http-request` — raw HTTP block for Burp/proxy replay
- `httpie` — cleaner for docs

**Evidence contract for mad-hacks reports** (fold into t3-reporter):
- Use `--include-all` so `include_request` + `include_response` both attach to every finding.
- `type_description` is always present alongside the single-letter `type` code — the report should quote the long form.
- JSON/JSONL envelope's `meta.target_summary` gives per-target status/findings/error_code — feed into the report's finding-density section.

---

## 6. WAF handling (`src/waf/`)

Dalfox fingerprints the WAF and tunes payload generation. Two knobs:
- `--waf-min-confidence <0..1>` — fingerprint confidence gate. At the default, dalfox is aggressive about identifying WAFs. Raise to 0.8+ if it's mis-classifying and you want a strict match.
- Combined with our `brain/payloads/xss-waf-bypass.txt` via `--custom-payload`, you get: dalfox-fingerprinted WAF + our coffinxp/MrHex/CYBERTIX bypass set = wide coverage.

If dalfox reports **no WAF fingerprint** but a payload is being stripped, dispatch the `waf-profiler` agent for a second opinion — dalfox's fingerprints don't cover every custom appliance.

---

## 7. Mad-hacks integration matrix

| Hunter / agent | How to use dalfox | Fallback |
|---|---|---|
| **xss-hunter** (reflected/DOM) | `dalfox scan <url-with-FUZZ> --inject-marker FUZZ --blind-oob --format jsonl --stream-findings --include-all` — feed each JSONL line into the VERIFY gate | curl + `brain/payloads/xss-by-context.md` |
| **xss-hunter** (stored) | `dalfox scan urls.txt --custom-payload brain/payloads/xss-waf-bypass.txt` on the endpoints that persist, then re-fetch the rendering page | manual injection → browser-verifier |
| **t3-scanner** (WEAPONIZE phase) | `dalfox scan --dry-run <url>` — cheap preflight for parameter discovery + impact estimate, no attack traffic | web-scan.sh |
| **CDC harness (research mode)** | `dalfox mcp` MCP server → CDC hunters call `preflight_dalfox` for safe surface mapping, then `scan_with_dalfox` (wait=true) for short scans | scripts/oob.sh + curl loops |
| **/mad-hunt (bug-bounty mode)** | `--rate-limit` at program cap, `--waf-min-confidence 0.7`, `--blind-oob` for stored/blind chains | same |
| **browser-verifier** | Consumes dalfox findings via SARIF, replays each PoC in a real browser | — |

---

## 8. Comparison — dalfox vs mad-hacks native

| Capability | dalfox v3 | mad-hacks native | Recommendation |
|---|---|---|---|
| Reflected/DOM XSS scanning | ✅ mature, parameter mining + AST-assisted | manual curl + `xss-by-context.md` payloads | **prefer dalfox** for scale |
| Blind XSS OAST correlation | ✅ native `--blind-oob` with interactsh | `scripts/oob.sh` (generic OOB) | **prefer dalfox** for XSS class |
| WAF fingerprint + bypass | ✅ built-in | `brain/payloads/xss-waf-bypass.txt` | **combine** — dalfox fingerprint + our payload set via `--custom-payload` |
| MCP integration | ✅ 6-tool stdio server | `ToolSearch("dalfox")` hooks | **register** `claude mcp add dalfox -- dalfox mcp` once, agents auto-adapt |
| Report formats | ✅ SARIF/JSON/JSONL/Markdown/TOML | `report.sh build-{html,docx,pdf}` | **feed dalfox JSONL → report.sh** (dalfox emits findings; report.sh assembles deliverable) |
| Doctrine gates (VERIFY/REFUTE) | ❌ no native adversarial validator | `t3-verifier` + visible verdict card | **dalfox emits → t3-verifier disproves → report** |
| Chain building | ❌ single-class only | `chain-builder` agent | **dalfox for XSS primitives → chain-builder to compose** |

---

## 9. Not-to-do

- Do not run `dalfox scan` on a target without scope confirmation. `receipt_required` still applies — dalfox does not know about your engagement.
- Do not point `--blind-oob-server` at a third-party OAST server without disclosing it to the client — callbacks contain URL context.
- Do not skip `--rate-limit` on bug-bounty programs — dalfox will happily saturate. Match the program's stated rate cap.
- Do not compile dalfox from `packs/dalfox/` — it's a reference clone. Install via `brew install dalfox` for the operational binary.

---

## 10. Attribution + License

- Repo: [github.com/hahwul/dalfox](https://github.com/hahwul/dalfox)
- License: MIT (see `packs/dalfox/LICENSE.txt`)
- Author: hahwul (© 2020–)
- Ingested at: 2026-09-01 (shallow clone, `--depth 1`, at v3.2.2)
- What we copied: methodology (subcommand map, MCP tool contract, OOB pipeline, output format matrix, WAF handling, evidence contract). Nothing compiled; no source vendored.
