#!/usr/bin/env python3
"""SARIF 2.1.0 exporter for T3MP3ST findings.

Converts t3-reporter findings from .t3mp3st/<target>/findings/ into a
GitHub code-scanning compatible SARIF document. Keyless, standalone.

Usage:
    python3 scripts/sarif-export.py <target-dir>
    # e.g. python3 scripts/sarif-export.py .t3mp3st/api-sit.moviussit.net

Outputs: <target-dir>/findings.sarif

Adapted from Strix SARIF module (Apache-2.0, usestrix/strix).
"""

import hashlib
import json
import os
import re
import sys
from pathlib import Path

SARIF_SCHEMA = "https://json.schemastore.org/sarif-2.1.0.json"
SARIF_VERSION = "2.1.0"
TOOL_NAME = "T3MP3ST"
TOOL_URI = "https://github.com/elder-plinius/T3MP3ST"

SEVERITY_TO_LEVEL = {
    "critical": "error",
    "high": "error",
    "medium": "warning",
    "low": "note",
    "info": "note",
    "informational": "note",
}

SEVERITY_TO_SCORE = {
    "critical": "9.5",
    "high": "8.0",
    "medium": "5.5",
    "low": "3.0",
    "info": "1.0",
    "informational": "1.0",
}

CWE_TO_STRIDE = {
    "20": ("T",), "22": ("T", "I"), "73": ("T", "I"), "78": ("T", "E"),
    "79": ("T", "I"), "89": ("T",), "91": ("T",), "94": ("T", "E"),
    "117": ("R",), "200": ("I",), "201": ("I",), "209": ("I",),
    "223": ("R",), "256": ("I",), "259": ("S", "I"), "269": ("E",),
    "284": ("E",), "285": ("E",), "287": ("S",), "290": ("S",),
    "294": ("S",), "306": ("S", "E"), "311": ("I",), "319": ("I",),
    "327": ("I",), "328": ("I",), "345": ("S", "T"), "346": ("S",),
    "352": ("T", "S"), "384": ("S",), "400": ("D",), "434": ("T",),
    "502": ("T", "E"), "521": ("S",), "522": ("I",), "525": ("I",),
    "532": ("I",), "538": ("I",), "598": ("I",), "611": ("I", "T"),
    "613": ("S",), "639": ("E",), "640": ("S",), "732": ("E",),
    "770": ("D",), "778": ("R",), "798": ("S", "I"), "862": ("E",),
    "863": ("E",), "915": ("E", "T"), "918": ("T", "I"),
    "1220": ("E",), "1333": ("D",), "1336": ("T", "E"), "1391": ("S",),
}

DEFAULT_STRIDE = ("T", "I")


def normalise_cwe(value):
    digits = "".join(c for c in str(value) if c.isdigit())
    return f"CWE-{digits}" if digits else None


def stride_for_cwe(cwe):
    if not cwe:
        return DEFAULT_STRIDE
    digits = "".join(c for c in str(cwe) if c.isdigit())
    return CWE_TO_STRIDE.get(digits, DEFAULT_STRIDE)


def parse_finding_md(path):
    """Parse a T3MP3ST finding markdown file into a report dict."""
    text = path.read_text(encoding="utf-8", errors="replace")
    finding = {"_source": str(path)}

    title_match = re.search(r"^#\s+(.+)", text, re.MULTILINE)
    if title_match:
        finding["title"] = title_match.group(1).strip()

    for field, patterns in {
        "severity": [r"\*\*Severity\*\*[:\s]*(\w+)", r"Severity[:\s]+(\w+)"],
        "cwe": [r"CWE[-:]?\s*(\d+)", r"\*\*CWE\*\*[:\s]*([\w-]+)"],
        "cve": [r"(CVE-\d{4}-\d+)"],
        "endpoint": [r"\*\*Endpoint\*\*[:\s]*(.+)", r"Endpoint[:\s]+(.+)"],
        "method": [r"\*\*Method\*\*[:\s]*(\w+)", r"Method[:\s]+(\w+)"],
    }.items():
        for pat in patterns:
            m = re.search(pat, text, re.IGNORECASE)
            if m:
                finding[field] = m.group(1).strip()
                break

    desc_match = re.search(
        r"(?:^##\s+Description|^##\s+Summary)\s*\n([\s\S]*?)(?=\n##\s|\Z)",
        text, re.MULTILINE
    )
    if desc_match:
        finding["description"] = desc_match.group(1).strip()

    impact_match = re.search(
        r"^##\s+Impact\s*\n([\s\S]*?)(?=\n##\s|\Z)", text, re.MULTILINE
    )
    if impact_match:
        finding["impact"] = impact_match.group(1).strip()

    remediation_match = re.search(
        r"^##\s+Remediation\s*\n([\s\S]*?)(?=\n##\s|\Z)", text, re.MULTILINE
    )
    if remediation_match:
        finding["remediation_steps"] = remediation_match.group(1).strip()

    if "id" not in finding:
        finding["id"] = path.stem

    return finding


def parse_finding_json(path):
    """Parse a JSON finding file."""
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        return data
    return None


