#!/usr/bin/env python3
"""
build-registry.py — walk the toolkit and emit brain/registry/assets.jsonl,
a machine-readable inventory of every asset (references, scripts, tools,
payloads, lessons, writeups) with a common schema.

Idempotent — regenerate any time (DROP + WRITE, single JSONL). Zero external
dependencies (stdlib only).

Schema per row:
  {
    "id":              "type:short-name",
    "type":            "reference | script | tool | payload | lesson | writeup | agent",
    "path":            "scripts/xss-surface.sh",
    "title":           "XSS surface probe",
    "description":     "first paragraph / docstring / summary",
    "capabilities":    ["xss-surface-detection", ...],
    "classes":         ["xss", "ssrf", ...],
    "technologies":    ["wordpress", "graphql", ...],   # inferred
    "prerequisites":   ["curl", "python3", ...],
    "commands":        ["bash scripts/xss-surface.sh <url>"],
    "outputs":         ["evidence/<host>/surface/J-xss-*.txt"],
    "provenance":      {"source": "path/to/source", "extracted_at": "..."},
    "epistemic_status":"verified | derived | inferred",  # verified=file exists+parsed cleanly
    "confidence":      "high | medium | low",
    "last_verified":   "2026-09-04T..."
  }

Usage:
    scripts/build-registry.py                   # write to brain/registry/assets.jsonl
    scripts/build-registry.py --stats           # print counts, don't write
    scripts/build-registry.py --search <query>  # regenerate + print matches
"""

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REGISTRY_DIR = REPO / "brain" / "registry"
REGISTRY_FILE = REGISTRY_DIR / "assets.jsonl"
FTS_DB = REGISTRY_DIR / "assets.db"     # SQLite FTS5 index (BM25 ranking)

