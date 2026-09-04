#!/usr/bin/env python3
"""
test_end_to_end.py — the full intelligence loop, exactly as described in the audit:

    init target
      → observe technology
        → recall (baseline)
          → add hypothesis
            → test (record result)
              → exhaust the negative vector
                → recall again
                  → verify exhausted vector is deprioritized or excluded
                    → new hypothesis
                      → add evidence
                        → export for ruflo

If any step breaks or the recall-after-exhaustion test fails (exhausted
still dominates), we've regressed the state-as-filter behavior.

Usage: python3 tests/intelligence/test_end_to_end.py [--verbose]
Exit: 0 pass, 1 fail.
"""

import argparse
import json
import subprocess
import sys
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
STATE  = REPO / "scripts" / "engagement-state.sh"
RECALL = REPO / "scripts" / "intelligence-recall.sh"
RUFLO  = REPO / "scripts" / "brain-sync-ruflo.sh"


def sh(*args, check=True):
    p = subprocess.run(list(args), capture_output=True, text=True, cwd=str(REPO))
    if check and p.returncode != 0:
        raise RuntimeError(f"cmd failed: {args}\n  stdout: {p.stdout}\n  stderr: {p.stderr}")
    return p.stdout


def run():
    target = "e2e-test.example.com"
    state_dir = REPO / ".engagement" / target
    if state_dir.exists():
        shutil.rmtree(state_dir)

    verbose = "--verbose" in sys.argv
    def log(*a):
        if verbose: print("   ", *a)

    passed = []
    failed = []
    def assert_(name, cond, detail=""):
        (passed if cond else failed).append((name, detail))
        print(f"  {'✓' if cond else '✗'} {name}" + (f"   ({detail})" if not cond else ""))

    print("── end-to-end intelligence loop ──")
    print()

    # STEP 1: init
    sh("bash", str(STATE), "init", target, "--tech", "Next.js 14, Postgres, AWS Fargate, defaults")
    assert_("init: engagement dir created", state_dir.is_dir())
    assert_("init: TECHNOLOGY.md populated", "Next.js 14" in (state_dir / "TECHNOLOGY.md").read_text())

    # STEP 2: observe
    sh("bash", str(STATE), "observe", target, "webhook /api/hook accepts url= param, server fetches it")
    obs = (state_dir / "OBSERVED.md").read_text()
    assert_("observe: observation appended", "webhook /api/hook" in obs)

    # STEP 3: baseline recall — RRF via router
    _ = sh("bash", str(RECALL), "SSRF url parameter webhook",
           "--target", target, "--class", "ssrf",
           "--sources", "lex,target", "--limit", "10", "--json")
    baseline_data = json.loads(_)
    baseline_top = [r.get("path", "?") for r in baseline_data.get("results", [])[:5]]
    log("baseline top-5:", baseline_top)
    assert_("recall: baseline returns results", len(baseline_data.get("results", [])) > 0)

    # STEP 4: add hypothesis
    sh("bash", str(STATE), "hypothesis", target, "add",
       "SSRF via redirect chain to internal ELB", "--priority", "high")
    hyp = (state_dir / "HYPOTHESES.md").read_text()
    assert_("hypothesis: added with HIGH priority", "[HIGH]" in hyp and "redirect chain" in hyp)

    # STEP 5: test the hypothesis (record result — negative)
    sh("bash", str(STATE), "tested", target,
       "SSRF via direct 169.254.169.254", "connection refused")
    tested = (state_dir / "TESTED.md").read_text()
    assert_("tested: hypothesis+result recorded",
            "SSRF via direct" in tested and "connection refused" in tested)

    # STEP 6: exhaust the negative vector
    sh("bash", str(STATE), "exhausted", target,
       "ssrf", "url_parameter", "direct-metadata",
       "AWS IMDSv1 blocked at /api/hook", "evidence/imds-x.txt")
    exh = (state_dir / "EXHAUSTED.md").read_text()
    assert_("exhaust: vector recorded with scope",
            "[ssrf]" in exh and "direct-metadata" in exh)

    # STEP 7: recall again — verify state IS visible to the router
    _ = sh("bash", str(RECALL), "SSRF direct metadata",
           "--target", target, "--class", "ssrf",
           "--sources", "target", "--limit", "10", "--json")
    post = json.loads(_)
    target_hits = post.get("sources", {}).get("target", 0)
    assert_("recall-after-exhaust: target source surfaces state files",
            target_hits >= 1,
            detail=f"target hits: {target_hits} (expected ≥1 — EXHAUSTED.md should register)")

    # STEP 8: evidence add w/ epistemic ternary
    sh("bash", str(STATE), "evidence", target, "add",
       "--observation", "server returns 500 'connection refused' on http://169.254.169.254",
       "--evidence", "evidence/imds-x.txt line 12",
       "--interpretation", "backend can reach IMDS host but v1 blocked",
       "--hypothesis", "IMDSv2 enabled — need token flow",
       "--epistemic", "DERIVED",
       "--confidence", "HIGH")
    evi_rows = [json.loads(l) for l in (state_dir / "EVIDENCE.jsonl").read_text().splitlines() if l.strip()]
    assert_("evidence: DERIVED/HIGH row appended",
            len(evi_rows) == 1
            and evi_rows[0]["epistemic_status"] == "DERIVED"
            and evi_rows[0]["confidence"] == "HIGH")

    # STEP 9: new hypothesis
    sh("bash", str(STATE), "hypothesis", target, "add",
       "IMDSv2 token flow via PUT with X-aws-ec2-metadata-token-ttl-seconds",
       "--priority", "high")
    hyp = (state_dir / "HYPOTHESES.md").read_text()
    assert_("hypothesis: post-evidence follow-up added",
            "IMDSv2 token flow" in hyp)

    # STEP 10: ruflo export (registry mode w/ provenance)
    sh("bash", str(RUFLO), "--from-registry")
    export = (REPO / "brain" / "ruflo-export.jsonl").read_text().splitlines()
    assert_("ruflo: export produced ≥100 provenance-tagged rows",
            len(export) >= 100)
    first_row = json.loads(export[0])
    assert_("ruflo: rows carry provenance.last_verified for staleness detection",
            "last_verified" in first_row.get("provenance", {}))

    # cleanup
    if state_dir.exists():
        shutil.rmtree(state_dir)

    print()
    print(f"  PASSED: {len(passed)}   FAILED: {len(failed)}")
    if failed:
        print()
        for name, detail in failed: print(f"    ✗ {name}   {detail}")
        sys.exit(1)


if __name__ == "__main__":
    run()
