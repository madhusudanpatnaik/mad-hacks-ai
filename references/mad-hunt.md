# /mad-hunt — autonomous bug-bounty spine

The converged design from the grill. A **thin adapter** that runs autopilot's exhaustion-contract *methodology* on mad-hacks' working plumbing. Invoke: `/mad-hunt <target> [--auto]` (`--auto` = fully autonomous, never pauses; default pauses after each confirmed finding). This file IS the orchestrator — read it, then run the loop.

**North star:** bug bounty — impact-only findings, per-program scope, chain-to-payout, ready-to-submit drafts. **Posture:** adaptive-throttle, never auto-submit, never create accounts.

## Design decisions (grilled, locked)
| Node | Decision |
|---|---|
| Spine | autopilot exhaustion methodology, thin adapter on mad-hacks plumbing (autopilot/hunt ship hollow — no `rules/`, `brain.py`, `scope.yaml` — mad-hacks has working equivalents) |
| Scope gate | `scripts/scope.py --md .t3mp3st/SCOPE.md <asset>` — deterministic deny-wins, default-deny, exit-code gates automation |
| Policy | `scripts/preamble.py --md .t3mp3st/SCOPE.md` → preamble injected into EVERY hunter dispatch |
| Surface probe | `recon.sh` + `web-scan.sh` (A/B/D/E) then `surface-probe.sh` (C/F/G/H/I). Per-HOST, no cross-host inference |
| Budget | surface×payout weighted, **≥25 attempts/class hard floor** for every applicable class; up to ~50 for lit-up high-payout classes |
| Throttle | adaptive: ramp on tolerance, back off on 429/WAF → WAF-bypass ladder (block = pivot, never stop) |
| Validate | 7-Question Gate inline → survivors → `t3-verifier` (adversarial REFUTE) |
| Escalate | confirmed → `chain-builder` (recursive A→B) → re-verify chain |
| Report | platform-native (auto-detected) via `t3-reporter` + `poc-builder` + `quality-check`; **never auto-submit** |
| Boundaries | never create accounts / submit / move funds / delete data — use test creds from SCOPE.md, flag human-only steps |

## Precondition — SCOPE gate (hard)
```bash
bash scripts/scope.sh init <target>     # first run: human fills program URL, in/out scope, prohibits, rate, header
bash scripts/scope.py --md .t3mp3st/SCOPE.md <target>   # must print IN-SCOPE (exit 0) or STOP
```
No SCOPE.md / OUT-OF-SCOPE = do not proceed. Authorization comes only from the program policy, never from a reachable host.

## The loop

### 0. Policy preamble + recall
```bash
PREAMBLE=$(python3 scripts/preamble.py --md .t3mp3st/SCOPE.md)   # capture the block + PLATFORM=
bash scripts/brain.sh recall <target>                            # prior findings, EXHAUSTED vectors, lessons
```
Read `brain/writeups-corpus.md` for the target's likely classes (payout-density intel). The `$PREAMBLE` block is prepended to EVERY subagent dispatch below, together with the Top-10 mistakes from `brain/lessons.md` and the adaptive-throttle rule.

### 1. RECON → P1 host list
`t3-recon` (or `recon.sh <target> --active` if authorized) → surface map → rank hosts P1/P2. The loop is **per-P1-host**.

### 2. SURFACE PROBE (per host, mandatory before any hunter — no agent, just curl)
```bash
bash scripts/recon.sh <host>            # A: paths/files, subdomains, headers
bash scripts/web-scan.sh https://<host> # B methods, D headers/CRLF, E CORS, TLS, WAF, exposure
bash scripts/surface-probe.sh <host> --header '<traffic-id from SCOPE.md>'   # C cache, F h2, G takeover, H CF, I SPA
```
Every probe result becomes a hunter seed OR a `brain.sh note <target> "class:<X> not-applicable:<reason>"` coverage entry. Refusing to run the full A–I for a P1 host is a PRE-COMPLETION-GATE fail.

