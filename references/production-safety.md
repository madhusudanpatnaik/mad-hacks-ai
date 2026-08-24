# Production & Bug-Bounty Safety — Rules of Engagement

For **authorized** testing against production / bug-bounty targets. You must *prove* the exploit (clients and triage teams pay for demonstrated impact, not theory) **without degrading service, touching real user data, or leaving anything behind.** These restrictions are hard — they override the urge to "go deeper."

## 0. Before anything — read the program/contract
The bug-bounty policy or engagement RoE is the **top authority** (above this file). Extract and record into `.t3mp3st/SCOPE.md`:
- Exact **in-scope** assets (domains, IP ranges, apps, APIs) and **out-of-scope** carve-outs.
- **Prohibited actions** (most programs ban: automated scanning, DoS, social engineering, physical, spam, brute force).
- **Rate limits / testing windows**, required **test accounts**, and any **traffic identifier** they want (header/UA).
- Whether **exploit chaining / lateral movement** is permitted, or you must stop at first proof.

## 1. Hard restrictions on production (do NOT cross)
| # | Restriction | Why |
|---|---|---|
| R1 | **No availability impact** — no DoS/DDoS, no volumetric fuzzing, no resource exhaustion, no thread-heavy scans. | You can be liable for downtime. |
| R2 | **No destructive/state-changing ops on real data** — no DELETE/DROP/UPDATE, no mass account/record creation, no deleting others' data. | Irreversible harm. |
| R3 | **No bulk data exfiltration** — prove access with **one** record, redact it. Never dump a table/bucket/mailbox. | Data-protection + trust. |
| R4 | **No access to other real users' data beyond minimal proof** — the moment you can read *one* other record, stop. If you hit PII, stop and report. | Privacy law. |
| R5 | **No persistence / backdoors / malware / C2** on prod. No web shells, no implants. | Out of scope, illegal. |
| R6 | **No credential brute-force / password spray** on prod unless the program explicitly allows it (account-lockout risk). | DoS of real users. |
| R7 | **No pivoting / lateral movement / privesc chains** beyond what scope allows — many programs stop at "first server-side proof." | Scope creep = report rejection or legal exposure. |
| R8 | **No third-party / out-of-scope assets** — CDNs, SaaS, other tenants, shared infra. | Not authorized. |
| R9 | **Throttle**: default ≤ a few req/s, `--delay` on tools, small wordlists on prod. `nuclei`/`ffuf`/`gobuster` rate-limited (`-rl`, `-rate`, `-p`). No `sqlmap --level>1 --risk>1` on prod. | Stay under WAF/DoS thresholds. |
| R10 | **Clean up** — delete every PoC artifact you created (uploaded file, test corpus, created record). Note the cleanup in the report. | Leave no trace. |
| R11 | **Tag your traffic** — add a benign identifier the blue team can filter (e.g. `X-Bug-Bounty: <handle>` or a marker in payloads) if the program asks / allows. | Distinguish research from real attack. |

## 2. Safe PoC catalog — prove impact minimally
Show the exploit fires, then stop. Use benign, self-evident, reversible proofs:

| Vuln | Safe PoC (prove, don't weaponize) | Do NOT |
|---|---|---|
| **XSS** | `alert(document.domain)` or `print(document.domain)`; screenshot firing in a real browser. Benign marker for stored. | keylogger, cookie exfil to your server, worm |
| **SQLi** | Boolean/time-based diff, or `SELECT @@version`/`current_user` (one value). Read **one** canary row. | dump tables, `--os-shell`, write files |
| **IDOR / BOLA** | Read **one** other object with your low-priv account; redact the returned PII. | enumerate/scrape all IDs |
| **SSRF** | OOB callback (interactsh) proving outbound; or fetch `http://169.254.169.254/latest/meta-data/` **metadata key name only**. | dump full IAM creds, pivot internally |
| **RCE / cmd-inj** | `id` / `whoami` / `hostname` output. | reverse shell, persistence, read sensitive files |
| **LFI / traversal** | Read a non-sensitive marker file (`/etc/hostname`) or the app's own config header. | exfil `/etc/shadow`, source dump |
| **Auth bypass / JWT** | Show you reach an authenticated route / forge a low-priv token; screenshot the unlocked action. | act as a real admin, change data |
| **Open redirect / CORS / CSRF** | Redirect to `example.com`; ACAO reflection screenshot; benign self-submitting PoC on a **test** account. | phish real users |
| **Exposed key/secret** | Validate scope (e.g. `?key=` returns 200 model list) — **redact the key**; estimate financial impact. | run up billable usage, access owner data |
| **File upload** | Upload a benign marker file, show it's served/executed with a harmless payload; delete it. | web shell |

## 3. Encode it in the run
- `scope.sh init` records the RoE; tick production restrictions there.
- Every active tool stays `receipt_required`; on prod, add throttle flags (R9).
- The **exploiter** proves one candidate, minimally, then hands to the **verifier**.
- The **reporter** frames each finding for the client: exact PoC steps + demonstrated impact + business risk + remediation + retest + **confirmation that PoC artifacts were cleaned up**.

## 4. Client / triage-ready evidence
A report that earns severity and moves fast: **(1)** exact reproducible steps + the request/response (redacted), **(2)** the *demonstrated* impact (screenshot/output, not "could lead to"), **(3)** business impact in their terms, **(4)** clear remediation + retest criteria. See `report-template.md`.

> The whole point: **maximum proof, minimum blast radius.** If proving it further would risk R1–R11, stop — a clean minimal PoC + a described escalation path is the professional result.
