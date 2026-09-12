# EXTRACTION — `rifteo-skills`

- **Upstream:** `https://github.com/Rifteo/skills` @ `c62366221cb3f448495c374eff376549e4bfa107` (MIT)
- **First mined:** initial clone (undated); normalized to JSONL 2026-09-08
- **Extractor:** shallow-pack raise-the-floor pass

## Rationale — why this pack is in the harness

Peer methodology library — 38 skills covering the same domain as mad-hacks. Instead of rewriting what Rifteo already wrote well, we keep the corpus verbatim in `packs/rifteo-skills/` and load specific skills on-demand for capabilities we don't natively have (Active Directory, APK static analysis, clickjacking, HPP, dedicated JWT cracker, nuclei template writer, CVE exploit lookup, CVSS scoring). Full mapping in `references/rifteo-skills-catalog.md`. Not adopted: their npm CLI (`@rifteo/skills`) — mad-hacks is keyless.

## Extracted lessons

| Brain record | Class | Title | Source |
|---|---|---|---|
| `brain/lessons.jsonl:L-rft-01` | `workflow` | rifteo-skills is a peer methodology library — 38 skills, load-on-demand | `references/rifteo-skills-catalog.md` |

## Extracted patterns

| ID | Class | Precondition → Action |
|---|---|---|
| `PAT-rft-01` | `workflow` | Mission needs a capability mad-hacks doesn't cover → look up in `references/rifteo-skills-catalog.md`, load `packs/rifteo-skills/<skill>/SKILL.md` on-demand as T3 reference |

## Extracted tools

None. Rifteo skills are methodology docs, not runtime tools.

## Extracted payloads

None. Rifteo does not ship payload archives — its skills reference external payload sets (which we cover separately via `brain/payloads/`).

## GAP-filler skills (per catalog)

Load from `packs/rifteo-skills/<name>/SKILL.md` on demand:

- `ad-breach` — Active Directory attack (Kerberoasting, ACL abuse, DCSync, AD CS ESC1-ESC8, NTLM relay, BloodHound)
- `droid-recon` — Android APK static analysis (apktool + jadx + MASVS mapping)
- `clickjacking-hunter` — Frame protection detection, JS frame-busting bypass, OAuth consent variants
- `hpp-hunter` — HTTP Parameter Pollution (server/client, WAF bypass, OAuth/payment abuse)
- `jwt-cracker` — Dedicated JWT attacks (alg:none, RS256→HS256, weak-secret brute, kid/jku/jwk injection)
- `nuclei-template-writer` — Generate nuclei templates from a finding or HTTP req/resp pair
- `check-exploit` — CVE exploitability lookup (searchsploit / Vulners / MSF / weaponized exploit refs)
- `cvss-scorer` — CVSS v3.1 scoring with metric inference from context

## Router integration

- `references/router.md` — 8 rows point at `packs/rifteo-skills/<skill>/` for on-demand loading
- `references/rifteo-skills-catalog.md` — the full mapping doc (mad-hacks-native ↔ Rifteo overlap or GAP)

## Notes / next re-mining

- Rifteo publishes new skills regularly via npm. Re-mine quarterly — if new skills land that fill mad-hacks GAPs, add them to the catalog and add a load-on-demand pattern if the skill is common enough to warrant one.
- Do NOT copy Rifteo content into brain/ — the pack IS the source of truth; brain only records that the pack exists + how to load its skills.
