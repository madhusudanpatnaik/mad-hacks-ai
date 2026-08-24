# Writeups Corpus — distilled disclosed-bounty intel

Distilled from the Pentester.land archive: **6,421 writeups, 2010-07 → 2024-09, 1,615 with disclosed $ bounties (max $288,500).** Raw archive: `packs/writeups/pentesterland-archive.json.gz` (query on demand). Source catalog + refresh recipe: `references/writeup-sources.md`.

**How to use:** before hunting class X, read its row → WebFetch a top-bounty exemplar for technique depth. The count column = how often that class appears in disclosed writeups (prevalence signal). Ranked by writeup volume.

## Per-class prevalence + top-bounty exemplars

| Class (router) | #writeups | Top disclosed exemplars (by bounty) |
|---|---|---|
| **xss** | 1148 | Hacked Apple 3 Months ($288.5k) · MS Teams RCE Pwn2Own ($150k) · $120k/yr automation |
| **rce / cmdi** | 1058 | Hacked Apple ($288.5k) · MS Healthcare "Lethal Injection" ($203k) · Zoom RCE Pwn2Own ($200k) |
| **auth-bypass / ato** | 775 | Hacked Apple ($288.5k) · Facebook Canvas $126k · CSP-in-WebKit auth break ($100k) |
| **info-disclosure** | 653 | CSP WebKit auth ($100k) · iPhone Camera Hack ($75k) · Instagram App Access Token ($38.3k) |
| **idor / bola** | 564 | Hacked Apple ($288.5k) · crypto-co chain ($59.4k) · Hacked Google A.I. ($50k) |
| **business-logic** | 379 | CloudKit accidental delete ($64k) · Workplace by Facebook ($27.5k) · FB Business Takeover ($27.5k) |
| **ssrf** | 298 | Hacked Apple ($288.5k) · Redash CVE-2021-41192 ($90k) · Hacked Facebook Pt.2 ($54.6k) |
| **lfi / traversal** | 251 | GitHub Pages Kramdown RCEs ($25k) · Magento eCommerce ($17k) · $15k RCE debug mode |
| **sqli** | 244 | Hacked Apple ($288.5k) · Subdomain Fuzzing 35k · WP Transposh Blind SQLi ($30k) |
| **csrf** | 243 | crypto-co chain ($59.4k) · FB account takeover chain ($44.6k) · EmojiDeploy Azure RCE ($30k) |
| **open-redirect** | 177 | FB/Oculus Firebase ATO ($44.25k) · FB unsafe-redirect ATO ($28.8k) · WhatsApp CVE-2019-18426 ($12.5k) |
| **jwt / oauth / saml** | 153 | FB OAuth Framework ($55k) · FB/Oculus Firebase ATO ($44.25k) · FB unsafe-redirect ATO ($28.8k) |
| **file-upload** | 117 | Auth-bypass+upload+traversal ($23k) · GCP cloud shell ($20k) · Simple RCE examples ($15k) |
| **deserialization** | 111 | Hello Lucee! hack Apple ($20k) · GitHub Enterprise 4-chain ($12.5k) · Jackson detection ($4.5k) |
| **subdomain-takeover** | 92 | Uber internal emails ($10k) · thousands of subdomains ($5k) · lucky $4.5k |
| **xxe** | 75 | Hacked Apple ($288.5k) · XXE in browsers via ChatGPT ($28k) · 0day XXE uber.com ($9k) |
| **cache-poison** | 67 | Akamai edge worldwide SSCP ($50k) · Cache Poisoning at Scale ($40k) · GitHub Pages $35k |
| **race** | 61 | Any Instagram Account ($30k) · iCloud accounts ($18k) · Race conditions on the web ($8.45k) |
| **graphql** | 50 | Hacked Google A.I. ($50k) · Private/Archived Posts ($30k) · FB private-group de-anon ($4.5k) |
| **cors** | 50 | EmojiDeploy Azure RCE ($30k) · Stealing Yahoo Cookies ($10k) · $9,240 30-day hunt |
| **smuggling** | 43 | Akamai misconfig ($46k) · business.apple.com desync ($36k) · Powerful HTTP smuggling ($17k) |
| **ssti** | 41 | Handlebars RCE in Shopify app ($10k) · WPML authed RCE ($1.6k) · {{6*200}} → $1.2k |
| **host-header** | 28 | ATO via host-header poisoning ($2k) ×3 (host-header rarely pays high solo — chain it) |
| **llm-ai** | 27 | Hacked Google A.I. ($50k) · ChatGPT ATO web-cache-deception ($6.5k) · HuggingFace proto ($3.25k) |
| **prototype-pollution** | 25 | Mozilla Firefox ($100k) · "pollution-free internet" ($12.6k) · MongoDB gadget |
| **nosqli** | 5 | MongoDB aggregation-pipeline NoSQLi · InfluxDB NoSQLi · NoSQLi in Plain Sight |

## Signal takeaways (for CLASSIFY / prioritization)
- **Volume ≠ payout ceiling.** host-header/ssti/nosqli are low-volume + low solo payout → **chain them** (host-header→ATO, ssti→RCE). The router already tags these as chain/feeder classes.
- **Top-dollar classes**: RCE, auth-bypass/ATO, SSRF, XXE, prototype-pollution and cache-poison all show $50k-$288k exemplars — the recurring pattern is **chained to ATO or full RCE**, not standalone.
- **The single most-cited writeup** across classes is Curry et al. "We Hacked Apple for 3 Months" ($288.5k) — it chains XSS+RCE+SSRF+SQLi+XXE+IDOR+ATO; a canonical study for multi-class chaining.
- LLM-AI is small (27) but **growing post-2023** and pays ($50k Google A.I.) — expect this to be under-represented since the archive stops Sep 2024. Refresh via `references/writeup-sources.md` feeds for current LLM writeups.
