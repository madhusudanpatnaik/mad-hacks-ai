#!/usr/bin/env python3
"""
test_retrieval.py — measure retrieval quality against the canonical query set
(tests/intelligence/queries.jsonl). Freezes the current behavior so future
router changes can be compared numerically.

Metrics per source configuration (FTS5-only / RRF-lex+writeups+target /
RRF-lex+sem+writeups+target when FAISS present):
    Recall@5, Recall@10  — did any expected class appear in the top K?
    Precision@5          — of the top 5, how many touch an expected class?
    MRR                  — 1/rank of the first correct hit
    nDCG@10              — discounted-cumulative-gain (binary relevance)

A "correct hit" = the returned row's `classes` list intersects the query's
`expected_classes` list (case-insensitive).

Usage:
    python3 tests/intelligence/test_retrieval.py                  # all queries
    python3 tests/intelligence/test_retrieval.py --category direct
    python3 tests/intelligence/test_retrieval.py --json           # machine-readable
    python3 tests/intelligence/test_retrieval.py --config lex     # only lexical
"""

import argparse
import json
import math
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
QUERIES = Path(__file__).parent / "queries.jsonl"
RECALL_SH = REPO / "scripts" / "intelligence-recall.sh"


def load_queries():
    return [json.loads(l) for l in QUERIES.read_text().splitlines() if l.strip()]


def run_router(query, sources="lex,writeups,target", limit=10):
    """Drive intelligence-recall.sh --json and parse the result set."""
    if not RECALL_SH.exists():
        return []
    try:
        out = subprocess.check_output(
            ["bash", str(RECALL_SH), query,
             "--sources", sources, "--limit", str(limit), "--json"],
            stderr=subprocess.DEVNULL, timeout=45
        ).decode("utf-8", errors="ignore")
    except (subprocess.SubprocessError, FileNotFoundError):
        return []
    try:
        data = json.loads(out)
        return data.get("results", [])
    except json.JSONDecodeError:
        return []


def is_correct(row, expected_classes):
    """Row is correct if its classes intersect expected_classes."""
    row_classes = {c.lower() for c in (row.get("classes") or [])}
    if not row_classes:
        # fall back to inferring class from tags/title/path for writeups
        text = " ".join([
            row.get("title", "") or "",
            " ".join(row.get("tags", [])) if isinstance(row.get("tags"), list) else str(row.get("tags", "")),
            row.get("path", "") or "",
        ]).lower()
        row_classes = set()
        for cls in expected_classes:
            if cls.lower() in text or cls.lower().replace("-", " ") in text:
                row_classes.add(cls.lower())
    expected = {c.lower() for c in expected_classes}
    return bool(row_classes & expected)


def metrics_for_query(query_row, results, k_recall=5, k_recall_wide=10, k_ndcg=10):
    expected = query_row["expected_classes"]
    # Recall@K: at least one correct in top K?
    top_recall = results[:k_recall]
    top_wide   = results[:k_recall_wide]
    top_ndcg   = results[:k_ndcg]
    top_prec   = results[:k_recall]

    recall_at_5  = 1 if any(is_correct(r, expected) for r in top_recall) else 0
    recall_at_10 = 1 if any(is_correct(r, expected) for r in top_wide)   else 0
    precision_at_5 = sum(1 for r in top_prec if is_correct(r, expected)) / max(1, len(top_prec)) if top_prec else 0.0

    # MRR: 1/rank of first correct
    mrr = 0.0
    for i, r in enumerate(results, 1):
        if is_correct(r, expected):
            mrr = 1.0 / i
            break

    # nDCG@10 with binary relevance
    dcg = 0.0
    for i, r in enumerate(top_ndcg, 1):
        rel = 1.0 if is_correct(r, expected) else 0.0
        if rel:
            dcg += rel / math.log2(i + 1)
    # ideal DCG when all top-K are relevant
    idcg = sum(1.0 / math.log2(i + 1) for i in range(1, min(k_ndcg, len(results)) + 1))
    ndcg = dcg / idcg if idcg > 0 else 0.0

    return {
        "recall@5":     recall_at_5,
        "recall@10":    recall_at_10,
        "precision@5":  round(precision_at_5, 3),
        "mrr":          round(mrr, 4),
        "ndcg@10":      round(ndcg, 4),
        "n_results":    len(results),
    }


