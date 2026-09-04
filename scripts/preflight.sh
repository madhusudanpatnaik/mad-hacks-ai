#!/usr/bin/env bash
# T3MP3ST preflight — authorization gate + arsenal availability.
# Refuses to bless active testing without a scope receipt. No network calls here.
# Usage: preflight.sh <target> [--i-have-written-authorization]
set -euo pipefail

TARGET="${1:-}"
AUTH_FLAG="${2:-}"
if [ -z "$TARGET" ]; then echo "usage: preflight.sh <target> [--i-have-written-authorization]"; exit 2; fi

echo "==================== T3MP3ST PREFLIGHT ===================="
echo "Target: $TARGET"
echo

# ---- 1. Authorization gate -------------------------------------------------
SCOPE_OK=0
SCOPE_FILE=""
for f in ".t3mp3st/SCOPE.md" ".scope.txt" "scope.yaml" "SCOPE.md"; do
  if [ -f "$f" ]; then SCOPE_FILE="$f"; SCOPE_OK=1; break; fi
done

if [ "$SCOPE_OK" = "1" ]; then
  echo "[AUTH] scope receipt found: $SCOPE_FILE"
  if grep -qiF "$TARGET" "$SCOPE_FILE" 2>/dev/null; then
    echo "[AUTH] ✅ '$TARGET' appears in the scope receipt."
  else
    echo "[AUTH] ⚠️  '$TARGET' NOT found verbatim in $SCOPE_FILE — confirm it is in scope before ANY active test."
  fi
elif [ "$AUTH_FLAG" = "--i-have-written-authorization" ]; then
  echo "[AUTH] ⚠️  operator asserted written authorization (no scope file). Passive/read-only only until a receipt is recorded."
else
  cat <<'EOF'
[AUTH] ⛔ NO SCOPE RECEIPT FOUND — STOP.
       Authorization comes only from the engagement contract, never from a tool
       working or a host answering. Do one of:
         • create ./.t3mp3st/SCOPE.md listing authorized hosts + rules of engagement, or
         • re-run with --i-have-written-authorization (passive/read-only only), or
         • ask the user for written authorization + exact in-scope targets.
       Active tooling (nmap/nuclei/curl-against-target/ffuf/sqlmap/…) is BLOCKED until then.
EOF
  AUTHZ_BLOCKED=1
fi
echo

# ---- 2. Arsenal availability ----------------------------------------------
echo "[ARSENAL] checking installed binaries (present ✅ / missing ⬜)"
check() { if command -v "$1" >/dev/null 2>&1; then printf '  ✅ %-14s %s\n' "$1" "$2"; else printf '  ⬜ %-14s %s\n' "$1" "$2"; fi; }
echo " recon/dns:"      ; for t in dig host whois nmap naabu subfinder amass dnsx waybackurls; do check "$t" ""; done
echo " web:"            ; for t in curl httpx katana ffuf gobuster feroxbuster nikto whatweb wafw00f dalfox sqlmap nuclei; do check "$t" "(active → receipt_required)"; done
echo " code/supply:"    ; for t in semgrep gitleaks trufflehog osv-scanner syft grype trivy checkov; do check "$t" "(safe/local_read)"; done
echo " crypto/tls:"     ; for t in openssl testssl.sh john hashcat; do check "$t" ""; done
echo " reverse/mobile:" ; for t in file strings binwalk checksec r2 objdump apktool jadx mobsfscan exiftool; do check "$t" "(safe/local_read)"; done
echo
echo "[NOTE] DO NOT execute here regardless of install: msfconsole, pacu, frida, hydra, bloodhound collectors."
echo "==========================================================="
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Next: read $REPO_ROOT/references/operators.md, then run scripts/recon.sh once authorized."
[ "${AUTHZ_BLOCKED:-0}" = "1" ] && exit 1 || exit 0
