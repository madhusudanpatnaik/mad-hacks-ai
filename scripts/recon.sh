#!/usr/bin/env bash
# mad-Hacks_ai recon — passive→active recon with system tools only (no Node, no LLM).
# Independent passive lookups (DNS, whois, subdomains, HTTP, tech) run CONCURRENTLY.
# Writes evidence under ./.t3mp3st/<target>/recon/. Active steps (nmap) are gated.
# Usage: recon.sh <host-or-domain> [--active]
#   default = passive/read-only.  --active enables nmap (REQUIRES authorization).
set -uo pipefail
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"   # ensure go/pipx tools are found

TARGET="${1:-}"
MODE="${2:-passive}"
if [ -z "$TARGET" ]; then echo "usage: recon.sh <host-or-domain> [--active]"; exit 2; fi
if ! printf '%s' "$TARGET" | grep -qE '^[A-Za-z0-9._:-]+$'; then
  echo "⛔ invalid target '$TARGET' — hostnames/IPs only (no spaces, pipes, or separators)."; exit 2
fi

OUT="./.t3mp3st/${TARGET}/recon"
mkdir -p "$OUT"
have() { command -v "$1" >/dev/null 2>&1; }
echo "mad-Hacks_ai recon → $TARGET  (mode: $MODE)  → $OUT  [parallel passive]"

# ── independent passive lookups, each in the background writing its own file ──
{
  if have dig; then
    { echo "# ANY"; dig +short "$TARGET" ANY; for r in A AAAA MX NS TXT CNAME; do echo "# $r"; dig +short "$TARGET" "$r"; done; } > "$OUT/dns.txt" 2>/dev/null
  elif have host; then host "$TARGET" > "$OUT/dns.txt" 2>/dev/null; fi
} &
PID_DNS=$!

{ have whois && whois "$TARGET" > "$OUT/whois.txt" 2>/dev/null; } &
PID_WHOIS=$!

{
  if have subfinder; then subfinder -d "$TARGET" -silent > "$OUT/subdomains.txt" 2>/dev/null
  elif have curl; then curl -s "https://crt.sh/?q=%25.${TARGET}&output=json" 2>/dev/null \
      | grep -oE '"name_value":"[^"]+"' | cut -d'"' -f4 | sort -u > "$OUT/subdomains.txt"; fi
} &
PID_SUB=$!

{
  if have curl; then
    : > "$OUT/http-headers.txt"
    for scheme in https http; do echo "# ${scheme}://${TARGET}" >> "$OUT/http-headers.txt"; curl -sSIk --max-time 12 "${scheme}://${TARGET}" >> "$OUT/http-headers.txt" 2>/dev/null; done
    curl -sk --max-time 12 "https://${TARGET}/robots.txt" > "$OUT/robots.txt" 2>/dev/null
  fi
} &
PID_HTTP=$!

{
  if have whatweb; then whatweb --color=never "https://${TARGET}" > "$OUT/whatweb.txt" 2>/dev/null
  elif have httpx; then httpx -u "https://${TARGET}" -silent -title -tech-detect -status-code > "$OUT/httpx.txt" 2>/dev/null; fi
} &
PID_TECH=$!

wait "$PID_DNS" "$PID_WHOIS" "$PID_SUB" "$PID_HTTP" "$PID_TECH" 2>/dev/null

# ── report (deterministic order, after all lookups finish) ──
sec(){ echo; echo "=== $1 ==="; }
sec "DNS (passive)";        [ -s "$OUT/dns.txt" ] && cat "$OUT/dns.txt" || echo "  (none)"
sec "WHOIS (passive)";      [ -s "$OUT/whois.txt" ] && head -40 "$OUT/whois.txt" || echo "  (none)"
sec "Subdomains (passive)"; [ -s "$OUT/subdomains.txt" ] && { wc -l < "$OUT/subdomains.txt" | xargs echo "  found:"; head -30 "$OUT/subdomains.txt"; } || echo "  (none)"
sec "HTTP headers + security-header gaps"
if [ -s "$OUT/http-headers.txt" ]; then
  grep -iE '^(server|x-powered-by|location|www-authenticate):' "$OUT/http-headers.txt" | sort -u
  echo "  security headers present:"; grep -ioE 'strict-transport-security|content-security-policy|x-frame-options|x-content-type-options|referrer-policy|permissions-policy' "$OUT/http-headers.txt" | sort -u | sed 's/^/    /' || echo "    (none — candidate findings)"
else echo "  (no HTTP response)"; fi
sec "Tech fingerprint"; { cat "$OUT/whatweb.txt" 2>/dev/null || cat "$OUT/httpx.txt" 2>/dev/null || echo "  infer from Server/X-Powered-By above"; } | head -6

if [ "$MODE" = "--active" ]; then
  sec "Port scan (ACTIVE — requires authorization)"
  if have naabu; then naabu -host "$TARGET" -top-ports 100 -silent 2>/dev/null | tee "$OUT/naabu.txt"; fi
  if have nmap; then nmap -sV --top-ports 100 --open "$TARGET" 2>/dev/null | tee "$OUT/nmap.txt"; else echo "  ⬜ no nmap"; fi
else
  echo; echo "[i] Port scan skipped (passive mode). Re-run with --active AFTER confirming authorization."
fi

echo; echo "✅ recon evidence saved under $OUT/  (parallel passive lookups)"
echo "   Next: WEAPONIZE — web-scan.sh, then (with a receipt) nuclei -u https://${TARGET} -severity medium,high,critical -jsonl"
