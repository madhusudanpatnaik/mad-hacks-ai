#!/usr/bin/env bash
# T3MP3ST scope — create/verify the authorization receipt the preflight gate checks.
# Authorization is a DECISION the user records here — this script only writes/reads the
# artifact; it does not grant anything. Usage:
#   scope.sh init <target> [more-hosts...]   → scaffold ./.t3mp3st/SCOPE.md
#   scope.sh check <target>                  → verify target is listed
set -euo pipefail
CMD="${1:-}"; shift || true
DIR="./.t3mp3st"; FILE="$DIR/SCOPE.md"

case "$CMD" in
  init)
    [ $# -ge 1 ] || { echo "usage: scope.sh init <target> [more-hosts...]"; exit 2; }
    mkdir -p "$DIR"
    if [ -f "$FILE" ]; then echo "⚠️  $FILE already exists — not overwriting. Edit it by hand."; exit 0; fi
    HOSTS=""; for h in "$@"; do HOSTS+="- $h"$'\n'; done
    cat > "$FILE" <<EOF
# Scope Receipt — T3MP3ST engagement

> This file is the authorization artifact. The operator (a human) affirms below that
> testing is authorized. Editing this file is a deliberate act. Keep it accurate.

## Authorization
- [ ] I have **written authorization** to test the hosts listed below (contract / bug-bounty program / owned lab / enrolled CTF).
- Authorizing party / program: __________________________
- Reference (contract id / program URL / ticket): __________________________
- Engagement window (start → end): __________________________

## In scope
$HOSTS
## Out of scope (do NOT touch)
- (list carve-outs: prod DBs, third-party SaaS, other tenants, etc.)

## Rules of engagement
- Environment: [ ] local/lab   [ ] staging   [ ] PRODUCTION / bug-bounty  (prod ⇒ production-safety.md R1–R11 apply)
- Allowed action classes: [ ] passive/read-only  [ ] active scan  [ ] exploit-PoC (minimal)  [ ] destructive (almost never)
- Program prohibits (tick what applies): [ ] automated scanning  [ ] DoS  [ ] brute-force  [ ] social-eng  [ ] physical
- Rate limits / testing hours: __________________________
- Traffic identifier (header/marker blue-team can filter): __________________________
- Data handling: redact secrets/PII; NO bulk exfiltration; prove impact with ONE record; clean up PoC artifacts.
- Chaining/lateral movement allowed? [ ] no (stop at first proof)  [ ] yes, up to: ____________
- Emergency contact / stop signal: __________________________

# PRODUCTION MODE: if the box above is PRODUCTION, the operator MUST follow references/production-safety.md
# (throttle scans, safe-PoC catalog only, no availability impact, no bulk data, clean up).
EOF
    echo "✅ wrote $FILE — open it, tick the authorization box, and fill the blanks BEFORE active testing."
    echo "   Until the authorization box is checked, treat this as passive/read-only only."
    ;;
  check)
    T="${1:-}"; [ -n "$T" ] || { echo "usage: scope.sh check <target>"; exit 2; }
    [ -f "$FILE" ] || { echo "⛔ no $FILE — run: scope.sh init $T"; exit 1; }
    if grep -qiF "$T" "$FILE"; then echo "✅ '$T' is listed in $FILE"; else echo "⛔ '$T' NOT in $FILE — add it or confirm scope"; exit 1; fi
    if grep -qE '^\- \[x\] I have \*\*written authorization' "$FILE"; then echo "✅ authorization box is checked"; else echo "⚠️  authorization box NOT checked — active testing stays blocked"; fi
    ;;
  *) echo "usage: scope.sh {init <target> [hosts...] | check <target>}"; exit 2;;
esac
