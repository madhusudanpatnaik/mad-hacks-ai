#!/usr/bin/env python3
"""
test_engagement_e2e.py — the full /mad-hunt organism, deterministic + synthetic.

Per the operator-integration audit: the retrieval subsystem is well-tested
(52 assertions in tests/intelligence/) but the actual operator chain is
not. This suite walks the documented /mad-hunt pipeline end-to-end with
synthetic fixtures, asserting each hop:

  scope accepted
    → state created
      → recon observation recorded
        → class selected & hunter context built
          → intelligence recall executed
            → exhausted item NOT prioritized
              → hypothesis surfaced
                → evidence captured
                  → confirmed finding reaches verifier input
                    → report input carries the finding
                      → brain learning persists

No real exploitation, no real dispatch, no real HTTP. The hunter dispatch
step is simulated by calling the exact scripts a hunter's Preflight would
call (per every hunter agent's .md), and asserting the observable outputs.
This is contract-testing at the pipeline level.

Usage: python3 tests/e2e/test_engagement_e2e.py [--verbose]
Exit: 0 on pass, 1 on any failure.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO      = Path(__file__).resolve().parent.parent.parent
SCOPE_PY  = REPO / "scripts" / "scope.py"
STATE_SH  = REPO / "scripts" / "engagement-state.sh"
RECALL_SH = REPO / "scripts" / "intelligence-recall.sh"
BRAIN_SH  = REPO / "scripts" / "brain.sh"
FIXTURE   = Path(__file__).parent / "fixtures" / "scope-basic.md"

# Synthetic target — inside the fixture's in-scope pattern (*.api.example.com)
TARGET       = "v1.api.example.com"
TARGET_SLUG  = TARGET.lower()  # engagement-state.sh slug()


def run(cmd, cwd=None, env=None):
    p = subprocess.run(list(cmd), capture_output=True, text=True,
                       cwd=cwd or str(REPO), env=env)
    return p.returncode, p.stdout, p.stderr


class Chain:
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.passed = []
        self.failed = []
        self.state_dir = REPO / ".engagement" / TARGET_SLUG
        # Context carried between hops (mimics what a hunter agent would
        # accumulate as it walks Preflight)
        self.hunter_ctx = {}

    def _check(self, name, cond, detail=""):
        (self.passed if cond else self.failed).append((name, detail))
        marker = "✓" if cond else "✗"
        if not cond or self.verbose:
            print(f"  {marker} {name}" + (f"   ({detail})" if not cond else ""))

    def _cleanup(self):
        if self.state_dir.exists():
            shutil.rmtree(self.state_dir)

    # ═════════════════════════════════════════════════════════════════
    # HOP 1 — Scope authorization gate
    # ═════════════════════════════════════════════════════════════════
    def hop1_scope_accepted(self):
        rc, out, err = run(["python3", str(SCOPE_PY), "--md", str(FIXTURE), TARGET])
        self._check("HOP1: scope.py accepts synthetic in-scope target", rc == 0,
                    detail=f"exit={rc} out={out.strip()[:80]}")
        self._check("HOP1: scope.py prints IN-SCOPE marker", "IN-SCOPE" in out)
        self.hunter_ctx["scope_ok"] = (rc == 0)

    # ═════════════════════════════════════════════════════════════════
    # HOP 2 — Engagement state initialization (with scope gate)
    # ═════════════════════════════════════════════════════════════════
    def hop2_state_created(self):
        self._cleanup()
        rc, out, err = run([
            "bash", str(STATE_SH), "init", TARGET,
            "--tech", "Next.js 14, Postgres, AWS, ELB, CloudFront",
            "--scope-check", str(FIXTURE),
        ])
        self._check("HOP2: engagement-state.sh init succeeds with scope gate",
                    rc == 0, detail=f"exit={rc} stderr={err.strip()[:120]}")
        self._check("HOP2: .engagement/<slug>/ directory created",
                    self.state_dir.is_dir())
        # Every canonical file exists
        for fname in ("TECHNOLOGY.md", "OBSERVED.md", "TESTED.md",
                      "EXHAUSTED.md", "HYPOTHESES.md", "EVIDENCE.jsonl", "LOG.md"):
            self._check(f"HOP2: {fname} initialized",
                        (self.state_dir / fname).is_file())
        # Tech string persisted
        tech = (self.state_dir / "TECHNOLOGY.md").read_text()
        self._check("HOP2: TECHNOLOGY.md captures --tech string",
                    "Next.js 14" in tech and "CloudFront" in tech)

    # ═════════════════════════════════════════════════════════════════
    # HOP 3 — Recon observation recorded (surface-probe / recon.sh
    # would call engagement-state.sh observe on each finding)
    # ═════════════════════════════════════════════════════════════════
    def hop3_recon_observation(self):
        obs_lines = [
            "webhook /api/import accepts ?url= param, server fetches it (SSRF surface)",
            "response header X-Powered-By: Next.js 14",
            "auth cookie: __Secure-next-auth.session-token (HttpOnly + Secure + SameSite=Lax)",
            "endpoint /api/graphql accepts application/json AND application/x-www-form-urlencoded",
        ]
        for line in obs_lines:
            rc, _, err = run(["bash", str(STATE_SH), "observe", TARGET, line])
            self._check(f"HOP3: observe recorded — '{line[:50]}...'",
                        rc == 0, detail=err.strip()[:120])
        obs = (self.state_dir / "OBSERVED.md").read_text()
        for line in obs_lines:
            self._check(f"HOP3: OBSERVED.md contains '{line[:40]}...'",
                        line[:40] in obs)

    # ═════════════════════════════════════════════════════════════════
    # HOP 4 — Class selection + hunter context built
    # ═════════════════════════════════════════════════════════════════
    def hop4_class_selected(self):
        """Simulate what /mad-hunt does: parse OBSERVED.md for known
        surface signatures → rank classes. We assert the classifier
        picks classes that match the seeded observations."""
        obs = (self.state_dir / "OBSERVED.md").read_text().lower()
        # Simple classifier — real /mad-hunt uses writeups-corpus + surface probe
        surface_signals = {
            "ssrf":   ["url=", "webhook", "fetches"],
            "graphql": ["/api/graphql", "graphql"],
            "auth-session": ["cookie", "session-token", "samesite"],
            "csrf":   ["cookie", "samesite=lax"],  # Lax leaves top-level GETs open
        }
        selected = []
        for cls, sigs in surface_signals.items():
            if any(s in obs for s in sigs):
                selected.append(cls)
        self._check("HOP4: classifier picks SSRF from ?url= + webhook signals",
                    "ssrf" in selected)
        self._check("HOP4: classifier picks GraphQL from /api/graphql",
                    "graphql" in selected)
        self._check("HOP4: classifier picks auth-session from cookie signals",
                    "auth-session" in selected)
        self._check("HOP4: classifier picks CSRF from SameSite=Lax cookie",
                    "csrf" in selected)
        # Build the hunter context — what a hunter's Preflight would see
        self.hunter_ctx.update({
            "target":         TARGET,
            "state_dir":      str(self.state_dir),
            "classes":        selected,
            "primary_class":  "ssrf",  # highest-signal per surface
        })
        self._check("HOP4: hunter context assembled (target/state/classes)",
                    all(k in self.hunter_ctx for k in ("target", "state_dir", "classes")))

    # ═════════════════════════════════════════════════════════════════
    # HOP 5 — Intelligence recall (the hunter's Preflight step 2)
    # ═════════════════════════════════════════════════════════════════
    def hop5_intelligence_recall(self):
        """Every hunter's Preflight calls intelligence-recall.sh —
        must return a JSON payload with `results` and `state` blocks."""
        cls = self.hunter_ctx["primary_class"]
        rc, out, err = run([
            "bash", str(RECALL_SH),
            "SSRF url parameter webhook fetch",
            "--target", TARGET, "--class", cls,
            "--limit", "12", "--json",
        ])
        self._check("HOP5: intelligence-recall.sh exit 0", rc == 0,
                    detail=err.strip()[:120])
        try:
            data = json.loads(out)
        except json.JSONDecodeError as e:
            self._check("HOP5: recall output is valid JSON", False, detail=str(e)[:120])
            return
        self._check("HOP5: JSON has 'results' array", isinstance(data.get("results"), list))
        self._check("HOP5: JSON has 'state' block (post-fusion state metadata)",
                    isinstance(data.get("state"), dict))
        self._check("HOP5: state.engaged is True (target set)",
                    data.get("state", {}).get("engaged") is True)
        self._check("HOP5: state.exhausted_classes is a list",
                    isinstance(data.get("state", {}).get("exhausted_classes"), list))
        self.hunter_ctx["recall_data"] = data
        self._check("HOP5: results non-empty (fusion produced hits)",
                    len(data.get("results", [])) > 0)

    # ═════════════════════════════════════════════════════════════════
    # HOP 6 — Exhausted item NOT prioritized
    # ═════════════════════════════════════════════════════════════════
    def hop6_exhausted_not_prioritized(self):
        """Record an exhausted vector, then re-run recall and verify
        the row that would-have-been-top for that class is demoted."""
        # Mark direct-metadata IMDSv1 as exhausted for SSRF
        rc, _, err = run([
            "bash", str(STATE_SH), "exhausted", TARGET,
            "ssrf", "url_parameter", "direct-metadata",
            "AWS IMDSv2 blocks v1 raw fetch — confirmed via 403 x-aws-ec2 header",
        ])
        self._check("HOP6: exhausted record written", rc == 0,
                    detail=err.strip()[:120])

        # Recall with state-filter ON vs OFF — compare rank of any ssrf-class row
        rc_on, out_on, _ = run([
            "bash", str(RECALL_SH), "SSRF", "--target", TARGET,
            "--state-filter", "on", "--limit", "15", "--json",
        ])
        rc_off, out_off, _ = run([
            "bash", str(RECALL_SH), "SSRF", "--target", TARGET,
            "--state-filter", "off", "--limit", "15", "--json",
        ])
        if rc_on != 0 or rc_off != 0:
            self._check("HOP6: both recall runs succeed",
                        False, detail=f"on={rc_on} off={rc_off}")
            return
        on_data = json.loads(out_on)
        off_data = json.loads(out_off)

        # Invariant 1: state filter must actually change the ranking.
        # Compare top-5 path/id ordering off vs on — some position must differ.
        def rowkey(r): return r.get("path") or r.get("id") or r.get("title","?")
        off_top5 = [rowkey(r) for r in off_data.get("results", [])[:5]]
        on_top5  = [rowkey(r) for r in on_data.get("results", [])[:5]]
        self._check(
            "HOP6: state filter changes the top-5 order (some position differs)",
            off_top5 != on_top5,
            detail=f"off_top5={off_top5[:3]}... vs on_top5={on_top5[:3]}...",
        )

        # Invariant 2: at least one row got demoted (final < rrf).
        # This proves the exhausted-class mechanism actually fired.
        demoted_on = [
            r for r in on_data.get("results", [])
            if r.get("_state_adj", {}).get("exhausted_penalty")
        ]
        self._check(
            "HOP6: ≥1 row demoted (has exhausted_penalty in _state_adj)",
            len(demoted_on) >= 1,
            detail=f"demoted rows: {len(demoted_on)}",
        )
        if demoted_on:
            first = demoted_on[0]
            self._check(
                "HOP6: demoted row carries exhausted_penalty=0.4",
                first.get("_state_adj", {}).get("exhausted_penalty") == 0.4,
                detail=str(first.get("_state_adj")),
            )
            self._check(
                "HOP6: demoted row _final_score < _rrf_score",
                first.get("_final_score", 0) < first.get("_rrf_score", 0),
                detail=f"rrf={first.get('_rrf_score')} final={first.get('_final_score')}",
            )

        # Invariant 3 (soft): demotion is a POINT REDUCTION, not a banish.
        # When the demoted row's raw rrf_score is >> next row's rrf_score,
        # the row keeps rank 1 even after ×0.4 — this is by design (chain
        # builder may still want the stepping-stone). So we verify the SCORE
        # DROP is real, not necessarily that rank changed.
        if demoted_on:
            key = rowkey(demoted_on[0])
            def find_row(data, key):
                for r in data.get("results", []):
                    if rowkey(r) == key: return r
                return None
            off_row = find_row(off_data, key)
            on_row  = find_row(on_data, key)
            if off_row and on_row:
                self._check(
                    "HOP6: same-row _final_score dropped meaningfully when filter engaged (soft demote works)",
                    on_row.get("_final_score", 0) < off_row.get("_final_score", 0) * 0.5,
                    detail=f"off_final={off_row.get('_final_score')} on_final={on_row.get('_final_score')}",
                )

        # Invariant 4: state block reports ssrf in exhausted_classes
        self._check(
            "HOP6: recall state block reports ssrf in exhausted_classes",
            "ssrf" in on_data.get("state", {}).get("exhausted_classes", []),
        )

    # ═════════════════════════════════════════════════════════════════
    # HOP 7 — Hypothesis surfaced (boost promotes hypothesis-aligned row)
    # ═════════════════════════════════════════════════════════════════
    def hop7_hypothesis_surfaced(self):
        # Add a HIGH-priority hypothesis with distinctive tokens
        rc, _, err = run([
            "bash", str(STATE_SH), "hypothesis", TARGET, "add",
            "SSRF via redirect chain to internal ELB IMDSv2 token flow",
            "--priority", "high",
        ])
        self._check("HOP7: hypothesis add exit 0", rc == 0,
                    detail=err.strip()[:120])
        rc2, out2, _ = run([
            "bash", str(RECALL_SH), "SSRF",
            "--target", TARGET, "--state-filter", "on",
            "--limit", "20", "--json",
        ])
        if rc2 != 0:
            self._check("HOP7: recall succeeded", False)
            return
        data = json.loads(out2)
        self._check("HOP7: state.hypotheses_active == 1",
                    data.get("state", {}).get("hypotheses_active") == 1)
        # At least one row boosted (has positive hypothesis_boost)
        boosted = [
            r for r in data.get("results", [])
            if r.get("_state_adj", {}).get("hypothesis_boost", 0) > 0
        ]
        self._check(
            "HOP7: at least one row received hypothesis_boost",
            len(boosted) >= 1,
            detail=f"boosted rows: {len(boosted)}",
        )
        if boosted:
            top = boosted[0]
            self._check(
                "HOP7: boosted row has hypothesis_tokens_matched populated",
                isinstance(top.get("_state_adj", {}).get("hypothesis_tokens_matched"), list)
                and len(top["_state_adj"]["hypothesis_tokens_matched"]) >= 1,
            )
            # class token 'ssrf' should be in the matched set (from hypothesis text)
            matched_tokens = set()
            for r in boosted:
                matched_tokens.update(r.get("_state_adj", {}).get("hypothesis_tokens_matched", []))
            self._check(
                "HOP7: class-vocabulary token 'ssrf' detected on ≥1 boosted row",
                "ssrf" in matched_tokens,
            )

    # ═════════════════════════════════════════════════════════════════
    # HOP 8 — Evidence captured (structured epistemic row)
    # ═════════════════════════════════════════════════════════════════
    def hop8_evidence_captured(self):
        rc, _, err = run([
            "bash", str(STATE_SH), "evidence", TARGET, "add",
            "--observation", "server returns 500 'connection refused' on 169.254.169.254",
            "--evidence", "evidence/imds-probe.txt line 12",
            "--interpretation", "backend can reach IMDS host but v1 blocked",
            "--hypothesis", "IMDSv2 requires token; test PUT with X-aws-ec2-metadata-token-ttl-seconds",
            "--epistemic", "DERIVED",
            "--confidence", "HIGH",
        ])
        self._check("HOP8: evidence add exit 0", rc == 0,
                    detail=err.strip()[:120])
        rows = [
            json.loads(l) for l in (self.state_dir / "EVIDENCE.jsonl").read_text().splitlines()
            if l.strip()
        ]
        self._check("HOP8: EVIDENCE.jsonl gained 1 row", len(rows) >= 1)
        row = rows[-1]
        self._check("HOP8: epistemic=DERIVED preserved (no silent upgrade)",
                    row.get("epistemic_status") == "DERIVED")
        self._check("HOP8: confidence=HIGH preserved",
                    row.get("confidence") == "HIGH")
        self._check("HOP8: observation field carries the raw ground-truth",
                    "169.254.169.254" in row.get("observation", ""))

    # ═════════════════════════════════════════════════════════════════
    # HOP 9 — Verifier input: does a synthetic finding survive the
    # ADVERSARIAL structure check? (contract test — no real verifier dispatch)
    # ═════════════════════════════════════════════════════════════════
    def hop9_verifier_input(self):
        """A confirmed finding must carry enough structure for t3-verifier to
        adversarially attack it: observation + evidence + interpretation +
        (optional) test + (optional) result. Any confirmed row without these
        is a fabrication risk."""
        rows = [
            json.loads(l) for l in (self.state_dir / "EVIDENCE.jsonl").read_text().splitlines()
            if l.strip()
        ]
        self._check("HOP9: at least one evidence row present", len(rows) >= 1)
        if not rows:
            return
        row = rows[-1]
        required = ["observation", "evidence", "interpretation"]
        missing = [k for k in required if not row.get(k)]
        self._check(
            "HOP9: verifier-input has all required fields (observation/evidence/interpretation)",
            not missing,
            detail=f"missing fields: {missing}",
        )
        # Recall the whole engagement — simulates t3-verifier's
        # `engagement-state.sh recall` step (adversarial gets full context)
        rc, out, err = run(["bash", str(STATE_SH), "recall", TARGET])
        self._check("HOP9: engagement recall for verifier exit 0",
                    rc == 0, detail=err.strip()[:120])
        # Recall output must contain the observation, hypothesis, and exhausted
        for token in ("SSRF via redirect chain", "connection refused", "[ssrf]"):
            self._check(f"HOP9: recall surfaces '{token[:40]}'",
                        token in out or token.lower() in out.lower(),
                        detail=f"missing from recall: {token[:60]}")

    # ═════════════════════════════════════════════════════════════════
    # HOP 10 — Report input: finding data reaches report writer
    # ═════════════════════════════════════════════════════════════════
    def hop10_report_input(self):
        """The report writer needs the same recall + evidence file. We test
        that a JSON snapshot of state (what a report-writer agent would
        read) contains the finding, the exhausted context (for what-was-tested),
        and the hypothesis chain (for exploitation path)."""
        recall_data = self.hunter_ctx.get("recall_data") or {}
        # Rerun recall so we have post-hypothesis data
        rc, out, _ = run([
            "bash", str(RECALL_SH), "SSRF IMDSv2 token flow",
            "--target", TARGET, "--limit", "10", "--json",
        ])
        if rc != 0:
            self._check("HOP10: recall for report gathering succeeds", False)
            return
        data = json.loads(out)
        # Report contract: exhausted classes + active hypotheses must be observable
        state = data.get("state", {})
        self._check("HOP10: report input has exhausted_classes list",
                    isinstance(state.get("exhausted_classes"), list) and state["exhausted_classes"])
        self._check("HOP10: report input has hypotheses_active count",
                    state.get("hypotheses_active", 0) >= 1)
        # Evidence-file contract: at least one row with a well-formed status
        evi_path = self.state_dir / "EVIDENCE.jsonl"
        evi_rows = [json.loads(l) for l in evi_path.read_text().splitlines() if l.strip()]
        self._check("HOP10: evidence available for report writer (≥1 row)",
                    len(evi_rows) >= 1)
        # LOG.md — timeline for the report
        log_content = (self.state_dir / "LOG.md").read_text()
        for marker in ("init: engagement bootstrap", "observe:", "exhausted:", "hypothesis add", "evidence add"):
            self._check(f"HOP10: LOG.md timeline contains '{marker}'",
                        marker in log_content)

    # ═════════════════════════════════════════════════════════════════
    # HOP 11 — Brain learning persists (mad-hacks capture-back doctrine)
    # ═════════════════════════════════════════════════════════════════
    def hop11_brain_learns(self):
        """After the hunter completes a probe, they call brain.sh learn to
        record a reusable heuristic. Assert the write persists AND the
        registry can find it on rebuild."""
        marker = f"E2E-TEST-HEURISTIC-{TARGET_SLUG}: on IMDSv2 hosts, always test the token PUT flow before declaring SSRF dead"
        rc, _, err = run(["bash", str(BRAIN_SH), "learn", marker])
        self._check("HOP11: brain.sh learn exit 0", rc == 0,
                    detail=err.strip()[:120])
        # Verify the lesson landed in the file
        lessons = (REPO / "brain" / "lessons.md").read_text()
        self._check("HOP11: lesson persisted in brain/lessons.md",
                    marker in lessons)
        # Cleanup the test heuristic to keep the file tidy
        import re as _re
        cleaned = _re.sub(rf"^- \[[^\]]+\] {_re.escape(marker)}\n", "",
                          lessons, count=1, flags=_re.M)
        (REPO / "brain" / "lessons.md").write_text(cleaned)
        # Confirm removal (double-check we didn't leave junk)
        self._check("HOP11: test heuristic cleaned from lessons.md",
                    marker not in (REPO / "brain" / "lessons.md").read_text())

    # ═════════════════════════════════════════════════════════════════
    # ORCHESTRATION
    # ═════════════════════════════════════════════════════════════════
    def run_all(self):
        print("── E2E engagement chain (synthetic /mad-hunt walk) ──")
        try:
            self.hop1_scope_accepted()
            self.hop2_state_created()
            self.hop3_recon_observation()
            self.hop4_class_selected()
            self.hop5_intelligence_recall()
            self.hop6_exhausted_not_prioritized()
            self.hop7_hypothesis_surfaced()
            self.hop8_evidence_captured()
            self.hop9_verifier_input()
            self.hop10_report_input()
            self.hop11_brain_learns()
        finally:
            self._cleanup()

        print()
        print(f"  PASSED: {len(self.passed)}   FAILED: {len(self.failed)}")
        if self.failed:
            print()
            print("  Failures:")
            for name, detail in self.failed:
                print(f"    ✗ {name}")
                if detail:
                    print(f"       → {detail[:300]}")
            sys.exit(1)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    Chain(verbose=args.verbose).run_all()