# ─── class keyword map (aligned with brain/lesson-index.md) ──
CLASS_KEYWORDS = {
    "ssrf":          ["ssrf", "oob", "collaborator", "interactsh", "oastify", "webhook", "imdsv", "169.254"],
    "xss":           ["xss", "reflection", "stored xss", "dom xss", "pastejack", "blind-xss", "dompurify", "mxss", "dalfox"],
    "sqli":          ["sqli", "sql injection", "sqlmap", "ghauri", "time-based", "boolean-blind", "union-based"],
    "idor":          ["idor", "bola", "object-level", "multi-tenant"],
    "auth-session":  ["session", "jwt", "oauth", "saml", "mfa", "auth bypass", "login", "bearer"],
    "rce":           ["rce", "command injection", "deserial", "ssti", "eval", "exec", "os command"],
    "lfi":           ["lfi", "path traversal", "file inclusion", "directory traversal"],
    "crlf":          ["crlf", "%0d", "%0a", "header injection", "response splitting"],
    "cache-poison":  ["cache poisoning", "unkeyed header"],
    "cache-deception": ["cache deception", "static extension", "path poison"],
    "xxe":           ["xxe", "xml entity", "xml external", "billion laughs"],
    "cors":          ["cors", "origin reflection", "access-control-allow"],
    "csrf":          ["csrf", "samesite", "cross-site request"],
    "ratelimit":     ["rate limit", "429", "brute-force", "brute force", "otp brute"],
    "recon":         ["recon", "subfinder", "nuclei", "katana", "httpx", "wayback", "crt.sh", "shodan", "asn", "dnsx", "gau"],
    "burp":          ["burp", "repeater", "intruder", "toolsearch", "mcp"],
    "workflow":      ["workflow", "orchestrat", "brain", "lesson", "router", "dispatch", "cdc harness"],
    "safety":        ["production-safety", "authorization", "scope", "destructive"],
    "reporting":     ["report", "evidence", "verdict", "triager", "cvss", "cwe", "severity"],
    "race":          ["race", "toctou", "parallel request"],
    "business-logic":["business logic", "workflow bypass", "coupon", "price manipulation"],
    "mass-assignment":["mass assign", "admin flag", "__proto__"],
    "wordpress":     ["wordpress", "wpscan", "wp-", "xmlrpc", "admin-ajax"],
    "graphql":       ["graphql", "introspection", "batching"],
    "registration":  ["registration", "signup", "sign-up", "email verification"],
    "punycode":      ["punycode", "idn", "homograph"],
    "file-upload":   ["file upload", "svg upload", "extension filter"],
    "open-redirect": ["open redirect", "returnurl", "redirect_uri", "returnto"],
    "subdomain-takeover": ["subdomain takeover", "cname", "dangling", "nosuchbucket"],
    "info-disclosure":["info disclosure", "stack trace", "debug endpoint", ".env", ".git"],
    "oauth":         ["oauth", "openid", "oidc", "pkce", "kid", "alg confusion"],
    "saml":          ["saml", "xsw", "assertion replay"],
    "mfa":           ["mfa", "2fa", "totp", "otp", "backup code"],
    "llm-ai":        ["llm", "prompt injection", "tool abuse", "rag", "mcp attack", "agentic"],
    "websocket":     ["websocket", "ws://", "wss://", "upgrade"],
    "cloud":         ["cloud", "s3", "gcs", "azure blob", "iam", "metadata", "imds", "cognito"],
    "tls":           ["tls", "ssl", "cert", "heartbleed", "openssl"],
    "active-directory":["active directory", "ad-breach", "kerberos", "kerberoast", "dcsync", "bloodhound", "ntlm relay"],
    "android":       ["android", "apk", "apktool", "jadx", "masvs"],
    "clickjacking":  ["clickjacking", "ui redressing", "frame busting", "x-frame-options"],
    "hpp":           ["http parameter pollution", "hpp", "parameter pollution"],
    "deadangle":     ["deadangle", "verified", "inferred", "assumed"],
    "handoff":       ["handoff", "engagement handoff"],
    "dalfox":        ["dalfox", "--blind-oob", "preflight_dalfox", "rmcp"],
    "waf-bypass":    ["waf", "waf bypass", "cloudflare", "akamai", "aws waf"],
    "http-smuggling":["http smuggling", "request smuggling", "h2c", "desync"],
    "prototype-pollution":["prototype pollution", "__proto__ pollution"],
    "nosqli":        ["nosql injection", "mongodb injection"],
    "ldap":          ["ldap injection"],
    "host-header":   ["host header injection", "host header"],
    "ctf":           ["ctf", "capture the flag"],
    "mobile":        ["mobile", "android", "ios", "apk", "ipa"],
    "binary":        ["binary", "reverse engineering", "checksec", "gdb"],
    "web3":          ["web3", "solidity", "smart contract", "foundry"],
}

TECH_KEYWORDS = {
    "wordpress": ["wordpress", "wpscan", "wp-"],
    "graphql":   ["graphql"],
    "nextjs":    ["next.js", "next-auth", "app router"],
    "django":    ["django"],
    "rails":     ["rails"],
    "aws":       ["aws", "imds", "s3", "iam"],
    "gcp":       ["gcp", "google cloud"],
    "azure":     ["azure"],
    "kubernetes":["kubernetes", "k8s"],
    "nodejs":    ["node.js", "node ", "npm"],
    "react":     ["react"],
    "vue":       ["vue"],
    "angular":   ["angular"],
    "spring":    ["spring boot", "spring-boot"],
    "laravel":   ["laravel"],
    "wordpress": ["wordpress", "wpscan"],
}

# ─── helpers ────────────────────────────────────────────────
def ts_now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")

def sha_short(text):
    return hashlib.sha256(text.encode("utf-8", errors="ignore")).hexdigest()[:12]

def infer_from_text(text, keyword_map):
    lo = text.lower()
    return sorted({tag for tag, kws in keyword_map.items() if any(k in lo for k in kws)})

def slugify(s):
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s[:60]

def read_head(path, chars=3000):
    try:
        return path.read_text(errors="ignore")[:chars]
    except Exception:
        return ""

# ─── extractors per asset type ──────────────────────────────
FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---\n(.*)", re.DOTALL)

