# EXTRACTION — `xalgorix`

- **Upstream:** `https://github.com/xalgorix/xalgorix` @ `98d18a458cb1cc4681cdd9fb8ef726f14167ddcb`
- **First mined:** 2026-08-25 (prose summary in `references/xalgorix-methodology.md`)
- **Last re-mined:** 2026-09-07 (prose → normalized JSONL records; schema-by-example first pass)
- **Extractor:** normalization sweep after user directive "stop measuring fold count, mine into normalized lessons + payloads + tools + patterns, not prose summaries"

## Rationale — why this pack is in the harness

Xalgorix is a Go+TS LLM-driven autonomous pentest orchestrator. We do NOT run it here (mad-hacks is keyless — Claude Code IS the reasoning engine, not an external LLM provider). What we borrow is its **methodology** (22-phase completeness checklist we can measure our own coverage against) and 5 **design patterns** (independent-verifier before shipping, weak-evidence rejection, selectable phases, skills-as-modules lazy load, adaptive throttle) — all of which are doctrinal alignments with our VERIFY + REFUTE gates.

The pack itself (1,234 files, mostly Go source) is a reference clone, not a runtime dependency.

## Extracted lessons

| Brain record | Class | Title | Source file |
|---|---|---|---|
| `brain/lessons.jsonl:L-xa-01` | `email-auth` | SPF/DKIM/DMARC/relay is a mad-hacks coverage gap | `references/xalgorix-methodology.md:26` |
| `brain/lessons.jsonl:L-xa-02` | `websocket` | WebSocket testing is a mad-hacks coverage gap | `references/xalgorix-methodology.md:28` |
| `brain/lessons.jsonl:L-xa-03` | `cms` | Non-WordPress CMS coverage gap (Drupal/Joomla/Ghost) | `references/xalgorix-methodology.md:29` |
| `brain/lessons.jsonl:L-xa-04` | `content-spoofing` | Broken-link hijacking + content spoofing gap | `references/xalgorix-methodology.md:30` |
| `brain/lessons.jsonl:L-xa-05` | `doctrine` | 'Detect vs prove' — proof-of-exploit doctrine | `references/xalgorix-methodology.md:6` |
| `brain/lessons.jsonl:L-xa-06` | `workflow` | 22-phase completeness checklist as coverage metric | `references/xalgorix-methodology.md:8-33` |

## Extracted payloads

None. Xalgorix ships no wordlists or payload sets — it's an orchestrator, not a payload archive. Its exploitation is done via wrapped external tools (nuclei, sqlmap, ffuf) whose payloads we already fold from other packs.

## Extracted tools

None. Xalgorix is deliberately NOT adopted as a runtime tool (`references/xalgorix-methodology.md:56-58` — LLM key requirement + dashboard + Go binary vendoring all rejected in favor of the mad-hacks keyless posture).

## Extracted patterns (conditional triggers)

| ID | Class | Precondition | Action | Source |
|---|---|---|---|---|
| `PAT-xa-01` | `reporting` | Candidate finding about to enter report OR marked CONFIRMED | Dispatch t3-verifier for adversarial REFUTE first | `references/xalgorix-methodology.md:39-40` |
| `PAT-xa-02` | `reporting` | About to write finding OR merge candidates | Enforce report-template.md evidence contract; reject weak evidence; dedup same root cause | `references/xalgorix-methodology.md:42-43` |
| `PAT-xa-03` | `workflow` | Focused engagement (single class or lead) | Use class-specific hunter dispatch via router.md; skip full 22-phase sweep | `references/xalgorix-methodology.md:45-46` |
| `PAT-xa-04` | `workflow` | About to load a reference/playbook/methodology doc | Use router.md load-on-CLASSIFY; do NOT preload | `references/xalgorix-methodology.md:48-49` |
| `PAT-xa-05` | `workflow` | Hunter about to burst OR target returned 429/WAF/latency spike | Honor mad-hunt.md §Adaptive-throttle; block is PIVOT signal not stop | `references/xalgorix-methodology.md:51-52` |

## Router integration

- `references/router.md` — row for "Coverage checklist against a 22-phase methodology + independent-verifier patterns" points at `references/xalgorix-methodology.md` (which is the prose summary; the atomic records above supersede it for programmatic queries but keep it as human overview).

## Verification (last run)

- Last `scripts/verify-packs.sh` result: pending re-run after this manifest lands
- Last drift check vs upstream: pinned `98d18a45` vs remote HEAD not checked this pass (would require a network fetch — do at next re-mine)

## Notes / next re-mining

- The pack has 1,234 files but only the top-level README + docs directory contribute methodology signal. The Go internals (cmd/, internal/) are the implementation of xalgorix's own orchestrator and are NOT knowledge to fold — they would be knowledge only if we were re-implementing an orchestrator, which we are not.
- Two adopted patterns already have inline enforcement (PAT-xa-01 in `t3-verifier`, PAT-xa-05 in `references/mad-hunt.md §Adaptive throttle`). Recall of these should surface the doctrinal reminder plus the enforcement path.
- Consider adding an `email-auth` hunter class to close L-xa-01 (currently GAP). If added, update this manifest.
- Consider adding a `websocket` hunter class to close L-xa-02.
