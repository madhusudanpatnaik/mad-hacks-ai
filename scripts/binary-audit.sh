#!/usr/bin/env bash
# mad-Hacks_ai binary-audit — keyless static RE of a binary/firmware (all local_read/safe).
# NO execution of the target (that's active/receipt_required — do it in a lab, not here).
# Usage: binary-audit.sh <file>
set -uo pipefail
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
BIN="${1:-}"; [ -f "$BIN" ] || { echo "usage: binary-audit.sh <binary-or-firmware-file>"; exit 2; }
NAME="$(basename "$BIN")"; OUT="./.t3mp3st/bin-${NAME}/audit"; mkdir -p "$OUT"
have(){ command -v "$1" >/dev/null 2>&1; }
sec(){ echo; echo "=== $1 ==="; }
echo "mad-Hacks_ai binary-audit → $BIN → $OUT  (STATIC only — never executes the target)"

sec "Identity"; file "$BIN" | tee "$OUT/file.txt"
have readelf && readelf -h "$BIN" 2>/dev/null | grep -iE 'class|machine|type' | sed 's/^/  /'

sec "Protections (checksec)"
if have checksec; then checksec --file="$BIN" 2>/dev/null | tee "$OUT/checksec.txt"
else echo "  (checksec missing) — quick greps:"; readelf -a "$BIN" 2>/dev/null | grep -iE 'GNU_STACK|RELRO|BIND_NOW|stack_chk|FORTIFY' | sort -u | sed 's/^/  /'; fi

sec "Dangerous imports / sink functions"
{ have nm && nm -D "$BIN" 2>/dev/null; strings -n 5 "$BIN" 2>/dev/null; } \
  | grep -owE 'system|exec[lv]e?p?|popen|strcpy|strcat|sprintf|vsprintf|gets|scanf|memcpy|alloca|malloc|free|realloc|printf|snprintf|read|recv|mmap|setuid|setgid' \
  | sort | uniq -c | sort -rn | head -25 | tee "$OUT/sinks.txt"

sec "Interesting strings (secrets / paths / cmds / URLs)"
strings -n 6 "$BIN" 2>/dev/null | grep -iE 'password|secret|key|token|/bin/|/etc/|http[s]?://|BEGIN (RSA|PRIVATE)|\.so$|cmd|shell' | head -30 | tee "$OUT/strings.txt"

sec "Embedded files / firmware layout (binwalk)"
if have binwalk; then binwalk "$BIN" 2>/dev/null | head -40 | tee "$OUT/binwalk.txt"
else echo "  (binwalk missing) — magic-byte scan skipped. See ctf-techniques.md#firmware-layout."; fi

sec "Disassembly entry (objdump)"
have objdump && objdump -d -M intel "$BIN" 2>/dev/null | grep -A12 '<main>:' | head -20 > "$OUT/main.asm" && echo "  main() disasm → main.asm" || echo "  (no objdump/main symbol)"

echo; echo "✅ binary-audit → $OUT/  — map sinks→reachable entry, then build a PoC in a LAB (execution is receipt_required)."
echo "   Deep methodology: references/ctf-techniques.md (reverse-pwn, firmware-layout, file-parser-chain)."
