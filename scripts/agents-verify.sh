#!/usr/bin/env bash
# agents-verify.sh — audit installed ~/.claude/agents/ against agents/manifest.json.
#
# Distinct from agents-sync.sh:
#   * sync    modifies the target to match the manifest
#   * verify  reports drift (READ-ONLY, useful for CI / preflight / audits)
#
# Verify runs three layers of check:
#   1. All manifest agents are installed (no MISSING).
#   2. Every installed sha256 matches the manifest (no MODIFIED).
#   3. Every declared dependency exists in the repo (scripts + references),
#      so an agent that references scripts/foo.sh but the script is deleted
#      is flagged as UNSATISFIED even if the agent file itself is intact.
#
# Usage:
#   scripts/agents-verify.sh                    # human-readable report
#   scripts/agents-verify.sh --strict           # exit 1 on ANY finding
#   scripts/agents-verify.sh --json             # machine-readable
#   scripts/agents-verify.sh --target <dir>     # custom install dir
#
# Exit codes:
#   0 — clean (or non-strict + only informational)
#   1 — drift detected (strict mode, or missing/modified in default mode)
#   2 — usage error
#   3 — manifest missing
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO/agents/manifest.json"
TARGET="$HOME/.claude/agents"
STRICT=0
JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --strict)   STRICT=1; shift ;;
    --json)     JSON=1; shift ;;
    --target)   TARGET="${2:-}"; shift 2 ;;
    --help|-h)  sed -n '1,30p' "$0"; exit 0 ;;
    *)          echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

[ -f "$MANIFEST" ] || { echo "✗ manifest missing: $MANIFEST" >&2; exit 3; }

PY="/usr/bin/python3"; command -v "$PY" >/dev/null || PY="python3"

"$PY" - "$MANIFEST" "$TARGET" "$REPO" "$STRICT" "$JSON" <<'PYEOF'
import hashlib, json, sys
from pathlib import Path

manifest_path, target, repo, strict, out_json = sys.argv[1:6]
strict = int(strict); out_json = int(out_json)
target = Path(target); repo = Path(repo)

def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

m = json.load(open(manifest_path))
agents = m["agents"]

findings = {"missing": [], "modified": [], "unsatisfied": []}

# ─── layer 1+2: presence + sha256 ─────────────────────────
for a in agents:
    tgt = target / (a["agent_id"] + ".md")
    if not tgt.exists():
        findings["missing"].append({
            "agent_id": a["agent_id"],
            "expected_path": str(tgt),
        })
        continue
    have_sha = sha256(tgt)
    if have_sha != a["sha256"]:
        findings["modified"].append({
            "agent_id": a["agent_id"],
            "installed_sha256": have_sha,
            "manifest_sha256":  a["sha256"],
            "installed_path":   str(tgt),
        })

# ─── layer 3: repo-side dependency satisfaction ──────────
for a in agents:
    unsat_scripts = [s for s in a.get("requires_scripts", [])
                     if not (repo / "scripts" / s).exists()]
    unsat_refs    = [r for r in a.get("requires_references", [])
                     if not (repo / "references" / r).exists()]
    if unsat_scripts or unsat_refs:
        findings["unsatisfied"].append({
            "agent_id":       a["agent_id"],
            "missing_scripts":    unsat_scripts,
            "missing_references": unsat_refs,
        })

report = {
    "manifest_agents": m["agent_count"],
    "target_dir":      str(target),
    "counts": {
        "missing":     len(findings["missing"]),
        "modified":    len(findings["modified"]),
        "unsatisfied": len(findings["unsatisfied"]),
    },
    "findings": findings,
}

if out_json:
    print(json.dumps(report, indent=2))
else:
    print(f"── agents-verify  target={target}  manifest={m['agent_count']} agents ──")
    print(f"  MISSING     (in manifest, not installed): {len(findings['missing'])}")
    print(f"  MODIFIED    (installed sha ≠ manifest sha):  {len(findings['modified'])}")
    print(f"  UNSATISFIED (agent references missing repo dep): {len(findings['unsatisfied'])}")
    for k in ("missing", "modified", "unsatisfied"):
        for f in findings[k]:
            aid = f.get("agent_id", "?")
            if k == "missing":
                print(f"    - MISSING  {aid}  (want at {f['expected_path']})")
            elif k == "modified":
                print(f"    - MODIFIED {aid}  installed={f['installed_sha256'][:12]}  manifest={f['manifest_sha256'][:12]}")
            else:
                miss = []
                if f.get("missing_scripts"):    miss.append("scripts=" + ",".join(f["missing_scripts"]))
                if f.get("missing_references"): miss.append("refs=" + ",".join(f["missing_references"]))
                print(f"    - UNSATISFIED {aid}  {' '.join(miss)}")

# ─── exit code ───────────────────────────────────────────
divergent = bool(findings["missing"] or findings["modified"])
if divergent or (strict and findings["unsatisfied"]):
    sys.exit(1)
sys.exit(0)
PYEOF
