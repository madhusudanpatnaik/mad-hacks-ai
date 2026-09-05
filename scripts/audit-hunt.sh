#!/usr/bin/env bash
# audit-hunt.sh — score every hunter in agents/manifest.json against a slice
# and emit the dispatch plan for the operator to execute via Agent() calls.
#
# Bash cannot spawn Claude Code subagents directly. This script does the
# READ-ONLY scoring + planning; the operator (Claude) then reads the plan
# and issues the Agent() calls with AUDIT_SLICE set so each hunter's
# Preflight preamble loads slice-scoped context.
#
# Scoring is 3-dimensional per references/mad-audit.md (equal weight):
#   1. attack-surface match  = |slice.attack_surface ∩ hunter.supported_classes| / |slice.attack_surface|
#   2. invariant coverage    = |slice_invariant_classes ∩ hunter.supported_classes| / |slice_invariant_classes|
#   3. dependency availability = 1 - missing_deps / total_deps  (all hunter.requires_scripts + requires_references)
# Preferred hunters (slice.preferred_hunters) break ties by getting a small bump.
#
# Usage:
#   audit-hunt.sh <slice_id>                → print top-6 hunters + dispatch plan
#   audit-hunt.sh <slice_id> --top N        → top-N (min 2, max 8)
#   audit-hunt.sh <slice_id> --json         → machine-readable
#   audit-hunt.sh <slice_id> --all          → all hunters ranked (debug)
#
# Exit codes: 0 ok · 2 usage · 3 missing dep · 4 slice/manifest not found.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT_DIR="./.audit"
MANIFEST="$REPO_ROOT/agents/manifest.json"

SLICE_ID="${1:-}"
TOP=6
FMT="text"
SHOW_ALL=0
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --top)   TOP="${2:-6}"; shift 2 ;;
    --json)  FMT="json"; shift ;;
    --all)   SHOW_ALL=1; shift ;;
    --help|-h) sed -n '1,26p' "$0"; exit 0 ;;
    *) echo "audit-hunt: unknown flag $1"; exit 2 ;;
  esac
done
[ -n "$SLICE_ID" ] || { sed -n '1,26p' "$0"; exit 2; }
[ -d "$AUDIT_DIR" ] || { echo "audit-hunt: .audit/ not initialized (run audit-slice.sh init)" >&2; exit 3; }
[ -f "$MANIFEST" ]   || { echo "audit-hunt: manifest missing ($MANIFEST) — run: python3 scripts/agents-manifest.py" >&2; exit 4; }

_pick_py() {
  for py in python3 /usr/bin/python3 /opt/homebrew/bin/python3 /usr/local/bin/python3 python; do
    if command -v "$py" >/dev/null 2>&1 && "$py" -c "import yaml" >/dev/null 2>&1; then
      printf '%s' "$py"; return 0
    fi
  done
  return 1
}
PY="$(_pick_py || true)"
[ -n "$PY" ] || { echo "audit-hunt: no python3 with PyYAML found" >&2; exit 3; }

"$PY" - "$MANIFEST" "$AUDIT_DIR" "$SLICE_ID" "$TOP" "$FMT" "$SHOW_ALL" "$REPO_ROOT" <<'PYEOF'
import json, sys, yaml
from pathlib import Path

manifest_path, audit_dir, slice_id, top, fmt, show_all, repo_root = sys.argv[1:8]
top = max(2, min(int(top), 8)); show_all = int(show_all)
audit_dir = Path(audit_dir); repo_root = Path(repo_root)

# ─── load state ─────────────────────────────────────────
manifest = json.load(open(manifest_path))
hunters  = [a for a in manifest["agents"] if a.get("agent_type") == "hunter"]
slices   = yaml.safe_load(open(audit_dir/"slices.yaml")).get("slices", []) or []
invariants_all = {i["id"]: i for i in (yaml.safe_load(open(audit_dir/"invariants.yaml")).get("invariants", []) or [])}

sl = next((s for s in slices if s.get("id") == slice_id), None)
if sl is None:
    print(f"✗ slice not found: {slice_id}", file=sys.stderr); sys.exit(4)

slice_surface = set(c.lower() for c in (sl.get("attack_surface", []) or []))
slice_inv_ids = sl.get("invariants", []) or []
preferred     = set(sl.get("preferred_hunters", []) or [])

# ─── derive invariant classes ───────────────────────────
slice_inv_classes = set()
for iid in slice_inv_ids:
    inv = invariants_all.get(iid)
    if inv:
        for c in inv.get("classes", []) or []:
            slice_inv_classes.add(c.lower())

