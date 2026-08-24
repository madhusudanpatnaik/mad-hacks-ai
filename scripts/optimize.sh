#!/usr/bin/env bash
# mad-Hacks_ai storage optimizer — keeps the single folder lean as repos/reports pile up.
# Idempotent + safe: dedupes payloads/wordlists, strips repo cruft from packs, compresses
# large raw archives, and reports the footprint. Run after every ingest.
# Usage: optimize.sh [--aggressive]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGG="${1:-}"
h(){ echo; echo "── $1 ──"; }
echo "════════ mad-Hacks_ai OPTIMIZE ════════  ($ROOT)"
before=$(du -sm "$ROOT" 2>/dev/null | cut -f1)

h "Dedupe brain payloads + wordlists (order-preserving)"
for f in "$ROOT"/brain/payloads/*.txt "$ROOT"/wordlists/*.txt; do
  [ -f "$f" ] || continue
  [ -L "$f" ] && continue   # skip symlinks — never materialize a dedup'd/symlinked file back into a real copy
  b=$(wc -l < "$f" | tr -d ' '); awk 'NF && !seen[$0]++' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  a=$(wc -l < "$f" | tr -d ' '); [ "$b" != "$a" ] && echo "  $(basename "$f"): $b → $a"
done
echo "  (per-file dedup done)"

h "Cross-file dedup — symlink byte-identical files (auto-catches repo dups)"
# hash every real file in wordlists/ + brain/payloads/ + packs/ + references/; if two share a hash,
# replace later ones with a symlink. packs/ is listed BEFORE references/ so packs stays canonical for
# cross-tree ingest dups (e.g. claude-bughunter's shared corpus). -type f skips symlinks → idempotent.
declare -a seen_hash seen_path
find "$ROOT/wordlists" "$ROOT/brain/payloads" "$ROOT/packs" "$ROOT/references" -type f 2>/dev/null | while read -r f; do
  hsh=$(md5 -q "$f" 2>/dev/null || md5sum "$f" 2>/dev/null | cut -d' ' -f1)
  match=$(grep -F "$hsh " "$ROOT/.opt-hashes.tmp" 2>/dev/null | head -1 | cut -d' ' -f2-)
  if [ -n "$match" ] && [ "$match" != "$f" ]; then
    ln -sf "$(python3 -c "import os,sys;print(os.path.relpath(sys.argv[1],os.path.dirname(sys.argv[2])))" "$match" "$f")" "$f"
    echo "  symlinked dup: ${f#$ROOT/} → ${match#$ROOT/}"
  else
    echo "$hsh $f" >> "$ROOT/.opt-hashes.tmp"
  fi
done
rm -f "$ROOT/.opt-hashes.tmp"

h "Strip repo cruft from packs/ (never needed by the workflow)"
find "$ROOT/packs" -type d \( -name '.git' -o -name 'node_modules' -o -name '__pycache__' -o -name '.github' -o -name 'demo' -o -name 'assets' -o -name 'tests' -o -name 'test' \) -prune -exec rm -rf {} + 2>/dev/null
find "$ROOT/packs" -type f \( -name '*.png' -o -name '*.svg' -o -name '*.jpg' -o -name '*.gif' -o -name '*.lock' -o -name '*.pyc' \) -delete 2>/dev/null
echo "  packs cleaned"

h "Compress large raw archives (reports/methodology kept, but zipped over 256KB)"
find "$ROOT/packs" -type f \( -name '*.md' -o -name '*.txt' -o -name '*.json' \) -size +256k 2>/dev/null | while read -r f; do
  gzip -f "$f" && echo "  gz: ${f#$ROOT/}"
done

if [ "$AGG" = "--aggressive" ]; then
  h "Aggressive: gzip the big wordlist (raft) — gunzip on demand for ffuf"
  [ -f "$ROOT/wordlists/raft-medium-dirs.txt" ] && gzip -f "$ROOT/wordlists/raft-medium-dirs.txt" && echo "  raft-medium-dirs.txt.gz"
  h "Aggressive: prune engagement evidence older than 30 days"
  find "$ROOT/engagements" -type f -mtime +30 -delete 2>/dev/null; echo "  old evidence pruned"
fi

h "Footprint"
after=$(du -sm "$ROOT" 2>/dev/null | cut -f1)
du -sh "$ROOT"/* 2>/dev/null | sort -h | sed "s|$ROOT/||"
echo; echo "TOTAL: ${before}M → ${after}M"
echo "════════ done ════════"