def _parse_frontmatter(text):
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
            fm[key] = val.strip("'\"") if val else []
    return fm, body

def extract_reference(path):
    """references/*.md — frontmatter title/description, else first heading + first paragraph."""
    text = read_head(path, 4000)
    fm, body = _parse_frontmatter(text) if text.startswith("---\n") else ({}, text)
    title = fm.get("name") or fm.get("title")
    desc  = fm.get("description")
    if not title:
        m = re.search(r"^#\s+(.+)$", body, re.MULTILINE)
        title = m.group(1).strip() if m else path.stem.replace("-", " ").title()
    if not desc:
        # first non-heading paragraph
        for para in re.split(r"\n\n+", body[:2000]):
            para = para.strip()
            if para and not para.startswith(("#", "```", "|", "-", "*", ">")):
                desc = para.replace("\n", " ")[:400]; break
        if not desc:
            desc = body[:200].replace("\n", " ")
    haystack = f"{path.name} {title} {desc}"
    return {
        "id":            f"reference:{slugify(path.stem)}",
        "type":          "reference",
        "path":          str(path.relative_to(REPO)),
        "title":         title,
        "description":   desc[:400],
        "capabilities": [],
        "classes":       infer_from_text(haystack, CLASS_KEYWORDS),
        "technologies":  infer_from_text(haystack, TECH_KEYWORDS),
        "prerequisites": [],
        "commands":      [],
        "outputs":       [],
        "provenance":    {"source": str(path.relative_to(REPO)), "extracted_at": ts_now()},
        "epistemic_status": "verified",
        "confidence":    "high",
        "last_verified": ts_now(),
    }

def extract_script(path):
    """scripts/*.sh|*.py or tools/* — parse shebang + top comment/docstring."""
    text = read_head(path, 4000)
    lines = text.splitlines()
    is_python = path.suffix == ".py" or (lines and "python" in lines[0])
    is_bash   = path.suffix == ".sh" or (lines and lines[0].startswith("#!") and "bash" in lines[0])

    # Extract top docstring/comment block
    doc_lines = []
    started = False
    if is_python:
        # Look for triple-quoted docstring
        m = re.search(r'"""(.+?)"""', text[:3500], re.DOTALL)
        if m:
            doc_lines = m.group(1).strip().splitlines()
        else:
            # Or leading # comments after shebang
            for ln in lines[1:60]:
                if ln.startswith("#") and not ln.startswith("#!"):
                    doc_lines.append(ln.lstrip("# ").rstrip())
                elif ln.strip() == "":
                    if doc_lines: continue
                else:
                    break
    else:
        # Bash / other: leading # comments after shebang
        for ln in lines[1:60]:
            if ln.startswith("#") and not ln.startswith("#!"):
                doc_lines.append(ln.lstrip("# ").rstrip())
            elif ln.strip() == "":
                if doc_lines: continue
            else:
                break

    title_line = doc_lines[0] if doc_lines else path.stem.replace("-", " ").replace("_", " ").title()
    description = "\n".join(doc_lines[:12])[:500] if doc_lines else f"{path.stem} (no docstring)"

    # Extract usage examples (lines that look like commands)
    commands = []
    for ln in doc_lines:
        s = ln.strip()
        # Usage: bash foo.sh <arg>  |  Usage:  foo.py --flag
        if re.match(r"^(usage|example|run|invoke):", s, re.I):
            commands.append(re.sub(r"^\w+:\s*", "", s))
        elif s.startswith(("scripts/", "bash ", "python3 ", "./")):
            commands.append(s)

    haystack = f"{path.name} {title_line} {description}"
    scripts_dir = "tools" if "tools" in str(path.parent) else "scripts"

    return {
        "id":            f"{scripts_dir[:-1]}:{slugify(path.stem)}",
        "type":          "tool" if scripts_dir == "tools" else "script",
        "path":          str(path.relative_to(REPO)),
        "title":         title_line[:200],
        "description":   description,
        "capabilities":  [],
        "classes":       infer_from_text(haystack, CLASS_KEYWORDS),
        "technologies":  infer_from_text(haystack, TECH_KEYWORDS),
        "prerequisites": ["python3"] if is_python else (["bash"] if is_bash else []),
        "commands":      commands[:5] or [f"{'python3' if is_python else 'bash'} {path.relative_to(REPO)}"],
        "outputs":       [],
        "provenance":    {"source": str(path.relative_to(REPO)), "extracted_at": ts_now(), "sha": sha_short(text)},
        "epistemic_status": "verified",
        "confidence":    "high" if doc_lines else "medium",
        "last_verified": ts_now(),
    }

