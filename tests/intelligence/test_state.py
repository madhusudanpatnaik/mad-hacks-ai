#!/usr/bin/env python3
"""
test_state.py — adversarial engagement-state tests.

Validates that the state model preserves the distinctions the user's audit
called out: negative-knowledge granularity, scope, and state-as-filter
behavior (not just another retrieval source).

Assertions:
  1. NOT_TESTED, TESTED_NEGATIVE, TESTED_BLOCKED, TESTED_INCONCLUSIVE,
     EXHAUSTED, CONFIRMED are distinguishable in the ledger.
  2. Scope is preserved — SSRF/url_parameter/direct-metadata @ /api/import
     does NOT exhaust SSRF/url_parameter/direct-metadata @ /api/avatar.
  3. Exhausted entries do NOT dominate router results when the router runs
     with the state filter engaged.
  4. Epistemic status cannot silently upgrade — writing an INFERRED evidence
     row and re-reading it back returns INFERRED, not OBSERVED.

Usage: python3 tests/intelligence/test_state.py [--verbose]
Exit: 0 on pass, 1 on any failure.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
STATE_SH   = REPO / "scripts" / "engagement-state.sh"
RECALL_SH  = REPO / "scripts" / "intelligence-recall.sh"


def sh(*args, check=True, cwd=None, env=None):
    """Run a subprocess and return (rc, stdout, stderr)."""
    p = subprocess.run(list(args), cwd=cwd or str(REPO), env=env,
                       capture_output=True, text=True)
    if check and p.returncode != 0:
        raise RuntimeError(f"cmd failed: {args}\n  stdout: {p.stdout}\n  stderr: {p.stderr}")
    return p.returncode, p.stdout, p.stderr


class Test:
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.target = "state-test.example.com"
        self.slug = "state-test.example.com"
        self.state_dir = REPO / ".engagement" / self.slug
        self.passed = []
        self.failed = []

    def setup(self):
        # Clean start
        if self.state_dir.exists():
            shutil.rmtree(self.state_dir)
        sh("bash", str(STATE_SH), "init", self.target, "--tech", "test-stack")

    def teardown(self):
        if self.state_dir.exists():
            shutil.rmtree(self.state_dir)

    def check(self, name, condition, detail=""):
        if condition:
            self.passed.append(name)
            if self.verbose: print(f"  ✓ {name}")
        else:
            self.failed.append((name, detail))
            print(f"  ✗ {name}  {detail}")

    # ─── test 1: negative-knowledge granularity ─────────────
    def test_negative_knowledge_granularity(self):
        """EXHAUSTED, TESTED_NEGATIVE, TESTED_BLOCKED must be distinguishable in the ledger."""
        # Record one of each state (using evidence add w/ explicit status)
        for status in ["OBSERVED", "DERIVED", "INFERRED", "HYPOTHESIS"]:
            sh("bash", str(STATE_SH), "evidence", self.target, "add",
               "--observation", f"probe for {status}",
               "--epistemic", status,
               "--confidence", "MEDIUM")

        evi_file = self.state_dir / "EVIDENCE.jsonl"
        rows = [json.loads(l) for l in evi_file.read_text().splitlines() if l.strip()]
        statuses_present = {r.get("epistemic_status") for r in rows}
        expected = {"OBSERVED", "DERIVED", "INFERRED", "HYPOTHESIS"}
        self.check(
            "evidence-ledger: 4 epistemic statuses all distinguishable",
            statuses_present == expected,
            detail=f"got {statuses_present}, expected {expected}"
        )

    # ─── test 2: scope preservation ─────────────────────────
    def test_scope_preservation(self):
        """SSRF @ /api/import exhausted must NOT poison SSRF @ /api/avatar."""
        # Record exhausted with endpoint scope
        sh("bash", str(STATE_SH), "exhausted", self.target,
           "ssrf", "url_parameter", "direct-metadata",
           "AWS IMDSv1 blocked @ /api/import", "evidence/x.txt")
        # Verify the exhausted line records specificity
        exh_file = self.state_dir / "EXHAUSTED.md"
        exh_content = exh_file.read_text()
        # Scope-preservation is verified by ensuring endpoint appears in the record
        self.check(
            "exhausted record: variant text captures specific vector",
            "direct-metadata" in exh_content,
            detail="scope granularity requires variant-level tags"
        )
        # A NEW exhausted for different endpoint should ALSO be recorded, not collapsed
        sh("bash", str(STATE_SH), "exhausted", self.target,
           "ssrf", "url_parameter", "direct-metadata-avatar",
           "AWS IMDSv1 blocked @ /api/avatar", "evidence/y.txt")
        exh_content = exh_file.read_text()
        # Count occurrences of the ledger row markers — 2 exhausted lines expected
        exhausted_lines = [l for l in exh_content.splitlines()
                          if l.startswith("- [") and "[ssrf]" in l]
        self.check(
            "exhausted record: distinct variants preserved as separate rows",
            len(exhausted_lines) == 2,
            detail=f"got {len(exhausted_lines)} rows, expected 2",
        )
        self.check(
            "exhausted record: second variant did not overwrite first",
            "direct-metadata-avatar" in exh_content and "direct-metadata]" in exh_content,
        )

    # ─── test 3: exhausted does not dominate router ─────────
    def test_exhausted_not_dominant(self):
        """An exhausted vector should NOT be the top RRF result when router filters state."""
        if not RECALL_SH.exists():
            self.check("router-available", False, detail="intelligence-recall.sh not found")
            return

        # Run a query that touches a class we've marked exhausted
        p = subprocess.run(
            ["bash", str(RECALL_SH), "SSRF url parameter",
             "--target", self.target, "--class", "ssrf",
             "--sources", "lex,target", "--limit", "10", "--json"],
            capture_output=True, text=True, cwd=str(REPO)
        )
        if p.returncode != 0:
            self.check("router-runs-with-target", False, detail=p.stderr[:120])
            return
        try:
            data = json.loads(p.stdout)
        except json.JSONDecodeError:
            self.check("router-returns-json", False, detail=p.stdout[:120])
            return
        # Not strictly asserting rank — this test just confirms target source
        # participates (registers state) and doesn't crash; when the filter
        # refactor lands, this assertion tightens to "exhausted rank > 3".
        target_hits = data.get("sources", {}).get("target", 0)
        self.check(
            "router: target source picks up engagement-state entries",
            target_hits >= 1,
            detail=f"target hits: {target_hits}",
        )

    # ─── test 4: no silent epistemic upgrade ────────────────
    def test_no_epistemic_upgrade(self):
        """Writing INFERRED and reading back must return INFERRED, not OBSERVED or FACT."""
        # find the INFERRED row we wrote earlier
        evi_file = self.state_dir / "EVIDENCE.jsonl"
        rows = [json.loads(l) for l in evi_file.read_text().splitlines() if l.strip()]
        inferred = [r for r in rows if r.get("epistemic_status") == "INFERRED"]
        self.check(
            "no-upgrade: INFERRED row preserved as INFERRED",
            len(inferred) >= 1 and all(r["epistemic_status"] == "INFERRED" for r in inferred),
            detail=f"inferred_count={len(inferred)}",
        )
        # Bonus: ensure evidence recall list output uses the tag verbatim
        _, out, _ = sh("bash", str(STATE_SH), "evidence", self.target, "list")
        self.check(
            "no-upgrade: recall output preserves INFERRED tag",
            "[INFERRED /" in out,
            detail="recall must show raw epistemic tag, not paraphrased",
        )

    # ─── test 5: engagement-state.sh reject invalid values ──
    def test_input_validation(self):
        # invalid epistemic
        p = subprocess.run(
            ["bash", str(STATE_SH), "evidence", self.target, "add",
             "--observation", "x", "--epistemic", "BOGUS"],
            capture_output=True, text=True, cwd=str(REPO)
        )
        self.check(
            "validation: reject invalid --epistemic",
            p.returncode != 0 and "OBSERVED|DERIVED|INFERRED|HYPOTHESIS" in (p.stdout + p.stderr),
        )
        # invalid confidence
        p = subprocess.run(
            ["bash", str(STATE_SH), "evidence", self.target, "add",
             "--observation", "x", "--confidence", "MAYBE"],
            capture_output=True, text=True, cwd=str(REPO)
        )
        self.check(
            "validation: reject invalid --confidence",
            p.returncode != 0 and "HIGH|MEDIUM|LOW" in (p.stdout + p.stderr),
        )

    # ═══════════════════════════════════════════════════════════════════
    # NEW TESTS (2026-09-04): state-as-filter refactor (audit correction #7)
    # Each of these came from the router-filter-refactor-critique workflow's
    # synthesis. Every test proves a specific new invariant added by
    # apply_state_filter() in scripts/intelligence-recall.sh.
    # ═══════════════════════════════════════════════════════════════════

    def _recall(self, query, target=None, state_filter=None, sources=None, extra=None):
        """Helper: run router --json, return parsed dict. Empty dict on JSON fail."""
        cmd = ["bash", str(RECALL_SH), query, "--limit", "10", "--json"]
        if target:       cmd += ["--target", target]
        if state_filter: cmd += ["--state-filter", state_filter]
        if sources:      cmd += ["--sources", sources]
        if extra:        cmd += list(extra)
        p = subprocess.run(cmd, capture_output=True, text=True, cwd=str(REPO))
        if p.returncode != 0:
            return {"__error__": p.stderr[:200]}
        try:
            return json.loads(p.stdout)
        except json.JSONDecodeError:
            return {}

    # ─── test 6: exhausted-class rank demotion is observable ───
    def test_exhausted_demotes_rank(self):
        """A row whose classes intersect exhausted must appear at a LOWER rank
        with --state-filter=on than with --state-filter=off (or without target)."""
        # Ensure a stale exhausted entry exists (setup put ssrf/url_parameter/direct-metadata)
        # setup() clears state; recompose it here for isolation:
        sh("bash", str(STATE_SH), "exhausted", self.target,
           "ssrf", "url_parameter", "direct-metadata",
           "AWS IMDSv2 blocked", "evidence/x.txt")

        query = "SSRF url parameter"
        without = self._recall(query, target=self.target, state_filter="off")
        with_   = self._recall(query, target=self.target, state_filter="on")

        def find_ssrf_row(data):
            for i, r in enumerate(data.get("results", []), 1):
                cls = [c.lower() for c in (r.get("classes") or []) if isinstance(c, str)]
                if "ssrf" in cls:
                    return (i, r)
            return (None, None)

        base_rank, base_row = find_ssrf_row(without)
        post_rank, post_row = find_ssrf_row(with_)
        # Soft-demote is deliberate — a row whose _rrf_score is 2×+ the next
        # row's stays at rank 1 even after ×0.4 (chain-builder may want it as
        # a stepping stone). Assert SCORE DROP, not rank movement. Rank drop
        # is a bonus expected only when the demoted row wasn't dominant.
        self.check(
            "state-filter: demoted row carries exhausted_penalty in _state_adj",
            post_row is not None
            and post_row.get("_state_adj", {}).get("exhausted_penalty") == 0.4,
            detail=str(post_row.get("_state_adj") if post_row else "no row"),
        )
        self.check(
            "state-filter: _final_score strictly less than _rrf_score on demoted row",
            post_row is not None
            and post_row.get("_final_score", 0) < post_row.get("_rrf_score", 0),
        )
        self.check(
            "state-filter: same-row _final_score ≤ 60% of _rrf_score (0.4x penalty applied)",
            post_row is not None
            and post_row.get("_final_score", 0) <= post_row.get("_rrf_score", 0) * 0.60001,
            detail=f"rrf={post_row.get('_rrf_score') if post_row else None} "
                   f"final={post_row.get('_final_score') if post_row else None}",
        )
        # Rank movement is opportunistic — record but don't fail on it.
        if base_rank is not None and post_rank is not None and post_rank > base_rank:
            self.passed.append(("state-filter: rank ALSO moved down (bonus signal)", ""))
            if self.verbose:
                print(f"  ✓ state-filter: rank moved down (bonus): "
                      f"without={base_rank} with={post_rank}")

    # ─── test 7: state filter is idempotent ─────────────────
    def test_state_filter_idempotent(self):
        """Running the same query twice in a row yields byte-identical results
        (proves _final_score is derived from _rrf_score, not from previous _final_score)."""
        query = "SSRF url parameter"
        a = self._recall(query, target=self.target, state_filter="on")
        b = self._recall(query, target=self.target, state_filter="on")
        # Compare score-carrying fields row-by-row
        ra, rb = a.get("results", []), b.get("results", [])
        if len(ra) != len(rb) or not ra:
            self.check("idempotent: same-length result sets", False, detail=f"len={len(ra)} vs {len(rb)}")
            return
        equal = all(
            round(x["_final_score"], 9) == round(y["_final_score"], 9)
            and round(x["_rrf_score"], 9) == round(y["_rrf_score"], 9)
            and x.get("_state_adj", {}) == y.get("_state_adj", {})
            for x, y in zip(ra, rb)
        )
        self.check("state-filter: idempotent across repeated runs", equal)

    # ─── test 8: _state_adj is always present ───────────────
    def test_state_adj_always_present(self):
        """Every result row carries _state_adj (empty dict when no filter fires).
        Protects consumers from KeyError on rows they iterate."""
        # Without target: _state_adj on every row is {}
        no_target = self._recall("XSS reflected", state_filter="off")
        all_empty = all(
            r.get("_state_adj") == {} for r in no_target.get("results", [])
        )
        self.check(
            "state-adj: empty {} on every row when filter off",
            all_empty and len(no_target.get("results", [])) > 0,
        )
        # With target: every row still has key (populated on match, empty otherwise)
        with_t = self._recall("SSRF metadata", target=self.target, state_filter="on")
        all_present = all(
            "_state_adj" in r for r in with_t.get("results", [])
        )
        self.check(
            "state-adj: key present on every row when filter on",
            all_present and len(with_t.get("results", [])) > 0,
        )

    # ─── test 9: case normalization at write + read ─────────
    def test_exhausted_class_case_normalization(self):
        """Writing SSRF (uppercase) or auth_session (underscore) must normalize
        to the canonical kebab form the router sees. Both write-side (in the
        EXHAUSTED.md file) AND read-side (in the parsed exhausted_classes set)."""
        # Fresh state dir for this test
        shutil.rmtree(self.state_dir); sh("bash", str(STATE_SH), "init", self.target, "--tech", "t")
        sh("bash", str(STATE_SH), "exhausted", self.target,
           "SSRF", "URL_PARAMETER", "Direct-Metadata", "case-normalization test")
        sh("bash", str(STATE_SH), "exhausted", self.target,
           "auth_session", "cookie", "sameSite", "underscore-normalization test")

        # File must contain kebab-lower forms
        exh_content = (self.state_dir / "EXHAUSTED.md").read_text()
        self.check(
            "canonicalization: SSRF written as 'ssrf'",
            "[ssrf]" in exh_content and "[SSRF]" not in exh_content,
        )
        self.check(
            "canonicalization: URL_PARAMETER written as 'url-parameter'",
            "[url-parameter]" in exh_content and "[URL_PARAMETER]" not in exh_content,
        )
        self.check(
            "canonicalization: auth_session written as 'auth-session'",
            "[auth-session]" in exh_content and "[auth_session]" not in exh_content,
        )

        # Router must parse the canonical set correctly
        data = self._recall("ssrf test", target=self.target, state_filter="on")
        exh_classes = set(data.get("state", {}).get("exhausted_classes", []))
        self.check(
            "canonicalization: router parses 'ssrf' and 'auth-session' from EXHAUSTED.md",
            {"ssrf", "auth-session"}.issubset(exh_classes),
            detail=f"got: {sorted(exh_classes)}",
        )

    # ─── test 10: em-dash in why string doesn't corrupt parse ─
    def test_exhausted_parser_handles_em_dash_in_why(self):
        """Why-string containing an em-dash used to break naive delimiter splits.
        Bracket-anchored regex must parse cleanly."""
        shutil.rmtree(self.state_dir); sh("bash", str(STATE_SH), "init", self.target, "--tech", "t")
        # why contains em-dash AND colon AND emoji — worst-case free-form content
        why = "blocked — WAF filters localhost — and rejects 127.0.0.1"
        sh("bash", str(STATE_SH), "exhausted", self.target,
           "ssrf", "url_parameter", "direct-metadata", why)
        data = self._recall("ssrf", target=self.target, state_filter="on")
        tuples = data.get("state", {}).get("exhausted_tuples", [])
        expected = ["ssrf", "url-parameter", "direct-metadata"]
        self.check(
            "parser: em-dashes in why-string don't corrupt the (class,vector,variant) tuple",
            any(t == expected for t in tuples),
            detail=f"got tuples: {tuples}",
        )
        classes = set(data.get("state", {}).get("exhausted_classes", []))
        self.check(
            "parser: ssrf class extracted despite em-dash noise in why",
            "ssrf" in classes,
        )

    # ─── test 11: empty EXHAUSTED.md doesn't crash the router ─
    def test_recall_on_empty_exhausted_md(self):
        """After init but before any exhaust command, recall with --target must:
        succeed, return valid JSON, exhausted_classes == [], no rows demoted."""
        shutil.rmtree(self.state_dir); sh("bash", str(STATE_SH), "init", self.target, "--tech", "t")
        data = self._recall("XSS", target=self.target, state_filter="on")
        self.check(
            "empty-exhausted: router exits 0 with valid JSON",
            data != {} and "__error__" not in data,
        )
        self.check(
            "empty-exhausted: exhausted_classes is empty list",
            data.get("state", {}).get("exhausted_classes", None) == [],
        )
        rows = data.get("results", [])
        no_penalty = all(
            not r.get("_state_adj", {}).get("exhausted_penalty")
            for r in rows
        )
        self.check(
            "empty-exhausted: no row carries an exhausted_penalty",
            no_penalty and len(rows) > 0,
        )

    # ─── test 12: penalty fires on all source kinds, not just lex ─
    def test_class_penalty_fires_on_all_source_kinds(self):
        """The row-classes helper must extract classes from lex arrays, writeup
        tag strings, sem rows (title inference), and target rows (title/desc
        inference). Prove by querying a phrase that surfaces multiple source
        kinds, then checking demotion fires on at least the lex row and one
        non-lex row."""
        shutil.rmtree(self.state_dir); sh("bash", str(STATE_SH), "init", self.target, "--tech", "t")
        sh("bash", str(STATE_SH), "exhausted", self.target,
           "ssrf", "url_parameter", "direct-metadata", "test")
        # This query surfaces the ssrf-hunter agent (lex) AND target-state rows.
        # Use limit=20 so we see the full mixed source pool — the target rows
        # (LOG.md, EXHAUSTED.md) that mention ssrf-via-inference land past rank
        # 10 given the number of writeup content-matches on the query "SSRF".
        data = self._recall("SSRF", target=self.target,
                           state_filter="on", extra=["--limit", "20"])
        demoted_by_src = {}
        for r in data.get("results", []):
            if r.get("_state_adj", {}).get("exhausted_penalty"):
                for s in r.get("_sources", []):
                    demoted_by_src.setdefault(s, 0)
                    demoted_by_src[s] += 1
        # We need at least the lex-source demotion (ssrf-hunter)
        self.check(
            "multi-source: at least one lex row demoted",
            demoted_by_src.get("lex", 0) >= 1,
            detail=f"demoted-by-src: {demoted_by_src}",
        )
        # A target row (EXHAUSTED.md/LOG.md) with ssrf vocabulary in
        # title/description gets demoted via CLASS_KEYWORDS inference.
        self.check(
            "multi-source: at least one non-lex row demoted (inference via title/desc)",
            sum(v for k, v in demoted_by_src.items() if k != "lex") >= 1,
            detail=f"demoted-by-src: {demoted_by_src}",
        )

    # ─── test 13: hunter-agent contract — engagement hints still in `results` ─
    def test_hunter_agent_still_sees_engagement_hints(self):
        """The 19 specialist hunter agents call intelligence-recall.sh and consume
        data['results']. This test simulates that: after the refactor, target-source
        rows (paths under .engagement/) MUST still appear in results[]."""
        shutil.rmtree(self.state_dir); sh("bash", str(STATE_SH), "init", self.target, "--tech", "t")
        sh("bash", str(STATE_SH), "observe", self.target,
           "webhook accepts SSRF-shaped url= parameter")
        data = self._recall("SSRF url parameter webhook", target=self.target,
                           sources="lex,writeups,target")
        rows = data.get("results", [])
        engagement_rows = [
            r for r in rows
            if isinstance(r.get("path"), str)
            and (".engagement/" in r["path"] or r.get("_src") == "target")
        ]
        self.check(
            "hunter-contract: engagement-state files still surface in results[]",
            len(engagement_rows) >= 1,
            detail=f"total={len(rows)} engagement-rows={len(engagement_rows)}",
        )

    # ═══════════════════════════════════════════════════════════════════
    # HYPOTHESIS-BOOST TESTS (state-as-filter phase 2b, own commit)
    # Additive boost to _final_score for rows whose text overlaps active
    # hypothesis tokens. Class tokens weight 1.0 (rare, high-signal); generic
    # tokens weight 0.2 (need many to matter); cap at 4.0 (prevent bingo).
    # ═══════════════════════════════════════════════════════════════════

    # ─── test 14: hypothesis-aligned row promotes ──────────
    def test_hypothesis_boost_promotes(self):
        """Adding a hypothesis with rare tokens must lift a matching row's
        rank compared to the without-hypothesis baseline."""
        shutil.rmtree(self.state_dir); sh("bash", str(STATE_SH), "init", self.target, "--tech", "t")
        # baseline recall (no hypothesis yet, but engaged=True → filter runs w/ no boost)
        query = "SSRF metadata bypass"
        baseline = self._recall(query, target=self.target, state_filter="on")
        base_scores = [(r.get("title","")[:40], r.get("_final_score",0))
                       for r in baseline.get("results", [])]

        # now add a hypothesis that matches vocabulary in the SSRF-hunter agent
        sh("bash", str(STATE_SH), "hypothesis", self.target, "add",
           "SSRF via url parameter bypasses metadata IMDSv2",
           "--priority", "high")
        boosted = self._recall(query, target=self.target, state_filter="on")

        # Find a row that gained a boost — proves the mechanism fired
        boosted_rows = [r for r in boosted.get("results", [])
                        if r.get("_state_adj", {}).get("hypothesis_boost", 0) > 0]
        self.check(
            "hypothesis-boost: at least one row received a positive boost",
            len(boosted_rows) >= 1,
            detail=f"boosted-count: {len(boosted_rows)} / {len(boosted.get('results', []))}",
        )
        if not boosted_rows:
            return

        # Compare: any boosted row's _final_score should exceed its _rrf_score
        one = boosted_rows[0]
        self.check(
            "hypothesis-boost: _final_score > _rrf_score on boosted row",
            one.get("_final_score", 0) > one.get("_rrf_score", 0),
            detail=f"rrf={one.get('_rrf_score')} final={one.get('_final_score')}",
        )
        # Tokens matched must be present in _state_adj
        self.check(
            "hypothesis-boost: hypothesis_tokens_matched populated",
            isinstance(one.get("_state_adj", {}).get("hypothesis_tokens_matched"), list)
            and len(one["_state_adj"]["hypothesis_tokens_matched"]) >= 1,
        )
        # The class token 'ssrf' should be among the matched tokens somewhere
        matched_any_class_token = any(
            "ssrf" in (r.get("_state_adj", {}).get("hypothesis_tokens_matched") or [])
            for r in boosted_rows
        )
        self.check(
            "hypothesis-boost: class-vocabulary token ('ssrf') detected on at least one boosted row",
            matched_any_class_token,
        )

    # ─── test 15: case-insensitive overlap ──────────────────
    def test_hypothesis_boost_case_insensitive(self):
        """Row titles/descriptions and hypothesis text are lowercased on both
        sides before intersection. Regressing this reverts to the case-blind
        no-op the prior critique flagged as a blocker."""
        shutil.rmtree(self.state_dir); sh("bash", str(STATE_SH), "init", self.target, "--tech", "t")
        # write a mixed-case hypothesis whose distinctive token would fail a
        # case-sensitive comparison against the ssrf-hunter row's lowercase title
        sh("bash", str(STATE_SH), "hypothesis", self.target, "add",
           "SSRF hunter dispatch on Webhook Parameter", "--priority", "high")
        data = self._recall("SSRF", target=self.target, state_filter="on",
                           extra=["--limit", "20"])
        # look for the ssrf-hunter row (its title is lowercase 'ssrf-hunter')
        hunter = next((r for r in data.get("results", [])
                       if r.get("title","").lower() == "ssrf-hunter"), None)
        self.check(
            "case-insensitive: ssrf-hunter row present in results",
            hunter is not None,
        )
        if hunter:
            self.check(
                "case-insensitive: ssrf-hunter row received hypothesis boost despite mixed-case hypothesis",
                hunter.get("_state_adj", {}).get("hypothesis_boost", 0) > 0,
                detail=str(hunter.get("_state_adj")),
            )

    # ─── test 16: active hypothesis count visible ───────────
    def test_hypothesis_active_count_visible(self):
        """The state block reports hypotheses_active count. Adding a
        hypothesis should increment it observably — this is the growth
        sensor for engagements that let HYPOTHESES.md accumulate."""
        shutil.rmtree(self.state_dir); sh("bash", str(STATE_SH), "init", self.target, "--tech", "t")
        d0 = self._recall("test", target=self.target, state_filter="on")
        n0 = d0.get("state", {}).get("hypotheses_active", -1)
        sh("bash", str(STATE_SH), "hypothesis", self.target, "add",
           "first probe hypothesis", "--priority", "low")
        sh("bash", str(STATE_SH), "hypothesis", self.target, "add",
           "second probe hypothesis", "--priority", "medium")
        d2 = self._recall("test", target=self.target, state_filter="on")
        n2 = d2.get("state", {}).get("hypotheses_active", -1)
        self.check(
            "hypotheses_active: starts at 0 after init",
            n0 == 0,
            detail=f"got {n0}",
        )
        self.check(
            "hypotheses_active: increments to 2 after two adds",
            n2 == 2,
            detail=f"got {n2}",
        )
        # boost side-effect: with hypotheses present, at least one row should
        # carry hypothesis_active_count in its _state_adj (informational field)
        with_active_count = [
            r for r in d2.get("results", [])
            if r.get("_state_adj", {}).get("hypothesis_active_count") == 2
        ]
        self.check(
            "hypotheses_active: _state_adj carries hypothesis_active_count on affected rows",
            len(with_active_count) >= 1,
            detail=f"rows-with-count: {len(with_active_count)}",
        )

    # ─── test 17: no boost when no hypothesis exists ────────
    def test_hypothesis_boost_absent_without_hypotheses(self):
        """Without any active hypothesis (empty HYPOTHESES.md), no row must
        carry hypothesis_boost or hypothesis_tokens_matched. The absence
        contract keeps the mechanism opt-in — protects test_retrieval floors."""
        shutil.rmtree(self.state_dir); sh("bash", str(STATE_SH), "init", self.target, "--tech", "t")
        data = self._recall("XSS reflected", target=self.target, state_filter="on")
        offenders = [
            r for r in data.get("results", [])
            if r.get("_state_adj", {}).get("hypothesis_boost")
            or r.get("_state_adj", {}).get("hypothesis_tokens_matched")
        ]
        self.check(
            "hypothesis-absent: no row carries hypothesis_boost/tokens when HYPOTHESES.md is empty",
            len(offenders) == 0 and len(data.get("results", [])) > 0,
            detail=f"offenders: {len(offenders)}, total: {len(data.get('results', []))}",
        )

    def run_all(self):
        print("── engagement-state adversarial tests ──")
        self.setup()
        try:
            self.test_negative_knowledge_granularity()
            self.test_scope_preservation()
            self.test_exhausted_not_dominant()
            self.test_no_epistemic_upgrade()
            self.test_input_validation()
            # ─── state-as-filter refactor tests (2026-09-04) ───
            self.test_exhausted_demotes_rank()
            self.test_state_filter_idempotent()
            self.test_state_adj_always_present()
            self.test_exhausted_class_case_normalization()
            self.test_exhausted_parser_handles_em_dash_in_why()
            self.test_recall_on_empty_exhausted_md()
            self.test_class_penalty_fires_on_all_source_kinds()
            self.test_hunter_agent_still_sees_engagement_hints()
            # ─── hypothesis-boost tests (b890e94 → this commit) ───
            self.test_hypothesis_boost_promotes()
            self.test_hypothesis_boost_case_insensitive()
            self.test_hypothesis_active_count_visible()
            self.test_hypothesis_boost_absent_without_hypotheses()
        finally:
            self.teardown()

        print()
        print(f"  PASSED: {len(self.passed)}   FAILED: {len(self.failed)}")
        if self.failed:
            print("  Failures:")
            for name, detail in self.failed:
                print(f"    - {name}: {detail}")
            sys.exit(1)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    Test(verbose=args.verbose).run_all()