def collect_findings(target_dir):
    """Collect findings from a T3MP3ST target directory."""
    findings = []
    findings_dir = target_dir / "findings"
    if findings_dir.is_dir():
        for f in sorted(findings_dir.iterdir()):
            if f.suffix == ".md":
                findings.append(parse_finding_md(f))
            elif f.suffix == ".json":
                parsed = parse_finding_json(f)
                if parsed:
                    findings.append(parsed)

    report_md = target_dir / "report.md"
    if report_md.exists() and not findings:
        text = report_md.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(
            r"^###?\s+((?:MVS|F|FINDING)-\d+[:\s].+?)$", text, re.MULTILINE
        ):
            findings.append({
                "id": m.group(1).split(":")[0].split()[0],
                "title": m.group(1),
            })

    return findings


def rule_id(report):
    cwe = report.get("cwe")
    if cwe:
        n = normalise_cwe(cwe)
        if n:
            return n
    cve = report.get("cve")
    if cve:
        return cve
    fid = report.get("id")
    if fid:
        return fid
    title = report.get("title", "finding")
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-") or "finding"
    return slug


def build_sarif(findings, tool_version=None):
    rules_by_id = {}
    rule_index = {}
    results = []

    for report in findings:
        rid = rule_id(report)
        if rid not in rules_by_id:
            rule_index[rid] = len(rules_by_id)
            sev = (report.get("severity") or "info").lower()
            stride_legs = stride_for_cwe(report.get("cwe"))
            tags = ["security"]
            if rid.startswith("CWE-"):
                tags.append(rid)
            for leg in stride_legs:
                tags.append(f"stride:{leg}")

            rules_by_id[rid] = {
                "id": rid,
                "name": report.get("title", rid),
                "shortDescription": {"text": report.get("title", rid)},
                "fullDescription": {
                    "text": report.get("description", report.get("title", rid))
                },
                "defaultConfiguration": {
                    "level": SEVERITY_TO_LEVEL.get(sev, "note")
                },
                "properties": {
                    "security-severity": SEVERITY_TO_SCORE.get(sev, "1.0"),
                    "tags": tags,
                },
            }
            if rid.startswith("CWE-"):
                cwe_num = rid.removeprefix("CWE-")
                rules_by_id[rid]["helpUri"] = (
                    f"https://cwe.mitre.org/data/definitions/{cwe_num}.html"
                )

        title = report.get("title", rid)
        desc = report.get("description", "")
        msg = f"{title}\n\n{desc}" if desc else title

        endpoint = report.get("endpoint", "")
        method = report.get("method", "")
        route = f"{method.upper()} {endpoint}".strip() if (method or endpoint) else ""

        fp_parts = [f"rule:{rid}"]
        if route:
            fp_parts.append(f"route:{route}")
        fp = hashlib.sha256("|".join(fp_parts).encode()).hexdigest() if fp_parts else None

        result = {
            "ruleId": rid,
            "ruleIndex": rule_index[rid],
            "level": SEVERITY_TO_LEVEL.get(
                (report.get("severity") or "info").lower(), "note"
            ),
            "message": {"text": msg},
        }

        if endpoint:
            result["locations"] = [
                {"logicalLocations": [
                    {"fullyQualifiedName": endpoint, "kind": "endpoint"}
                ]}
            ]

        if fp:
            result["partialFingerprints"] = {"primaryLocationLineHash": fp}

        props = {
            "security-severity": SEVERITY_TO_SCORE.get(
                (report.get("severity") or "info").lower(), "1.0"
            ),
        }
        t3 = {}
        for key in ("id", "severity", "cwe", "cve", "endpoint", "method",
                     "impact", "remediation_steps"):
            if report.get(key):
                t3[key] = report[key]
        if t3:
            props["t3mp3st"] = t3
        result["properties"] = props
        results.append(result)

    driver = {
        "name": TOOL_NAME,
        "informationUri": TOOL_URI,
        "rules": list(rules_by_id.values()),
    }
    if tool_version:
        driver["version"] = tool_version

    return {
        "version": SARIF_VERSION,
        "$schema": SARIF_SCHEMA,
        "runs": [{"tool": {"driver": driver}, "results": results}],
    }


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <target-dir>", file=sys.stderr)
        print("  e.g. python3 scripts/sarif-export.py .t3mp3st/api-sit.moviussit.net")
        sys.exit(1)

    target_dir = Path(sys.argv[1])
    if not target_dir.is_dir():
        print(f"Not a directory: {target_dir}", file=sys.stderr)
        sys.exit(1)

    findings = collect_findings(target_dir)
    if not findings:
        print(f"No findings in {target_dir}", file=sys.stderr)
        sys.exit(0)

    sarif = build_sarif(findings)
    out = target_dir / "findings.sarif"
    tmp = out.with_name(f"{out.name}.{os.getpid()}.tmp")
    try:
        with tmp.open("w", encoding="utf-8") as f:
            json.dump(sarif, f, ensure_ascii=False, indent=2)
            f.write("\n")
        tmp.replace(out)
    finally:
        tmp.unlink(missing_ok=True)

    print(f"SARIF 2.1.0: {out} ({len(findings)} findings)")


if __name__ == "__main__":
    main()
