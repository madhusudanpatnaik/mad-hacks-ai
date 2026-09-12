# EXTRACTION — `Awesome-Bugbounty-Writeups`

- **Upstream:** `https://github.com/devanshbatham/Awesome-Bugbounty-Writeups` @ `72010067cd49196f8f45b9137d1c0d06ad5ba915`
- **First mined:** initial clone; normalized 2026-09-08

## Rationale — why this pack is in the harness

Devansh Batham's community-curated index of disclosed bug bounty writeups, categorized by vuln class (XSS, CSRF, Clickjacking, LFI, Subdomain Takeover, DoS, Auth Bypass, SQLi, IDOR, 2FA, CORS, SSRF, Race Condition). It's a link-index, not a corpus — actual writeup bodies live on Medium/HackerOne/personal blogs. Complements `brain/writeups-corpus.md` (which ingests full bodies) with a curated per-class link list. Grep here first when hunting a specific vuln class for prior public writeups by category.

## Extracted lessons

| Brain record | Class | Title | Source |
|---|---|---|---|
| `brain/lessons.jsonl:L-abw-01` | `workflow` | Awesome-Bugbounty-Writeups is a per-class disclosed-writeup link index — grep by class | `packs/Awesome-Bugbounty-Writeups/README.md` |

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-abw-01` | `workflow` | Studying a vuln class before hunting → grep `packs/Awesome-Bugbounty-Writeups/README.md` for class-section, follow ~5 top links for real examples |

## Extracted tools

None. This is a curated Markdown index, not a runtime tool.

## Extracted payloads

None. Writeups reference external URLs, not payload files.

## Router integration

- `references/router.md` — writeup lookup / index-first for public disclosures per class

## Notes / next re-mining

- Upstream is community-maintained; refresh quarterly. New vuln-class sections mean new brain lookup coverage.