def extract_payload(path):
    """brain/payloads/*.txt|*.md — class name = filename stem, description = first commented line."""
    text = read_head(path, 800)
    first_lines = text.splitlines()[:15]
    desc_lines = [l.lstrip("# ").rstrip() for l in first_lines if l.startswith("#") and l.strip("# ").strip()]
    stem = path.stem
    title = f"{stem} payload set"
    desc = " ".join(desc_lines[:3])[:400] or f"{stem} payloads"
    # count non-comment, non-blank lines as probe count
    probe_count = sum(1 for l in read_head(path, 400000).splitlines()
                      if l.strip() and not l.strip().startswith("#"))
    haystack = f"{stem} {desc}"
    classes = infer_from_text(haystack, CLASS_KEYWORDS)
    if not classes and stem in CLASS_KEYWORDS:
        classes = [stem]

    return {
        "id":            f"payload:{slugify(stem)}",
        "type":          "payload",
        "path":          str(path.relative_to(REPO)),
        "title":         title,
        "description":   desc,
        "capabilities":  ["payload-set"],
        "classes":       classes or [stem],
        "technologies":  [],
        "prerequisites": [],
        "commands":      [f"cat {path.relative_to(REPO)}"],
        "outputs":       [f"{probe_count} probes"],
        "provenance":    {"source": str(path.relative_to(REPO)), "extracted_at": ts_now(), "probe_count": probe_count},
        "epistemic_status": "verified",
        "confidence":    "high",
        "last_verified": ts_now(),
    }

def extract_lesson(line, index):
    """One row per lesson from brain/lessons.md."""
    # format: "- [timestamp] text"
    m = re.match(r"^-\s*\[([^\]]+)\]\s*(.+)$", line)
    if not m: return None
    ts, body = m.group(1), m.group(2).strip()
    classes = infer_from_text(body, CLASS_KEYWORDS)
    technologies = infer_from_text(body, TECH_KEYWORDS)
    # first N words as title
    title_words = body.split()[:12]
    title = " ".join(title_words) + ("..." if len(body.split()) > 12 else "")
    return {
        "id":            f"lesson:{index:03d}",
        "type":          "lesson",
        "path":          "brain/lessons.md",
        "title":         title[:200],
        "description":   body[:500],
        "capabilities":  [],
        "classes":       classes,
        "technologies":  technologies,
        "prerequisites": [],
        "commands":      [],
        "outputs":       [],
        "provenance":    {"source": "brain/lessons.md", "recorded_at": ts, "extracted_at": ts_now()},
        "epistemic_status": "derived",
        "confidence":    "medium",
        "last_verified": ts_now(),
    }

def extract_agent(path):
    """agents/*.md or ~/.claude/agents/*.md — frontmatter name + description + tools."""
    text = read_head(path, 3000)
    fm, body = _parse_frontmatter(text) if text.startswith("---\n") else ({}, text)
    name = fm.get("name") or path.stem
    desc = fm.get("description") or (body.strip().split("\n\n", 1)[0])[:400]
    tools_str = fm.get("tools", "")
    tools_list = [t.strip() for t in tools_str.split(",")] if isinstance(tools_str, str) else []
    haystack = f"{name} {desc}"
    return {
        "id":            f"agent:{slugify(name)}",
        "type":          "agent",
        "path":          str(path.relative_to(REPO)) if REPO in path.parents else str(path),
        "title":         name,
        "description":   desc[:400],
        "capabilities":  ["dispatchable-subagent"],
        "classes":       infer_from_text(haystack, CLASS_KEYWORDS),
        "technologies":  infer_from_text(haystack, TECH_KEYWORDS),
        "prerequisites": [],
        "commands":      [f"Agent({{subagent_type:'{name}', prompt:'...'}})"],
        "outputs":       tools_list[:6],
        "provenance":    {"source": str(path), "extracted_at": ts_now()},
        "epistemic_status": "verified",
        "confidence":    "high",
        "last_verified": ts_now(),
    }

