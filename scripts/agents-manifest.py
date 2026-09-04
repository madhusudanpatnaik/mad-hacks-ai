#!/usr/bin/env python3
"""
agents-manifest.py — regenerate agents/manifest.json from the repo's canonical
agent tree (agents/hunters/ + agents/operators/).

The manifest is the SOURCE OF TRUTH for what an installed mad-Hacks_ai
runtime should have in ~/.claude/agents/. scripts/agents-verify.sh compares
the installed files against this manifest's sha256 + presence list.

Per-agent metadata:
  agent_id              basename minus .md  (matches Claude Code agent name)
  agent_type            "hunter" or "operator"
  path                  repo-relative path
  sha256                sha256 of file contents (hex)
  size_bytes            file size
  description           first-line description from frontmatter (truncated)
  tools                 tools declared in frontmatter (as-is)
  model                 model declared in frontmatter (or "inherit")
  supported_classes     inferred from name + description
  requires_scripts      list of scripts referenced in the file body
  requires_references   list of references/*.md files referenced
  requires_mcp          list of ToolSearch keywords referenced (per Preflight
                        preamble pattern)

Usage:
  python3 scripts/agents-manifest.py                # regenerate to agents/manifest.json
  python3 scripts/agents-manifest.py --check        # exit 1 if generated differs from on-disk
  python3 scripts/agents-manifest.py --dry-run      # print, don't write
"""
import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

REPO         = Path(__file__).resolve().parent.parent
AGENTS_DIR   = REPO / "agents"
MANIFEST_OUT = AGENTS_DIR / "manifest.json"


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_frontmatter(text):
    """Extract YAML-ish frontmatter as a dict of top-level scalars."""
    m = re.match(r"---\s*\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        if ":" in line and not line.strip().startswith("#"):
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm


# Canonical class vocabulary — mirrors intelligence-recall.sh CLASS_KEYWORDS
CLASS_KEYWORDS = {
    "xss": ["xss", "cross-site scripting"],
    "sqli": ["sql injection", "sqli"],
    "rce": ["remote code execution", "rce", "command injection"],
    "ssrf": ["ssrf", "server-side request forgery"],
    "ssti": ["ssti", "template injection"],
    "idor": ["idor", "bola", "broken object level"],
    "csrf": ["csrf", "cross-site request forgery"],
    "cors": ["cors"],
    "xxe": ["xxe", "xml external"],
    "lfi": ["lfi", "path traversal"],
    "jwt": ["jwt"],
    "oauth": ["oauth", "oidc", "openid", "saml"],
    "clickjacking": ["clickjacking"],
    "deserialization": ["deserialization"],
    "graphql": ["graphql"],
    "open-redirect": ["open redirect", "redirect_uri"],
    "cache-poison": ["cache poison"],
    "subdomain-takeover": ["subdomain takeover"],
    "file-upload": ["file upload"],
    "auth-session": ["auth bypass", "session", "mfa"],
    "http-smuggling": ["http smuggling"],
    "waf-bypass": ["waf"],
    "cloud": ["cloud", "s3", "aws", "gcp", "azure"],
    "llm-ai": ["llm", "prompt injection"],
    "race": ["race condition", "toctou"],
    "info-disclosure": ["info disclosure", "information disclosure"],
    "privilege-escalation": ["privilege escalation", "privesc"],
    "business-logic": ["business logic"],
    "web3": ["web3", "smart contract"],
    "recon": ["recon", "reconnaissance"],
    "sast": ["sast", "static analysis"],
}


def infer_classes(agent_id, description):
    """Best-effort class inference from agent_id + description."""
    text = f"{agent_id} {description}".lower()
    hits = set()
    for cls, kws in CLASS_KEYWORDS.items():
        if cls in text or any(kw in text for kw in kws):
            hits.add(cls)
    return sorted(hits)


# Extract references to repo assets — surfaces cross-file dependencies
SCRIPT_RE     = re.compile(r"scripts/([a-zA-Z0-9_.-]+\.(?:sh|py))")
REFERENCE_RE  = re.compile(r"references/([a-zA-Z0-9_.-]+\.md)")
MCP_TOOL_RE   = re.compile(r'ToolSearch\(\s*["\']([^"\']+)["\']')


def extract_refs(text):
    scripts    = sorted(set(SCRIPT_RE.findall(text)))
    references = sorted(set(REFERENCE_RE.findall(text)))
    mcp_hints  = sorted(set(MCP_TOOL_RE.findall(text)))
    return scripts, references, mcp_hints


def build_manifest():
    entries = []
    for atype in ("hunter", "operator"):
        d = AGENTS_DIR / (atype + "s")
        if not d.is_dir():
            continue
        for f in sorted(d.glob("*.md")):
            text = f.read_text(encoding="utf-8", errors="ignore")
            fm = parse_frontmatter(text)
            desc = (fm.get("description") or "").strip()
            scripts, refs, mcp_hints = extract_refs(text)
            entries.append({
                "agent_id":            fm.get("name") or f.stem,
                "agent_type":          atype,
                "path":                str(f.relative_to(REPO)),
                "sha256":              sha256(f),
                "size_bytes":          f.stat().st_size,
                "description":         desc[:280],
                "tools":               fm.get("tools", ""),
                "model":               fm.get("model", "inherit"),
                "supported_classes":   infer_classes(f.stem, desc),
                "requires_scripts":    scripts,
                "requires_references": refs,
                "requires_mcp":        mcp_hints,
            })
    return {
        "manifest_version": 1,
        "generated_by":     "scripts/agents-manifest.py",
        "agent_count":      len(entries),
        "hunters":          sum(1 for e in entries if e["agent_type"] == "hunter"),
        "operators":        sum(1 for e in entries if e["agent_type"] == "operator"),
        "agents":           entries,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if generated manifest differs from on-disk")
    ap.add_argument("--dry-run", action="store_true",
                    help="print manifest to stdout, don't write")
    args = ap.parse_args()

    m = build_manifest()
    serialized = json.dumps(m, indent=2, sort_keys=False) + "\n"

    if args.dry_run:
        print(serialized, end="")
        return 0

    if args.check:
        if not MANIFEST_OUT.exists():
            print(f"✗ manifest missing: {MANIFEST_OUT}", file=sys.stderr)
            return 1
        current = MANIFEST_OUT.read_text()
        if current != serialized:
            print(f"✗ manifest OUT OF DATE — regenerate with: python3 scripts/agents-manifest.py", file=sys.stderr)
            return 1
        print(f"✓ manifest fresh: {m['agent_count']} agents ({m['hunters']}h + {m['operators']}o)")
        return 0

    MANIFEST_OUT.write_text(serialized)
    print(f"✓ wrote {MANIFEST_OUT.relative_to(REPO)}   {m['agent_count']} agents ({m['hunters']}h + {m['operators']}o)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