def aggregate(per_query_metrics):
    if not per_query_metrics:
        return {}
    keys = ["recall@5", "recall@10", "precision@5", "mrr", "ndcg@10"]
    return {k: round(sum(m[k] for m in per_query_metrics) / len(per_query_metrics), 4) for k in keys}


def run_config(queries, sources, label, verbose=True):
    per_query = []
    if verbose: print(f"\n── config: {label}  (sources={sources}) ──")
    for q in queries:
        results = run_router(q["query"], sources=sources, limit=10)
        m = metrics_for_query(q, results)
        m["id"] = q["id"]
        m["query"] = q["query"]
        m["category"] = q.get("category", "")
        per_query.append(m)
        if verbose:
            hit = "✓" if m["recall@5"] else ("~" if m["recall@10"] else "✗")
            print(f"  {hit} {q['id']} [{q.get('category','?'):9s}]  MRR={m['mrr']:.3f}  R@5={m['recall@5']}  R@10={m['recall@10']}  nDCG@10={m['ndcg@10']:.3f}  ({q['query'][:50]})")
    agg = aggregate(per_query)
    return {"label": label, "sources": sources, "per_query": per_query, "aggregate": agg}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--category", type=str, help="filter by category (direct/synonym/indirect/ambiguous/tech-cross)")
    ap.add_argument("--config", type=str, help="only run one config: lex | rrf | rrf-sem")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--quiet", action="store_true", help="only print aggregate summary")
    args = ap.parse_args()

    if not RECALL_SH.exists():
        print(f"  ✗ router not found: {RECALL_SH}"); sys.exit(3)

    queries = load_queries()
    if args.category:
        queries = [q for q in queries if q.get("category") == args.category]
    if not queries:
        print(f"  ✗ no queries matched filter"); sys.exit(1)

    # decide which configs to run
    configs = []
    faiss_available = (REPO / "brain" / "registry" / "assets.faiss").exists()
    if not args.config or args.config == "lex":
        configs.append(("FTS5 only",              "lex"))
    if not args.config or args.config == "rrf":
        configs.append(("RRF lex+writeups+target","lex,writeups,target"))
    if faiss_available and (not args.config or args.config == "rrf-sem"):
        configs.append(("RRF lex+sem+writeups+target","lex,sem,writeups,target"))

    reports = []
    for label, sources in configs:
        report = run_config(queries, sources, label, verbose=not args.quiet)
        reports.append(report)

    print()
    print("═══════════════════════════════════════════════════════════════════════")
    print(" AGGREGATE — over {} queries".format(len(queries)))
    print("═══════════════════════════════════════════════════════════════════════")
    print(f"  {'config':<40s}  {'MRR':>6s}  {'R@5':>6s}  {'R@10':>6s}  {'P@5':>6s}  {'nDCG@10':>8s}")
    print("  " + "-" * 84)
    for r in reports:
        a = r["aggregate"]
        print(f"  {r['label']:<40s}  {a['mrr']:>6.3f}  {a['recall@5']:>6.3f}  {a['recall@10']:>6.3f}  {a['precision@5']:>6.3f}  {a['ndcg@10']:>8.3f}")

    if not faiss_available:
        print()
        print("  ~ FAISS index absent → semantic config skipped.")
        print("    Enable with: pip3 install faiss-cpu sentence-transformers && python3 scripts/build-embeddings.py")

    if args.json:
        print()
        print(json.dumps({"reports": reports, "queries_count": len(queries),
                         "faiss_available": faiss_available}, indent=2))


if __name__ == "__main__":
    main()
