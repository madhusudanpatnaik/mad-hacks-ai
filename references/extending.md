# Extending the toolkit — fold in new repos & payloads

The toolkit is designed to grow. When you get a new repo (tools, prompts, methodology) or a payload set, absorb the *reusable assets* — don't bolt on a second framework.

## Process
1. **Scan it:** `bash scripts/ingest.sh <repo-or-file>` → prints a classified merge plan (read-only).
2. **Route each asset to its home:**
   | Asset in the repo | Where it goes in the toolkit |
   |---|---|
   | Operator/agent system prompt | new `~/.claude/agents/t3-<name>.md` (verbatim prompt) |
   | Payloads / probe lists | `references/payloads.md`, deduped + class-tagged |
   | A CLI tool / binary | adapter row in `references/arsenal.md` (binary, risk, execution mode, commandHint) |
   | A wrapper script | `scripts/` (keyless, evidence to `.t3mp3st/`) |
   | nuclei/semgrep/yara rules | reference from arsenal usage; custom rules → `rules/` (create on first use) |
   | Methodology / playbook | matching family in `references/mission-families.md` or a new runbook |
3. **Curate, don't dump.** Add novel, high-signal items only. A 100k-line wordlist is a file to point `ffuf -w` at, not something to inline.
4. **Preserve the invariants.** New material is *evidence-tooling*, never new authority. The doctrine, the SCOPE gate, and the VERIFY→REFUTE gates always apply — a payload working is not permission.
5. **Re-tag execution mode.** Any new active/intrusive tool defaults to `receipt_required`; anything that runs code on a live process is `catalog_only` (operator-only).

## Naming conventions
- Subagents: `t3-<role>` (e.g. `t3-graphql`, `t3-cloud`).
- New family scripts: `<domain>-audit.sh` / `<domain>-scan.sh`, mirroring `web-scan.sh` / `code-audit.sh`.
- Keep evidence layout identical: `./.t3mp3st/<target>/{recon,weaponize,evidence,findings}/`.

This keeps every future addition composable with the same orchestrator, doctrine, and report pipeline.
