#!/usr/bin/env bash
# T3MP3ST report — scaffold a finding, or assemble findings into a report.
# Usage:
#   report.sh finding <target> <slug>       → new findings/F-NNN-<slug>.md from template
#   report.sh import-evidence <target>      → ingest .engagement/<target>/EVIDENCE.jsonl
#                                              rows as findings/F-NNN-*.md stubs
#                                              (bridges the .engagement→.t3mp3st gap
#                                              per operator-integration audit #2)
#   report.sh build <target>                → auto-imports evidence THEN assembles
#                                              findings/*.md + evidence index → report.md
#   report.sh build-html <target>           → report.md → report.html   (pandoc → cmark → md2html)
#   report.sh build-docx <target>           → report.md → report.docx   (pandoc → python-docx fallback)
#   report.sh build-pdf  <target>           → report.md → report.pdf    (pandoc → weasyprint → wkhtmltopdf)
#   report.sh build-all  <target>           → build + build-html + build-docx + build-pdf (best-effort per format)
# Keyless: uses whichever converter is present; reports gracefully if none.
set -euo pipefail
CMD="${1:-}"; TARGET="${2:-}"; SLUG="${3:-}"
[ -n "$TARGET" ] || { echo "usage: report.sh {finding <target> <slug> | import-evidence <target> | build <target> | build-html <target> | build-docx <target> | build-pdf <target> | build-all <target>}"; exit 2; }
BASE="./.t3mp3st/${TARGET}"; FIND="$BASE/findings"; EV="$BASE/evidence"
mkdir -p "$FIND" "$EV"

# ─── engagement-state slug helper (matches engagement-state.sh slug()) ───
_engagement_slug() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9.-' '-' | sed 's/^-//; s/-$//'; }

# ─── auto-import EVIDENCE.jsonl → F-NNN stubs (bridges the storage split) ─
# .engagement/<slug>/EVIDENCE.jsonl is written by engagement-state.sh evidence add
# during hunter dispatch. Without this bridge, `report.sh build` NEVER sees those
# rows because it only reads .t3mp3st/<target>/findings/. Bridge: turn each
# CONFIRMED-shaped evidence row (has observation + evidence + interpretation
# and epistemic in {OBSERVED, DERIVED}) into an F-NNN stub, tagged with source.
# Idempotent: skips rows already imported (fingerprints ts+observation-hash).
_import_evidence_rows() {
  local target="$1"
  local slug; slug=$(_engagement_slug "$target")
  local evi_file=""
  # Support all three storage roots the router already understands
  for root in ".engagement" ".cdc" ".t3mp3st"; do
    if [ -f "./$root/$slug/EVIDENCE.jsonl" ]; then evi_file="./$root/$slug/EVIDENCE.jsonl"; break; fi
  done
  [ -n "$evi_file" ] && [ -s "$evi_file" ] || { echo "  (no EVIDENCE.jsonl found under .engagement/.cdc/.t3mp3st for $slug — nothing to import)"; return 0; }

  local imported_marker="$FIND/.imported-from-evidence.log"
  touch "$imported_marker"
  local added=0
  export FIND imported_marker
  python3 - "$evi_file" <<'PYEOF'
import hashlib, json, os, re, sys
from pathlib import Path
evi_file = Path(sys.argv[1])
FIND     = Path(os.environ["FIND"])
LOG      = Path(os.environ["imported_marker"])
seen = set(LOG.read_text().splitlines()) if LOG.exists() else set()
added = 0
for line in evi_file.read_text().splitlines():
    line = line.strip()
    if not line: continue
    try:
        row = json.loads(line)
    except json.JSONDecodeError:
        continue
    ts    = row.get("ts", "")
    obs   = row.get("observation", "")
    eps   = row.get("epistemic_status", "")
    fp    = hashlib.sha1((ts + "|" + obs[:200]).encode()).hexdigest()[:16]
    if fp in seen: continue
    # Only auto-import evidence-grade rows (OBSERVED / DERIVED); HYPOTHESIS
    # and INFERRED are exploratory and should not appear in a report
    # without operator review.
    if eps not in ("OBSERVED", "DERIVED"): continue
    # Assign next F-NNN
    existing = sorted(FIND.glob("F-*.md"))
    nxt = len(existing) + 1
    slug_bit = re.sub(r"[^a-z0-9]+", "-", (obs[:40].lower())).strip("-") or "finding"
    fname = FIND / f"F-{nxt:03d}-{slug_bit}.md"
    body = f"""# F-{nxt:03d}: {obs[:80] or 'Imported from EVIDENCE.jsonl'}

- **Severity:**   review-required
- **CVSS:**       (assign after operator review)
- **CWE:**        (assign after operator review)
- **Confidence:** {'confirmed' if eps == 'OBSERVED' else 'probable'}  ({eps} / {row.get('confidence', '?')})
- **Affected:**   {row.get('affected', '(specify)')}
- **Source:**     auto-imported from {evi_file.name} (ts={ts})

## Summary
{obs}

## Evidence
- {row.get('evidence', '(evidence path/artifact)')}

## Interpretation
{row.get('interpretation', '')}

## Hypothesis / next test
{row.get('hypothesis', '')}

## Test performed
{row.get('test', '')}

## Result
{row.get('result', '')}

## Conclusion
{row.get('conclusion', '')}

## Uncertainty
Auto-imported stub — operator MUST review, assign severity/CVSS/CWE, verify affected asset, and confirm impact before shipping to a bounty program or client.
"""
    fname.write_text(body)
    with open(LOG, "a") as f:
        f.write(fp + "\n")
    added += 1
print(f"  imported {added} evidence row(s) → {FIND}")
PYEOF
}

