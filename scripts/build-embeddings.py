#!/usr/bin/env python3
"""
build-embeddings.py — optional semantic-retrieval layer for the registry.

If `faiss-cpu` + `sentence-transformers` are installed, embeds every registry
row's (title + description + capabilities + classes + technologies) with
all-MiniLM-L6-v2 (fast, 90 MB, general-purpose) and writes:

    brain/registry/assets.faiss         (FAISS IndexFlatIP)
    brain/registry/assets.embed-map.jsonl  (row_id ↔ vector-index mapping)

If the deps are absent, prints an install recipe and exits 0 (never blocks the
toolkit — semantic search is a fusion layer, not a hard dependency).

Usage:
    scripts/build-embeddings.py            # build
    scripts/build-embeddings.py --search "URL parameter influencing backend fetch"
    scripts/build-embeddings.py --check    # just report install state
"""

import argparse
import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REG = REPO / "brain" / "registry"
JSONL = REG / "assets.jsonl"
FAISS_INDEX = REG / "assets.faiss"
EMBED_MAP = REG / "assets.embed-map.jsonl"

MODEL_NAME = "all-MiniLM-L6-v2"   # 384-dim, ~90 MB, fast


def check_deps():
    have = {"faiss": False, "st": False}
    try:
        import faiss  # noqa: F401
        have["faiss"] = True
    except Exception:
        pass
    try:
        import sentence_transformers  # noqa: F401
        have["st"] = True
    except Exception:
        pass
    return have


def print_install_hint():
    print("── Semantic retrieval is opt-in — deps not present ──")
    print("")
    print("  install (~200 MB — first run downloads the MiniLM model):")
    print("    pip3 install faiss-cpu sentence-transformers")
    print("")
    print("  then:")
    print("    python3 scripts/build-embeddings.py         # ~2 min for 265 rows")
    print("    python3 scripts/build-embeddings.py --search 'URL param influencing backend fetch'")
    print("")
    print("  brain.sh search will automatically fuse lexical (FTS5) + semantic (FAISS)")
    print("  once the index file exists. Deleting brain/registry/assets.faiss falls back")
    print("  to lexical-only silently — no breakage.")


def load_rows():
    if not JSONL.exists():
        print(f"  ✗ registry missing: {JSONL}")
        print("    build it first: python3 scripts/build-registry.py")
        sys.exit(3)
    return [json.loads(l) for l in JSONL.read_text().splitlines() if l.strip()]


def row_text(r):
    """Concatenate the fields that carry semantic meaning."""
    parts = [
        r.get("title", "") or "",
        r.get("description", "") or "",
        " ".join(r.get("capabilities", [])),
        " ".join(r.get("classes", [])),
        " ".join(r.get("technologies", [])),
    ]
    return " | ".join(p for p in parts if p)[:1500]


def build_index():
    import faiss
    from sentence_transformers import SentenceTransformer
    import numpy as np

    rows = load_rows()
    print(f"  ✓ loaded {len(rows)} registry rows")

    model = SentenceTransformer(MODEL_NAME)
    print(f"  ✓ model {MODEL_NAME} loaded (dim={model.get_sentence_embedding_dimension()})")

    texts = [row_text(r) for r in rows]
    print(f"  ✓ encoding {len(texts)} rows...")
    vecs = model.encode(texts, convert_to_numpy=True, show_progress_bar=True, batch_size=64,
                        normalize_embeddings=True)
    dim = vecs.shape[1]

    # Inner-product on normalized vectors = cosine similarity
    index = faiss.IndexFlatIP(dim)
    index.add(vecs)
    faiss.write_index(index, str(FAISS_INDEX))
    print(f"  ✓ FAISS index → {FAISS_INDEX.relative_to(REPO)}  ({FAISS_INDEX.stat().st_size // 1024} KB)")

    # id → position map so callers can look up rows by faiss result index
    with EMBED_MAP.open("w") as f:
        for i, r in enumerate(rows):
            f.write(json.dumps({"pos": i, "id": r["id"], "type": r["type"], "path": r["path"]},
                               separators=(",", ":")) + "\n")
    print(f"  ✓ embed map → {EMBED_MAP.relative_to(REPO)}")


def semantic_search(query, k=10):
    import faiss
    from sentence_transformers import SentenceTransformer
    import numpy as np

    if not FAISS_INDEX.exists():
        return []
    model = SentenceTransformer(MODEL_NAME)
    index = faiss.read_index(str(FAISS_INDEX))
    q = model.encode([query], convert_to_numpy=True, normalize_embeddings=True)
    D, I = index.search(q, k)

    # Load embed map for id lookups + JSONL rows for full data
    rows_by_pos = [json.loads(l) for l in JSONL.read_text().splitlines() if l.strip()]
    results = []
    for pos, score in zip(I[0], D[0]):
        if pos == -1:
            continue
        r = dict(rows_by_pos[pos])
        r["_score"] = float(score)   # cosine sim, higher=better
        results.append(r)
    return results


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="just report dep-install state")
    ap.add_argument("--search", type=str, help="semantic search (requires deps + built index)")
    args = ap.parse_args()

    have = check_deps()
    if args.check:
        for k, v in have.items():
            print(f"  {'✓' if v else '✗'} {k}")
        if all(have.values()) and FAISS_INDEX.exists():
            print(f"  ✓ index present ({FAISS_INDEX.stat().st_size // 1024} KB)")
        elif all(have.values()):
            print(f"  ~ deps present, index NOT built — run: python3 {__file__}")
        return

    if not (have["faiss"] and have["st"]):
        print_install_hint()
        return

    if args.search:
        results = semantic_search(args.search)
        if not results:
            print("  (no semantic index found — run without --search first to build)")
            return
        print(f"── semantic search: '{args.search}' (cosine similarity via all-MiniLM-L6-v2) ──")
        for r in results:
            path = r.get("path", "?")
            cls = ",".join(r.get("classes", [])[:3])
            print(f"  [{r['_score']:.3f}]  [{r['type']:<9}]  {r['title'][:60]:60s}  ({cls})")
            print(f"             {path}")
        return

    build_index()


if __name__ == "__main__":
    main()
