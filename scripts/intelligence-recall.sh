#!/usr/bin/env bash
# intelligence-recall.sh — unified query router for the mad-hacks brain.
#
# ONE interface agents call instead of the current 3-way brain.sh chain.
# Fuses results across:
#   1. LEXICAL — brain/registry/assets.db (SQLite FTS5, BM25 ranking, stdlib)
#   2. SEMANTIC — brain/registry/assets.faiss (all-MiniLM-L6-v2 cosine, opt-in)
#   3. WRITEUPS — ~/.local/share/pentest-writeups/metadata.db (6.7k rows)
#   4. TARGET   — .engagement/<target>/ or .cdc/<target>/ state (if present)
#
# Merges rankings via Reciprocal Rank Fusion (RRF, k=60) and returns a
# deduplicated, unified ranking. Absent sources are skipped silently — the
# router degrades gracefully.
#
# Usage:
#   intelligence-recall.sh "url parameter influencing backend fetch"
#   intelligence-recall.sh "jwt alg confusion" --target api.example.com --class oauth
#   intelligence-recall.sh "clickjacking" --limit 20 --json
#   intelligence-recall.sh "graphql" --sources lex,sem   # opt out of writeups+target
#
# Env / overrides:
#   MADHACKS_RRF_K=60          — RRF constant (higher = less aggressive top-heavy)
#   MADHACKS_LIMIT_PER_SOURCE  — how many raw hits per source before fusion (default 15)

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
QUERY=""
TARGET=""
CLASS=""
LIMIT=10
SOURCES="lex,sem,writeups,target"
FORMAT="text"

while [ $# -gt 0 ]; do
  case "$1" in
    --target)  TARGET="${2:-}"; shift 2 ;;
    --class)   CLASS="${2:-}"; shift 2 ;;
    --limit)   LIMIT="${2:-10}"; shift 2 ;;
    --sources) SOURCES="${2:-}"; shift 2 ;;
    --json)    FORMAT="json"; shift ;;
    --help|-h) sed -n '1,25p' "$0"; exit 0 ;;
    *)         QUERY="${QUERY:+$QUERY }$1"; shift ;;
  esac
done
[ -n "$QUERY" ] || { sed -n '1,25p' "$0"; exit 2; }

command -v python3 >/dev/null || { echo "intelligence-recall: python3 required"; exit 3; }

export REPO QUERY TARGET CLASS LIMIT SOURCES FORMAT
python3 - <<'PY'
import json, os, sqlite3, sys, subprocess
from pathlib import Path

REPO   = Path(os.environ["REPO"])
QUERY  = os.environ["QUERY"]
TARGET = os.environ["TARGET"] or ""
CLASS  = os.environ["CLASS"] or ""
LIMIT  = int(os.environ["LIMIT"])
SOURCES = set(s.strip() for s in os.environ["SOURCES"].split(",") if s.strip())
FMT    = os.environ["FORMAT"]

K_RRF  = int(os.environ.get("MADHACKS_RRF_K", "60"))
K_RAW  = int(os.environ.get("MADHACKS_LIMIT_PER_SOURCE", "15"))

FTS_DB      = REPO / "brain" / "registry" / "assets.db"
FAISS_INDEX = REPO / "brain" / "registry" / "assets.faiss"
WRITEUP_DB  = Path(os.path.expanduser("~/.local/share/pentest-writeups/metadata.db"))

# ─── source 1: LEXICAL (SQLite FTS5, BM25 ranking) ─────────
def source_lex(query):
    if not FTS_DB.exists() or "lex" not in SOURCES:
        return []
    import re
    words = re.findall(r"[A-Za-z0-9_-]+", query)
    if not words:
        return []
    match_expr = " AND ".join(f'"{w}"*' for w in words)
    conn = sqlite3.connect(str(FTS_DB))
    conn.row_factory = sqlite3.Row
    try:
        rows = conn.execute(
            "SELECT row_json, bm25(assets) AS rank FROM assets WHERE assets MATCH ? ORDER BY rank LIMIT ?",
            (match_expr, K_RAW)
        ).fetchall()
    except sqlite3.OperationalError:
        rows = []
    conn.close()
    return [{**json.loads(r["row_json"]), "_src": "lex", "_rank": i + 1}
            for i, r in enumerate(rows)]

# ─── source 2: SEMANTIC (FAISS, opt-in) ────────────────────
def source_sem(query):
    if not FAISS_INDEX.exists() or "sem" not in SOURCES:
        return []
    # Delegate to build-embeddings.py --search which handles the model load;
    # cheaper than importing faiss here every call.
    try:
        out = subprocess.check_output(
            ["python3", str(REPO / "scripts" / "build-embeddings.py"),
             "--search", query],
            stderr=subprocess.DEVNULL, timeout=45
        ).decode("utf-8", errors="ignore")
    except (subprocess.SubprocessError, FileNotFoundError):
        return []
    # Parse the human output — each match is 2 lines: header + path
    results = []
    lines = out.splitlines()
    i = 0
    while i < len(lines):
        ln = lines[i]
        # match:  [0.582]  [type    ]  Title...  (cls,...)
        if ln.strip().startswith("[") and "  [" in ln:
            try:
                score = float(ln.strip()[1:6])
                # parse type and title crudely; robust parsing not needed — the
                # actual row comes from the JSONL lookup below by title match
                after_type = ln.split("  [", 1)[1]
                type_str = after_type.split("]", 1)[0].strip()
                title_part = after_type.split("]", 1)[1].split("(")[0].strip()
                path = lines[i+1].strip() if i+1 < len(lines) else ""
                results.append({"_src": "sem", "_rank": len(results)+1,
                                "_score": score, "path": path,
                                "type": type_str, "title": title_part})
                i += 2
                continue
            except (IndexError, ValueError):
                pass
        i += 1
    return results

