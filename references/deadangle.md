# deadangle — Verified / Inferred / Assumed discipline

**Adapted from Rifteo's `deadangle` skill** ([full source](../packs/rifteo-skills/deadangle/SKILL.md), MIT © 2026 Rifteo). This is a **doctrine extension** for mad-hacks: it strengthens the binary CONFIRMED/REFUTED verdict emitted by `t3-verifier` (see `agents/t3-verifier.md`) into the ternary the evidence actually supports.

## The rule

Before delivering **any** conclusion — a finding, an attack chain, a severity call, a coverage summary — pass it through this filter:

> **"What would destroy this conclusion if I was wrong?"**

If you don't have a concrete answer, the conclusion is at most *inferred* or *assumed*, not *verified*. Ship it with the right label.

## The three labels

| Label | Meaning | Language you're allowed to use |
|---|---|---|
| **Verified** | Directly observed or tested. You have the artifact — captured output, replayed request, code execution result. | *"is vulnerable"*, *"I confirmed"*, *"executed"*, *"reproduced"* |
| **Inferred** | Logical conclusion from evidence, but you didn't trigger it end-to-end. The signals are present but the exploit wasn't fired to impact. | *"likely vulnerable"*, *"probably reachable"*, *"consistent with"*, *"the evidence suggests"* |
| **Assumed** | Taken for granted without observation. A default behavior, framework convention, or reasonable expectation you never checked. | *"assumes"*, *"if this behaves as documented"*, *"typically"*, *"unless configured otherwise"* |

**Assumed elements MUST be surfaced before the conclusion is delivered.** Presenting assumed reasoning with the language of verified fact is exactly what this discipline exists to prevent.

## Match depth to stakes

- A single well-scoped finding → one honest label + any assumption that matters. **Don't run the heavy framework on a light question — bloat is itself a failure this discipline exists to prevent.**
- A full report, a multi-step attack chain, or a severity call across many findings → run every position-shift pass.

## Selective assumption audit

Not everything in your reasoning needs to be questioned. Direct observations are facts — treat them as facts. This audit targets only:

- Conclusions drawn from **indirect signals** rather than direct observation
- Anything where **two interpretations were plausible** and you chose one without testing the other
- **Chain dependencies** that have not been directly verified
- Reasoning where you used *"probably"*, *"likely"*, *"should be"*, *"typically"* without checking

## Position shift — re-examine from adversarial angles

After producing output, move off your current position and re-examine:

- **The adversary of your adversary** — if a defender was actively monitoring, would this conclusion survive? Does it hold against a patched, alert, monitored environment, or only against a passive one?
- **The senior operator** — someone more experienced reviews your output not looking to confirm it, but looking for what you oversimplified, concluded too fast, or missed entirely. What do they find?
- **The triager who has seen this bug 100 times** — do they see a real finding, or a common false positive dressed up in real language?
- **The developer who wrote the code** — is there a defensive layer you didn't check that would make this impossible?

Full framework (positions, questions, examples): `packs/rifteo-skills/deadangle/SKILL.md`.

## Wiring into the mad-hacks loop

### 1. t3-verifier verdict card gets a third field

The existing visible verdict card at [`agents/t3-verifier.md`](../agents/t3-verifier.md) § "Layer 2" ships CONFIRMED / DOWNGRADED / REFUTED / NEEDS-MORE-EVIDENCE. Extend the card with a **label breakdown** for the finding's key claims:

```
   Label breakdown:
     • <claim 1>  → Verified   (artifact: evidence/EV-3.txt line 42)
     • <claim 2>  → Inferred   (signal present; end-to-end not triggered)
     • <claim 3>  → Assumed    (default framework behavior; not tested here)
```

A CONFIRMED verdict whose claims are majority-Inferred/Assumed is grounds for DOWNGRADED-to-NEEDS-MORE-EVIDENCE.

### 2. CDC harness verdicts pull the same discipline

`workflows/cdc-verify.js` verifiers already default to DISPROVED. Add a rule: any verdict where `oracle_grounded=false` AND the underlying claims are labeled Inferred/Assumed → auto-downgrade to `INCONCLUSIVE`.

### 3. Report shipping gate

`scripts/report.sh build` should refuse to ship a finding whose claims are majority-Assumed without an explicit operator override. (Not enforced yet — future hardening task.)

## Trigger words (when to invoke this discipline explicitly)

- Before delivering a finding/vulnerability conclusion/attack path
- After completing recon and summarizing coverage
- Before presenting a multi-step attack chain
- Before assigning severity/impact/confidence
- Before using language like *"this is vulnerable"* or *"I confirmed"*
- When the operator types `/deadangle` or says "deadangle" or "check that conclusion"

## What deadangle is NOT

- It is not hesitation. A hesitant operator doubts without structure. A precise operator knows exactly what was verified and what was not, and labels accordingly.
- It is not a redo pass. It re-labels what you already produced; it doesn't repeat the work.
- It is not universal skepticism. Direct observations are facts — this discipline audits only the uncertain parts.

## Attribution

Full methodology by Rifteo, MIT. Full source: [`packs/rifteo-skills/deadangle/SKILL.md`](../packs/rifteo-skills/deadangle/SKILL.md). Master question and label taxonomy quoted with attribution.
