#!/usr/bin/env bash
# intelligence-recall.sh — unified query router for the mad-hacks brain.
#
# ONE interface agents call instead of the current 3-way brain.sh chain.
# Two-phase design (audit correction #7 — state as filter, not fused source):
#   PHASE 1 (fusion): RRF over knowledge sources (lex + sem + writeups) + target-files
#   PHASE 2 (state):  when --target set, apply exhausted-class demote (0.4x) to
#                     rows whose normalized classes intersect the engagement's
#                     EXHAUSTED.md class set. State DECISIONS filter/rerank;
#                     state DOCUMENTS still fuse.
#
# Sources fused in PHASE 1:
#   1. LEXICAL — brain/registry/assets.db (SQLite FTS5, BM25 ranking, stdlib)
#   2. SEMANTIC — brain/registry/assets.faiss (all-MiniLM-L6-v2 cosine, opt-in)
#   3. WRITEUPS — ~/.local/share/pentest-writeups/metadata.db (6.7k rows)
#   4. TARGET   — .engagement/<target>/ or .cdc/<target>/ FILES (docs, not decisions)
#
# Absent sources skipped silently; the router degrades gracefully.
#
# Usage:
#   intelligence-recall.sh "url parameter influencing backend fetch"
#   intelligence-recall.sh "jwt alg confusion" --target api.example.com --class oauth
#   intelligence-recall.sh "clickjacking" --limit 20 --json
#   intelligence-recall.sh "graphql" --sources lex,sem   # opt out of writeups+target
#   intelligence-recall.sh "ssrf" --target acme --state-filter off   # bypass demote
#
# Every result row carries:
#   _rrf_score  — original fused score (immutable; other consumers rely on scale)
#   _final_score — after state-decision rerank (== _rrf_score when no state applied)
#   _state_adj  — {exhausted_penalty: 0.4|0, classes_matched: [...]}; always present
#
# Env / overrides:
#   MADHACKS_RRF_K=60          — RRF constant (higher = less aggressive top-heavy)
#   MADHACKS_LIMIT_PER_SOURCE  — how many raw hits per source before fusion (default 15)
#   MADHACKS_EXHAUSTED_PENALTY — multiplier for exhausted-class rows (default 0.4)
#   MADHACKS_HYPOTHESIS_BOOST  — coefficient for hypothesis-alignment (default 0.15)
#   MADHACKS_HYPOTHESIS_CAP    — cap on effective overlap signal (default 4.0)

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
QUERY=""
TARGET=""
CLASS=""
LIMIT=10
SOURCES="lex,sem,writeups,target"
FORMAT="text"
STATE_FILTER="auto"   # auto|on|off — auto = fires when --target set

while [ $# -gt 0 ]; do
  case "$1" in
    --target)       TARGET="${2:-}"; shift 2 ;;
    --class)        CLASS="${2:-}"; shift 2 ;;
    --limit)        LIMIT="${2:-10}"; shift 2 ;;
    --sources)      SOURCES="${2:-}"; shift 2 ;;
    --state-filter) STATE_FILTER="${2:-auto}"; shift 2 ;;
    --json)         FORMAT="json"; shift ;;
    --help|-h)      sed -n '1,40p' "$0"; exit 0 ;;
    *)              QUERY="${QUERY:+$QUERY }$1"; shift ;;
  esac
done
[ -n "$QUERY" ] || { sed -n '1,40p' "$0"; exit 2; }

command -v python3 >/dev/null || { echo "intelligence-recall: python3 required"; exit 3; }

case "$STATE_FILTER" in auto|on|off) : ;;
  *) echo "intelligence-recall: --state-filter must be auto|on|off (got: $STATE_FILTER)" >&2; exit 2 ;;
esac

export REPO QUERY TARGET CLASS LIMIT SOURCES FORMAT STATE_FILTER
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
STATE_FILTER = os.environ.get("STATE_FILTER", "auto")

