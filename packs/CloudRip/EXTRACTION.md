# EXTRACTION — `CloudRip`

- **Upstream:** `https://github.com/moscovium-mc/CloudRip` @ `5bd7d54a6976e86bcb5a816886b2b8432a81967c` (MIT)
- **First mined:** 2026-11-04 (initial clone) · **Re-mined:** 2026-09-08 (normalized to JSONL)
- **Extractor:** shallow-pack raise-the-floor pass

## Rationale — why this pack is in the harness

CloudRip is a focused Python tool for one job: **discover the origin IP behind Cloudflare** by scanning subdomains. Cloudflare-fronted targets are the single most common "we can't get past the WAF" dead-end in bug bounty; a subdomain that exposes the origin IP is often the whole bypass. Complements the existing `AKAMAI ORIGIN-IP + HOST-HEADER BYPASS METHODOLOGY` lesson in `brain/lessons.md` (which uses crt.sh SAN mining) — CloudRip does the subdomain-scan variant. Two paths, more coverage.

## Extracted lessons

None as pure lessons — the knowledge is action-shaped and lives as a tool + pattern.

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-cr-01` | `cloudflare-bypass` | Target returns cf-ray or CF interstitial → run CloudRip on apex + subdomains BEFORE WAF-bypass ladder |

## Extracted payloads

None. Not a payload archive.

## Extracted tools

| ID | Name | Purpose | Install |
|---|---|---|---|
| `T-cloudrip` | `CloudRip` | Cloudflare origin-IP discovery via subdomain scanning | `git clone .../CloudRip && pip install -r requirements.txt` |

`execution_mode: receipt_required` (touches external DNS + issues HTTP fetches; needs operator authorization on the target).

## Router integration

- `references/router.md` — cloudflare-bypass row (implicit — via retrieval `brain.sh recall-class cloudflare-bypass`)

## Notes / next re-mining

- Upstream is at MIT and small (~1 Python file). Re-mining every 3 months is enough — the tool's contract is stable.
- Consider wiring CloudRip into `scripts/surface-probe.sh` phase H (Cloudflare) as an automatic follow-up when cf-ray is detected — currently manual.
