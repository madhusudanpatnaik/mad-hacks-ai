#!/usr/bin/env bash
# oob.sh — Out-of-band interaction orchestrator (blind class confirmation)
#
# Wraps ProjectDiscovery's `interactsh-client` + a per-target ledger so blind SSRF/XXE/SQLi/RCE
# are attributable: fresh payload per param, correlate interactions to the exact trigger.
# Doctrine (brain lessons):
#   - Blind classes need OOB (DNS+HTTP) — no callback = not confirmed.
#   - Fresh payload PER PARAM (never batch) so attribution is unambiguous.
#   - Server echoing URL in an error message is NOT confirmation.
#
# Usage:
#   oob.sh seed <target> <family> [param]     → allocate 1 fresh payload; append to ledger; print it
#   oob.sh seed <target> <family> -n <count>  → allocate N fresh payloads
#   oob.sh fire <target> <param> <payload>    → record "payload P was fired against param X"
#   oob.sh poll <target> [--wait <sec>]       → pull interactions, correlate to ledger, print matches
#   oob.sh attribute <target>                 → show payload → interactions map (attribution table)
#   oob.sh list <target>                      → dump the ledger
#   oob.sh listen <target> [--json]           → run interactsh-client in the FG for a session
#   oob.sh clean <target>                     → remove the OOB state for this target
set -uo pipefail

CMD="${1:-}"; TARGET="${2:-}"
[ -n "$CMD" ] && [ -n "$TARGET" ] || { sed -n '1,20p' "$0"; exit 2; }
command -v interactsh-client >/dev/null || {
  echo "oob.sh: interactsh-client not installed."
  echo "  install: go install -v github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
  echo "  or:      brew install projectdiscovery/tap/interactsh-client"
  exit 4
}