# ─── walk + collect ─────────────────────────────────────────
def collect_all():
    rows = []
    counts = {}

    # references/
    for f in sorted((REPO / "references").glob("*.md")):
        rows.append(extract_reference(f))
    counts["reference"] = sum(1 for r in rows if r["type"] == "reference")

    # scripts/
    for pat in ("*.sh", "*.py"):
        for f in sorted((REPO / "scripts").glob(pat)):
            rows.append(extract_script(f))
    counts["script"] = sum(1 for r in rows if r["type"] == "script")

    # tools/
    for f in sorted((REPO / "tools").iterdir()):
        if f.is_file() and not f.name.startswith("."):
            rows.append(extract_script(f))
    counts["tool"] = sum(1 for r in rows if r["type"] == "tool")

    # brain/payloads/
    for pat in ("*.txt", "*.md"):
        for f in sorted((REPO / "brain" / "payloads").glob(pat)):
            rows.append(extract_payload(f))
    counts["payload"] = sum(1 for r in rows if r["type"] == "payload")

    # brain/lessons.md
    lessons_file = REPO / "brain" / "lessons.md"
    if lessons_file.exists():
        for i, line in enumerate(lessons_file.read_text().splitlines(), 1):
            if line.startswith("- ["):
                row = extract_lesson(line, i)
                if row: rows.append(row)
    counts["lesson"] = sum(1 for r in rows if r["type"] == "lesson")

    # agents/  (mad-hacks-native t3-* only; symlinked specialist hunters live at ~/.claude/agents/)
    for f in sorted((REPO / "agents").glob("*.md")):
        rows.append(extract_agent(f))
    # also index specialist hunters at ~/.claude/agents/ (they're the swarm)
    home_agents = Path.home() / ".claude" / "agents"
    if home_agents.exists():
        for f in sorted(home_agents.glob("*.md")):
            # skip already-indexed t3-* files (symlinked from repo)
            if f.is_symlink() and str(f.resolve()).startswith(str(REPO)):
                continue
            rows.append(extract_agent(f))
    counts["agent"] = sum(1 for r in rows if r["type"] == "agent")

    return rows, counts

# ─── write + query ──────────────────────────────────────────
def write_registry(rows):
    REGISTRY_DIR.mkdir(parents=True, exist_ok=True)
    with REGISTRY_FILE.open("w") as f:
        for row in rows:
            f.write(json.dumps(row, separators=(",", ":")) + "\n")

def write_fts_index(rows):
    """Build SQLite FTS5 index for BM25-ranked lexical search (stdlib only)."""
    import sqlite3
    if FTS_DB.exists():
        FTS_DB.unlink()
    conn = sqlite3.connect(str(FTS_DB))
    conn.executescript("""
        CREATE VIRTUAL TABLE assets USING fts5(
            id UNINDEXED,
            type UNINDEXED,
            path UNINDEXED,
            title,
            description,
            capabilities,
            classes,
            technologies,
            provenance UNINDEXED,
            row_json UNINDEXED,
            tokenize = 'porter unicode61 remove_diacritics 2'
        );
    """)
    for r in rows:
        conn.execute(
            "INSERT INTO assets(id,type,path,title,description,capabilities,classes,technologies,provenance,row_json) "
            "VALUES(?,?,?,?,?,?,?,?,?,?)",
            (
                r["id"], r["type"], r["path"],
                r.get("title", "") or "",
                r.get("description", "") or "",
                " ".join(r.get("capabilities", [])),
                " ".join(r.get("classes", [])),
                " ".join(r.get("technologies", [])),
                json.dumps(r.get("provenance", {})),
                json.dumps(r, separators=(",", ":")),
            )
        )
    conn.commit()
    conn.close()

