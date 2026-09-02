#!/usr/bin/env bash
# xss-surface.sh — the J. XSS-surface probe for /mad-hunt's SURFACE PROBE phase.
# surface-probe.sh covers C/F/G/H/I; recon.sh + web-scan.sh cover A/B/D/E. This is the
# missing "J. XSS surface" seed-maker: it LIGHTS UP where XSS could live so the ranked
# hunt loop can dispatch hunt-xss / xss-hunter with context, instead of blind-fuzzing.
#
# KEYLESS  — system curl/grep/sed only, no API keys, no installed scanners.
# SAFE     — GET reflection probes with a benign canary (zqxj9137) + inert markup
#            metacharacters only. No <script>, no event handlers, no POSTs, no auth
#            actions, no writes to the target. It only READS how input comes back.
# ACTIVE   — sends real (benign) requests to the target: run only on authorized hosts.
#
# Detections (each → a SEED line for the hunt loop, or a not-applicable coverage line):
#   J1 Reflected-XSS surface   — canary per query-param, context-classified reflection
#   J2 DOM-sink surface        — dangerous sinks in page + linked JS
#   J3 postMessage surface     — message listeners without an obvious origin check
#   J4 Sanitizer/renderer FP   — DOMPurify / markdown / Trusted-Types / React|Angular|Vue
#   J5 Stored-XSS candidates   — POST-form targets + input/textarea names (passive parse)
#
# Usage:  bash scripts/xss-surface.sh <url|host> [--header 'X-Bug-Bounty: user'] \
#              [--params <param-names-file>] [--endpoints <discovered-endpoints-file>]
set -uo pipefail

RAW="${1:-}"
[ -n "$RAW" ] || { echo "usage: xss-surface.sh <url|host> [--header 'H: v'] [--params <file>] [--endpoints <file>]"; exit 2; }
shift || true

# ── optional flags (order-independent), house-style array for --header ──
HDR=(); PARAMS_FILE=""; ENDPOINTS_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --header)    HDR=(-H "$2"); shift 2 ;;
    --params)    PARAMS_FILE="${2:-}"; shift 2 ;;
    --endpoints) ENDPOINTS_FILE="${2:-}"; shift 2 ;;
    *)           shift ;;
  esac
done

have(){ command -v "$1" >/dev/null 2>&1; }
have curl || { echo "⛔ curl not found — this probe needs system curl"; exit 3; }

# ── normalize input into scheme / host / path / query (keep full URL for J1) ──
case "$RAW" in http://*|https://*) URL="$RAW" ;; *) URL="https://$RAW" ;; esac
proto=$(printf '%s' "$URL" | sed -E 's#://.*##')
authority=$(printf '%s' "$URL" | sed -E 's#^https?://##; s#/.*##')   # host[:port] — kept for fetching
h=$(printf '%s' "$authority" | sed -E 's#:.*##')                    # bare hostname — evidence dir + validation
printf '%s' "$h" | grep -qE '^[A-Za-z0-9._-]+$' || { echo "⛔ bad host in URL"; exit 2; }
BASE="$proto://$authority"
pathq=$(printf '%s' "$URL" | sed -E 's#^https?://[^/]*##')
path=$(printf '%s' "$pathq" | sed -E 's#\?.*##'); [ -n "$path" ] || path="/"
query=$(printf '%s' "$pathq" | sed -E 's#^[^?]*##; s#^\?##')
TARGET="$BASE$path"

OUT="evidence/$h/surface"; mkdir -p "$OUT"
CURL=(curl -sSk --max-time 15 ${HDR[@]+"${HDR[@]}"})   # +guard: empty array + set -u is safe on bash 3.2
sec(){ printf '\n\033[1m── %s ──\033[0m\n' "$1"; }

CANARY="zqxj9137"                     # benign marker family — NOT a payload (per-param nonce appended)
PROBE_SUFFIX="%3C%3E%22%27"           # inert <>"' (URL-encoded) appended to read the encoding context

echo "surface-probe J (xss surface) → $OUT   ($URL)"
echo "  [active-aware] sends benign GET reflection probes (canary '$CANARY' + inert markup"
echo "  metacharacters). No <script>, no POSTs, no auth actions, no writes. Honors SCOPE.md —"
echo "  run only on hosts the engagement contract authorizes."

