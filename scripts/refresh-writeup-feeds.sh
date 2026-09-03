#!/usr/bin/env bash
# refresh-writeup-feeds.sh — pull fresh writeups from the 8 RSS feeds documented
# in references/writeup-sources.md and INSERT-OR-SKIP into the writeup-search DB.
#
# Idempotent — dedupes on the source URL, so re-running only adds genuinely new
# entries. Complements scripts/build-writeup-corpus.sh (which builds the base
# corpus from packs/writeups/); this script keeps it fresh.
#
# Usage:
#   scripts/refresh-writeup-feeds.sh             # pull all 8 feeds
#   scripts/refresh-writeup-feeds.sh --dry-run   # report what would land, insert nothing
#
# After running: pkill -f mcp-writeup-server  (client auto-respawns fresh DB)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
REPO_ROOT="$PWD"
DATA_DIR="${WRITEUP_DB_DIR:-$HOME/.local/share/pentest-writeups}"
DB="$DATA_DIR/metadata.db"
DRY_RUN=""
[ "${1:-}" = "--dry-run" ] && DRY_RUN="1"

[ -f "$DB" ] || { echo "refresh-writeup-feeds: $DB not found — run scripts/build-writeup-corpus.sh first"; exit 3; }
command -v python3 >/dev/null || { echo "refresh-writeup-feeds: python3 required"; exit 3; }

echo "── refreshing writeup feeds ──"
echo "  db: $DB"
echo "  dry-run: ${DRY_RUN:-no}"
echo ""

python3 - "$DB" "$DRY_RUN" <<'PY'
import sys
import sqlite3
import urllib.request
import urllib.error
import ssl
import xml.etree.ElementTree as ET
import re
import socket
from datetime import datetime, timezone

DB_PATH = sys.argv[1]
DRY_RUN = bool(sys.argv[2])

FEEDS = [
    ("PortSwigger Research",       "https://portswigger.net/research/rss"),
    ("InfoSec Write-ups",          "https://infosecwriteups.com/feed"),
    ("Intigriti blog",             "https://blog.intigriti.com/feed/"),
    ("Google Project Zero",        "https://googleprojectzero.blogspot.com/feeds/posts/default"),
    ("Assetnote research",         "https://blog.assetnote.io/feed.xml"),
    ("Datadog Security Labs",      "https://securitylabs.datadoghq.com/rss/feed.xml"),
    ("samcurry.net",               "https://samcurry.net/api/feed.rss"),
    ("Medium bug-bounty",          "https://medium.com/feed/tag/bug-bounty"),
    ("Medium bug-bounty-writeup",  "https://medium.com/feed/tag/bug-bounty-writeup"),
    ("Medium bugbounty",           "https://medium.com/feed/tag/bugbounty"),
    ("Medium bug-bounty-tips",     "https://medium.com/feed/tag/bug-bounty-tips"),
]

# Bug-class keyword map — used to auto-tag feed entries by inferred class.
# Broad matches; a hunter can filter further in the search query.
BUG_KEYWORDS = {
    "xss":         ["xss", "cross-site scripting", "cross site scripting"],
    "ssrf":        ["ssrf", "server-side request forgery"],
    "sqli":        ["sqli", "sql injection", "sqlmap", "ghauri"],
    "rce":         ["rce", "remote code execution", "command injection", "code execution"],
    "idor":        ["idor", "bola", "broken access", "insecure direct object"],
    "auth":        ["auth bypass", "authentication bypass", "account takeover", "ato"],
    "oauth":       ["oauth", "openid", "oidc"],
    "saml":        ["saml"],
    "jwt":         ["jwt", "json web token", "alg none", "alg:none"],
    "ssti":        ["ssti", "template injection"],
    "xxe":         ["xxe", "xml external entity"],
    "csrf":        ["csrf", "samesite"],
    "cors":        ["cors misconfig", "cors reflection"],
    "lfi":         ["lfi", "local file inclusion", "path traversal", "directory traversal"],
    "rfi":         ["rfi", "remote file inclusion"],
    "crlf":        ["crlf", "http header injection", "response splitting"],
    "open-redirect":["open redirect", "redirect_uri"],
    "cache-poison":["cache poisoning"],
    "cache-deception":["cache deception"],
    "request-smuggling":["request smuggling", "http smuggling", "h2c smuggling"],
    "prototype-pollution":["prototype pollution"],
    "race":        ["race condition"],
    "deserialization":["deserialization", "insecure deserialization"],
    "graphql":     ["graphql"],
    "nosql":       ["nosql injection", "mongodb injection"],
    "file-upload": ["file upload"],
    "subdomain-takeover":["subdomain takeover"],
    "cve":         ["cve-"],
    "llm":         ["llm ", "prompt injection", "ai security", "agentic"],
    "cloud":       ["aws imds", "gcp metadata", "azure metadata", "iam privilege"],
}

def infer_classes(text):
    lo = text.lower()
    hits = [cls for cls, kws in BUG_KEYWORDS.items() if any(k in lo for k in kws)]
    return hits

# XML namespaces we may hit
NS = {
    "atom":    "http://www.w3.org/2005/Atom",
    "content": "http://purl.org/rss/1.0/modules/content/",
    "dc":      "http://purl.org/dc/elements/1.1/",
}

def _text(node, tag_variants, ns_prefix=None):
    """Return the first non-empty text from any tag variant, checking both plain and namespaced."""
    if node is None:
        return ""
    for t in tag_variants:
        for path in (t, f"atom:{t}", f"dc:{t}"):
            try:
                found = node.find(path, NS) if ":" in path else node.find(path)
                if found is not None and (found.text or found.get("href")):
                    return (found.text or found.get("href") or "").strip()
            except Exception:
                continue
    return ""

