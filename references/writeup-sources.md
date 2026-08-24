# Writeup & Disclosure Sources — intel recon reference

Where to pull fresh bug-bounty writeups + disclosed reports on demand (to keep the brain current, study a class before hunting it, or match a disclosed pattern). Source list distilled from The-XSS-Rat/BountySkiller `sources.py` (we took the intel, not the app). **Unified record schema:** `source, kind, title, url, published_at, author, program, severity, bounty, tags, extra`.

> **Safety posture:** these are public feeds/datasets — pull them the safe way (single GET of a published dataset, or normal RSS consumption via WebFetch / `writeup-search` MCP / one `curl`). **Do NOT run automated HackerOne hacktivity scraping** (spoofed browser UA + deep-paging their internal GraphQL to 10k rows = ToS-restricted automated access). We already hold CBH's 681 H1-derived patterns; pull *individual* disclosed reports by URL when needed, don't bulk-scrape.

## Curated archives (best signal, safe single-fetch)

| Source | Endpoint | Notes |
|---|---|---|
| **Pentester.land** | `https://pentester.land/writeups.json` | 6,421 curated writeups (2010→Sep 2024) w/ vuln-class + program + bounty tags. **Already ingested** → `brain/writeups-corpus.md` + archived `packs/writeups/pentesterland-archive.json.gz`. Upstream stopped updating Sep 2024. |

## RSS/Atom feeds (freshness — newest ~10–40 items each, safe to poll)

| Source | Feed URL |
|---|---|
| PortSwigger Research | `https://portswigger.net/research/rss` |
| InfoSec Write-ups | `https://infosecwriteups.com/feed` |
| Intigriti blog | `https://blog.intigriti.com/feed/` |
| Google Project Zero | `https://googleprojectzero.blogspot.com/feeds/posts/default` |
| Assetnote research | `https://blog.assetnote.io/feed.xml` |
| Datadog Security Labs | `https://securitylabs.datadoghq.com/rss/feed.xml` |
| samcurry.net | `https://samcurry.net/api/feed.rss` |
| Medium (bug-bounty tags) | `https://medium.com/feed/tag/{bug-bounty,bug-bounty-writeup,bugbounty,bug-bounty-tips}` |

## HackerOne hacktivity (disclosed reports) — reference only, do not bulk-scrape

Public disclosed reports live at `https://hackerone.com/hacktivity` (filter `disclosed:true`, optional `team_handle:<program>`). To study **one** report, WebFetch its `https://hackerone.com/reports/<id>` URL. For pattern-matching at scale, prefer our local corpus (`packs/claude-bughunter/disclosed-reports/`, `references/writeups-index.md`) over live scraping. BountySkiller's GraphQL query (`CompleteHacktivityReportIndex`, sort `latest_disclosable_activity_at`) is documented in its `sources.py` if a *bounded, authorized* pull is ever needed.

## Other channels already in the toolkit
- `writeup-search` MCP — search our indexed writeup corpus by technique/payload (when connected).
- `references/writeups-index.md` — 23 practitioner writeups (packs/writeups/).
- `packs/claude-bughunter/disclosed-reports/` — 24 H1 disclosed-report pattern libraries (681 reports).

## On-demand pull recipe
1. **Study a class before hunting:** open `brain/writeups-corpus.md` → its per-class top-bounty exemplars → WebFetch the specific writeup URL for technique depth.
2. **Refresh:** WebFetch a feed URL above (or one `curl`), diff titles against `brain/writeups-corpus.md`, fold genuinely-new high-signal ones in.
3. **Full archive query:** `gunzip -c packs/writeups/pentesterland-archive.json.gz | jq '.data[] | select(.Bugs[]? | test("SSRF"))'`
