#!/usr/bin/env bash
# audit-slice.sh — thin CLI over the .audit/ control plane (per references/mad-audit.md).
#
# YAML is authoritative. This script does CRUD + state transitions +
# recording decisions. Every operation is git-reviewable — .audit/*.yaml
# is meant to be committed to the engagement branch.
#
# Usage:
#   audit-slice.sh init <target>              → scaffold .audit/*.yaml from
#                                                references/audit-schemas/
#   audit-slice.sh next                       → print the highest-priority
#                                                slice whose status=planned AND
#                                                whose depends_on are complete
#   audit-slice.sh show <slice_id>            → print that slice's YAML block
#                                                plus resolved invariants
#   audit-slice.sh start <slice_id>           → status planned → active
#   audit-slice.sh complete <slice_id>        → status active → complete +
#                                                aggregate update
#   audit-slice.sh skip <slice_id> "<reason>" → status planned → skipped
#   audit-slice.sh invalidate <slice_id>      → status → invalidated (won't
#                                                be picked by `next`)
#   audit-slice.sh decision <slice_id> <CONFIRMED|REJECTED|INCONCLUSIVE> "<claim>" "<reason>" [<evidence_ids>]
#                                              → append to decisions.yaml
#   audit-slice.sh status                     → 1-liner overall progress
#   audit-slice.sh accounting <slice_id> <input_toks> <output_toks> \
#                             <scaffold> <slice_ctx> <memory> <code> <verify>
#                                              → append to progress.yaml
#                                                runs[].context_accounting
#
# Exit codes: 0 ok · 2 usage · 3 missing dep · 4 slice not found · 5 wrong state.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT_DIR="./.audit"
SCHEMAS="$REPO_ROOT/references/audit-schemas"

CMD="${1:-}"; shift || true
[ -n "$CMD" ] || { sed -n '1,32p' "$0"; exit 2; }

# Pick a python with PyYAML — reuse the pattern from secrets-scan.sh
_pick_py() {
  for py in python3 /usr/bin/python3 /opt/homebrew/bin/python3 /usr/local/bin/python3 python; do
    if command -v "$py" >/dev/null 2>&1 && "$py" -c "import yaml" >/dev/null 2>&1; then
      printf '%s' "$py"; return 0
    fi
  done
  return 1
}
PY="$(_pick_py || true)"
if [ -z "$PY" ]; then
  echo "audit-slice: no python3 with PyYAML found" >&2
  echo "  install via: pip3 install --user pyyaml  |  apk add py3-yaml  |  apt install python3-yaml" >&2
  exit 3
fi

_require_init() {
  [ -d "$AUDIT_DIR" ] || { echo "audit-slice: .audit/ not initialized. Run: audit-slice.sh init <target>" >&2; exit 3; }
}

case "$CMD" in

  # ─── init ───────────────────────────────────────────────
  init)
    TARGET="${1:-}"; [ -n "$TARGET" ] || { echo "usage: audit-slice.sh init <target>"; exit 2; }
    if [ -d "$AUDIT_DIR" ]; then
      echo "⚠️  $AUDIT_DIR already exists — not overwriting. Delete it manually to re-init." >&2
      exit 0
    fi
    mkdir -p "$AUDIT_DIR"
    for f in system-context threat-model invariants slices progress decisions; do
      cp "$SCHEMAS/${f}.yaml" "$AUDIT_DIR/${f}.yaml"
    done
    # Substitute the target name in system-context
    "$PY" - "$AUDIT_DIR/system-context.yaml" "$TARGET" <<'PYEOF'
import sys
p, target = sys.argv[1], sys.argv[2]
text = open(p).read().replace("TARGET_NAME", target)
open(p, "w").write(text)
PYEOF
    echo "✓ .audit/ scaffolded for target=$TARGET"
    echo "  next: edit .audit/system-context.yaml (trust boundaries + crown jewels + attackers)"
    echo "        then Agent(slice-planner) to populate threat-model + invariants + slices"
    ;;

  # ─── next ───────────────────────────────────────────────
  next)
    _require_init
    "$PY" - "$AUDIT_DIR" <<'PYEOF'
import sys, yaml
from pathlib import Path
d = Path(sys.argv[1])
slices  = yaml.safe_load(open(d/"slices.yaml")).get("slices", []) or []
# A slice is eligible if status=planned AND every depends_on slice is complete or skipped
done_states = {"complete", "skipped"}
def eligible(s, done_ids):
    if s.get("status") != "planned": return False
    for dep in s.get("depends_on", []) or []:
        if dep not in done_ids: return False
    return True
done_ids = {s["id"] for s in slices if s.get("status") in done_states}
elig = [s for s in slices if eligible(s, done_ids)]
if not elig:
    n_planned = sum(1 for s in slices if s.get("status") == "planned")
    n_blocked = n_planned  # planned but dep-blocked
    print(f"(no eligible slice — planned={n_planned}, none unblocked)")
    sys.exit(0)