slug(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's#[^a-z0-9._-]#_#g'; }
TS(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
SLUG="$(slug "$TARGET")"
ROOT=".t3mp3st/${SLUG}/oob"
LEDGER="$ROOT/ledger.tsv"
SESSION="$ROOT/session.json"
INTERACTIONS="$ROOT/interactions.jsonl"
mkdir -p "$ROOT"
[ -f "$LEDGER" ] || printf 'timestamp\tfamily\tparam\tpayload\tstatus\n' > "$LEDGER"

shift 2 || true

case "$CMD" in
  # ─── seed: allocate fresh interactsh payloads ────────────────────
  seed)
    FAMILY="${1:-generic}"; shift || true
    PARAM=""
    N=1
    while [ $# -gt 0 ]; do
      case "$1" in
        -n|--number) N="${2:-1}"; shift 2;;
        *) PARAM="$1"; shift;;
      esac
    done
    # generate N fresh payloads. interactsh-client outputs one payload per line and (with -json) event JSON to stdout.
    # We use --number so it emits N unique domains, then Ctrl-C via timeout after they're printed.
    # Session-file persistence keeps the correlation ids across polls.
    RAW=$(mktemp)
    ( interactsh-client -number "$N" -o "$RAW" -sf "$SESSION" -pi 2 -q 2>/dev/null & sleep 1; kill %1 2>/dev/null; wait 2>/dev/null ) || true
    # interactsh-client -o writes plain lines like "cxxx.oast.fun"; some versions prefix with "[INF]"
    PAYLOADS=$(grep -oE '[a-z0-9]+\.(oast\.pro|oast\.live|oast\.site|oast\.online|oast\.fun|oast\.me)' "$RAW" | sort -u | head -"$N")
    rm -f "$RAW"
    [ -n "$PAYLOADS" ] || { echo "oob.sh seed: no payload allocated (interactsh unreachable?)"; exit 5; }
    while IFS= read -r P; do
      [ -n "$P" ] || continue
      printf '%s\t%s\t%s\t%s\t%s\n' "$(TS)" "$FAMILY" "${PARAM:-*}" "$P" "seeded" >> "$LEDGER"
      echo "$P"
    done <<< "$PAYLOADS"
    ;;

  # ─── fire: record that a payload was fired against a param ──────
  fire)
    PARAM="${1:-}"; PAYLOAD="${2:-}"
    [ -n "$PARAM" ] && [ -n "$PAYLOAD" ] || { echo "usage: oob.sh fire <target> <param> <payload>"; exit 2; }
    # Update ledger row's param + mark as fired (append a fired row for provenance)
    printf '%s\t%s\t%s\t%s\t%s\n' "$(TS)" "-" "$PARAM" "$PAYLOAD" "fired" >> "$LEDGER"
    echo "✓ fired: $PARAM ← $PAYLOAD"
    ;;

  # ─── poll: pull interactions + correlate to ledger ──────────────
  poll)
    WAIT=8
    [ "${1:-}" = "--wait" ] && { WAIT="${2:-8}"; shift 2 || true; }
    # capture new interactions in JSON. run for WAIT seconds.
    TMP=$(mktemp)
    ( interactsh-client -sf "$SESSION" -json -o "$TMP" -pi 2 -q 2>/dev/null & PID=$!; sleep "$WAIT"; kill "$PID" 2>/dev/null; wait 2>/dev/null ) || true
    # Each line is a JSON interaction event. Preserve.
    [ -s "$TMP" ] && cat "$TMP" >> "$INTERACTIONS"
    NEW=$(wc -l < "$TMP" | tr -d ' ')
    rm -f "$TMP"
    echo "── polled ${WAIT}s: $NEW new interaction(s) landed in $INTERACTIONS ──"
    [ "$NEW" -gt 0 ] || { echo "  (no callbacks — try firing your payloads again, or increase --wait)"; exit 0; }
    # correlate: for each seeded/fired payload in ledger, count interactions containing that payload
    echo ""
    echo "── correlation (payload → # interactions) ──"
    awk -F'\t' 'NR>1 && ($5=="seeded"||$5=="fired") {print $4}' "$LEDGER" | sort -u | while read -r P; do
      HITS=$(grep -c "$P" "$INTERACTIONS" 2>/dev/null || echo 0)
      if [ "$HITS" -gt 0 ]; then
        # find the ledger row that names this payload — pick most recent 'fired' or 'seeded'
        META=$(awk -F'\t' -v p="$P" '$4==p{last=$0} END{print last}' "$LEDGER")
        FAM=$(printf '%s' "$META" | cut -f2)
        PARAM=$(printf '%s' "$META" | cut -f3)
        printf "  %-45s  %-8s  param=%-30s  → %d hit(s)\n" "$P" "$FAM" "$PARAM" "$HITS"
      fi
    done
    ;;

  # ─── attribute: show payload → interactions with protocol split ─
  attribute)
    [ -f "$INTERACTIONS" ] || { echo "(no interactions polled yet — run 'oob.sh poll $TARGET')"; exit 0; }
    echo "── OOB attribution for $TARGET ──"
    awk -F'\t' 'NR>1 && ($5=="seeded"||$5=="fired")' "$LEDGER" | while IFS=$'\t' read -r T FAM PARAM P STATUS; do
      DNS=$(grep -c "\"protocol\":\"dns\".*$P\|$P.*\"protocol\":\"dns\"" "$INTERACTIONS" 2>/dev/null || echo 0)
      HTTP=$(grep -c "\"protocol\":\"http\".*$P\|$P.*\"protocol\":\"http\"" "$INTERACTIONS" 2>/dev/null || echo 0)
      TOTAL=$((DNS + HTTP))
      if [ "$TOTAL" -gt 0 ]; then
        printf "  ✓ [%s]  family=%-8s  param=%-25s  payload=%-45s  DNS=%d  HTTP=%d\n" \
               "CONFIRMED" "$FAM" "$PARAM" "$P" "$DNS" "$HTTP"
      else
        printf "    [no-hit]   family=%-8s  param=%-25s  payload=%s\n" \
               "$FAM" "$PARAM" "$P"
      fi
    done
    ;;

  # ─── list: dump the ledger ──────────────────────────────────────
  list)
    column -t -s $'\t' "$LEDGER" 2>/dev/null || cat "$LEDGER"
    ;;

  # ─── listen: foreground interactsh-client (interactive) ─────────
  listen)
    JSON=""
    [ "${1:-}" = "--json" ] && JSON="-json"
    echo "── interactsh-client running (Ctrl-C to stop) — session: $SESSION ──"
    interactsh-client -sf "$SESSION" $JSON -pi 5
    ;;

  # ─── clean: remove OOB state for this target ────────────────────
  clean)
    rm -rf "$ROOT"
    echo "✓ cleaned $ROOT"
    ;;

  *)
    sed -n '1,20p' "$0"; exit 2
    ;;
esac
