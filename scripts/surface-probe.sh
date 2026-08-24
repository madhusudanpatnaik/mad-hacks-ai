#!/usr/bin/env bash
# surface-probe.sh — the C/F/G/H/I gap probes for /mad-hunt's SURFACE PROBE phase.
# recon.sh + web-scan.sh already cover A (paths/files), B (methods), D (headers/CRLF),
# E (CORS). This fills the gaps: C cache-deception, F HTTP/2 desync, G subdomain-takeover,
# H Cloudflare, I SPA/hash-routing seeds. Cheap curl only — NO agent dispatch, NO active
# exploitation. Each result becomes a hunter seed or a brain 'not-applicable' coverage entry.
#
# Usage:  bash scripts/surface-probe.sh <host> [--header 'X-Bug-Bounty: user']
set -uo pipefail
HOST="${1:-}"; [ -n "$HOST" ] || { echo "usage: surface-probe.sh <host> [--header 'H: v']"; exit 2; }
shift || true
HDR=()
[ "${1:-}" = "--header" ] && { HDR=(-H "$2"); shift 2; }
h=$(printf '%s' "$HOST" | sed 's#https\?://##; s#/.*##')
BASE="https://$h"
OUT="evidence/$h/surface"; mkdir -p "$OUT"
CURL=(curl -sSk --max-time 15 "${HDR[@]}")
sec(){ printf '\n\033[1m── %s ──\033[0m\n' "$1"; }
echo "surface-probe C/F/G/H/I → $OUT   ($BASE)"

# ── C. Cache deception ──────────────────────────────────────────────
sec "C. Cache deception"
{
  for suffix in '/robots.txt' '/nonexistent.css' '/account/..%2fnonexistent.js' '/;.css'; do
    printf '%s ' "$suffix"
    "${CURL[@]}" -o /dev/null -D - "$BASE$suffix" 2>/dev/null \
      | grep -iE 'cf-cache-status|x-cache|age:|cache-control|vary' | tr '\n' '|'; echo
  done
} | tee "$OUT/C-cache.txt"
grep -qiE 'cf-cache-status: *hit|x-cache: *hit' "$OUT/C-cache.txt" \
  && echo "  SEED: caching layer HITs on odd paths → cache-deception/poison candidate" \
  || echo "  not-applicable: no cache HIT on probed paths"

# ── F. HTTP/2 desync indicators ─────────────────────────────────────
sec "F. HTTP/2 desync indicators"
proto=$("${CURL[@]}" -o /dev/null -w '%{http_version}' "$BASE/" 2>/dev/null)
echo "  negotiated HTTP version: $proto" | tee "$OUT/F-h2.txt"
code421=$("${CURL[@]}" -o /dev/null -w '%{http_code}' -H 'Host: not-'"$h" "$BASE/" 2>/dev/null)
echo "  wrong-Host response code: $code421" | tee -a "$OUT/F-h2.txt"
{ [ "$proto" = "2" ] && echo "  SEED: HTTP/2 in use → h2-desync/smuggling worth a custom PoC"; } \
  || echo "  not-applicable: HTTP/1.1 only (no h2 desync surface)"

# ── G. Subdomain takeover (this host) ───────────────────────────────
sec "G. Subdomain takeover"
cname=$(command -v dig >/dev/null && dig +short CNAME "$h" 2>/dev/null | head -1)
echo "  CNAME: ${cname:-<none>}" | tee "$OUT/G-takeover.txt"
body=$("${CURL[@]}" "$BASE/" 2>/dev/null | head -c 4000)
echo "$body" | grep -iqE "NoSuchBucket|There isn't a GitHub Pages site here|Repository not found|herokucdn|no-such-app|Fastly error: unknown domain|The specified bucket does not exist|Domain uses a Cloudflare|Sorry, this shop is currently unavailable|Do not have this domain|project not found" \
  && echo "  SEED: dangling-service fingerprint in body → subdomain-takeover candidate (verify CNAME target unclaimed)" \
  || echo "  not-applicable: no takeover fingerprint"

# ── H. Cloudflare-specific ──────────────────────────────────────────
sec "H. Cloudflare"
hdrs=$("${CURL[@]}" -o /dev/null -D - "$BASE/" 2>/dev/null)
if echo "$hdrs" | grep -iqE 'server: *cloudflare|cf-ray:'; then
  echo "  Cloudflare detected (cf-ray/server)." | tee "$OUT/H-cf.txt"
  echo "  SEED: try origin-IP discovery (crt.sh history, SPF/MX, /cdn-cgi/trace), CF-Connecting-IP spoof on origin, WAF-bypass ladder on blocks."
else
  echo "  not-applicable: no Cloudflare fingerprint" | tee "$OUT/H-cf.txt"
fi

# ── I. SPA / hash-routing seeds ─────────────────────────────────────
sec "I. SPA / hash-routing seeds"
page=$("${CURL[@]}" "$BASE/" 2>/dev/null)
js=$(echo "$page" | grep -oiE 'src="[^"]+\.js[^"]*"' | sed 's/src="//; s/"$//' | head -8)
{ echo "$page" | grep -oiE '#/[A-Za-z0-9_/-]+' | sort -u | head -20
  for u in $js; do
    case "$u" in http*) J="$u";; /*) J="$BASE$u";; *) J="$BASE/$u";; esac
    "${CURL[@]}" "$J" 2>/dev/null | grep -oiE '"/(api|v[0-9]|graphql|internal)[A-Za-z0-9_/.-]*"' | sort -u | head -30
  done; } | sort -u | tee "$OUT/I-spa.txt" | head -40
[ -s "$OUT/I-spa.txt" ] && echo "  SEED: $(wc -l < "$OUT/I-spa.txt") SPA route/API endpoints → feed idor/auth/xss hunters" \
  || echo "  not-applicable: no SPA hash-routes or JS-embedded API endpoints found"

echo; echo "surface-probe C/F/G/H/I complete → $OUT"
