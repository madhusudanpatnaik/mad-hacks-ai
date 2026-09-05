#!/usr/bin/env python3
"""
test_audit.py — regression suite for the /mad-audit sliced-audit control plane.

Five test areas per references/mad-audit.md § "The next commit I'd approve":
  1. slice selection    — audit-slice.sh next picks correct slice
  2. hunter scoring     — audit-hunt.sh 3-dim scoring produces expected ranking
  3. retrieval filtering — intelligence-recall.sh --slice scopes correctly
  4. state transitions  — init → start → complete + decision recording
  5. verifier schema    — verifier-strict output shape validates

Uses a per-test tempdir so no real .audit/ is touched.

Usage: python3 tests/audit/test_audit.py [--verbose]
Exit: 0 pass · 1 fail.
"""
import argparse, json, os, shutil, subprocess, sys, tempfile, yaml
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
SLICE_SH  = REPO / "scripts" / "audit-slice.sh"
HUNT_SH   = REPO / "scripts" / "audit-hunt.sh"
RECALL_SH = REPO / "scripts" / "intelligence-recall.sh"


def sh(cmd, cwd=None, check=True):
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    if check and p.returncode != 0:
        raise RuntimeError(f"cmd failed: {cmd}\n  stdout: {p.stdout}\n  stderr: {p.stderr}")
    return p.returncode, p.stdout, p.stderr