# Highest priority = first in list order (operator-controlled). Ties broken by
# fewest depends_on (simpler slices first).
elig.sort(key=lambda s: (slices.index(s), len(s.get("depends_on", []) or [])))
pick = elig[0]
print(f"→ {pick['id']}  ({pick.get('name','?')})")
print(f"   attack_surface: {pick.get('attack_surface', [])}")
print(f"   invariants:     {pick.get('invariants', [])}")
print(f"   attacker:       {pick.get('attacker', '?')}")
print(f"   depends_on:     {pick.get('depends_on', [])}")
PYEOF
    ;;

  # ─── show ───────────────────────────────────────────────
  show)
    _require_init
    SLICE_ID="${1:-}"; [ -n "$SLICE_ID" ] || { echo "usage: audit-slice.sh show <slice_id>"; exit 2; }
    "$PY" - "$AUDIT_DIR" "$SLICE_ID" <<'PYEOF'
import sys, yaml
from pathlib import Path
d, slice_id = Path(sys.argv[1]), sys.argv[2]
slices = yaml.safe_load(open(d/"slices.yaml")).get("slices", []) or []
sl = next((s for s in slices if s.get("id") == slice_id), None)
if sl is None:
    print(f"✗ slice not found: {slice_id}", file=sys.stderr); sys.exit(4)
print(yaml.safe_dump({"slice": sl}, sort_keys=False, indent=2))
# Resolve invariants for the operator
inv_all = {i["id"]: i for i in (yaml.safe_load(open(d/"invariants.yaml")).get("invariants", []) or [])}
print("── invariants (resolved) ──")
for iid in sl.get("invariants", []) or []:
    inv = inv_all.get(iid)
    if not inv: print(f"  ! {iid}  (NOT FOUND in invariants.yaml)"); continue
    print(f"  {iid}  classes={inv.get('classes', [])}")
    print(f"    {inv.get('statement','').strip()}")
PYEOF
    ;;

  # ─── state transitions ─────────────────────────────────
  start|complete|skip|invalidate)
    _require_init
    SLICE_ID="${1:-}"; REASON="${2:-}"
    [ -n "$SLICE_ID" ] || { echo "usage: audit-slice.sh $CMD <slice_id> [reason]"; exit 2; }
    "$PY" - "$AUDIT_DIR" "$SLICE_ID" "$CMD" "$REASON" <<'PYEOF'
import sys, yaml, datetime
from pathlib import Path
d, slice_id, cmd, reason = Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
slices_path = d/"slices.yaml"
data = yaml.safe_load(open(slices_path))
slices = data.get("slices", []) or []
sl = next((s for s in slices if s.get("id") == slice_id), None)
if sl is None:
    print(f"✗ slice not found: {slice_id}", file=sys.stderr); sys.exit(4)
transitions = {
    "start":       ("planned", "active"),
    "complete":    ("active", "complete"),
    "skip":        ("planned", "skipped"),
    "invalidate":  (None, "invalidated"),   # from any state
}
from_state, to_state = transitions[cmd]
cur = sl.get("status", "planned")
if from_state is not None and cur != from_state:
    print(f"✗ cannot {cmd}: slice is in state '{cur}', requires '{from_state}'", file=sys.stderr); sys.exit(5)
sl["status"] = to_state
ts = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
if cmd == "start":
    sl.setdefault("started_at", ts)
elif cmd == "complete":
    sl.setdefault("completed_at", ts)
if cmd in ("skip", "invalidate") and reason:
    sl.setdefault(f"{cmd}_reason", reason)
open(slices_path, "w").write(yaml.safe_dump(data, sort_keys=False, indent=2))
# also append to progress.yaml runs on start / complete
if cmd in ("start", "complete"):
    prog_path = d/"progress.yaml"
    prog = yaml.safe_load(open(prog_path)) or {"schema_version": 1, "runs": [], "aggregate": {}}
    if not isinstance(prog.get("runs"), list): prog["runs"] = []
    if cmd == "start":
        prog["runs"].append({"slice_id": slice_id, "started_at": ts})
    elif cmd == "complete":
        for r in reversed(prog["runs"]):
            if r.get("slice_id") == slice_id and "completed_at" not in r:
                r["completed_at"] = ts; break
    open(prog_path, "w").write(yaml.safe_dump(prog, sort_keys=False, indent=2))
print(f"✓ {slice_id}: {cur} → {to_state}")
PYEOF
    ;;

  # ─── decision ──────────────────────────────────────────
  decision)
    _require_init
    SLICE_ID="${1:-}"; VERDICT="${2:-}"; CLAIM="${3:-}"; REASON="${4:-}"; EVIDENCE="${5:-}"
    [ -n "$SLICE_ID" ] && [ -n "$VERDICT" ] && [ -n "$CLAIM" ] \
      || { echo 'usage: audit-slice.sh decision <slice_id> <CONFIRMED|REJECTED|INCONCLUSIVE> "<claim>" "<reason>" [<evidence_ids>]'; exit 2; }
    case "$VERDICT" in CONFIRMED|REJECTED|INCONCLUSIVE) : ;;
      *) echo "verdict must be CONFIRMED|REJECTED|INCONCLUSIVE (got: $VERDICT)" >&2; exit 2 ;;
    esac
    "$PY" - "$AUDIT_DIR" "$SLICE_ID" "$VERDICT" "$CLAIM" "$REASON" "$EVIDENCE" <<'PYEOF'