# ── fetch the page once; harvest linked JS; fold any discovered endpoints into corpus ──
PAGE=$("${CURL[@]}" "$URL" 2>/dev/null)
JS_URLS=$(printf '%s' "$PAGE" | grep -oiE 'src=["'"'"'][^"'"'"']+\.js[^"'"'"']*' \
          | sed -E 's/^src=["'"'"']//' | head -12)
JS_CORPUS=""
for u in $JS_URLS; do
  case "$u" in
    http*) J="$u" ;;
    //*)   J="$proto:$u" ;;
    /*)    J="$BASE$u" ;;
    *)     J="$BASE/$u" ;;
  esac
  JS_CORPUS="$JS_CORPUS
$("${CURL[@]}" "$J" 2>/dev/null | head -c 200000)"
done

HTML_CORPUS="$PAGE"
if [ -n "$ENDPOINTS_FILE" ] && [ -f "$ENDPOINTS_FILE" ]; then
  n=0
  while IFS= read -r ep && [ "$n" -lt 10 ]; do
    ep=$(printf '%s' "$ep" | tr -d ' \t\r'); [ -n "$ep" ] || continue
    case "$ep" in http*) E="$ep" ;; /*) E="$BASE$ep" ;; *) E="$BASE/$ep" ;; esac
    HTML_CORPUS="$HTML_CORPUS
$("${CURL[@]}" "$E" 2>/dev/null | head -c 200000)"
    n=$((n+1))
  done < "$ENDPOINTS_FILE"
fi
CORPUS="$HTML_CORPUS
$JS_CORPUS"

# ── J1. Reflected-XSS surface ───────────────────────────────────────
sec "J1. Reflected-XSS surface"
: > "$OUT/J-xss-reflected.txt"

# param set: existing query params → supplied --params file → common defaults
PARAMS=()
if [ -n "$query" ]; then
  IFS='&' read -ra qparts <<< "$query"
  for kv in "${qparts[@]}"; do k="${kv%%=*}"; [ -n "$k" ] && PARAMS+=("$k"); done
fi
if [ -n "$PARAMS_FILE" ] && [ -f "$PARAMS_FILE" ]; then
  while IFS= read -r p; do p=$(printf '%s' "$p" | tr -d ' \t\r'); [ -n "$p" ] && PARAMS+=("$p"); done < "$PARAMS_FILE"
fi
[ ${#PARAMS[@]} -gt 0 ] || PARAMS=(q search s name redirect url msg error id callback page lang)
PARAM_LIST=$(printf '%s\n' "${PARAMS[@]}" | awk 'NF && !seen[$0]++' | head -20)

# preserve other existing params, set the tested one to the probe value
build_query(){ local q="$1" tk="$2" nv="$3" out="" part k
  IFS='&' read -ra ps <<< "$q"
  for part in "${ps[@]}"; do k="${part%%=*}"
    if [ "$k" = "$tk" ]; then out="$out&$k=$nv"; else out="$out&$part"; fi
  done
  printf '%s' "${out#&}"
}

reflected_any=0; raw_hits=0; i=0
while IFS= read -r param; do
  [ -n "$param" ] || continue
  i=$((i+1)); mark="${CANARY}${i}"           # per-param nonce → a hit is attributable to THIS injection
  probe="${mark}${PROBE_SUFFIX}"
  if [ -n "$query" ]; then url="$TARGET?$(build_query "$query" "$param" "$probe")"
  else                     url="$TARGET?$param=$probe"; fi
  flat=$("${CURL[@]}" "$url" 2>/dev/null | tr '\n\r\t' '   ')
  printf '%s' "$flat" | grep -q "$mark" || continue   # only our injected value, not pre-existing page text
  reflected_any=1

  # encoding: did the inert <>"' survive raw, get entity-encoded, or get stripped?
  if   printf '%s' "$flat" | grep -q "${mark}<"; then                                enc="raw-html"; raw_hits=$((raw_hits+1))
  elif printf '%s' "$flat" | grep -qE "${mark}[\"']"; then                           enc="raw-quote"; raw_hits=$((raw_hits+1))
  elif printf '%s' "$flat" | grep -qiE "${mark}(&lt;|&#0*60;|&#x0*3c;|&quot;)"; then enc="html-encoded"
  else                                                                              enc="stripped-or-encoded"; fi

  # structural context (priority: script > href > attribute > html body)
  if   printf '%s' "$flat" | grep -qiE "<script[^>]*>[^<]*${mark}"; then                                   ctx="script"
  elif printf '%s' "$flat" | grep -qiE "(href|src)[[:space:]]*=[[:space:]]*[\"']?[^\"'<> ]*${mark}"; then    ctx="href"
  elif printf '%s' "$flat" | grep -qiE "<[a-zA-Z][^<>]*[[:space:]][a-zA-Z:-]+[[:space:]]*=[[:space:]]*[\"'][^\"'<>]*${mark}"; then ctx="attribute"
  elif printf '%s' "$flat" | grep -qiE ">[^<>]*${mark}"; then                                              ctx="html"
  else                                                                                                       ctx="unclassified"; fi

  echo "  SEED: param '$param' reflects → dispatch xss-hunter (reflected, context=$ctx, encoding=$enc)  [$url]" \
    | tee -a "$OUT/J-xss-reflected.txt"
done <<< "$PARAM_LIST"

if [ "$reflected_any" -eq 1 ]; then
  [ "$raw_hits" -eq 0 ] && echo "  note: reflection encoded — likely safe, still browser-verify high-value params" \
    | tee -a "$OUT/J-xss-reflected.txt"
else
  echo "  not-applicable: canary '$CANARY' not reflected in any tested param" | tee -a "$OUT/J-xss-reflected.txt"
fi

# ── J2. DOM-sink surface ────────────────────────────────────────────
sec "J2. DOM-sink surface"
: > "$OUT/J-xss-dom.txt"
SINKS=()
add_sink(){ printf '%s' "$CORPUS" | grep -qiE "$2" && SINKS+=("$1"); }
add_sink "document.write"          'document\.write'
add_sink ".innerHTML"              '\.innerHTML'
add_sink ".outerHTML"              '\.outerHTML'
add_sink "insertAdjacentHTML"      'insertAdjacentHTML'
add_sink "eval()"                  'eval[[:space:]]*\('
add_sink "setTimeout(string)"      "setTimeout[[:space:]]*\([[:space:]]*[\"'\`]"
add_sink "new Function"            'new[[:space:]]+Function'
add_sink "location.hash"           'location\.hash'
add_sink "location.search"         'location\.search'
add_sink "document.URL"            'document\.URL'
add_sink "dangerouslySetInnerHTML" 'dangerouslySetInnerHTML'
add_sink "v-html"                  'v-html'
add_sink "ng-bind-html"            'ng-bind-html'
if [ ${#SINKS[@]} -gt 0 ]; then
  { IFS=,; printf '  sinks present: %s\n' "${SINKS[*]}"; } | tee -a "$OUT/J-xss-dom.txt"
  echo "  SEED: DOM sinks reachable → dispatch xss-hunter (dom, source→sink review)" | tee -a "$OUT/J-xss-dom.txt"
else
  echo "  not-applicable: no DOM XSS sinks in page + linked JS" | tee -a "$OUT/J-xss-dom.txt"
fi

# ── J3. postMessage surface ─────────────────────────────────────────
sec "J3. postMessage surface"
: > "$OUT/J-xss-postmessage.txt"
if printf '%s' "$CORPUS" | grep -qiE "addEventListener[[:space:]]*\([[:space:]]*[\"']message|onmessage[[:space:]]*="; then
  if printf '%s' "$CORPUS" | grep -qiE '(event|e|msg|ev)\.origin|\.origin[[:space:]]*(===|==|!==|!=)|origin[[:space:]]*(===|==|!==|!=)'; then
    echo "  message listener present WITH an origin reference nearby" | tee -a "$OUT/J-xss-postmessage.txt"
    echo "  note: verify the origin check is not bypassable (startsWith/indexOf/regex/substring flaws) → xss-hunter (postMessage)" \
      | tee -a "$OUT/J-xss-postmessage.txt"
  else
    echo "  message listener present with NO obvious origin check" | tee -a "$OUT/J-xss-postmessage.txt"
    echo "  SEED: postMessage listener, verify origin validation → xss-hunter (postMessage sub-technique)" \
      | tee -a "$OUT/J-xss-postmessage.txt"
  fi
else
  echo "  not-applicable: no postMessage listener (addEventListener('message') / onmessage)" | tee -a "$OUT/J-xss-postmessage.txt"
fi

# ── J4. Sanitizer / renderer fingerprint ────────────────────────────
sec "J4. Sanitizer / renderer fingerprint"
: > "$OUT/J-xss-fingerprint.txt"
FP=()
fp(){ printf '%s' "$CORPUS" | grep -qiE "$2" && FP+=("$1"); }
fp "DOMPurify"     'DOMPurify'
fp "sanitize-html" 'sanitize-html'
fp "marked"        'marked\.js|marked@|marked\.min|["'"'"' ]marked['"'"'" (]'
fp "markdown-it"   'markdown-it'
fp "showdown"      'showdown'
fp "remarkable"    'remarkable'
fp "Trusted-Types" 'trustedTypes|require-trusted-types-for'
fp "React"         'data-reactroot|__NEXT_DATA__|react-dom|react\.production|react\.development|_reactListening'
fp "Angular"       'ng-version|ng-app|angular\.min\.js|angular\.js|__ngContext__'
fp "Vue"           'data-v-[0-9a-f]|__vue__|vue\.min|vue\.runtime|v-bind|v-if'
if [ ${#FP[@]} -gt 0 ]; then
  for name in "${FP[@]}"; do
    echo "  SEED: sanitizer/renderer=$name → check mXSS / renderer-XSS CVE catalog in references/hunt-xss.md" \
      | tee -a "$OUT/J-xss-fingerprint.txt"
  done
else
  echo "  not-applicable: no known sanitizer/markdown/framework renderer fingerprint" | tee -a "$OUT/J-xss-fingerprint.txt"
fi

# ── J5. Stored-XSS candidate inputs (passive parse — no POST is sent) ─
sec "J5. Stored-XSS candidate inputs"
: > "$OUT/J-xss-stored.txt"
htmlflat=$(printf '%s' "$HTML_CORPUS" | tr '\n\r\t' '   ')
form_actions=$(printf '%s' "$htmlflat" | grep -oiE '<form[^>]*>' \
  | grep -iE 'method[[:space:]]*=[[:space:]]*["'"'"']?post' \
  | grep -oiE 'action[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']*' \
  | sed -E 's/^action[[:space:]]*=[[:space:]]*["'"'"']//' | sort -u | head -15)
names=$(printf '%s' "$htmlflat" | grep -oiE '<(input|textarea)[^<>]*name[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']*' \
  | grep -oiE 'name[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']*' \
  | sed -E 's/^name[[:space:]]*=[[:space:]]*["'"'"']//' | sort -u | head -30)
{
  [ -n "$form_actions" ] && { echo "POST form actions:"; printf '  %s\n' $form_actions; }
  [ -n "$names" ]        && { echo "input/textarea names:"; printf '  %s\n' $names; }
} | tee -a "$OUT/J-xss-stored.txt"
if [ -n "$form_actions" ] || [ -n "$names" ]; then
  echo "  SEED: stored-XSS candidate sinks (inject canary, then re-fetch rendering page) → xss-hunter (stored)" \
    | tee -a "$OUT/J-xss-stored.txt"
else
  echo "  not-applicable: no POST forms or named input/textarea fields on this page" | tee -a "$OUT/J-xss-stored.txt"
fi

# ── summary ─────────────────────────────────────────────────────────
seeds=$(grep -rhoE '^  SEED:' "$OUT"/J-xss-*.txt 2>/dev/null | wc -l | tr -d ' ')
echo
echo "surface-probe J (xss surface) complete → $OUT   ($seeds XSS seed(s) → feed hunt-xss / xss-hunter)"
