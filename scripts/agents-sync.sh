#!/usr/bin/env bash
# agents-sync.sh — sync repo-canonical agents into ~/.claude/agents/.
#
# Repo layout is canonical; ~/.claude/agents/ is a REPLICA. Every sync
# starts from what the repo says (sha256-anchored in agents/manifest.json)
# and rewrites the replica to match. Never the other way around.
#
# Usage:
#   scripts/agents-sync.sh                     # sync all repo agents
#   scripts/agents-sync.sh --dry-run           # show what would change
#   scripts/agents-sync.sh --target <dir>      # sync into a custom dir
#                                                (default: ~/.claude/agents)
#   scripts/agents-sync.sh --prune             # ALSO delete files in the
#                                                target that aren't in the
#                                                manifest (dangerous — off
#                                                by default because targets
#                                                may hold user-personal
#                                                agents outside our scope)
#   scripts/agents-sync.sh --check             # exit 1 if target diverges
#                                                from manifest (read-only)
#
# Exit codes:
#   0 — success (or already in sync)
#   1 — divergence (only with --check)
#   2 — usage error
#   3 — manifest missing / not readable
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO/agents/manifest.json"
TARGET="$HOME/.claude/agents"
DRY_RUN=0
PRUNE=0
CHECK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY_RUN=1; shift ;;
    --target)   TARGET="${2:-}"; shift 2 ;;
    --prune)    PRUNE=1; shift ;;
    --check)    CHECK=1; shift ;;
    --help|-h)  sed -n '1,30p' "$0"; exit 0 ;;
    *)          echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

[ -f "$MANIFEST" ] || { echo "✗ manifest missing: $MANIFEST — run: python3 scripts/agents-manifest.py" >&2; exit 3; }

mkdir -p "$TARGET"

PY="/usr/bin/python3"; command -v "$PY" >/dev/null || PY="python3"

# Diff manifest ↔ target — return operations to perform
"$PY" - "$MANIFEST" "$TARGET" "$REPO" "$DRY_RUN" "$PRUNE" "$CHECK" <<'PYEOF'
import hashlib, json, os, shutil, sys
from pathlib import Path

manifest_path, target, repo, dry_run, prune, check = sys.argv[1:7]
dry_run = int(dry_run); prune = int(prune); check = int(check)
target = Path(target); repo = Path(repo)

def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

m = json.load(open(manifest_path))
agents = m["agents"]

# What the manifest wants — agent_id → (repo_path, expected_sha256)
want = {a["agent_id"]: (repo / a["path"], a["sha256"]) for a in agents}

# What's on target now
have = {}
for f in target.glob("*.md"):
    have[f.stem] = f  # agent_id = filename stem

to_add     = []   # in manifest, not in target
to_update  = []   # in both, sha differs
to_prune   = []   # in target, not in manifest (only if --prune)
in_sync    = []

for agent_id, (repo_path, want_sha) in want.items():
    tgt = target / (agent_id + ".md")
    if not tgt.exists():
        to_add.append((agent_id, repo_path, tgt))
    else:
        have_sha = sha256(tgt)
        if have_sha != want_sha:
            to_update.append((agent_id, repo_path, tgt, have_sha, want_sha))
        else:
            in_sync.append(agent_id)

for stem, path in have.items():
    if stem not in want:
        to_prune.append((stem, path))

# ─── report ──────────────────────────────────────────────
def line(sym, msg): print(f"  {sym} {msg}")
mode = "CHECK" if check else ("DRY-RUN" if dry_run else "SYNC")
print(f"── agents-sync ({mode})  manifest={m['agent_count']} agents  target={target} ──")
print(f"  in sync:   {len(in_sync)}")
print(f"  to add:    {len(to_add)}")
print(f"  to update: {len(to_update)}")
print(f"  extra in target (would prune):  {len(to_prune)}" + ("" if prune else "   [--prune to remove]"))

for agent_id, repo_path, tgt in to_add:
    line("+", f"ADD  {agent_id}  ← {repo_path.relative_to(repo)}")
for agent_id, repo_path, tgt, have_sha, want_sha in to_update:
    line("~", f"UPDATE {agent_id}  sha {have_sha[:12]}→{want_sha[:12]}")
if prune:
    for stem, path in to_prune:
        line("-", f"PRUNE {stem}")

# ─── decisions ───────────────────────────────────────────
divergence = bool(to_add or to_update or (prune and to_prune))

if check:
    if divergence:
        print(f"\n✗ target diverges from manifest — run: bash scripts/agents-sync.sh", file=sys.stderr)
        sys.exit(1)
    print("\n✓ target in sync with manifest")
    sys.exit(0)

if dry_run:
    print("\n(dry-run — no changes made)")
    sys.exit(0)

# ─── execute ─────────────────────────────────────────────
for agent_id, repo_path, tgt in to_add:
    shutil.copy2(repo_path, tgt)
for agent_id, repo_path, tgt, _, _ in to_update:
    shutil.copy2(repo_path, tgt)
if prune:
    for stem, path in to_prune:
        path.unlink()

print(f"\n✓ synced: +{len(to_add)} added, ~{len(to_update)} updated"
      + (f", -{len(to_prune)} pruned" if prune else ""))
PYEOF