case "$CMD" in
  finding)
    [ -n "$SLUG" ] || { echo "usage: report.sh finding <target> <slug>"; exit 2; }
    N=$(printf 'F-%03d' "$(( $(ls "$FIND"/F-*.md 2>/dev/null | wc -l | tr -d ' ') + 1 ))")
    F="$FIND/${N}-${SLUG}.md"
    cat > "$F" <<EOF
# ${N}: <title — vuln + where>

- **Severity:**   info|low|medium|high|critical
- **CVSS:**       <vector + score>
- **CWE:**        CWE-XXX
- **Confidence:** hypothesis|probable|confirmed
- **Affected:**   <exact URL / host / file:line / resource id>
- **MITRE:**      <Txxxx>

## Summary
<what it is, one paragraph>

## Evidence
- EV-1: \`<command>\`
  \`\`\`
  <raw output excerpt — redact secrets/PII>
  \`\`\`
  (artifact: evidence/EV-1.txt)

## Reproduction
<exact minimal deterministic steps>

## Impact
<demonstrated, not theoretical — what an attacker can do + blast radius>

## Remediation
<specific fix>

## Retest
<acceptance criteria to confirm the fix closed it>

## Uncertainty
<what was NOT verified; residual risk>
EOF
    echo "✅ $F"
    echo "   Remember the gates: VERIFY (proof in real captured output) then REFUTE (try to disprove) before marking confirmed."
    ;;
  import-evidence)
    _import_evidence_rows "$TARGET"
    echo "   Review the generated F-*.md files, then run: report.sh build $TARGET"
    ;;
  build)
    # Auto-import EVIDENCE.jsonl before assembly — closes the storage split
    # (audit disconnect #2). Idempotent: already-imported rows are skipped.
    _import_evidence_rows "$TARGET"
    R="$BASE/report.md"
    {
      echo "# Security Assessment — ${TARGET}"
      echo; echo "_Generated $(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo 'UTC')_  · Operator: Claude Code (T3MP3ST keyless)"
      echo; echo "## Scope & authorization"
      if [ -f "$BASE/../SCOPE.md" ]; then echo "See SCOPE.md."; elif [ -f "./.t3mp3st/SCOPE.md" ]; then sed 's/^/> /' "./.t3mp3st/SCOPE.md" | head -20; else echo "> ⚠️ no SCOPE.md recorded."; fi
      echo; echo "## Findings"
      shopt -s nullglob
      files=("$FIND"/F-*.md)
      if [ ${#files[@]} -eq 0 ]; then echo "_No findings recorded._"; else
        for f in "${files[@]}"; do echo; echo "---"; echo; cat "$f"; done
      fi
      echo; echo "---"; echo; echo "## Evidence index"
      if ls "$EV"/* >/dev/null 2>&1; then for e in "$EV"/*; do echo "- $(basename "$e")  ($(wc -l < "$e" 2>/dev/null | tr -d ' ') lines)"; done; else echo "_none_"; fi
      echo; echo "## Methodology"
      echo "T3MP3ST keyless kill chain: classify → scope → decompose → recon → weaponize → exploit → VERIFY → REFUTE → report. Tools driven over Bash by Claude Code as backbone."
    } > "$R"
    echo "✅ assembled $R  (findings: $(ls "$FIND"/F-*.md 2>/dev/null | wc -l | tr -d ' '))"
    ;;
  build-html)
    R="$BASE/report.md"
    [ -f "$R" ] || { echo "report.sh build-html: no report.md — run 'build' first"; exit 3; }
    OUT="$BASE/report.html"
    if command -v pandoc >/dev/null; then
      pandoc "$R" -f gfm -t html5 --standalone --metadata title="Security Assessment — ${TARGET}" -o "$OUT"
      echo "✅ HTML (pandoc): $OUT"
    elif command -v cmark >/dev/null; then
      { echo "<!DOCTYPE html><html><head><meta charset=utf-8><title>Security Assessment — ${TARGET}</title><style>body{font-family:system-ui,sans-serif;max-width:900px;margin:2em auto;padding:0 1em;line-height:1.55}pre{background:#f5f5f5;padding:.75em;overflow-x:auto}code{background:#f5f5f5;padding:.1em .3em;border-radius:3px}h1,h2,h3{margin-top:1.4em}table{border-collapse:collapse}td,th{border:1px solid #ddd;padding:.4em .7em}</style></head><body>"; cmark "$R"; echo "</body></html>"; } > "$OUT"
      echo "✅ HTML (cmark): $OUT"
    elif command -v python3 >/dev/null && python3 -c "import markdown" 2>/dev/null; then
      python3 - "$R" "$OUT" "${TARGET}" <<'PY'
import sys, markdown
md_path, out_path, target = sys.argv[1], sys.argv[2], sys.argv[3]
with open(md_path) as f: src = f.read()
body = markdown.markdown(src, extensions=['tables','fenced_code'])
html = f"""<!DOCTYPE html><html><head><meta charset=utf-8><title>Security Assessment — {target}</title><style>body{{font-family:system-ui,sans-serif;max-width:900px;margin:2em auto;padding:0 1em;line-height:1.55}}pre{{background:#f5f5f5;padding:.75em;overflow-x:auto}}code{{background:#f5f5f5;padding:.1em .3em;border-radius:3px}}h1,h2,h3{{margin-top:1.4em}}table{{border-collapse:collapse}}td,th{{border:1px solid #ddd;padding:.4em .7em}}</style></head><body>{body}</body></html>"""
with open(out_path,'w') as f: f.write(html)
PY
      echo "✅ HTML (python markdown): $OUT"
    else
      echo "⚠️  no HTML converter found — install one:"
      echo "    brew install pandoc                # richest, preserves tables/code blocks"
      echo "    brew install cmark                 # tiny, fast"
      echo "    pip3 install markdown              # fallback"
      exit 4
    fi
    ;;
  build-docx)
    R="$BASE/report.md"
    [ -f "$R" ] || { echo "report.sh build-docx: no report.md — run 'build' first"; exit 3; }
    OUT="$BASE/report.docx"
    if command -v pandoc >/dev/null; then
      pandoc "$R" -f gfm -t docx --metadata title="Security Assessment — ${TARGET}" -o "$OUT"
      echo "✅ DOCX (pandoc): $OUT"
    elif command -v python3 >/dev/null && python3 -c "import docx" 2>/dev/null; then
      python3 - "$R" "$OUT" "${TARGET}" <<'PY'
import sys, re
from docx import Document
from docx.shared import Pt

md_path, out_path, target = sys.argv[1], sys.argv[2], sys.argv[3]
with open(md_path) as f: lines = f.read().splitlines()

doc = Document()
doc.styles['Normal'].font.name = 'Calibri'
doc.styles['Normal'].font.size = Pt(11)

def flush_para(buf):
    if not buf: return
    text = ' '.join(buf).strip()
    if text: doc.add_paragraph(text)

in_code, buf, code_buf = False, [], []
for ln in lines:
    if ln.startswith('```'):
        flush_para(buf); buf = []
        if in_code:
            para = doc.add_paragraph()
            run = para.add_run('\n'.join(code_buf))
            run.font.name = 'Consolas'; run.font.size = Pt(9)
            code_buf = []
        in_code = not in_code
        continue
    if in_code:
        code_buf.append(ln); continue
    if ln.startswith('# '):
        flush_para(buf); buf = []; doc.add_heading(ln[2:].strip(), level=1)
    elif ln.startswith('## '):
        flush_para(buf); buf = []; doc.add_heading(ln[3:].strip(), level=2)
    elif ln.startswith('### '):
        flush_para(buf); buf = []; doc.add_heading(ln[4:].strip(), level=3)
    elif ln.startswith('- ') or ln.startswith('* '):
        flush_para(buf); buf = []
        doc.add_paragraph(ln[2:].strip(), style='List Bullet')
    elif re.match(r'^\d+\.\s', ln):
        flush_para(buf); buf = []
        doc.add_paragraph(re.sub(r'^\d+\.\s', '', ln).strip(), style='List Number')
    elif ln.strip() == '':
        flush_para(buf); buf = []
    else:
        buf.append(ln.strip())
