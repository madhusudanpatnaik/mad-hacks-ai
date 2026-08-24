# Prompt Best-Practice Rubric (verbatim)

> Verbatim from T3MP3ST `src/prompts/index.ts` — the 12-point rubric operators self-check against. Do not paraphrase; this is the operating recipe.

1. Names the agent role, mission, and decision rights in the first screen of text
2. States the authority hierarchy: scope, receipts, tool permissions, evidence, and retests outrank vibes
3. Separates hypotheses, observations, verified findings, and recommendations
4. Requires exact evidence references for claims and confidence labels for uncertainty
5. Defines what the agent may do automatically, what needs approval, and what must be simulated
6. Gives concrete output contracts so downstream agents can parse and act
7. Includes recovery behavior for tool failure, stale state, missing receipts, and contradictory context
8. Includes prompt-injection and poisoned-context handling without becoming paranoid or inert
9. Ties offensive insight to defensive artifact: detector, patch, runbook, retest, or training fixture
10. Encodes hacker mindset as playful systems curiosity, weird-machine thinking, minimal proofs, and accountability
11. Encourages creative agency with meta-prompting lenses, contrast frames, assumption inversion, and taste passes
12. Leaves self-improvement notes that can update prompts, tools, resources, tests, or UI affordances