import sys, yaml
from pathlib import Path
d, slice_id, verdict, claim, reason, evidence = (Path(sys.argv[1]),) + tuple(sys.argv[2:7])
dec_path = d/"decisions.yaml"
data = yaml.safe_load(open(dec_path)) or {"schema_version": 1, "decisions": []}
# YAML `decisions:` with no rows parses to None, not []; normalize.
if not isinstance(data.get("decisions"), list): data["decisions"] = []
next_id = f"DEC-{len(data['decisions'])+1:03d}"
evi_list = [e.strip() for e in (evidence or "").split(",") if e.strip()]
reason_list = [r.strip() for r in (reason or "").split(";") if r.strip()]
data["decisions"].append({
    "id": next_id,
    "slice_id": slice_id,
    "decision": verdict,
    "claim": claim,
    "reason": reason_list,
    "evidence": evi_list,
    "promoted_to_brain_lesson": False,
})
open(dec_path, "w").write(yaml.safe_dump(data, sort_keys=False, indent=2))
print(f"✓ {next_id}: {verdict} — {claim[:60]}")
PYEOF
    ;;

  # ─── accounting ────────────────────────────────────────
  accounting)
    _require_init
    SLICE_ID="${1:-}"; shift || true
    IN_TOK="${1:-0}"; OUT_TOK="${2:-0}"
    SCAF="${3:-0}"; SLICE_CTX="${4:-0}"; MEM="${5:-0}"; CODE="${6:-0}"; VER="${7:-0}"
    [ -n "$SLICE_ID" ] || { echo "usage: audit-slice.sh accounting <slice_id> <in> <out> <scaf> <slice_ctx> <mem> <code> <verify>"; exit 2; }
    "$PY" - "$AUDIT_DIR" "$SLICE_ID" "$IN_TOK" "$OUT_TOK" "$SCAF" "$SLICE_CTX" "$MEM" "$CODE" "$VER" <<'PYEOF'
import sys, yaml
from pathlib import Path
args = sys.argv[1:]
d = Path(args[0]); slice_id = args[1]
ints = [int(x or 0) for x in args[2:9]]
in_tok, out_tok, scaf, slice_ctx, mem, code, ver = ints
prog_path = d/"progress.yaml"
prog = yaml.safe_load(open(prog_path)) or {"schema_version": 1, "runs": [], "aggregate": {}}
if not isinstance(prog.get("runs"), list): prog["runs"] = []
run = None
for r in reversed(prog["runs"]):
    if r.get("slice_id") == slice_id:
        run = r; break
if run is None:
    run = {"slice_id": slice_id}; prog["runs"].append(run)
run["context_accounting"] = {
    "total_input_tokens": in_tok,
    "total_output_tokens": out_tok,
    "persistent_scaffolding_tokens": scaf,
    "slice_context_tokens": slice_ctx,
    "memory_tokens": mem,
    "code_exploration_tokens": code,
    "verification_tokens": ver,
}
open(prog_path, "w").write(yaml.safe_dump(prog, sort_keys=False, indent=2))
total_context = scaf + slice_ctx + mem + code + ver
if total_context > 0:
    exploration_pct = round(100 * code / total_context, 1)
    scaffolding_pct = round(100 * (scaf + slice_ctx) / total_context, 1)
    verify_pct = round(100 * ver / total_context, 1)
    print(f"✓ accounting recorded for {slice_id}")
    print(f"  ratio: scaffolding={scaffolding_pct}%  exploration={exploration_pct}%  verification={verify_pct}%")
    if scaffolding_pct > 15:
        print(f"  ⚠ scaffolding >15% — consider trimming system-context.yaml or threat-model.yaml")
PYEOF
    ;;

  # ─── status ────────────────────────────────────────────
  status)
    _require_init
    "$PY" - "$AUDIT_DIR" <<'PYEOF'
import sys, yaml
from pathlib import Path
from collections import Counter
d = Path(sys.argv[1])
slices  = yaml.safe_load(open(d/"slices.yaml")).get("slices", []) or []
decs    = yaml.safe_load(open(d/"decisions.yaml")).get("decisions", []) or []
statuses = Counter(s.get("status", "planned") for s in slices)
verdicts = Counter(dec.get("decision", "?") for dec in decs)
print(f"── audit status ──")
print(f"  slices:     {dict(statuses)}   (total {len(slices)})")
print(f"  decisions:  {dict(verdicts)}    (total {len(decs)})")
PYEOF
    ;;

  *)
    sed -n '1,32p' "$0"; exit 2
    ;;
esac