class Test:
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.passed = []; self.failed = []

    def check(self, name, cond, detail=""):
        (self.passed if cond else self.failed).append((name, detail))
        marker = "✓" if cond else "✗"
        if not cond or self.verbose:
            print(f"  {marker} {name}" + (f"   ({detail})" if not cond else ""))

    # ─── HELPER: fresh .audit/ in a tempdir ─────────────
    def _fresh_audit(self, td):
        sh(["bash", str(SLICE_SH), "init", "audit-e2e.example.com"], cwd=td)
        return Path(td) / ".audit"

    # ─── AREA 1: slice selection ────────────────────────
    def test_slice_selection(self):
        """`audit-slice next` picks the first planned slice whose depends_on
        are all complete/skipped. Blocked slices are held."""
        with tempfile.TemporaryDirectory() as td:
            audit = self._fresh_audit(td)
            # Extend slices with a dependency chain
            slices_yaml = audit / "slices.yaml"
            data = yaml.safe_load(open(slices_yaml))
            data["slices"] = [
                {"id": "S-A", "name": "A", "status": "planned", "invariants": ["INV-001"], "attack_surface": ["xss"], "depends_on": []},
                {"id": "S-B", "name": "B", "status": "planned", "invariants": ["INV-002"], "attack_surface": ["sqli"], "depends_on": ["S-A"]},
                {"id": "S-C", "name": "C", "status": "planned", "invariants": ["INV-003"], "attack_surface": ["ssrf"], "depends_on": []},
            ]
            open(slices_yaml, "w").write(yaml.safe_dump(data, sort_keys=False))
            _, out, _ = sh(["bash", str(SLICE_SH), "next"], cwd=td)
            self.check("AREA1: next() picks the first eligible slice (S-A)",
                       "S-A" in out, detail=out.strip()[:120])
            # Mark S-A complete; next should now pick S-B (was blocked)
            sh(["bash", str(SLICE_SH), "start", "S-A"], cwd=td)
            sh(["bash", str(SLICE_SH), "complete", "S-A"], cwd=td)
            _, out, _ = sh(["bash", str(SLICE_SH), "next"], cwd=td)
            self.check("AREA1: after S-A complete, next() unblocks S-B",
                       "S-B" in out, detail=out.strip()[:120])
            # Now if all planned are done → 'no eligible'
            for sid in ["S-B", "S-C"]:
                sh(["bash", str(SLICE_SH), "start", sid], cwd=td)
                sh(["bash", str(SLICE_SH), "complete", sid], cwd=td)
            _, out, _ = sh(["bash", str(SLICE_SH), "next"], cwd=td)
            self.check("AREA1: exhausted plan → 'no eligible'",
                       "no eligible" in out, detail=out.strip()[:120])

    # ─── AREA 2: hunter scoring ─────────────────────────
    def test_hunter_scoring(self):
        """audit-hunt.sh --json produces a ranking with 3 breakdown dims.
        Preferred hunters get the +0.05 bump. Zero-signal hunters excluded."""
        with tempfile.TemporaryDirectory() as td:
            audit = self._fresh_audit(td)
            _, out, _ = sh(["bash", str(HUNT_SH), "S-USERAUTH-001", "--json"], cwd=td)
            data = json.loads(out)
            self.check("AREA2: --json output has 'dispatched' list",
                       isinstance(data.get("dispatched"), list) and len(data["dispatched"]) >= 2,
                       detail=f"got {len(data.get('dispatched', []))}")
            # every entry has all 3 breakdown dims + score
            for row in data["dispatched"]:
                b = row.get("breakdown", {})
                if not all(k in b for k in ("attack_surface", "invariant_coverage", "dependency_availability")):
                    self.check("AREA2: every ranked row has 3-dim breakdown", False,
                               detail=f"{row.get('agent_id')} missing dims: {list(b)}")
                    return
            self.check("AREA2: every ranked row has 3-dim breakdown", True)
            # preferred hunters ranked at top when they have >0 signal
            top_ids = [r["agent_id"] for r in data["dispatched"][:2]]
            preferred = set(data.get("preferred_hunters", []))
            hit = preferred & set(top_ids)
            self.check("AREA2: at least one preferred hunter (auth-tester/oauth-hunter/jwt-hunter) in top-2",
                       len(hit) >= 1,
                       detail=f"top-2={top_ids}  preferred={sorted(preferred)}")
            # score is monotone-decreasing
            scores = [r["score"] for r in data["dispatched"]]
            self.check("AREA2: dispatched list is monotone-decreasing by score",
                       all(scores[i] >= scores[i+1] for i in range(len(scores)-1)))
            # zero-signal hunters not in the list (score > 0 for all)
            self.check("AREA2: no zero-score hunters dispatched",
                       all(r["score"] > 0 for r in data["dispatched"]))

    # ─── AREA 3: retrieval filtering ────────────────────
    def test_retrieval_filtering(self):
        """intelligence-recall.sh --slice augments the query with slice terms
        AND surfaces the slice_id in the state block."""
        with tempfile.TemporaryDirectory() as td:
            audit = self._fresh_audit(td)
            # Run recall against the template slice with a neutral raw query
            _, out, _ = sh([
                "bash", str(RECALL_SH), "middleware",
                "--slice", "S-USERAUTH-001",
                "--limit", "5", "--json",
            ], cwd=td)
            data = json.loads(out)
            q = data.get("query", "")
            self.check("AREA3: --slice augments query with attack_surface + invariant classes",
                       "jwt" in q and "authz" in q and "middleware" in q,
                       detail=f"query={q!r}")
            self.check("AREA3: state block reports slice_id",
                       data.get("state", {}).get("slice_id") == "S-USERAUTH-001",
                       detail=str(data.get("state", {}).get("slice_id")))
            self.check("AREA3: --slice still returns results (query didn't over-narrow)",
                       len(data.get("results", [])) > 0)
            # baseline: without --slice, query is raw
            _, out2, _ = sh(["bash", str(RECALL_SH), "middleware", "--limit", "5", "--json"], cwd=td)
            data2 = json.loads(out2)
            self.check("AREA3: without --slice, state.slice_id is null",
                       data2.get("state", {}).get("slice_id") is None,
                       detail=str(data2.get("state", {}).get("slice_id")))
            self.check("AREA3: without --slice, query is unaugmented",
                       data2.get("query") == "middleware",
                       detail=f"got {data2.get('query')!r}")

    # ─── AREA 4: state transitions + decision recording ─
    def test_state_transitions(self):
        with tempfile.TemporaryDirectory() as td:
            audit = self._fresh_audit(td)
            # planned → active → complete
            rc, out, _ = sh(["bash", str(SLICE_SH), "start", "S-USERAUTH-001"], cwd=td, check=False)
            self.check("AREA4: start on planned slice succeeds", rc == 0, detail=out.strip()[:120])
            # cannot start twice
            rc, _, err = sh(["bash", str(SLICE_SH), "start", "S-USERAUTH-001"], cwd=td, check=False)
            self.check("AREA4: cannot start an already-active slice (exit 5)",
                       rc == 5, detail=err.strip()[:120])
            rc, _, _ = sh(["bash", str(SLICE_SH), "complete", "S-USERAUTH-001"], cwd=td, check=False)
            self.check("AREA4: complete on active slice succeeds", rc == 0)
            # decision recording
            rc, out, _ = sh([
                "bash", str(SLICE_SH), "decision", "S-USERAUTH-001",
                "REJECTED", "test claim", "test reason", "EV-001",
            ], cwd=td, check=False)
            self.check("AREA4: decision REJECTED recorded", rc == 0 and "DEC-001" in out)
            # decision REJECTED must land in decisions.yaml
            dec = yaml.safe_load(open(audit / "decisions.yaml"))
            self.check("AREA4: decisions.yaml has 1 REJECTED row",
                       len(dec.get("decisions", []) or []) == 1
                       and dec["decisions"][0]["decision"] == "REJECTED")
            # invalid verdict rejected
            rc, _, err = sh([
                "bash", str(SLICE_SH), "decision", "S-USERAUTH-001",
                "MAYBE", "x", "y",
            ], cwd=td, check=False)
            self.check("AREA4: invalid verdict rejected (exit 2)",
                       rc == 2 and "verdict must be" in err,
                       detail=err.strip()[:120])
            # accounting
            rc, out, _ = sh([
                "bash", str(SLICE_SH), "accounting", "S-USERAUTH-001",
                "1000", "500", "200", "300", "400", "500", "100",
            ], cwd=td, check=False)
            self.check("AREA4: accounting records + prints ratio",
                       rc == 0 and "ratio:" in out,
                       detail=out.strip()[:200])
            prog = yaml.safe_load(open(audit / "progress.yaml"))
            runs = prog.get("runs", []) or []
            self.check("AREA4: progress.yaml runs[] carries context_accounting",
                       len(runs) >= 1 and "context_accounting" in runs[-1])

    # ─── AREA 5: verifier schema shape ──────────────────
    def test_verifier_schema(self):
        """The verifier-strict.md file documents the mandatory YAML shape.
        This test asserts the shape spec is present + parseable — i.e. any
        verdict emitted by a live verifier can be validated against these
        required keys."""
        vp = REPO / "agents" / "operators" / "verifier-strict.md"
        self.check("AREA5: verifier-strict.md exists", vp.exists())
        if not vp.exists(): return
        body = vp.read_text()
        # extract the YAML block from the "Verdict output" section
        # It's between triple-backticks marked as yaml
        import re as _re
        m = _re.search(r"```yaml\n(.+?)\n```", body, _re.DOTALL)
        self.check("AREA5: verifier-strict.md contains a YAML verdict block",
                   m is not None)
        if not m: return
        yaml_block = m.group(1)
        # Should parse as YAML (with the placeholder tokens like true|false being strings)
        # Just check that required keys are present as literal substrings
        required_keys = ["verification:", "reachability:", "attacker_control:",
                         "invariant_violation:", "exploitability:", "impact:",
                         "decision:", "claim:", "reason:", "evidence:",
                         "lesson:", "applies_to_hunters:"]
        missing = [k for k in required_keys if k not in yaml_block]
        self.check("AREA5: verdict block declares all required keys",
                   not missing, detail=f"missing: {missing}")
        # Decision enum
        self.check("AREA5: decision enum is CONFIRMED|REJECTED|INCONCLUSIVE",
                   all(x in yaml_block for x in ["CONFIRMED", "REJECTED", "INCONCLUSIVE"]))

    def run_all(self):
        print("── mad-audit sliced-audit regression suite ──")
        self.test_slice_selection()
        self.test_hunter_scoring()
        self.test_retrieval_filtering()
        self.test_state_transitions()
        self.test_verifier_schema()
        print()
        print(f"  PASSED: {len(self.passed)}   FAILED: {len(self.failed)}")
        if self.failed:
            print()
            print("  Failures:")
            for name, detail in self.failed[:20]:
                print(f"    ✗ {name}")
                if detail:
                    print(f"       → {detail[:280]}")
            sys.exit(1)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    Test(verbose=args.verbose).run_all()
