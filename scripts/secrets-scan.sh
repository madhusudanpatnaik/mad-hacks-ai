#!/usr/bin/env bash
# secrets-scan.sh — trufflehog + gitleaks wrapper for the secrets/API-key/tokens/
# credentials/passwords detection lane. 1610 ReDoS-safe regex patterns from
# packs/secrets-patterns-db (mazen160). Finds AWS AKIA, GCP, Azure, Stripe,
# GitHub PAT, Slack, Google API, OpenAI, JWT, OAuth secrets, .env leaks, .git.
# Single entry point for the mad-hacks secrets-detection workflow.
#
# Pre-generated rule sets live in brain/registry/secrets-rules/ — regenerate
# from the pack via --rebuild-rules after any upstream update.
#
# Execution mode: receipt_required for --verify (may hit provider APIs like
# aws sts / github /user to prove a match is LIVE). Default is
# safe_command (regex-only, no outbound).
#
# Usage:
#   scripts/secrets-scan.sh <path>                    # both scanners, no verification
#   scripts/secrets-scan.sh <path> --scanner truffle  # only trufflehog
#   scripts/secrets-scan.sh <path> --scanner gitleaks # only gitleaks
#   scripts/secrets-scan.sh <path> --high-only        # high-confidence rules only
#   scripts/secrets-scan.sh <path> --verify           # try to verify LIVE credentials
#                                                     # (RECEIPT_REQUIRED — pauses)
#   scripts/secrets-scan.sh <path> --out <dir>        # write raw JSON here
#
# Exit codes:
#   0 — no secrets found
#   1 — secrets found (see report)
#   2 — usage error / missing dep
#   3 — rules missing (run: bash scripts/secrets-scan.sh --rebuild-rules)
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
RULES_DIR="$REPO/brain/registry/secrets-rules"
TH_RULES="$RULES_DIR/trufflehog-v3.yml"
GL_RULES="$RULES_DIR/gitleaks.toml"
PATTERN_DB="$REPO/packs/secrets-patterns-db/db/rules-stable.yml"

TARGET=""
SCANNER="both"
HIGH_ONLY=0
VERIFY=0
OUT="$(mktemp -d)"
REBUILD=0

while [ $# -gt 0 ]; do
  case "$1" in
    --scanner)        SCANNER="${2:-both}"; shift 2 ;;
    --high-only)      HIGH_ONLY=1; shift ;;
    --verify)         VERIFY=1; shift ;;
    --out)            OUT="${2:-$OUT}"; mkdir -p "$OUT"; shift 2 ;;
    --rebuild-rules)  REBUILD=1; shift ;;
    --help|-h)        sed -n '1,30p' "$0"; exit 0 ;;
    *)                TARGET="$1"; shift ;;
  esac
done

# ─── portable python3-with-yaml probe ─────────────────────
# CORRECTION (2026-09): the earlier comment claimed "yaml stdlib on macOS".
# That was wrong — PyYAML is bundled with Apple's /usr/bin/python3 via the
# Xcode CLT, but it is NOT part of the Python stdlib. On stock Linux, Alpine
# containers, and bare Docker images, /usr/bin/python3 has no yaml.
# Probe candidates in preference order and pick the first one whose python
# can actually `import yaml`. Fail loudly with an actionable message.
_pick_python_with_yaml() {
  local candidates="python3 /usr/bin/python3 /opt/homebrew/bin/python3 /usr/local/bin/python3 python"
  for py in $candidates; do
    if command -v "$py" >/dev/null 2>&1; then
      if "$py" -c "import yaml" >/dev/null 2>&1; then
        printf '%s' "$py"; return 0
      fi
    fi
  done
  return 1
}

# ─── --rebuild-rules ────────────────────────────────────────
if [ "$REBUILD" = "1" ]; then
  [ -f "$PATTERN_DB" ] || { echo "✗ pattern DB missing: $PATTERN_DB — run scripts/reinstall-packs.sh"; exit 3; }
  mkdir -p "$RULES_DIR"
  PY="$(_pick_python_with_yaml || true)"
  if [ -z "$PY" ]; then
    echo "✗ no python3 with PyYAML found. tried: python3 /usr/bin/python3 /opt/homebrew/bin/python3 /usr/local/bin/python3 python" >&2
    echo "  install PyYAML in ONE of them, e.g.:" >&2
    echo "    pip3 install --user pyyaml                 # user-space" >&2
    echo "    python3 -m venv .venv && .venv/bin/pip install pyyaml   # per-project venv" >&2
    echo "    apk add py3-yaml                            # Alpine" >&2
    echo "    apt install python3-yaml                    # Debian/Ubuntu" >&2
    exit 3
  fi
  # Use a heredoc for the version probe so bash doesn't need to escape the quotes
  PY_INFO=$("$PY" - <<'PYEOF'
import sys, yaml
print(f"python {sys.version.split()[0]}, PyYAML {yaml.__version__}")
PYEOF
)
  echo "  using python: $PY  ($PY_INFO)"
  "$PY" "$REPO/packs/secrets-patterns-db/scripts/convert-rules.py" \
    --db "$PATTERN_DB" --type trufflehogv3 --export "$RULES_DIR/trufflehog-v3" || exit 3
  "$PY" "$REPO/packs/secrets-patterns-db/scripts/convert-rules.py" \
    --db "$PATTERN_DB" --type gitleaks --export "$RULES_DIR/gitleaks" || exit 3
  echo "✓ rules rebuilt from $PATTERN_DB"
  ls -la "$RULES_DIR"
  exit 0
