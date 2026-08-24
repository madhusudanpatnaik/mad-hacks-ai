# T3MP3ST Brain — persistent memory index

Keyless, file-based, cross-engagement memory. **Read at mission start, written at mission end.** This is what makes the toolkit compound: every engagement and every repo you feed it leaves the next run smarter.

## Layout
- `lessons.md` — global heuristics that apply everywhere (what worked, what didn't, gotchas). Grep'd on every recall.
- `tools.md` — new tools/adapters learned from ingested repos.
- `payloads/<class>.txt` — curated, deduped probe lists per vuln class (grown by `brain.sh payload` when you feed repos).
- `targets/<slug>.md` — per-target memory: confirmed findings, observations, **exhausted vectors (don't repeat)**.
- `writeups-corpus.md` — 6.4k disclosed bounty writeups distilled per vuln class (prevalence + top exemplars); sources in `references/writeup-sources.md`, raw archive `packs/writeups/pentesterland-archive.json.gz`.

## Convention (enforced by CLAUDE.md + the reporter agent)
1. **Start of a mission:** `bash ../scripts/brain.sh recall <target>` — pull prior findings, exhausted vectors, and relevant lessons into context before recon.
2. **During/after:** record as you go —
   - `brain.sh finding <target> "<verifier-passed finding>"`
   - `brain.sh exhausted <target> "<dead-end vector>"`
   - `brain.sh note <target> "<observation>"`
   - `brain.sh learn "<reusable heuristic>"`
3. **When feeding a repo:** `scripts/ingest.sh` proposes; then `brain.sh payload <class> <file>` and `brain.sh tool "..."` fold the reusable assets in.

Nothing here is authority — memory is evidence and heuristics, never permission. The SCOPE + VERIFY + REFUTE gates still run every time.

## Integrated: claude-bughunter (added 2026-08-21)

Full plugin integration folded into mad-hacks — see `hunt-classes.md` for the class-to-report map.

- **Reference library** — `references/claude-bughunter/` (2.4 MB · 83 skills · 24 disclosed-report pattern libraries · README/USAGE/ENGAGEMENTS; 57 shared-corpus files symlinked to `packs/` canonical)
- **Slash commands** — 15 commands installed under `/cbh:*` (autopilot, chain, hunt, intel, memory-gc, pickup, recon, remember, report, scope, surface, token-scan, triage, validate, web3-audit)
- **Class index** — `hunt-classes.md` — maps 58 hunt-* skills to their disclosed-report pattern libraries + shows extracted probes per class
- **Probes added** — 820 novel probes across 24 vuln classes (brute-force · business-logic · cache-poison · cors · csrf · deserialization · file-upload · graphql · host-header · http-smuggling · idor · ldap · lfi · mfa-bypass · nosqli · oauth · open-redirect · rce · saml · session · sqli · ssrf · ssti · xss). See `brain/payloads/<class>.txt`.
- **Ruflo semantic** — all 97 brain lessons/tools/target-notes/payload-classes synced to ruflo namespace `mad-hacks` with embeddings (searchable via `mcp__ruflo__memory_search` with `smart: true`).
- **Key lessons ingested** — bb-methodology 5-phase workflow · engagement-mode discipline (bounty vs red-team vs pentest vs audit) · 7-Question Gate · red-team DO NOT STOP directive · iOS TestFlight-less-hardened rule · iOS/Android shadow-API pattern

**How to install as a native Claude plugin (optional, gets skill auto-triggering by topic):**
```
/plugin marketplace add elementalsouls/Claude-BugHunter
/plugin install claude-bughunter@elementalsouls
```