def fts_search(query, limit=15, type_filter=None):
    """BM25-ranked search via SQLite FTS5. Auto-quotes phrase, handles bare words."""
    import sqlite3
    if not FTS_DB.exists():
        return []
    conn = sqlite3.connect(str(FTS_DB))
    conn.row_factory = sqlite3.Row
    # Sanitize + build FTS5 MATCH expression: each word as a prefix search, ANDed
    words = re.findall(r"[A-Za-z0-9_-]+", query)
    if not words:
        return []
    match_expr = " AND ".join(f'"{w}"*' for w in words)
    sql = "SELECT row_json, bm25(assets) AS rank FROM assets WHERE assets MATCH ?"
    params = [match_expr]
    if type_filter:
        sql += " AND type = ?"
        params.append(type_filter)
    sql += " ORDER BY rank LIMIT ?"
    params.append(limit)
    results = []
    try:
        for row in conn.execute(sql, params):
            r = json.loads(row["row_json"])
            r["_score"] = -row["rank"]  # bm25 is negative; flip so higher=better
            results.append(r)
    except sqlite3.OperationalError:
        pass  # bad FTS syntax — fall through
    conn.close()
    return results

def load_registry():
    if not REGISTRY_FILE.exists():
        return []
    return [json.loads(l) for l in REGISTRY_FILE.read_text().splitlines() if l.strip()]

def search_registry(rows, query, limit=15):
    """Lexical search across title + description + capabilities + classes + technologies."""
    kws = [k.lower() for k in query.split() if len(k) > 1]
    if not kws:
        return []
    scored = []
    for row in rows:
        hay = " ".join([
            row.get("title", ""), row.get("description", ""),
            " ".join(row.get("capabilities", [])),
            " ".join(row.get("classes", [])),
            " ".join(row.get("technologies", [])),
            row.get("path", ""),
        ]).lower()
        # score: sum of keyword hits; require ALL keywords present for a hit
        if not all(k in hay for k in kws):
            continue
        score = sum(hay.count(k) for k in kws)
        scored.append((score, row))
    scored.sort(key=lambda x: -x[0])
    return scored[:limit]

# ─── CLI ────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--stats",  action="store_true", help="print counts, don't write")
    ap.add_argument("--search", type=str, help="regenerate + print matches for QUERY")
    ap.add_argument("--json",   action="store_true", help="print rows as JSON (with --search)")
    args = ap.parse_args()

    rows, counts = collect_all()

    if args.stats:
        print(f"── registry stats (not written) ──")
        for t, n in sorted(counts.items(), key=lambda x: -x[1]):
            print(f"  {n:>5}  {t}")
        print(f"  {sum(counts.values()):>5}  TOTAL")
        return

    write_registry(rows)
    write_fts_index(rows)
    print(f"✅ wrote {len(rows)} rows → {REGISTRY_FILE.relative_to(REPO)}")
    print(f"✅ built FTS5 index → {FTS_DB.relative_to(REPO)}  ({FTS_DB.stat().st_size // 1024} KB)")
    for t, n in sorted(counts.items(), key=lambda x: -x[1]):
        print(f"    {n:>5}  {t}")

    if args.search:
        print()
        print(f"── search '{args.search}' (BM25 via FTS5) ──")
        results = fts_search(args.search)
        if not results:
            # fallback: legacy substring scan over JSONL
            print("  (no FTS5 hits — falling back to substring scan)")
            for score, row in search_registry(rows, args.search):
                results.append({**row, "_score": score})
        if args.json:
            print(json.dumps(results, indent=2))
            return
        for row in results:
            path = row.get("path", "?")
            cls = ",".join(row.get("classes", [])[:3])
            score = row.get("_score", 0)
            print(f"  [{score:>6.2f}]  [{row['type']:<9}]  {row['title'][:60]:60s}  ({cls})")
            print(f"              {path}")

if __name__ == "__main__":
    main()
