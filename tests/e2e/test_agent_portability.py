#!/usr/bin/env python3
"""
test_agent_portability.py — the 55-agent runtime as a repo-canonical invariant.

Per the operator-integration audit priority #3: your runtime behavior depends
on artifacts that aren't represented by `git checkout`. Fix: agents/ becomes
canonical, manifest.json anchors sha256 for every agent, sync/verify make
target install match the repo.

This suite proves the fresh-machine reproducibility invariant:

    git checkout + bootstrap → same mad-Hacks behavior

Four adversarial scenarios (all use a tempdir target, never touch the real
~/.claude/agents/):

  1. Fresh sync from an empty target → all 55 agents land + verify green
  2. Corrupt one agent file post-sync → verify FAILS with MODIFIED
  3. Delete one agent file post-sync → verify FAILS with MISSING
  4. Manifest self-consistency:
     - every listed agent exists on disk in the repo
     - every repo agent is listed in the manifest
     - every sha256 in the manifest matches disk (freshness check)
     - every declared required_scripts/references exists in the repo

Usage: python3 tests/e2e/test_agent_portability.py [--verbose]
Exit: 0 pass, 1 fail.
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO       = Path(__file__).resolve().parent.parent.parent
AGENTS_DIR = REPO / "agents"
MANIFEST   = AGENTS_DIR / "manifest.json"
SYNC_SH    = REPO / "scripts" / "agents-sync.sh"
VERIFY_SH  = REPO / "scripts" / "agents-verify.sh"
MANIFEST_PY = REPO / "scripts" / "agents-manifest.py"


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def run(cmd):
    p = subprocess.run(list(cmd), capture_output=True, text=True, cwd=str(REPO))
    return p.returncode, p.stdout, p.stderr


class Test:
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.passed = []
        self.failed = []

    def check(self, name, cond, detail=""):
        (self.passed if cond else self.failed).append((name, detail))
        marker = "✓" if cond else "✗"
        if not cond or self.verbose:
            print(f"  {marker} {name}" + (f"   ({detail})" if not cond else ""))

    # ═════════════════════════════════════════════════════════════════
    # SCENARIO 1 — fresh sync
    # ═════════════════════════════════════════════════════════════════
    def test_fresh_sync(self):
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "agents"
            target.mkdir()
            rc, out, err = run(["bash", str(SYNC_SH), "--target", str(target)])
            self.check(
                "SCENARIO 1: fresh sync into empty target succeeds",
                rc == 0,
                detail=(err or out)[:200],
            )
            manifest = json.load(open(MANIFEST))
            expected_count = manifest["agent_count"]
            landed = list(target.glob("*.md"))
            self.check(
                "SCENARIO 1: exactly manifest_count agents landed",
                len(landed) == expected_count,
                detail=f"got {len(landed)}, expected {expected_count}",
            )
            # verify against the fresh target — should be all-green
            rc, out, err = run(["bash", str(VERIFY_SH), "--target", str(target)])
            self.check(
                "SCENARIO 1: verify against fresh target is clean (exit 0)",
                rc == 0,
                detail=err.strip()[:200],
            )
            self.check(
                "SCENARIO 1: verify reports 0 missing / 0 modified / 0 unsatisfied",
                "MISSING     (in manifest, not installed): 0" in out
                and "MODIFIED    (installed sha ≠ manifest sha):  0" in out
                and "UNSATISFIED (agent references missing repo dep): 0" in out,
            )

    # ═════════════════════════════════════════════════════════════════
    # SCENARIO 2 — corrupted agent file
    # ═════════════════════════════════════════════════════════════════
    def test_corrupt_one_file_detected(self):
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "agents"
            target.mkdir()
            run(["bash", str(SYNC_SH), "--target", str(target)])
            # Corrupt ssrf-hunter — append junk (fastest way to change sha)
            victim = target / "ssrf-hunter.md"
            self.check("SCENARIO 2: victim file present after sync",
                       victim.exists())
            with open(victim, "a") as f:
                f.write("\n<!-- adversarial-tamper -->\n")
            rc, out, err = run(["bash", str(VERIFY_SH), "--target", str(target)])
            self.check(
                "SCENARIO 2: verify EXITS 1 on corrupted file",
                rc == 1,
                detail=err.strip()[:200],
            )
            self.check(
                "SCENARIO 2: verify names ssrf-hunter as MODIFIED",
                "MODIFIED ssrf-hunter" in out or "MODIFIED    ssrf-hunter" in out,
                detail=out[:250],
            )
            # Show the drift is machine-readable via --json
            rc, out2, _ = run(["bash", str(VERIFY_SH), "--target", str(target), "--json"])
            data = json.loads(out2)
            self.check(
                "SCENARIO 2: --json report has 1 modified entry",
                data.get("counts", {}).get("modified") == 1,
            )
            modified = data.get("findings", {}).get("modified", [])
            self.check(
                "SCENARIO 2: --json modified entry names ssrf-hunter + both hashes",
                modified and modified[0].get("agent_id") == "ssrf-hunter"
                and modified[0].get("installed_sha256") != modified[0].get("manifest_sha256"),
            )

    # ═════════════════════════════════════════════════════════════════
    # SCENARIO 3 — deleted agent file
    # ═════════════════════════════════════════════════════════════════
    def test_delete_one_file_detected(self):
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "agents"
            target.mkdir()
            run(["bash", str(SYNC_SH), "--target", str(target)])
            victim = target / "xxe-hunter.md"
            self.check("SCENARIO 3: victim file present after sync",
                       victim.exists())
            victim.unlink()
            rc, out, err = run(["bash", str(VERIFY_SH), "--target", str(target)])
            self.check(
                "SCENARIO 3: verify EXITS 1 on missing file",
                rc == 1,
                detail=err.strip()[:200],
            )
            self.check(
                "SCENARIO 3: verify names xxe-hunter as MISSING",
                "MISSING  xxe-hunter" in out or "MISSING xxe-hunter" in out,
                detail=out[:250],
            )
            # And a re-sync must recover
            rc2, out2, _ = run(["bash", str(SYNC_SH), "--target", str(target)])
            self.check(
                "SCENARIO 3: re-sync recovers the missing file (idempotent)",
                rc2 == 0 and victim.exists(),
                detail=f"exit={rc2} recovered={victim.exists()}",
            )
            rc3, _, _ = run(["bash", str(VERIFY_SH), "--target", str(target)])
            self.check(
                "SCENARIO 3: verify is clean after re-sync",
                rc3 == 0,
            )

    # ═════════════════════════════════════════════════════════════════
    # SCENARIO 4 — manifest self-consistency
    # ═════════════════════════════════════════════════════════════════
    def test_manifest_self_consistency(self):
        # Every listed agent must exist in the repo at the declared path
        m = json.load(open(MANIFEST))
        for a in m["agents"]:
            p = REPO / a["path"]
            self.check(
                f"SCENARIO 4: manifest agent '{a['agent_id']}' exists at repo path",
                p.exists() and p.is_file(),
                detail=f"expected: {p}",
            )
        # Every agent's manifest sha256 matches file sha256 (freshness)
        stale = []
        for a in m["agents"]:
            p = REPO / a["path"]
            if not p.exists():
                continue
            actual = sha256(p)
            if actual != a["sha256"]:
                stale.append((a["agent_id"], actual, a["sha256"]))
        self.check(
            "SCENARIO 4: every manifest sha256 matches file sha256 (manifest is fresh)",
            not stale,
            detail=(
                f"{len(stale)} stale entries — regenerate: python3 scripts/agents-manifest.py; "
                f"examples: {stale[:2]}"
            ),
        )
        # Reverse: every repo agent under agents/{hunters,operators}/ is listed
        want_ids = {a["agent_id"] for a in m["agents"]}
        for atype in ("hunters", "operators"):
            for f in (AGENTS_DIR / atype).glob("*.md"):
                # An unlisted repo file suggests the manifest is stale, OR a
                # dev added a file without regenerating. Either way we flag.
                self.check(
                    f"SCENARIO 4: repo file agents/{atype}/{f.name} appears in manifest",
                    f.stem in want_ids,
                    detail=f"manifest missing entry for {f.stem}",
                )
        # And: python3 scripts/agents-manifest.py --check exits 0 (manifest
        # is byte-identical to what the generator would produce right now)
        rc, out, err = run(["python3", str(MANIFEST_PY), "--check"])
        self.check(
            "SCENARIO 4: manifest --check exits 0 (manifest exactly reproducible)",
            rc == 0,
            detail=(err or out)[:200],
        )

    # ═════════════════════════════════════════════════════════════════
    # BONUS — dependency satisfaction on the current repo
    # ═════════════════════════════════════════════════════════════════
    def test_dependency_satisfaction(self):
        """Every script an agent claims to require must exist in scripts/.
        Every reference must exist in references/. This catches dead links
        BEFORE the hunter dispatches and tries to bash a nonexistent file."""
        m = json.load(open(MANIFEST))
        for a in m["agents"]:
            for s in a.get("requires_scripts", []):
                self.check(
                    f"deps: agent '{a['agent_id']}' -> scripts/{s} exists",
                    (REPO / "scripts" / s).exists(),
                )
            for r in a.get("requires_references", []):
                self.check(
                    f"deps: agent '{a['agent_id']}' -> references/{r} exists",
                    (REPO / "references" / r).exists(),
                )

    def run_all(self):
        print("── agent portability + provenance ──")
        self.test_fresh_sync()
        self.test_corrupt_one_file_detected()
        self.test_delete_one_file_detected()
        self.test_manifest_self_consistency()
        self.test_dependency_satisfaction()

        print()
        print(f"  PASSED: {len(self.passed)}   FAILED: {len(self.failed)}")
        if self.failed:
            print()
            print("  Failures:")
            for name, detail in self.failed[:20]:
                print(f"    ✗ {name}")
                if detail:
                    print(f"       → {detail[:300]}")
            if len(self.failed) > 20:
                print(f"    ... and {len(self.failed) - 20} more")
            sys.exit(1)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    Test(verbose=args.verbose).run_all()