def parse_feed(name, url, xml_bytes):
    """Return list of {title, link, description, author, published}."""
    entries = []
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError as e:
        print(f"  [parse-error] {name}: {e}", file=sys.stderr)
        return entries

    # RSS 2.0: <rss><channel><item>...
    for item in root.findall(".//item"):
        title = _text(item, ["title"])
        link  = _text(item, ["link", "guid"])
        desc  = _text(item, ["description"]) or _text(item, ["content:encoded"])
        auth  = _text(item, ["author", "dc:creator"])
        pub   = _text(item, ["pubDate", "dc:date"])
        if title and link:
            entries.append({"title": title, "link": link, "description": desc or "",
                           "author": auth or "", "published": pub or ""})

    # Atom: <feed><entry>...
    for entry in root.findall("atom:entry", NS):
        title = _text(entry, ["title"])
        # Atom uses <link href="...">
        link_el = entry.find("atom:link", NS)
        link = link_el.get("href") if link_el is not None else ""
        desc = _text(entry, ["summary", "content"])
        auth_el = entry.find("atom:author/atom:name", NS)
        auth = (auth_el.text or "").strip() if auth_el is not None else ""
        pub  = _text(entry, ["published", "updated"])
        if title and link:
            entries.append({"title": title, "link": link, "description": desc or "",
                           "author": auth or "", "published": pub or ""})

    return entries

def fetch(url, timeout=15):
    req = urllib.request.Request(url, headers={
        "User-Agent": "mad-hacks/refresh-writeup-feeds (RSS reader; single GET, no scraping)"
    })
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
        return resp.read()

# ── connect DB
conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row

# Non-unique index for fast SELECT-then-INSERT dedup.
# We don't use a UNIQUE constraint because the initial pentester.land archive
# already contains duplicate source URLs across records; dedup happens via the
# explicit `SELECT WHERE source = ?` check per entry below.
existing = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='index'").fetchall()}
if "idx_writeups_source" not in existing:
    conn.execute("CREATE INDEX IF NOT EXISTS idx_writeups_source ON writeups(source)")
    conn.commit()

before_count = conn.execute("SELECT COUNT(*) FROM writeups").fetchone()[0]

# ── pull each feed
totals = {"added": 0, "dupe": 0, "class_hits": {}}
per_feed = []

for name, url in FEEDS:
    added = 0
    dupe = 0
    err = ""
    entries = []
    try:
        socket.setdefaulttimeout(15)
        xml_bytes = fetch(url)
        entries = parse_feed(name, url, xml_bytes)
    except (urllib.error.URLError, urllib.error.HTTPError, socket.timeout, ssl.SSLError) as e:
        err = str(e)[:60]

    if err:
        per_feed.append((name, len(entries), 0, 0, f"ERR: {err}"))
        continue

    for e in entries:
        # Dedup: any existing row with the same source URL?
        exists = conn.execute("SELECT 1 FROM writeups WHERE source = ? LIMIT 1", (e["link"],)).fetchone()
        if exists:
            dupe += 1
            continue

        classes = infer_classes(f"{e['title']} {e['description']}")
        for c in classes:
            totals["class_hits"][c] = totals["class_hits"].get(c, 0) + 1

        title = e["title"][:500]
        # Build a searchable content block (RSS descriptions can be HTML — strip crude)
        clean_desc = re.sub(r"<[^>]+>", " ", e["description"])
        clean_desc = re.sub(r"\s+", " ", clean_desc).strip()[:2000]
        content = "\n".join([
            f"# {title}",
            "",
            f"Feed:     {name}",
            f"Author:   {e['author'] or '-'}",
            f"Published: {e['published'] or '-'}",
            f"Classes:  {', '.join(classes) if classes else '-'}",
            f"Source:   {e['link']}",
            "",
            clean_desc,
            "",
            "(RSS-feed entry — fetch the source URL for the full writeup)",
        ])
        tags = ", ".join(classes)

        if not DRY_RUN:
            try:
                conn.execute(
                    "INSERT INTO writeups(title, content, source, tags, bounty, authors, programs, publication_date) "
                    "VALUES(?,?,?,?,?,?,?,?)",
                    (title, content, e["link"], tags, "-", e["author"] or "", name, e["published"] or "")
                )
                added += 1
            except sqlite3.IntegrityError:
                dupe += 1
        else:
            added += 1

    per_feed.append((name, len(entries), added, dupe, ""))
    totals["added"] += added
    totals["dupe"] += dupe

if not DRY_RUN:
    conn.commit()

after_count = conn.execute("SELECT COUNT(*) FROM writeups").fetchone()[0]

# ── report
print(f"{'feed':<28} {'entries':>8} {'added':>7} {'dupe':>7}  note")
print("-" * 68)
for name, ne, na, nd, note in per_feed:
    print(f"{name:<28} {ne:>8} {na:>7} {nd:>7}  {note}")
print("-" * 68)
print(f"{'TOTAL':<28} {sum(x[1] for x in per_feed):>8} {totals['added']:>7} {totals['dupe']:>7}")
print()
print(f"  rows before: {before_count:>6}")
print(f"  rows after:  {after_count:>6}")
print(f"  delta:       {after_count - before_count:>+6}")
if totals["class_hits"]:
    print()
    print("  new writeups by inferred class (top 15):")
    for cls, n in sorted(totals["class_hits"].items(), key=lambda x: -x[1])[:15]:
        print(f"    {n:>4}  {cls}")

conn.close()
if DRY_RUN:
    print()
    print("  (dry-run — no rows written)")
PY

echo ""
echo "── done. next: pkill -f mcp-writeup-server  (client auto-respawns w/ fresh DB) ──"
