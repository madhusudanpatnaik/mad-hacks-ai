# packs/UPSTREAM.md — provenance for externally-cloned packs

Some entries under `packs/` are **shallow clones of external repos**, kept for on-demand reference. They carry their own `.git` directory, are **gitignored in this repo**, and are re-hydrated on demand via `scripts/reinstall-packs.sh`.

## Externally-cloned packs (gitignored — re-hydrate to use)

| Pack | Upstream | Commit at ingest | Ingested | License |
|---|---|---|---|---|
| `packs/xalgorix/` | https://github.com/xalgorix/xalgorix | `98d18a458cb1cc4681cdd9fb8ef726f14167ddcb` | 2026-08-25 | Apache-2.0 |
| `packs/dalfox/` | https://github.com/hahwul/dalfox | `7bb684fdf48959d10c6a6ac24d4a190361c58c8f` (v3.2.2) | 2026-09-01 | MIT |
| `packs/rifteo-skills/` | https://github.com/Rifteo/skills | `c62366221cb3f448495c374eff376549e4bfa107` | 2026-09-02 | MIT |

To re-hydrate:
```bash
bash scripts/reinstall-packs.sh
```

`references/` docs that depend on these packs (`xalgorix-methodology.md`, `dalfox-guide.md`, `rifteo-skills-catalog.md`, `deadangle.md`, `engagement-handoff.md`) reference `packs/<pack>/SKILL.md` paths — they will fail their load-on-demand step until the pack is re-hydrated.

## Tracked packs (committed to this repo as regular files)

`packs/writeups/` · `packs/cyberstrike/` · `packs/strix/` · `packs/claude-bughunter/` · `packs/ai-pentesting/` · `packs/payloads-all-the-things/` · `packs/lostfuzzer/` · `packs/t3mp3st/` · `packs/writeups/pentesterland-archive.json.gz` — these are content packs (methodology docs, disclosed reports, payload archives). They live inside this repo's git history.

The distinction: **externally-cloned packs** are code + tool trees maintained by third parties (large, evolving, own release cadence). **Tracked packs** are curated content extracts.
