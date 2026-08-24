#!/usr/bin/env bash
# mad-Hacks_ai mobile-audit — keyless APK/mobile static analysis (all local_read/safe).
# NO device, NO dynamic instrumentation. Decompile + manifest + secrets/cleartext.
# Usage: mobile-audit.sh <app.apk | app-source-dir>
set -uo pipefail
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
SRC="${1:-}"; [ -e "$SRC" ] || { echo "usage: mobile-audit.sh <app.apk|src-dir>"; exit 2; }
NAME="$(basename "$SRC" | sed 's/\.[^.]*$//')"; OUT="./.t3mp3st/mobile-${NAME}/audit"; mkdir -p "$OUT"
have(){ command -v "$1" >/dev/null 2>&1; }
sec(){ echo; echo "=== $1 ==="; }
echo "mad-Hacks_ai mobile-audit → $SRC → $OUT  (static, keyless)"

WORK="$SRC"
if echo "$SRC" | grep -qi '\.apk$'; then
  sec "Decompile APK"
  if have apktool; then apktool d -f "$SRC" -o "$OUT/apk" >/dev/null 2>&1 && WORK="$OUT/apk" && echo "  apktool → $OUT/apk"; fi
  have jadx && { jadx --output-dir "$OUT/jadx" "$SRC" >/dev/null 2>&1 && echo "  jadx → $OUT/jadx"; WORK="$OUT/jadx"; }
  [ "$WORK" = "$SRC" ] && echo "  (no apktool/jadx — analyzing raw apk / provide decompiled dir)"
fi

sec "Manifest misconfig"
MAN=$(find "$WORK" -name 'AndroidManifest.xml' 2>/dev/null | head -1)
if [ -n "$MAN" ]; then
  grep -oE 'android:(debuggable|allowBackup|usesCleartextTraffic|exported)="[^"]*"' "$MAN" 2>/dev/null | sort -u | sed 's/^/  /'
  grep -q 'android:debuggable="true"' "$MAN" 2>/dev/null && echo "  - [HIGH] debuggable=true"
  grep -q 'android:allowBackup="true"' "$MAN" 2>/dev/null && echo "  - [MEDIUM] allowBackup=true"
  grep -q 'usesCleartextTraffic="true"' "$MAN" 2>/dev/null && echo "  - [MEDIUM] cleartext traffic allowed"
else echo "  (no AndroidManifest.xml found)"; fi

sec "Static scan (mobsfscan)"
have mobsfscan && mobsfscan --json "$WORK" 2>/dev/null | jq -r '.results | to_entries[] | "- "+.key' 2>/dev/null | head -30 | tee "$OUT/mobsf.txt" || echo "  (mobsfscan not available)"

sec "Secrets / endpoints / cleartext"
{ echo "## secrets"; grep -rInE 'api[_-]?key|secret|password|token|BEGIN (RSA|PRIVATE)' "$WORK" 2>/dev/null | grep -viE '\.apk$' | head -15
  echo "## http endpoints"; grep -rInoE 'https?://[a-zA-Z0-9._/-]+' "$WORK" 2>/dev/null | grep -iE 'http://' | head -15
} | tee "$OUT/strings.txt"
have apkleaks && echo "$SRC" | grep -qi '\.apk$' && apkleaks -f "$SRC" -o "$OUT/apkleaks.txt" 2>/dev/null && echo "  apkleaks → $OUT/apkleaks.txt"

echo; echo "✅ mobile-audit → $OUT/  — VERIFY each issue before it's a finding."