K_RRF  = int(os.environ.get("MADHACKS_RRF_K", "60"))
K_RAW  = int(os.environ.get("MADHACKS_LIMIT_PER_SOURCE", "15"))
EXH_PENALTY  = float(os.environ.get("MADHACKS_EXHAUSTED_PENALTY", "0.4"))
HYP_COEFF    = float(os.environ.get("MADHACKS_HYPOTHESIS_BOOST",   "0.15"))
HYP_CAP      = float(os.environ.get("MADHACKS_HYPOTHESIS_CAP",     "4.0"))
# Class-keyword tokens are HIGH-signal (rare, discriminating) — single hit
# counts as 1.0. Generic tokens are noise — need many to matter (0.2 each).
HYP_CLASS_WEIGHT   = 1.0
HYP_GENERIC_WEIGHT = 0.2

FTS_DB      = REPO / "brain" / "registry" / "assets.db"
FAISS_INDEX = REPO / "brain" / "registry" / "assets.faiss"
WRITEUP_DB  = Path(os.path.expanduser("~/.local/share/pentest-writeups/metadata.db"))

# ─── class-vocabulary normalization + inference ────────────
# Canonical class tokens are lowercase-kebab-case (matches build-registry.py's
# CLASS_KEYWORDS output). Every input from users or non-lex row kinds MUST pass
# through normalize_class() before set-intersection — otherwise the penalty is
# a silent no-op (correctness-critic finding #2).
CLASS_KEYWORDS = {
    "xss": ["xss","cross-site scripting","reflected","stored","dom xss"],
    "sqli": ["sql injection","sqli","sqlmap","ghauri"],
    "rce": ["remote code execution","rce","command injection","cmd injection"],
    "ssrf": ["ssrf","server-side request forgery"],
    "ssti": ["ssti","template injection","jinja"],
    "idor": ["idor","bola","broken object level authorization"],
    "csrf": ["csrf","cross-site request forgery"],
    "cors": ["cors","origin reflection"],
    "xxe": ["xxe","xml external entity"],
    "lfi": ["lfi","local file inclusion","path traversal"],
    "jwt": ["jwt","json web token","alg none","alg confusion"],
    "oauth": ["oauth","oidc","openid","pkce"],
    "crlf": ["crlf","header injection","response splitting"],
    "clickjacking": ["clickjacking","ui redressing","frame busting"],
    "hpp": ["hpp","http parameter pollution"],
    "deserialization": ["deserialization","insecure deserialization","object injection"],
    "graphql": ["graphql","introspection"],
    "open-redirect": ["open redirect","redirect_uri"],
    "cache-deception": ["cache deception","cache-deception"],
    "cache-poison": ["cache poison","cache poisoning"],
    "subdomain-takeover": ["subdomain takeover","dangling cname"],
    "file-upload": ["file upload","extension filter"],
    "prototype-pollution": ["prototype pollution"],
    "auth-session": ["auth bypass","session fixation","mfa bypass"],
    "http-smuggling": ["http smuggling","request smuggling","h2 desync"],
    "waf-bypass": ["waf bypass","waf evasion"],
    "cloud": ["cloud metadata","imds","s3 bucket"],
    "llm-ai": ["prompt injection","llm","llm01"],
    "race": ["race condition","toctou"],
}

def normalize_class(tok):
    """Canonicalize a class token. Lowercase, strip, unify separators to '-'.
    Returns '' for empty input. Idempotent."""
    if not tok:
        return ""
    s = str(tok).strip().lower()
    # unify separators: underscore or whitespace → hyphen
    import re as _re
    s = _re.sub(r"[\s_]+", "-", s)
    # collapse multiple hyphens
    s = _re.sub(r"-+", "-", s).strip("-")
    return s

def infer_classes_from_text(text):
    """Best-effort class inference from title+description when a row lacks
    explicit classes (sem, target, some writeup rows). Returns a set of
    canonical class tokens matching CLASS_KEYWORDS."""
    if not text:
        return set()
    lo = text.lower()
    found = set()
    for canonical, kws in CLASS_KEYWORDS.items():
        if canonical in lo:
            found.add(canonical); continue
        for kw in kws:
            if kw in lo:
                found.add(canonical); break
    return found

