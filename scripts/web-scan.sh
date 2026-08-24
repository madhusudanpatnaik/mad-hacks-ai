#!/usr/bin/env bash
# mad-Hacks_ai web-scan — keyless WEAPONIZE pass on an owned/authorized web target.
# Independent probes (CORS, methods, redirect, exposure, WAF, TLS) run CONCURRENTLY.
# Heavy scans (nuclei) are receipt-gated. Usage: web-scan.sh <url> [--active]
set -uo pipefail
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
URL="${1:-}"; MODE="${2:-light}"
[ -n "$URL" ] || { echo "usage: web-scan.sh <url> [--active]"; exit 2; }
case "$URL" in http://*|https://*) ;; *) URL="https://$URL";; esac
HOST="$(printf '%s' "$URL" | sed -E 's#^https?://##; s#/.*##; s#:.*##')"
printf '%s' "$HOST" | grep -qE '^[A-Za-z0-9._:-]+$' || { echo "⛔ bad host in URL"; exit 2; }

OUT="./.t3mp3st/${HOST}/weaponize"; mkdir -p "$OUT"
have(){ command -v "$1" >/dev/null 2>&1; }
echo "mad-Hacks_ai web-scan → $URL  (mode: $MODE)  → $OUT  [parallel probes]"

# ── headers first (fast, needed for gap analysis) ──
HDR="$OUT/headers.txt"
curl -sSIkL --max-time 15 "$URL" > "$HDR" 2>/dev/null

# ── independent probes, each backgrounded, each writing its own candidate fragment ──
probe_cors(){ local c; c=$(curl -sSIk --max-time 12 -H "Origin: https://evil.example" "$URL" 2>/dev/null | tr -d '\r'); echo "$c" | grep -i 'access-control-allow-origin' > "$OUT/cors.txt"
  if echo "$c" | grep -iq 'access-control-allow-origin: https://evil.example'; then echo "- [HIGH] CORS reflects arbitrary Origin" >> "$OUT/c.cors"
    echo "$c" | grep -iq 'access-control-allow-credentials: true' && echo "- [CRITICAL] CORS reflects Origin WITH credentials:true (account data theft)" >> "$OUT/c.cors"; fi; }
probe_methods(){ curl -sSIk --max-time 12 -X OPTIONS "$URL" 2>/dev/null | grep -i '^allow:' > "$OUT/methods.txt"
  grep -iqE 'PUT|DELETE|TRACE|PATCH' "$OUT/methods.txt" 2>/dev/null && echo "- [LOW] Risky HTTP methods advertised (methods.txt)" >> "$OUT/c.methods"; }
probe_redirect(){ for p in next url redirect return returnTo dest; do
    local loc; loc=$(curl -sSIk --max-time 10 "$URL?$p=https://evil.example" 2>/dev/null | grep -i '^location:' | tr -d '\r')
    echo "$loc" | grep -iq 'evil.example' && echo "- [MEDIUM] Possible open redirect via ?$p= → $loc" >> "$OUT/c.redirect"; done; true; }
probe_exposure(){ : > "$OUT/exposure.txt"; for path in robots.txt sitemap.xml .git/config .env .well-known/security.txt .DS_Store; do
    local code; code=$(curl -so /dev/null -w '%{http_code}' -k --max-time 10 "$URL/$path" 2>/dev/null); echo "$path → $code" >> "$OUT/exposure.txt"
    case "$path:$code" in ".git/config:200"|".env:200"|".DS_Store:200") echo "- [HIGH] Exposed $path (HTTP 200)" >> "$OUT/c.exposure";; esac; done; }
probe_waf(){ have wafw00f && wafw00f "$URL" 2>/dev/null | grep -iE 'is behind|seems to be|No WAF' > "$OUT/waf.txt"; }
probe_tls(){ if have testssl.sh; then testssl.sh --quiet --color 0 --severity MEDIUM "$HOST" 2>/dev/null | grep -iE 'VULNERABLE|NOT ok|expired|self-signed' | head -20 > "$OUT/tls.txt"
    grep -qi VULNERABLE "$OUT/tls.txt" && echo "- [MEDIUM] TLS weakness (tls.txt)" >> "$OUT/c.tls"
  elif have openssl; then echo | openssl s_client -connect "$HOST:443" -servername "$HOST" 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null > "$OUT/tls.txt"; fi; }

probe_cors & probe_methods & probe_redirect & probe_exposure & probe_waf & probe_tls &
wait 2>/dev/null

# ── header-derived candidates (local, fast) ──
: > "$OUT/c.headers"
h(){ grep -iq "^$1:" "$HDR"; }
h 'strict-transport-security'  || echo "- [MEDIUM] Missing HSTS" >> "$OUT/c.headers"
h 'content-security-policy'    || echo "- [MEDIUM] Missing Content-Security-Policy" >> "$OUT/c.headers"
h 'x-frame-options'            || grep -iq 'frame-ancestors' "$HDR" || echo "- [LOW] Missing X-Frame-Options / frame-ancestors (clickjacking)" >> "$OUT/c.headers"
h 'x-content-type-options'     || echo "- [LOW] Missing X-Content-Type-Options: nosniff" >> "$OUT/c.headers"
h 'referrer-policy'            || echo "- [INFO] Missing Referrer-Policy" >> "$OUT/c.headers"
grep -iqE '^server:.*[0-9]' "$HDR" && echo "- [INFO] Server version leak: $(grep -i '^server:' "$HDR" | head -1 | tr -d '\r')" >> "$OUT/c.headers"
grep -i '^set-cookie:' "$HDR" | while IFS= read -r c; do
  echo "$c" | grep -iq 'httponly' || echo "- [LOW] Cookie without HttpOnly: $(echo "$c" | cut -c1-50)" >> "$OUT/c.headers"
  echo "$c" | grep -iq 'secure'   || echo "- [LOW] Cookie without Secure: $(echo "$c" | cut -c1-50)" >> "$OUT/c.headers"; done

# ── merge candidates (deterministic order) ──
CAND="$OUT/candidates.md"
cat "$OUT"/c.headers "$OUT"/c.cors "$OUT"/c.exposure "$OUT"/c.redirect "$OUT"/c.methods "$OUT"/c.tls 2>/dev/null > "$CAND"
rm -f "$OUT"/c.* 2>/dev/null

if [ "$MODE" = "--active" ]; then
  echo "=== nuclei (ACTIVE — requires authorization) ==="
  if have nuclei; then nuclei -u "$URL" -severity medium,high,critical -jsonl -silent 2>/dev/null | tee "$OUT/nuclei.jsonl" \
      | jq -r '"- ["+(.info.severity|ascii_upcase)+"] "+.info.name+" @ "+.matched_at' 2>/dev/null >> "$CAND" || true; fi
else
  echo "[i] nuclei skipped (light mode). Re-run with --active AFTER confirming authorization."
fi

echo; echo "=== candidate findings ==="; cat "$CAND" 2>/dev/null || echo "(none)"
echo; echo "✅ candidates → $CAND  (parallel probes)"
echo "   Next: VERIFY each against saved evidence, then REFUTE before it becomes a finding (pipeline.md)."