fi

[ -n "$TARGET" ] || { sed -n '1,30p' "$0"; exit 2; }
[ -e "$TARGET" ] || { echo "✗ target not found: $TARGET"; exit 2; }

# ─── ensure rule sets exist ─────────────────────────────────
if [ ! -f "$TH_RULES" ] || [ ! -f "$GL_RULES" ]; then
  echo "! rule files missing under $RULES_DIR — auto-rebuilding..."
  exec "$0" --rebuild-rules
fi

# ─── run scanners ───────────────────────────────────────────
mkdir -p "$OUT"
FOUND=0
echo "── secrets-scan  target=$TARGET  scanner=$SCANNER  high-only=$HIGH_ONLY  verify=$VERIFY ──"

if [ "$SCANNER" = "trufflehog" ] || [ "$SCANNER" = "both" ]; then
  command -v trufflehog >/dev/null || { echo "  ✗ trufflehog not installed — brew install trufflehog"; exit 2; }
  echo ""
  echo "── trufflehog (packs/secrets-patterns-db → $TH_RULES) ──"
  th_args=(filesystem "$TARGET" --config="$TH_RULES" --json)
  [ "$VERIFY" = "0" ] && th_args+=(--no-verification)
  trufflehog "${th_args[@]}" > "$OUT/trufflehog.jsonl" 2>/dev/null
  th_count=$(wc -l < "$OUT/trufflehog.jsonl" 2>/dev/null | tr -d ' ')
  echo "  → $th_count line(s) in $OUT/trufflehog.jsonl"
  [ "$th_count" -gt 0 ] 2>/dev/null && FOUND=1
fi

if [ "$SCANNER" = "gitleaks" ] || [ "$SCANNER" = "both" ]; then
  command -v gitleaks >/dev/null || { echo "  ✗ gitleaks not installed — brew install gitleaks"; exit 2; }
  echo ""
  echo "── gitleaks (packs/secrets-patterns-db → $GL_RULES) ──"
  gl_args=(detect --source "$TARGET" --config "$GL_RULES" --no-git --report-format json --report-path "$OUT/gitleaks.json")
  gitleaks "${gl_args[@]}" 2>&1 | tail -3
  if [ -s "$OUT/gitleaks.json" ]; then
    # json parsing needs stdlib json only — any python3 works here (no yaml needed)
    PY_ANY="$(command -v python3 || command -v /usr/bin/python3)"
    gl_count=$("$PY_ANY" -c "import json; print(len(json.load(open('$OUT/gitleaks.json'))))" 2>/dev/null || echo 0)
    echo "  → $gl_count secret(s) in $OUT/gitleaks.json"
    [ "$gl_count" -gt 0 ] 2>/dev/null && FOUND=1
  fi
fi

# ─── high-confidence filter (--high-only) ───────────────────
if [ "$HIGH_ONLY" = "1" ] && [ -s "$OUT/trufflehog.jsonl" ]; then
  # Read the raw pattern DB and build a whitelist of high-confidence rule names,
  # then filter trufflehog.jsonl's ExtraData.name field. Keeps output triage-friendly.
  # NEEDS yaml — reuse the same portable probe.
  PY_YAML="$(_pick_python_with_yaml || true)"
  if [ -z "$PY_YAML" ]; then
    echo "  ! --high-only requires PyYAML; skipping filter (see --rebuild-rules for install hints)" >&2
  else
  "$PY_YAML" <<PY
import json, yaml, sys
db = yaml.safe_load(open("$PATTERN_DB"))
high = {p["pattern"]["name"] for p in db["patterns"] if p["pattern"].get("confidence")=="high"}
out = []
for line in open("$OUT/trufflehog.jsonl"):
    try:
        r = json.loads(line)
        if r.get("ExtraData",{}).get("name") in high:
            out.append(r)
    except: pass
with open("$OUT/trufflehog-high.jsonl","w") as f:
    for r in out: f.write(json.dumps(r) + "\n")
print(f"  → high-confidence: {len(out)} in $OUT/trufflehog-high.jsonl")
PY
  fi   # end of PY_YAML availability branch
fi

# ─── summary ────────────────────────────────────────────────
echo ""
echo "── report ──"
echo "  output dir:     $OUT"
if [ "$FOUND" = "1" ]; then
  echo "  status:         SECRETS FOUND"
  [ -s "$OUT/gitleaks.json" ] && echo "  gitleaks:       $OUT/gitleaks.json"
  [ -s "$OUT/trufflehog.jsonl" ] && echo "  trufflehog:     $OUT/trufflehog.jsonl"
  [ -s "$OUT/trufflehog-high.jsonl" ] && echo "  high-conf only: $OUT/trufflehog-high.jsonl"
  echo ""
  echo "  next steps:"
  echo "    (1) triage — many hits are pattern-noise; grep for high-confidence names first"
  echo "    (2) verify — for each candidate, prove it's LIVE before reporting"
  echo "        AWS AKIA:    aws sts get-caller-identity --access-key-id X --secret-access-key Y"
  echo "        GitHub PAT:  curl -H 'Authorization: token X' https://api.github.com/user"
  echo "        Slack tok:   curl -X POST https://slack.com/api/auth.test -H 'Authorization: Bearer X'"
  echo "        Google API:  curl 'https://maps.googleapis.com/maps/api/staticmap?center=0,0&zoom=1&size=1x1&key=X'"
  echo "    (3) redact the raw secret in evidence — never write the full key to reports"
  exit 1
else
  echo "  status:         no secrets detected"
  exit 0
fi
