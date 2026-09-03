#!/usr/bin/env bash
# build-writeup-corpus.sh — assemble a SQLite corpus for the writeup-search MCP.
#
# Consumes:
#   packs/writeups/*.md                        — full-body CoffinXP / Lostsec writeups
#   packs/writeups/pentesterland-archive.json.gz — 6421 metadata records (title/link/bugs/bounty)
#
# Produces:
#   $WRITEUP_DB_DIR/metadata.db (default: ~/.local/share/pentest-writeups/metadata.db)
#
# Schema matches what /Users/we45/tools/pentest-agents/mcp-writeup-server/server.py expects:
#   writeups(id, title, content, source, tags, bounty, authors, programs, publication_date)
#
# Idempotent — DROP+CREATE, safe to re-run after ingesting new writeups.
# After running, /mcp reconnect writeup-search picks up the new corpus.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
REPO_ROOT="$PWD"
DATA_DIR="${WRITEUP_DB_DIR:-$HOME/.local/share/pentest-writeups}"

command -v python3 >/dev/null || { echo "build-writeup-corpus: python3 required"; exit 3; }

mkdir -p "$DATA_DIR"
DB="$DATA_DIR/metadata.db"

echo "── building writeup corpus ──"
echo "  repo:     $REPO_ROOT"
echo "  data dir: $DATA_DIR"
echo "  db:       $DB"
echo ""

python3 - "$REPO_ROOT" "$DB" <<'PY'
import gzip
import json
import re
import sqlite3
import sys
from pathlib import Path

REPO_ROOT = Path(sys.argv[1])
DB_PATH = Path(sys.argv[2])

WRITEUPS_DIR = REPO_ROOT / "packs" / "writeups"
ARCHIVE = WRITEUPS_DIR / "pentesterland-archive.json.gz"

# schema
conn = sqlite3.connect(str(DB_PATH))
conn.executescript("""
DROP TABLE IF EXISTS writeups;
CREATE TABLE writeups (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    title             TEXT NOT NULL,
    content           TEXT NOT NULL,
    source            TEXT,
    tags              TEXT,
    bounty            TEXT,
    authors           TEXT,
    programs          TEXT,
    publication_date  TEXT
);
CREATE INDEX idx_writeups_content ON writeups(content);
CREATE INDEX idx_writeups_tags    ON writeups(tags);
""")

FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---\n(.*)", re.DOTALL)

def parse_frontmatter(text):
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}, text
    fm_raw, body = m.group(1), m.group(2)
    fm = {}
    key = None
    for line in fm_raw.splitlines():
        if not line.strip():
            continue
        if line.startswith("- "):
            if key and isinstance(fm.get(key), list):
                fm[key].append(line[2:].strip().strip("'\""))
            continue
        m2 = re.match(r"^(\w[\w-]*)\s*:\s*(.*)$", line)
        if m2:
            key, val = m2.group(1), m2.group(2).strip()
            if val:
                fm[key] = val.strip("'\"")
            else:
                fm[key] = []
    return fm, body

# 1. CoffinXP writeups (full body)
md_count = 0
for md in sorted(WRITEUPS_DIR.glob("*.md")):
    text = md.read_text(errors="ignore")
    fm, body = parse_frontmatter(text)
    title = fm.get("title") or md.stem.replace("-", " ").title()
    tags_val = fm.get("tags")
    if isinstance(tags_val, list):
        tags = ", ".join(tags_val)
    else:
        tags = str(tags_val or "")
    source = fm.get("source_url") or fm.get("freedium_url") or f"packs/writeups/{md.name}"
    pub_date = fm.get("published") or fm.get("updated") or ""

    conn.execute(
        "INSERT INTO writeups(title, content, source, tags, bounty, authors, programs, publication_date) "
        "VALUES(?,?,?,?,?,?,?,?)",
        (title.strip(), body.strip(), source, tags, "", "", "CoffinXP / Lostsec", pub_date),
    )
    md_count += 1

# 2. Pentester.land archive (metadata-only records)
pl_count = 0
if ARCHIVE.exists():
    with gzip.open(ARCHIVE, "rt", encoding="utf-8") as f:
        data = json.load(f)
    records = data.get("data") if isinstance(data, dict) else data
    for rec in records or []:
        links = rec.get("Links") or []
        if not links:
            continue
        for link in links:
            title = (link.get("Title") or "").strip()
            url = (link.get("Link") or "").strip()
            if not title:
                continue
            bugs = rec.get("Bugs") or []
            authors = rec.get("Authors") or []
            programs = rec.get("Programs") or []
            bounty = (rec.get("Bounty") or "").strip() or "-"
            pub = rec.get("PublicationDate") or rec.get("AddedDate") or ""

            content_lines = [
                f"# {title}",
                "",
                f"Programs: {', '.join(programs) if programs else '-'}",
                f"Bug classes: {', '.join(bugs) if bugs else '-'}",
                f"Bounty: {bounty}",
                f"Authors: {', '.join(authors) if authors else '-'}",
                f"Published: {pub}",
                f"Source: {url}",
                "",
                "(metadata-only record — fetch the source URL for the full writeup)",
            ]
            content = "\n".join(content_lines)
            tags = ", ".join(bugs) if bugs else ""
            authors_s = ", ".join(authors)
            programs_s = ", ".join(programs)

            conn.execute(
                "INSERT INTO writeups(title, content, source, tags, bounty, authors, programs, publication_date) "
                "VALUES(?,?,?,?,?,?,?,?)",
                (title, content, url, tags, bounty, authors_s, programs_s, pub),
            )
            pl_count += 1

conn.commit()

# stats
total = conn.execute("SELECT COUNT(*) FROM writeups").fetchone()[0]

print(f"  ✓ CoffinXP (full body):        {md_count} writeups")
print(f"  ✓ Pentester.land (metadata):   {pl_count} records")
print(f"  ✓ total rows in `writeups`:    {total}")
print(f"  ✓ db size: {DB_PATH.stat().st_size / 1024:.1f} KB")

# smoke test
print()
print("  smoke test — search 'XSS WAF':")
kws = ["XSS", "WAF"]
sql = "SELECT title, source FROM writeups WHERE " + " AND ".join(["content LIKE ?"] * len(kws)) + " LIMIT 5"
params = [f"%{k}%" for k in kws]
for row in conn.execute(sql, params):
    print(f"    - {row[0][:80]}")

conn.close()
PY

echo ""
echo "── done. next: /mcp reconnect writeup-search  (in your interactive session) ──"
echo "── to rebuild after new writeups land: re-run this script ──"
