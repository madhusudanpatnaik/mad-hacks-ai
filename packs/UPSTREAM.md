# packs/UPSTREAM.md — provenance for externally-cloned packs

Some entries under `packs/` are **shallow clones of external repos**, kept for on-demand reference. They carry their own `.git` directory, are **gitignored in this repo**, and are re-hydrated on demand via `scripts/reinstall-packs.sh`.

## Externally-cloned packs (gitignored — re-hydrate to use)

| Pack | Upstream | Commit at ingest | Ingested | License |
|---|---|---|---|---|
| `packs/xalgorix/` | https://github.com/xalgorix/xalgorix | `98d18a458cb1cc4681cdd9fb8ef726f14167ddcb` | 2026-08-25 | Apache-2.0 |
| `packs/dalfox/` | https://github.com/hahwul/dalfox | `7bb684fdf48959d10c6a6ac24d4a190361c58c8f` (v3.2.2) | 2026-09-01 | MIT |
| `packs/rifteo-skills/` | https://github.com/Rifteo/skills | `c62366221cb3f448495c374eff376549e4bfa107` | 2026-09-02 | MIT |
| `packs/secrets-patterns-db/` | https://github.com/mazen160/secrets-patterns-db | `24984df1a3f78475132ed183cebce4452b601161` | 2026-11-04 | (see upstream LICENSE) |
| `packs/exploitarium/` | https://github.com/bikini/exploitarium | `cdcbe772ed7ee2a36f2d84a93018f820a32a4a9f` | 2026-11-04 | (see upstream LICENSE) |
| `packs/CloudRip/` | https://github.com/moscovium-mc/CloudRip | `5bd7d54a6976e86bcb5a816886b2b8432a81967c` | 2026-11-04 | MIT |
| `packs/Poc/` | https://github.com/shadowsock5/Poc | `b6e7ec272fa6f4bc93918b4d7ba7d83ce8940eaa` | 2026-11-04 | (see upstream LICENSE) |
| `packs/Awesome-Bugbounty-Writeups/` | https://github.com/devanshbatham/Awesome-Bugbounty-Writeups | `72010067cd49196f8f45b9137d1c0d06ad5ba915` | 2026-09-05 | (see upstream LICENSE) |
| `packs/vulnerability-research/` | https://github.com/skraft9/vulnerability-research | `e5a0a9ea4be91f765b10027ad4b690ce9c063d89` | 2026-09-05 | (see upstream LICENSE) |
| `packs/AILA/` | https://github.com/project-lambda-zero/AILA | `ae50589ff301b23ab501594737d47cf775ca694a` | 2026-09-05 | (see upstream LICENSE) |

To re-hydrate:
```bash
bash scripts/reinstall-packs.sh
```

`references/` docs that depend on these packs (`xalgorix-methodology.md`, `dalfox-guide.md`, `rifteo-skills-catalog.md`, `deadangle.md`, `engagement-handoff.md`) reference `packs/<pack>/SKILL.md` paths — they will fail their load-on-demand step until the pack is re-hydrated.

## Tracked packs (committed to this repo as regular files)

`packs/writeups/` · `packs/cyberstrike/` · `packs/strix/` · `packs/claude-bughunter/` · `packs/ai-pentesting/` · `packs/payloads-all-the-things/` · `packs/lostfuzzer/` · `packs/t3mp3st/` · `packs/writeups/pentesterland-archive.json.gz` — these are content packs (methodology docs, disclosed reports, payload archives). They live inside this repo's git history.

The distinction: **externally-cloned packs** are code + tool trees maintained by third parties (large, evolving, own release cadence). **Tracked packs** are curated content extracts.
| `packs/ai-pentesting/` | https://github.com/Mr-Infect/AI-penetration-testing | `5b623516eccfec694978fd559dd01269192412f7` | 2026-09-08 | (see upstream LICENSE) |
| `packs/strix/` | https://github.com/usestrix/strix | `52b19233477a783004467c1522651eec96015e73` | 2026-09-08 | Apache-2.0 |
| `packs/payloads-all-the-things/` | https://github.com/swisskyrepo/PayloadsAllTheThings | `3ac27901c711bdf3f5b65a7b1d1820a1f65bd09a` | 2026-09-08 | MIT |
| `packs/reverse-skill/` | https://github.com/zhaoxuya520/reverse-skill | `7e2097fd90d25c2f976f6eba26d6c00aa88051df` | 2026-09-08 | MIT |
| `packs/camofox-browser/` | https://github.com/jo-inc/camofox-browser | `e5a36f5cd0332fde6597de474329a308a53a0716` | 2026-09-08 | MIT |
| `packs/OmniRoute/` | https://github.com/diegosouzapw/OmniRoute | `ba597b631d22d85e56db6982f24b7d1ebe238df9` | 2026-09-09 | MIT |
