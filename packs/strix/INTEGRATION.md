# Strix x T3MP3ST Integration Map

Source: https://github.com/usestrix/strix (Apache-2.0)
Author: UseStrix | Ingested: 2026-08-23
Assets: 9 consumer skills, 70+ internal knowledge packs, SARIF exporter, dedup engine, API spec parser

## What Strix Adds to T3MP3ST

| Capability | Where it landed | Status |
|-----------|----------------|--------|
| **SARIF 2.1.0 output** | `scripts/sarif-export.py` | Standalone, keyless |
| **CWE→STRIDE mapping** (60+ entries) | `references/stride-mapping.md` | New reference |
| **Technology-stack playbooks** (12 stacks) | `references/tech-stack-playbooks.md` | New reference |
| **Finding deduplication methodology** | `references/dedup-methodology.md` | New reference |
| **Scan mode strategies** (quick/standard/deep) | `references/scan-modes.md` | New reference |
| **Tool usage guides** (12 tools) | `references/tool-guides.md` | New reference |
| **9 consumer skills** | `~/.claude/skills/strix-*` | Installed |
| **70+ internal knowledge packs** | `packs/strix/skills-internal/` | Archived |
| **Source modules** (SARIF, dedup, API spec, context budget) | `packs/strix/source-modules/` | Archived |

## T3MP3ST Pipeline x Strix Mapping

| T3MP3ST Phase | Strix Enhancement |
|---|---|
| **CLASSIFY** | Tech-stack router (tech-stack-playbooks.md) identifies target technology and loads per-stack playbook |
| **SCOPE** | API spec detection: OpenAPI/Swagger/Postman spec → scoped endpoint list (concepts from api_spec.py) |
| **RECON** | Asset discovery + infrastructure lifecycle skills (packs/strix/skills-internal/reconnaissance/) |
| **WEAPONIZE** | 27 vuln-class skills + 4 framework skills + 7 technology skills + 4 cloud skills + scan mode strategy |
| **EXPLOIT** | Per-technology test checklists from tech-stack-playbooks.md |
| **VERIFY/REFUTE** | Dedup gate (dedup-methodology.md) prevents duplicate findings from entering report |
| **REPORT** | SARIF 2.1.0 export (sarif-export.py) + STRIDE tagging (stride-mapping.md) |
| **REFLECT** | Scan mode calibration (scan-modes.md) — adjust depth for next iteration |

## Internal Knowledge Packs (70+ files archived)

### Vulnerabilities (27 skills)
agentic_system_security | argument_injection | authentication_jwt | broken_function_level_authorization
browser_security | business_logic | csrf | header_injection | http_request_smuggling
idor | information_disclosure | insecure_deserialization | insecure_file_uploads
llm_prompt_injection | mass_assignment | nosql_injection | open_redirect
path_traversal_lfi_rfi | prototype_pollution | race_conditions | rce
semantic_confusion | sql_injection | ssrf | ssti | subdomain_takeover
weak_password_detection | xss | xxe

### Technologies (7 skills)
active_directory | auth0 | electron_desktop_apps | firebase
grafana_prometheus | llm_applications | supabase

### Frameworks (4 skills)
django | fastapi | nestjs | nextjs

### Cloud (4 skills)
aws | azure | gcp | kubernetes

### Protocols (2 skills)
graphql | oauth

### Tooling (12 guides)
agent_browser | ffuf | httpx | hurl | hypothesis | katana
naabu | nmap | nuclei | python | semgrep | sqlmap | subfinder

### Scan Modes (3 strategies)
deep | quick | standard

### Reconnaissance (2 skills)
asset_discovery | infrastructure_lifecycle

### Custom (4 skills)
api_spec_testing | dependency_cve_scanning | npx_confusion | source_aware_sast

### Coordination (2 skills)
root_agent | source_aware_whitebox

## Consumer Skills (9, installed as strix-*)

| Skill | Purpose |
|-------|---------|
| `strix-penetration-testing-with-strix` | Run headless pentest, read results |
| `strix-managed-pentesting-with-strix` | Drive app.strix.ai platform via REST |
| `strix-fix-security-vulnerabilities-with-strix` | Remediate + re-scan to verify |
| `strix-ci-security-scanning-with-strix` | PR scanning in CI |
| `strix-application-security-testing` | Whole-product AppSec review |
| `strix-web-app-penetration-testing` | Black-box pentest of live web app |
| `strix-api-security-testing` | REST/GraphQL API security |
| `strix-owasp-top-10-testing` | Systematic OWASP Top 10 assessment |
| `strix-find-security-vulnerabilities-in-code` | White-box source code review |

## How to Use

### From T3MP3ST (primary)
The kill chain runs as before. Strix's knowledge packs auto-load by technology/framework when detected during RECON. The `t3-*` subagents remain the orchestrator.

### New gates added to pipeline
1. **Tech-stack routing** (CLASSIFY): when RECON detects a technology, load references/tech-stack-playbooks.md
2. **Dedup gate** (VERIFY): before confirming, check against existing findings per references/dedup-methodology.md
3. **STRIDE tagging** (REPORT): tag every finding with STRIDE leg(s) per references/stride-mapping.md
4. **SARIF export** (REPORT): `python3 scripts/sarif-export.py .t3mp3st/<target>`
5. **Scan mode** (ALL): calibrate depth per references/scan-modes.md

### Direct Strix CLI (when Docker + LLM key available)
```bash
export STRIX_LLM="anthropic/claude-sonnet-4-20250514"
export LLM_API_KEY="$ANTHROPIC_API_KEY"
strix -n --target ./app --scan-mode quick
```

### Brain Integration
Strix lessons, tools, and methodology are recorded in T3MP3ST brain:
- `brain.sh recall` pulls Strix-sourced lessons alongside T3MP3ST's own
- 6 new methodology lessons: dedup gate, STRIDE tagging, tech-stack routing, SARIF output, scan mode selection, SSRF methodology merger
- 5 new references added to the skill reference tree

## Source Attribution
Strix (Apache-2.0, github.com/usestrix/strix). Full repo cloned at /tmp/strix.
Internal skills and source modules archived in packs/strix/ for reference.
