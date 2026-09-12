# EXTRACTION — `reverse-skill`

- **Upstream:** `https://github.com/zhaoxuya520/reverse-skill` (MIT; upstream URL to be pinned in UPSTREAM.md at next housekeeping pass)
- **First mined:** initial clone; normalized 2026-09-08

## Rationale — why this pack is in the harness

Chinese cybersecurity skills router — 43 technique docs under `techniques/` covering AD (Kerberos delegation, AD certificate abuse, DPAPI credential chain), cloud (metadata paths, agent-cloud, K8s control plane), mobile (Android/iOS runtime hooking, crypto-mobile), containers (runtime escape, kernel escape), forensics (timeline, source-map recovery from bundles), and cross-cutting primitives (JWT claim confusion, GraphQL-RPC drift, custom protocol replay, file parser chain). Complements Rifteo's methodology library with more depth on Chinese-ecosystem-specific techniques (WeChat, Baidu Cloud, Chinese enterprise AD).

## Extracted lessons

| Brain record | Class | Title | Source |
|---|---|---|---|
| `brain/lessons.jsonl:L-rs-01` | `workflow` | reverse-skill has 43 categorized technique docs — load specific one on demand | `packs/reverse-skill/README.md` + `packs/reverse-skill/techniques/` |

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-rs-01` | `workflow` | Mission needs a technique-specific playbook (AD attack chain, cloud metadata path, container escape, mobile hooking, K8s control plane, etc.) → `ls packs/reverse-skill/techniques/` and load the matching `.md` on demand |

## Extracted tools

None. Techniques are methodology docs, not runtime tools.

## Extracted payloads

None. Techniques reference external tools + payloads that live elsewhere (BloodHound, apktool, jadx, etc. — some covered via Rifteo's gap-fillers, some are standard offensive tooling).

## Router integration

- `references/router.md` — technique-lookup / on-demand row (implicit)

## Notes / next re-mining

- Upstream SHA needs pinning in `packs/UPSTREAM.md` — currently untracked. Add at next housekeeping pass.
- Overlap with Rifteo's `ad-breach`, `droid-recon`, `container escape` skills — reverse-skill covers similar ground with more Chinese-ecosystem angles. Cross-load when the target's stack matches.