### 3. RANK classes — surface × payout
Order the canonical classes by (surface the probe lit up) × (payout density from `brain/writeups-corpus.md`). Skip classes with no surface via `not-applicable:<reason>`. Hunt high-value-high-surface first. Default seed order when tied: idor → auth-bypass → ssrf → xss → rce → the rest (`references/router.md` class table names the agent + payloads + depth per class).

### 4. HUNT LOOP (per applicable class, ranked order)
For each class, dispatch its specialist hunter (Agent tool, `model: inherit`) with:
- the `$PREAMBLE` + Top-10 mistakes + adaptive-throttle rule,
- the class row from `references/router.md` (payload file, depth-doc pick-order),
- **Depth Engine floor: ≥25 distinct attempts** (encoding-variant matrix: raw, url, double-url `%253C`, unicode-escape-then-url, html-entity, mixed-case, comment-break), up to ~50 for lit-up high-payout classes,
- **before every dispatch**: pull the class's top corpus exemplar (`brain/writeups-corpus.md`) for technique.

Log attempts → `evidence/<host>/coverage/<class>-attempts.jsonl`; write one `brain.sh note` summary per class (`class:X attempts:N result:exhausted|signal:…`).

**Adaptive throttle** (in every hunter preamble): baseline serial ~1 req/2s + traffic header + honor the SCOPE.md rate cap (HARD). Ramp (add concurrency / tighten delay) only if last ~20 reqs <300ms with zero 429/challenge. Back off (halve concurrency, double delay) on 429 / WAF-fingerprinted 403 / `Retry-After` / latency>2s / CAPTCHA, and run the WAF-bypass ladder (`references/vuln-playbooks.md#403-bypass` + `brain/payloads/xss-waf-bypass.txt`). A block is a PIVOT signal, never a stop. Per-host hard stop only after serial+max-delay+full ladder still blocked → `brain.sh note … blocked:<signal>` and move on.

### 5. VALIDATE (two-layer)
Each candidate → **7-Question Gate** inline (kill on any "no": usable now? impact on program's list? real consequence? reproducible from fresh context? attacker-attainable? triager would pay?). Survivors → dispatch **t3-verifier** (adversarial REFUTE — oracle-grounded evidence, benign explanations, blocking controls, inflated severity). Blind classes: OOB-or-it-didn't-happen (Collaborator/interactsh, one payload/param, restart between). Client-side: browser-verify. Only survivors are CONFIRMED.

### 6. ESCALATE (think like a hacker)
Every CONFIRMED finding → **chain-builder** (recursive A→B, no depth limit) to escalate toward ATO/RCE/data (the corpus proved standalone rarely pays; chains hit $50k–$288k). Re-verify each chain link. Feed `correlator` if multiple findings exist.

### 7. PRE-COMPLETION GATE (blocks early "done")
Before any summary, assert: every P1 host ran full A–I; every applicable class hit its ≥25 floor OR carries a `not-applicable`/`blocked` entry; ≥18 distinct subagent dispatches this run; every confirmed finding passed t3-verifier AND a chain attempt. Fail → return to the queue, do not summarize.

### 8. REPORT (ready-to-submit, never auto-submit)
Detect platform from `PLATFORM=` (preamble). Dispatch `t3-reporter` + `poc-builder`: platform-native draft (HackerOne/Bugcrowd/Intigriti fields) = CVSS 3.1 vector + human-tone "why it matters to THIS program" + copy-paste HTTP/curl PoC + self-contained HTML PoC where useful. Run `quality-check` + the 7-Q gate before marking **READY-TO-SUBMIT**. Write drafts to `engagements/<target>/reports/`. **STOP — the human reviews and submits.** Never auto-submit; never create accounts to reproduce.

### 9. CAPTURE
`brain.sh finding <target>` (confirmed), `brain.sh exhausted <target>` (dead vectors — never repeat), `brain.sh learn` (reusable heuristics). This is what makes the next hunt smarter.

## Absolute boundaries (regardless of scope/policy)
Never: create accounts · submit reports · enter credentials · move funds · delete/modify real data · bulk-exfiltrate · persist/backdoor. These are human-only or forbidden — flag them, don't do them. Secrets are evidence: summarize/redact, never loot.