# ─── score every hunter ─────────────────────────────────
def score(h):
    hunter_classes = set(c.lower() for c in (h.get("supported_classes", []) or []))
    # d1: attack-surface match
    d1 = (len(slice_surface & hunter_classes) / max(len(slice_surface), 1)) if slice_surface else 0.5
    # d2: invariant coverage
    d2 = (len(slice_inv_classes & hunter_classes) / max(len(slice_inv_classes), 1)) if slice_inv_classes else 0.5
    # d3: dependency availability
    req_s = h.get("requires_scripts", []) or []
    req_r = h.get("requires_references", []) or []
    missing = sum(1 for s in req_s if not (repo_root/"scripts"/s).exists()) \
            + sum(1 for r in req_r if not (repo_root/"references"/r).exists())
    total = len(req_s) + len(req_r)
    d3 = 1.0 if total == 0 else (total - missing) / total
    # equal weight
    base = (d1 + d2 + d3) / 3.0
    # small bump for preferred hunters (tie-breaker)
    bump = 0.05 if h.get("agent_id") in preferred else 0.0
    return round(base + bump, 4), {"attack_surface": round(d1, 3),
                                    "invariant_coverage": round(d2, 3),
                                    "dependency_availability": round(d3, 3),
                                    "preferred_bump": bump}

ranked = []
for h in hunters:
    s, breakdown = score(h)
    if s <= 0: continue  # skip zero-signal hunters entirely
    ranked.append({"agent_id": h["agent_id"], "score": s, "breakdown": breakdown,
                   "path": h["path"], "supported_classes": h.get("supported_classes", [])})
ranked.sort(key=lambda x: -x["score"])

picked = ranked[:top]

# ─── output ─────────────────────────────────────────────
if fmt == "json":
    print(json.dumps({
        "slice_id": slice_id,
        "slice_attack_surface": sorted(slice_surface),
        "slice_invariant_classes": sorted(slice_inv_classes),
        "preferred_hunters": sorted(preferred),
        "dispatched": picked,
        "considered": len(ranked),
    }, indent=2))
    sys.exit(0)

# text mode
print(f"── audit-hunt  slice={slice_id}  attack_surface={sorted(slice_surface)}  invariant_classes={sorted(slice_inv_classes)} ──")
print(f"   considered: {len(ranked)} hunters   dispatched: top {len(picked)}")
print()
print(f"  {'#':>2}  {'score':>6}  {'aS':>5} {'iC':>5} {'dA':>5}  {'agent_id':<32}  classes")
print("  " + "-" * 84)
for i, r in enumerate(picked, 1):
    b = r["breakdown"]
    marker = "★" if b.get("preferred_bump", 0) > 0 else " "
    print(f"  {i:>2}  {r['score']:>6.3f}  {b['attack_surface']:>5.2f} {b['invariant_coverage']:>5.2f} {b['dependency_availability']:>5.2f}  {marker} {r['agent_id']:<30}  {r['supported_classes']}")

if show_all:
    print()
    print("── all ranked (--all) ──")
    for r in ranked[len(picked):]:
        b = r["breakdown"]
        print(f"      {r['score']:>6.3f}  {b['attack_surface']:>5.2f} {b['invariant_coverage']:>5.2f} {b['dependency_availability']:>5.2f}    {r['agent_id']:<30}")

# ─── dispatch plan for the operator ─────────────────────
print()
print("── DISPATCH PLAN ──")
print(f"  For each picked hunter, invoke via the Agent tool with AUDIT_SLICE={slice_id} in env:")
for r in picked:
    print(f"    Agent({{subagent_type: '{r['agent_id']}', prompt: '<slice-scoped brief>'}})")
print()
print(f"  Each hunter's Preflight will detect AUDIT_SLICE and call:")
print(f"    bash scripts/intelligence-recall.sh --slice {slice_id} --target <target> --limit 12 --json")
print(f"  Instead of the broader class-only recall used by /mad-hunt.")
print()
print(f"  On candidate emission, dispatch verifier-strict:")
print(f"    Agent({{subagent_type: 'verifier-strict', prompt: '<candidate + slice + invariants>'}})")
print()
print(f"  Then record the verdict via:")
print(f"    bash scripts/audit-slice.sh decision {slice_id} <CONFIRMED|REJECTED|INCONCLUSIVE> \"<claim>\" \"<reason>\" [<evi>]")
PYEOF