def row_normalized_classes(row):
    """Return the canonical class set for a fused row, regardless of source kind.
    Handles: explicit classes array (lex), comma/space-delimited tag strings
    (writeup), missing classes (sem/target — infer from title+description)."""
    raw = row.get("classes")
    out = set()
    if isinstance(raw, list):
        for c in raw:
            n = normalize_class(c)
            if n: out.add(n)
    elif isinstance(raw, str):
        # writeup tags may be 'ssrf,idor,rce' or 'ssrf, idor, rce' or 'ssrf rce'
        import re as _re
        for tok in _re.split(r"[,\s;]+", raw):
            n = normalize_class(tok)
            if n: out.add(n)
    # ALWAYS also try inference from title+description — writeup rows carry
    # publisher tags like "Bug Bounty"/"Technology" that never match our
    # canonical vocabulary, so relying on `raw` alone leaves them uncovered.
    # Union rather than fall-through so both explicit AND inferred contribute.
    text = " ".join([
        str(row.get("title","") or ""),
        str(row.get("description","") or ""),
    ])
    out |= infer_classes_from_text(text)
    return out

# ─── EXHAUSTED.md parser (bracket-anchored) ────────────────
# Line format written by engagement-state.sh line 154:
#   - [ts] [class] [vector] [variant] — why[ — evidence: path]
# The <why> can itself contain em-dashes; a naive split misparses. Use a
# bracket-anchored regex that pins the first 4 [bracketed] fields, then
# treats the remainder as free-form. Header text and code-fence examples in
# EXHAUSTED.md do NOT start with "- [" — they are safely ignored.
_EXH_LINE = None
def _exh_re():
    global _EXH_LINE
    if _EXH_LINE is None:
        import re as _re
        _EXH_LINE = _re.compile(
            r"^- \[(?P<ts>[^\]]+)\] "
            r"\[(?P<cls>[^\]]+)\] "
            r"\[(?P<vec>[^\]]+)\] "
            r"\[(?P<var>[^\]]+)\]"
        )
    return _EXH_LINE

def load_exhausted_state(target):
    """Parse .engagement/<slug>/EXHAUSTED.md into a dict:
        {"classes": set(canonical class tokens),
         "tuples":  set((class, vector, variant) canonical tuples),
         "path":    Path to the file (or None)}
    Returns empty structure on missing/empty file. Never raises."""
    empty = {"classes": set(), "tuples": set(), "path": None}
    if not target:
        return empty
    slug = target.lower().replace("/","-").replace(":","-")
    for root_name in (".engagement", ".cdc", ".t3mp3st"):
        f = REPO / root_name / slug / "EXHAUSTED.md"
        if f.exists():
            break
    else:
        return empty
    try:
        text = f.read_text(errors="ignore")
    except Exception:
        return empty
    classes, tuples = set(), set()
    rx = _exh_re()
    for line in text.splitlines():
        m = rx.match(line)
        if not m: continue
        cls = normalize_class(m.group("cls"))
        vec = normalize_class(m.group("vec"))
        var = normalize_class(m.group("var"))
        if cls:
            classes.add(cls)
            tuples.add((cls, vec, var))
    return {"classes": classes, "tuples": tuples, "path": f}

# ─── tokenizer + HYPOTHESES.md loader (state-as-filter phase 2b) ─
# The hypothesis-boost promotes rows whose text overlaps with any active
# hypothesis. We use a length-3 minimum on tokens (drops "on", "via", "the")
# and always lowercase both sides — the case-blind bug the correctness
# critic flagged in the prior refactor would have made this a silent no-op.
def tokenize_text(text):
    """Return lowercase alphanumeric-and-hyphen tokens of len>=3.
    Idempotent, no external state."""
    if not text:
        return set()
    import re as _re
    return {t for t in _re.findall(r"[A-Za-z0-9][A-Za-z0-9-]{2,}", str(text).lower())}

# HYPOTHESES.md line format (engagement-state.sh line 174):
#   - [ts] [PRIORITY] hypothesis text goes here
# where PRIORITY is HIGH|MEDIUM|LOW. Header lines don't start with "- [".
_HYP_LINE = None
def _hyp_re():
    global _HYP_LINE
    if _HYP_LINE is None:
        import re as _re
        _HYP_LINE = _re.compile(
            r"^- \[(?P<ts>[^\]]+)\] "
            r"\[(?P<prio>[A-Za-z]+)\] "
            r"(?P<text>.+)$"
        )
    return _HYP_LINE

