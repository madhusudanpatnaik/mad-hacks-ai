#!/usr/bin/env python3
"""
preamble.py — extract the POLICY PREAMBLE from a mad-hacks SCOPE.md.

The preamble is injected verbatim into EVERY specialist-hunter dispatch by
/mad-hunt so that program rules (required header, rate cap, prohibited actions,
chaining boundary, prod mode) travel with every subagent. Violating a program's
policy = disqualification/ban, so this is enforced in code, not trusted to memory.

Usage:  python3 scripts/preamble.py --md .t3mp3st/SCOPE.md
Also prints a machine-readable PLATFORM=<hackerone|bugcrowd|intigriti|unknown>
line (from the program URL) that the reporter uses to pick its template.
"""
import argparse
import re
import sys


def _field(text, label):
    """Value after 'label:' on the same line, minus placeholder underscores."""
    m = re.search(re.escape(label) + r"\s*:?\s*(.+)", text, re.IGNORECASE)
    if not m:
        return None
    v = m.group(1).strip().strip("_").strip()
    return v or None


def _ticked(text, section_line):
    """Return the list of ticked '[x]' options on a checkbox line."""
    m = re.search(re.escape(section_line) + r".*", text, re.IGNORECASE)
    if not m:
        return []
    line = m.group(0)
    # options look like: [x] automated scanning  [ ] DoS
    return [opt.strip() for tick, opt in
            re.findall(r"\[([ xX])\]\s*([A-Za-z0-9 /_-]+?)(?=\s*\[|$)", line)
            if tick.lower() == "x"]


def _platform(text):
    ref = (_field(text, "Reference (contract id / program URL / ticket)") or "") + \
          (_field(text, "Authorizing party / program") or "")
    ref = ref.lower()
    if "hackerone.com" in ref or "h1" in ref:
        return "hackerone"
    if "bugcrowd.com" in ref:
        return "bugcrowd"
    if "intigriti.com" in ref:
        return "intigriti"
    return "unknown"


def build(text):
    program = _field(text, "Authorizing party / program") or "(program not recorded)"
    rate = _field(text, "Rate limits / testing hours") or "no explicit limit — stay gentle"
    header = _field(text, "Traffic identifier (header/marker blue-team can filter)")
    prohibits = _ticked(text, "Program prohibits (tick what applies):")
    is_prod = bool(re.search(r"\[[xX]\]\s*PRODUCTION", text))
    # chaining line: "Chaining/lateral movement allowed? [ ] no ... [x] yes, up to: ___"
    chain_yes = bool(re.search(r"\[[xX]\]\s*yes", text, re.IGNORECASE))
    platform = _platform(text)

    lines = [
        "POLICY CONSTRAINTS (VIOLATION = DISQUALIFICATION/BAN):",
        "SCOPE AND POLICY MUST BE OBEYED AT ALL TIMES. Out-of-scope = hard stop.",
        f"- Program: {program}",
    ]
    if header:
        lines.append(f"- REQUIRED on every HTTP request — traffic identifier: {header}")
    else:
        lines.append("- No traffic identifier recorded — set one in SCOPE.md if the program requires it.")
    lines.append(f"- Rate limit / testing window: {rate}. Treat as a HARD ceiling; adaptive-throttle under it.")
    if prohibits:
        lines.append(f"- PROHIBITED (program): {', '.join(prohibits)}. Do NOT perform these.")
    lines.append("- NEVER create accounts, submit reports, move funds, or delete/modify real data. "
                 "Use only test creds recorded in SCOPE.md; flag human-only steps.")
    lines.append(f"- Chaining/lateral movement: {'ALLOWED (per SCOPE.md) — escalate' if chain_yes else 'NOT allowed — stop at first server-side proof'}.")
    if is_prod:
        lines.append("- PRODUCTION target: references/production-safety.md R1-R11 are BINDING. "
                     "Safe-PoC only (alert(document.domain), id, one canary record, OOB callback). Clean up artifacts.")
    lines.append("- Prove impact minimally, redact secrets/PII, no bulk data.")
    return "\n".join(lines), platform


def main(argv=None):
    ap = argparse.ArgumentParser(description="Emit the /mad-hunt policy preamble from SCOPE.md")
    ap.add_argument("--md", required=True, help="path to .t3mp3st/SCOPE.md")
    args = ap.parse_args(argv)
    try:
        text = open(args.md, encoding="utf-8").read()
    except OSError as e:
        print(f"cannot read {args.md}: {e}", file=sys.stderr)
        return 2
    preamble, platform = build(text)
    print(preamble)
    print(f"\nPLATFORM={platform}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