flush_para(buf)
doc.save(out_path)
PY
      echo "✅ DOCX (python-docx): $OUT"
    else
      echo "⚠️  no DOCX converter found — install one:"
      echo "    brew install pandoc                # best, preserves formatting"
      echo "    pip3 install python-docx           # fallback"
      exit 4
    fi
    ;;
  build-pdf)
    R="$BASE/report.md"
    [ -f "$R" ] || { echo "report.sh build-pdf: no report.md — run 'build' first"; exit 3; }
    OUT="$BASE/report.pdf"
    # Prefer pandoc (needs a LaTeX engine); fall back to HTML→PDF converters.
    if command -v pandoc >/dev/null && ( command -v pdflatex >/dev/null || command -v xelatex >/dev/null || command -v tectonic >/dev/null ); then
      pandoc "$R" -f gfm -o "$OUT"
      echo "✅ PDF (pandoc): $OUT"
    elif command -v weasyprint >/dev/null; then
      # weasyprint reads HTML — build HTML first
      HTML="$BASE/.report.tmp.html"
      "$0" build-html "$TARGET" >/dev/null
      cp "$BASE/report.html" "$HTML"
      weasyprint "$HTML" "$OUT"
      rm -f "$HTML"
      echo "✅ PDF (weasyprint via HTML): $OUT"
    elif command -v wkhtmltopdf >/dev/null; then
      HTML="$BASE/.report.tmp.html"
      "$0" build-html "$TARGET" >/dev/null
      cp "$BASE/report.html" "$HTML"
      wkhtmltopdf --quiet "$HTML" "$OUT" 2>/dev/null || wkhtmltopdf "$HTML" "$OUT"
      rm -f "$HTML"
      echo "✅ PDF (wkhtmltopdf via HTML): $OUT"
    else
      echo "⚠️  no PDF converter found — install one:"
      echo "    brew install pandoc mactex-no-gui    # richest, LaTeX-based"
      echo "    brew install weasyprint              # HTML→PDF (Python)"
      echo "    brew install --cask wkhtmltopdf      # HTML→PDF (WebKit)"
      exit 4
    fi
    ;;
  build-all)
    "$0" build      "$TARGET"
    "$0" build-html "$TARGET" || echo "  (HTML skipped)"
    "$0" build-docx "$TARGET" || echo "  (DOCX skipped)"
    "$0" build-pdf  "$TARGET" || echo "  (PDF skipped)"
    echo ""
    echo "── deliverables at $BASE ──"
    ls -la "$BASE"/report.* 2>/dev/null | awk '{print "  "$NF"  ("$5" bytes)"}'
    ;;
  *) echo "usage: report.sh {finding <target> <slug> | build <target> | build-html <target> | build-docx <target> | build-pdf <target> | build-all <target>}"; exit 2;;
esac