# ─── source 3: WRITEUP CORPUS (~/.local/share/pentest-writeups/metadata.db) ─
def source_writeups(query):
    if not WRITEUP_DB.exists() or "writeups" not in SOURCES:
        return []
    import re
    words = re.findall(r"[A-Za-z0-9_-]+", query)
    if not words:
        return []
    conn = sqlite3.connect(str(WRITEUP_DB))
    conn.row_factory = sqlite3.Row
    like_clauses = " AND ".join(["content LIKE ?"] * len(words))
    params = [f"%{w}%" for w in words] + [K_RAW]
    rows = conn.execute(
        f"SELECT id, title, source, tags, bounty, publication_date "
        f"FROM writeups WHERE {like_clauses} LIMIT ?", params
    ).fetchall()
    conn.close()
    return [{
        "_src": "writeups", "_rank": i + 1,
        "id": f"writeup:{r['id']}", "type": "writeup",
        "path": r["source"] or f"writeup#{r['id']}",
        "title": r["title"],
        "description": f"[{r['bounty'] or '-'}] {r['tags'] or ''} ({r['publication_date'] or ''})",
        "classes": (r["tags"] or "").split(", "),
    } for i, r in enumerate(rows)]

# ─── source 4: TARGET STATE (.engagement/<target>/ or .cdc/<target>/) ─
def source_target(query):
    if not TARGET or "target" not in SOURCES:
        return []
    slug = TARGET.lower().replace("/", "-").replace(":", "-")
    candidates = [
        REPO / ".engagement" / slug,
        REPO / ".cdc" / slug,
        REPO / ".t3mp3st" / slug,
    ]
    root = next((c for c in candidates if c.exists()), None)
    if root is None:
        return []
    # Read every .md/.txt in the target dir; substring-match query keywords
    import re
    words = [w.lower() for w in re.findall(r"[A-Za-z0-9_-]+", query) if len(w) > 2]
    hits = []
    for f in root.rglob("*"):
        if not f.is_file() or f.suffix not in (".md", ".txt", ".tsv"): continue
        try:
            text = f.read_text(errors="ignore")
        except Exception: continue
        lo = text.lower()
        score = sum(lo.count(w) for w in words)
        if score:
            hits.append({
                "_src": "target", "_rank": 0,   # ranks assigned after sort
                "_hit_count": score,
                "id": f"target:{f.name}",
                "type": "target-state",
                "path": str(f.relative_to(REPO)),
                "title": f.stem + f"  (engagement={slug})",
                "description": (text[:200].replace("\n", " ")),
            })
    hits.sort(key=lambda x: -x["_hit_count"])
    for i, h in enumerate(hits[:K_RAW], 1):
        h["_rank"] = i
    return hits[:K_RAW]

# ─── RRF fusion ─────────────────────────────────────────────
def rrf(source_hits, k=K_RRF):
    """Reciprocal Rank Fusion. Each doc's score = Σ 1/(k + rank_in_source)."""
    scores = {}
    seen   = {}
    for src_name, hits in source_hits.items():
        for h in hits:
            # dedup key: path OR id (whichever is stable)
            key = h.get("path") or h.get("id")
            if not key: continue
            scores[key] = scores.get(key, 0) + 1.0 / (k + h["_rank"])
            # keep the fullest record we've seen for this key
            if key not in seen or len(json.dumps(h)) > len(json.dumps(seen[key])):
                seen[key] = h
            seen[key].setdefault("_sources", set()).add(src_name)
    ranked = []
    for key, score in sorted(scores.items(), key=lambda x: -x[1]):
        r = dict(seen[key])
        r["_rrf_score"] = round(score, 6)
        r["_sources"] = sorted(r["_sources"])
        ranked.append(r)
    return ranked

# ─── run ────────────────────────────────────────────────────
# If --class was passed, augment the query with it (so lex/sem pick up class-tagged docs)
q_full = QUERY + (f" {CLASS}" if CLASS else "")

hits = {
    "lex":      source_lex(q_full),
    "sem":      source_sem(q_full),
    "writeups": source_writeups(q_full),
    "target":   source_target(QUERY),
}

fused = rrf(hits)[:LIMIT]

if FMT == "json":
    print(json.dumps({
        "query":   QUERY,
        "target":  TARGET,
        "class":   CLASS,
        "sources": {k: len(v) for k, v in hits.items()},
        "results": fused,
    }, indent=2, default=str))
else:
    print(f"── intelligence-recall  query={QUERY!r}"
          + (f"  target={TARGET}" if TARGET else "")
          + (f"  class={CLASS}"   if CLASS  else "")
          + " ──")
    for k, v in hits.items():
        if k in SOURCES:
            state = f"{len(v)} hit(s)" if v else "0 hits"
            print(f"  source: {k:9s}  → {state}")
    print()
    if not fused:
        print("  (no results across any source)")
    else:
        print(f"  RRF-fused top {len(fused)} (sources shown per row):")
        for i, r in enumerate(fused, 1):
            srcs = "+".join(r.get("_sources", []))
            cls  = ",".join(r.get("classes", [])[:3])
            print(f"  {i:>2}. [{r['_rrf_score']:.4f}]  [{r.get('type','?'):<12s}]  [{srcs:15s}]  {r.get('title','')[:60]}")
            print(f"                                                                {r.get('path','')}")
PY