def load_hypotheses(target):
    """Parse .engagement/<slug>/HYPOTHESES.md into:
        {"active":  [ {ts, priority, text, tokens} ],
         "path":    Path or None }
    Empty structure on missing/empty file. Never raises.

    'Active' scope for this commit: every listed hypothesis. A follow-up
    commit will introduce `hypothesis resolve` and time-window filtering
    (workflow critic during-implement #8). Until then, keep engagements
    disciplined — resolve hypotheses by pruning HYPOTHESES.md manually if
    the count grows unbounded (visible via _state_adj.hypothesis_active_count)."""
    empty = {"active": [], "path": None}
    if not target:
        return empty
    slug = target.lower().replace("/","-").replace(":","-")
    for root_name in (".engagement", ".cdc", ".t3mp3st"):
        f = REPO / root_name / slug / "HYPOTHESES.md"
        if f.exists():
            break
    else:
        return empty
    try:
        text = f.read_text(errors="ignore")
    except Exception:
        return empty
    active = []
    rx = _hyp_re()
    for line in text.splitlines():
        m = rx.match(line)
        if not m: continue
        htext = m.group("text").strip()
        active.append({
            "ts":       m.group("ts"),
            "priority": m.group("prio").upper(),
            "text":     htext,
            "tokens":   tokenize_text(htext),
        })
    return {"active": active, "path": f}

# ─── security-vocabulary query expansion ───────────────────
# Maps a query token (lowercase) → set of synonyms/related terms to OR into
# the lexical search. Doesn't touch the registry — expansion happens per query.
# Aligned with brain/lesson-index.md's class keyword map.
EXPANSIONS = {
    "bola":         ["idor", "broken object level authorization", "authorization"],
    "idor":         ["bola", "broken object level authorization", "authorization"],
    "ssrf":         ["server-side request forgery", "url fetch", "backend fetch"],
    "xss":          ["cross-site scripting", "reflection", "javascript injection"],
    "sqli":         ["sql injection", "sqlmap", "ghauri"],
    "rce":          ["remote code execution", "command injection", "code execution", "exec"],
    "ssti":         ["template injection", "server-side template", "jinja"],
    "xxe":          ["xml external entity", "xxe injection", "billion laughs"],
    "csrf":         ["cross-site request forgery", "state-changing"],
    "cors":         ["origin reflection", "access-control-allow"],
    "lfi":          ["local file inclusion", "path traversal"],
    "jwt":          ["json web token", "alg none", "alg confusion", "kid injection"],
    "oauth":        ["openid", "oidc", "redirect_uri", "pkce"],
    "crlf":         ["header injection", "response splitting", "%0d%0a"],
    "clickjacking": ["ui redressing", "frame busting", "x-frame-options"],
    "hpp":          ["http parameter pollution", "parameter pollution"],
    "deserialization":["insecure deserialization", "object injection"],
    "graphql":      ["introspection", "batching", "resolver"],
    "ato":          ["account takeover", "auth-session"],
    "wcd":          ["cache deception", "static extension"],
    # semantic ← surface: hints that describe symptoms
    "authorization bypass": ["idor", "bola", "auth bypass"],
    "url parameter":        ["url", "parameter", "webhook"],
    "backend fetch":        ["ssrf", "server-side request"],
    "template renders":     ["ssti", "template injection"],
    "static extension":     ["cache deception", "cache-deception"],
    "double extension":     ["file upload", "extension filter"],
}

def expand_query(query):
    """Return an OR-expanded query string mixing original + synonyms + related terms."""
    lo = query.lower()
    added = set()
    for key, syns in EXPANSIONS.items():
        if key in lo:
            for s in syns:
                added.add(s)
    if not added:
        return query
    # emit original + expansions (space-joined; FTS5 tokenizer will handle each word)
    return query + " " + " ".join(sorted(added))

