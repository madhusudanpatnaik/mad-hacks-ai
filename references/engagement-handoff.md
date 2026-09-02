# engagement-handoff — save session state so the next agent continues without asking

**Adapted from Rifteo's `engagement-handoff` skill** ([full source](../packs/rifteo-skills/engagement-handoff/SKILL.md), MIT © 2026 Rifteo). This gives mad-hacks a save-state pattern we lacked — a compact `HANDOFF.md` written at end-of-session so the next agent (fresh context, no memory of the current one) can pick up without interrogation.

## When to write a handoff

- Operator says: *"handoff"*, *"save progress"*, *"pick this up next session"*, *"summarize the engagement"*, *"end of day"*, *"shift change"*
- Context window is getting long and you want to continue in a fresh session
- At the end of a testing day
- Before switching operators mid-engagement

## When NOT to write a handoff

- User asked a general methodology question (not an active engagement)
- No engagement content exists yet (no findings, no coverage, no threads)
- User wants a **final** deliverable — that's `report.sh build-all` (`t3-reporter`), not a handoff

## The template

Write to `./.t3mp3st/<target>/HANDOFF.md`. Under 100 lines. Reference existing artifacts (`SCOPE.md`, `findings/F-*.md`, `evidence/EV-*.txt`, `.cdc/<target>/*.md`) instead of duplicating them.

```markdown
# Handoff — <target>

**Session date:** <YYYY-MM-DD>
**Mode:** bug-bounty | pentest | research | ctf
**Continue from:** see .t3mp3st/<target>/SCOPE.md for scope + target details.
                   see .cdc/<target>/GOAL.md + DEPLOYMENT.md if CDC harness in use.

## Findings so far
- F-001 <title> — severity — status: CONFIRMED / DOWNGRADED / OPEN / NEEDS-MORE
- F-002 <title> — …
_(details in findings/F-*.md — do NOT rewrite here)_

## Coverage
**Tested:**
- <endpoint / component / class> — <how deep / what payloads / what result>

**Skipped:**
- <endpoint / component / class> — <why: out-of-scope / low priority / no time>

**Partially tested:**
- <endpoint / component / class> — <what's left: which payloads not tried, which auth roles not tested>

## Open threads (suspected but not confirmed)
- <thread 1> — evidence so far, what's blocking confirmation
- <thread 2> — …

## Next steps (ordered — first thing next session does)
1. <specific action, specific command>
2. <specific action>
3. …

## Doctrine reminders for the next agent
- <target-specific gotcha discovered this session>
- <e.g. "target's WAF blocks 'alert' but not 'prompt' — jump to Tier 2 first">
- <e.g. "OOB callbacks land ~30s late on this host — extend --wait">
```

## Rules

- **Under 100 lines.** If it's longer, you're duplicating instead of referencing. Cut ruthlessly.
- **No credentials, tokens, PII, or raw sensitive evidence** in the handoff file. Redact aggressively — the next session may not have the same trust level.
- **Next steps must be specific enough that the next agent can start without any additional context.** No "continue testing" — write the exact command.
- **If `SCOPE.md` exists**, open with: *"Continue from: see SCOPE.md for scope and target details."*
- **If a CDC run is in progress**, open with: *"CDC run active — see .cdc/<target>/GOAL.md, DEPLOYMENT.md, PRIMITIVES.md, CHAIN.md."*

## Wiring

- No new script — the handoff is a markdown file the operator writes at end-of-session.
- `t3-reporter` should NOT write a handoff (it writes the final report).
- Every mad-hacks command (`/mad-hunt`, `/cdc-research`, `/mad-hacks`) can be asked "handoff" at any point — the operator writes to `HANDOFF.md` following this template.
- At the start of a fresh session on the same target, the operator's first action is:
  ```bash
  cat ./.t3mp3st/<target>/HANDOFF.md
  bash ~/.claude/skills/mad-hacks/scripts/brain.sh recall <target>
  ```

## Attribution

Full methodology by Rifteo, MIT. Full source: [`packs/rifteo-skills/engagement-handoff/SKILL.md`](../packs/rifteo-skills/engagement-handoff/SKILL.md).
