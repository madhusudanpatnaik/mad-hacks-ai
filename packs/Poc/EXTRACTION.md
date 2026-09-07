# EXTRACTION — `Poc`

- **Upstream:** `https://github.com/shadowsock5/Poc` @ `b6e7ec272fa6f4bc93918b4d7ba7d83ce8940eaa`
- **First mined:** initial clone; normalized 2026-09-08

## Rationale — why this pack is in the harness

Chinese-language security vulnerability library aggregator — indexes CMS-focused PoCs (ActiveMQ, Java security, Chinese enterprise apps) and cross-links major Chinese vuln databases (baizesec/bylibrary, EdgeSecurityTeam, pen4uin, tenable/poc, ptresearch/AttackDetection, r0eXpeR/supplier). Useful when hunting a Chinese enterprise stack or an obscure CMS with limited English writeups.

## Extracted lessons

| Brain record | Class | Title | Source |
|---|---|---|---|
| `brain/lessons.jsonl:L-poc-01` | `vuln-research` | Poc is a Chinese-language CMS/PoC aggregator — check for stacks with weak English coverage | `packs/Poc/README.md` |

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-poc-01` | `vuln-research` | Target is Chinese-language stack OR obscure CMS with no English writeup → grep `packs/Poc/` and follow the linked upstream sources for PoCs |

## Extracted tools

None. Pack is a link index + reference collection, not a runtime tool.

## Extracted payloads

None. PoCs are per-target scripts across many upstream sources, not general payload sets.

## Router integration

- `references/router.md` — vuln-research row / on-demand for Chinese-stack targets

## Notes / next re-mining

- Upstream is a curated index — refresh quarterly. If the Chinese-security ecosystem shifts platforms (Baidu Cloud, WeChat mini-programs, DingTalk), watch for new sections.