# ─── source 1: LEXICAL (SQLite FTS5, BM25 ranking) ─────────
def _fts_query(conn, words, op="AND", limit=None):
    """Run one FTS5 MATCH; returns raw rows."""
    if not words: return []
    match_expr = f" {op} ".join(f'"{w}"*' for w in words)
    lim = limit or K_RAW
    try:
        return conn.execute(
            "SELECT row_json, bm25(assets) AS rank FROM assets WHERE assets MATCH ? ORDER BY rank LIMIT ?",
            (match_expr, lim)
        ).fetchall()
    except sqlite3.OperationalError:
        return []

def source_lex(query):
    """Lexical retrieval — tries strict AND on the original query first, then
    OR-fallback with expanded vocabulary IF the strict result set is < 5. This
    preserves precision on strong queries while letting weak/synonym queries
    benefit from the expansion map."""
    if not FTS_DB.exists() or "lex" not in SOURCES:
        return []
    import re
    words = re.findall(r"[A-Za-z0-9_-]+", query)
    if not words:
        return []
    conn = sqlite3.connect(str(FTS_DB))
    conn.row_factory = sqlite3.Row

    # tier 1: strict AND on the original query — precise, high-precision
    rows = _fts_query(conn, words, op="AND")

    # tier 2: ONLY when strict returned zero, fall back to expanded OR search.
    # This preserves precision on strong queries (which get 1+ hit and stop
    # here) and rescues synonym/indirect queries (which get 0 hits and expand).
    # Rationale: measured — <5 threshold flooded top-K on direct queries and
    # DROPPED MRR/nDCG. Zero-threshold + fallback lifts synonym MRR without
    # regressing direct.
    if len(rows) == 0:
        expanded = expand_query(query)
        exp_words = re.findall(r"[A-Za-z0-9_-]+", expanded)
        if exp_words and set(exp_words) != set(words):
            # Smaller fallback pool — marginal hits dilute RRF fusion when they
            # compete with high-precision writeup+target hits. Measured: K_RAW/3
            # keeps RRF regression <2% while lifting synonym-category R@10 from
            # 0.0 → 0.7 (previously unanswerable queries now surface anything).
            rows = _fts_query(conn, exp_words, op="OR", limit=max(3, K_RAW // 3))

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
                                # synthesize an id — dedup fallback when path empty
                                # (workflow critic during-implement fix #6)
                                "id": f"sem:{title_part[:60]}:{len(results)+1}",
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
            # dedup key: path OR id — fallback to src:title so sem-only rows without a
            # path (workflow critic during-implement #6) don't silently drop from fusion.
            key = h.get("path") or h.get("id") or f"{h.get('_src')}:{h.get('title','?')}"
            if not key: continue
            scores[key] = scores.get(key, 0) + 1.0 / (k + h["_rank"])
            # keep the fullest record we've seen for this key.
            # Use `default=str` because a prior iteration's row may already
            # carry `_sources` as a set (mutated by setdefault below), which
            # is not JSON-serializable by json.dumps default encoder.
            if key not in seen or len(json.dumps(h, default=str)) > len(json.dumps(seen[key], default=str)):
                seen[key] = h
            seen[key].setdefault("_sources", set()).add(src_name)
    ranked = []
    for key, score in sorted(scores.items(), key=lambda x: -x[1]):
        r = dict(seen[key])
        r["_rrf_score"] = round(score, 6)
        r["_sources"] = sorted(r["_sources"])
        ranked.append(r)
    return ranked

# ─── PHASE 2: state as post-fusion filter (audit correction #7) ───
# The reranker demotes rows whose CLASSES intersect the engagement's exhausted
# set. It never removes rows — chain-builder may still want an exhausted vector
# as a stepping stone. Every row gets _final_score and _state_adj (empty when
# no state applied) so consumers can rely on the schema unconditionally.
#
# Two mechanisms compose additively per row (see hypothesis_boost() for math):
#   (a) exhausted-demote (shipped b890e94): row.classes ∩ EXHAUSTED.md.classes
#       → multiply by EXH_PENALTY (0.4)
#   (b) hypothesis-boost  (this commit):    row.text ∩ active-hypothesis.text
#       → add COEFF * median * signal (where signal weights class-tokens 1.0
#         and generic tokens 0.2, capped at HYP_CAP=4)
# Both can fire on the same row — an exhausted vector aligned with an active
# hypothesis takes a smaller net demotion (chain-building hint).
#
# CONFIRMED-class boost still deferred to a separate commit.
def hypothesis_boost(row, hypo_tokens, median):
    """Compute the additive boost for one row against the union hypothesis
    token set. Returns (boost_value, list_of_matched_tokens).
    Returns (0, []) if no signal — safe to always add.

    Signal weighting (from prior critique's must-fix #3):
      class-keyword token (rare, high-signal) → 1.0 each
      generic token                            → 0.2 each
    A single class-token match therefore already crosses a meaningful
    threshold ("ssrf" alone), while noise tokens need to accumulate."""
    if not hypo_tokens or median <= 0:
        return 0.0, []
    # Case-critical: lowercase BOTH sides. The prior critique flagged that
    # pseudocode lowercased hypo_tokens but not row_tokens — a silent no-op.
    row_text = " ".join([
        str(row.get("title","") or ""),
        str(row.get("description","") or ""),
    ])
    row_tokens = tokenize_text(row_text)
    overlap = row_tokens & hypo_tokens
    if not overlap:
        return 0.0, []
    signal = 0.0
    for t in overlap:
        signal += HYP_CLASS_WEIGHT if t in CLASS_KEYWORDS else HYP_GENERIC_WEIGHT
    signal = min(signal, HYP_CAP)
    boost = HYP_COEFF * median * signal
    return boost, sorted(overlap)

def apply_state_filter(fused_rows, exhausted, hypotheses, engaged, limit):
    """Return a new ranked list. Every row gets:
        _rrf_score     — unchanged (immutable — other consumers depend on scale)
        _final_score   — post-adjustment score used for sorting
        _state_adj     — dict describing what changed (always present)
    Non-mutating on the fusion score. Idempotent (result of running twice
    equals result of running once — the filter operates on _rrf_score, not
    on the previously-emitted _final_score).

    Median score for boost scaling is computed ONCE over the top-`limit` rows
    of the pre-adjustment fusion — pinning this prevents the boost from
    drifting between calls with different fusion sizes (during-implement #1)."""
    import statistics
    exhausted_cls = exhausted["classes"] if exhausted else set()

    # Pin median over the top-`limit` slice — this is the pool the caller will
    # actually see, so it's the right basis for a scale-invariant boost.
    top_slice = fused_rows[:max(limit, 1)]
    median_score = (statistics.median(r.get("_rrf_score", 0.0) for r in top_slice)
                    if top_slice else 0.0)

    # Union hypothesis tokens across all active hypotheses. Log count so an
    # operator watching _state_adj can see growth (during-implement #8:
    # HYPOTHESES.md accumulates until a resolve subcommand ships).
    active_hyps = hypotheses["active"] if hypotheses else []
    hypo_tokens = set()
    for h in active_hyps:
        hypo_tokens |= h.get("tokens", set())
    hypo_count = len(active_hyps)

    out = []
    for r in fused_rows:
        r = dict(r)
        rrf = r.get("_rrf_score", 0.0)
        adj = {}
        final = rrf

        # (a) exhausted-demote (unchanged from b890e94)
        if engaged and exhausted_cls:
            row_cls = row_normalized_classes(r)
            matched = sorted(row_cls & exhausted_cls)
            if matched:
                penalty = EXH_PENALTY
                final = final * penalty
                adj["exhausted_penalty"] = penalty
                adj["classes_matched"]   = matched

        # (b) hypothesis-boost — additive; applied after demote so an exhausted
        # row that still aligns with an active hypothesis gets partial recovery.
        if engaged and hypo_tokens:
            boost, tokens_matched = hypothesis_boost(r, hypo_tokens, median_score)
            if boost > 0:
                final = final + boost
                adj["hypothesis_boost"]        = round(boost, 6)
                adj["hypothesis_tokens_matched"] = tokens_matched
        # Always record active count when engaged — even 0 is informative
        if engaged and hypo_count:
            adj["hypothesis_active_count"] = hypo_count

        r["_final_score"] = round(final, 6)
        r["_state_adj"]   = adj  # empty dict when nothing applied — always present
        out.append(r)
    # sort by _final_score (stable when equal)
    out.sort(key=lambda x: -x["_final_score"])
    return out

# ─── run ────────────────────────────────────────────────────
# The original query drives each source. source_lex() handles fallback-expansion
# internally (strict AND first; OR+expansion only if <5 hits). Passing the raw
# query to every source keeps precision high on strong queries.
q_full = QUERY + (f" {CLASS}" if CLASS else "")

hits = {
    "lex":      source_lex(q_full),
    "sem":      source_sem(q_full),
    "writeups": source_writeups(q_full),
    "target":   source_target(QUERY),
}

# PHASE 1: RRF fusion over knowledge + target-files (unchanged)
fused = rrf(hits)

# PHASE 2: state-decision filter (opt-in via --state-filter=on|off|auto)
# auto = fires whenever --target is set. Load state ONCE (not per row).
engaged = (STATE_FILTER == "on") or (STATE_FILTER == "auto" and bool(TARGET))
exhausted_state = load_exhausted_state(TARGET) if engaged else None
hypotheses     = load_hypotheses(TARGET)     if engaged else None
fused = apply_state_filter(fused, exhausted_state, hypotheses, engaged, LIMIT)[:LIMIT]

# state metadata for JSON output — makes the filter observable
state_meta = {
    "filter":              STATE_FILTER,
    "engaged":             bool(engaged),
    "exhausted_classes":   sorted(exhausted_state["classes"]) if exhausted_state else [],
    "exhausted_tuples":    [list(t) for t in sorted(exhausted_state["tuples"])] if exhausted_state else [],
    "exhausted_path":      str(exhausted_state["path"].relative_to(REPO)) if (exhausted_state and exhausted_state["path"]) else None,
    "penalty":             EXH_PENALTY,
    "hypotheses_active":   len(hypotheses["active"]) if hypotheses else 0,
    "hypotheses_path":     str(hypotheses["path"].relative_to(REPO)) if (hypotheses and hypotheses["path"]) else None,
    "hypothesis_coeff":    HYP_COEFF,
    "hypothesis_cap":      HYP_CAP,
}

if FMT == "json":
    print(json.dumps({
        "query":   QUERY,
        "target":  TARGET,
        "class":   CLASS,
        "sources": {k: len(v) for k, v in hits.items()},
        "state":   state_meta,
        "results": fused,
    }, indent=2, default=str))
else:
    print(f"── intelligence-recall  query={QUERY!r}"
          + (f"  target={TARGET}" if TARGET else "")
          + (f"  class={CLASS}"   if CLASS  else "")
          + (f"  state-filter={STATE_FILTER}" if engaged else "")
          + " ──")
    for k, v in hits.items():
        if k in SOURCES:
            state = f"{len(v)} hit(s)" if v else "0 hits"
            print(f"  source: {k:9s}  → {state}")
    if engaged and exhausted_state and exhausted_state["classes"]:
        print(f"  state:              exhausted classes={sorted(exhausted_state['classes'])} penalty={EXH_PENALTY}x")
    if engaged and hypotheses and hypotheses["active"]:
        print(f"  state:              hypotheses active={len(hypotheses['active'])} boost={HYP_COEFF}x median (cap={HYP_CAP})")
    print()
    if not fused:
        print("  (no results across any source)")
    else:
        # marker: ★ demoted (exhausted-class hit), ▲ boosted (hypothesis-aligned), ✚ both
        print(f"  fused top {len(fused)} (sources shown per row; ★=demoted ▲=boosted ✚=both):")
        for i, r in enumerate(fused, 1):
            srcs = "+".join(r.get("_sources", []))
            adj = r.get("_state_adj", {})
            demoted = bool(adj.get("exhausted_penalty"))
            boosted = bool(adj.get("hypothesis_boost"))
            marker = "✚" if (demoted and boosted) else "▲" if boosted else "★" if demoted else " "
            print(f"  {i:>2}. {marker} [{r['_final_score']:.4f}]  [{r.get('type','?'):<12s}]  [{srcs:15s}]  {r.get('title','')[:60]}")
            print(f"                                                                {r.get('path','')}")
PY
