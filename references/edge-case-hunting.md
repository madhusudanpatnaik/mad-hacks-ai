# Edge-Case Hunting — where rare bugs (and vulns) hide

> Methodology adapted from **workersio/skills (`wio`)** (MIT) — a defensive test-discovery skill — reframed for offensive vuln hunting. Edge cases that break software are the same inputs that break its security assumptions. Use with `code-audit.sh`, the fuzzing family, and the exploiter.

## The lens: bugs live at the boundaries
For any input/state/interface, systematically probe the boundary, not the happy path:
- **Empty / null / missing** — no value, null, `undefined`, empty string/array/object.
- **Boundary numbers** — 0, -1, MAX_INT, MIN_INT, off-by-one, overflow, float precision.
- **Size extremes** — 0-length, 1, huge (10^6), deeply nested, recursive.
- **Encoding** — unicode, emoji, RTL, homoglyphs, double-encoding, null bytes, mixed charset.
- **Type confusion** — string where int expected, array where scalar expected, object where string expected (feeds mass-assignment, NoSQLi, deserialization).
- **Concurrency / order** — same op twice, out-of-order, mid-flight state change (feeds race conditions, TOCTOU).
- **Trust boundary** — value crosses auth/tenant/privilege line unchanged (feeds IDOR, mass-assignment).

## Testing strategies → vuln-discovery uses
| Strategy (wio) | Offensive use |
|---|---|
| **Fuzz** | Malformed/random inputs to parsers, uploads, APIs → crashes, memory bugs, parser differentials. Tools: `radamsa`, `afl-fuzz`, `ffuf`. |
| **Property-based** | Define an invariant the target must never violate (e.g. "a user never sees another tenant's data"), generate inputs to break it → IDOR, authz bypass, logic flaws. |
| **Mutation** | Flip one field/byte/condition at a time, observe if the guard still holds → auth bypass, validation gaps, WAF blind spots. This is "one reversible probe at a time" formalized. |
| **Resilience** | Inject failure (timeout, dropped dep, partial write) → race windows, inconsistent state, fail-open auth. |
| **Contract / workload** | Replay realistic multi-step sequences → business-logic bugs, state-drift, coupon/payment abuse. |

## The review discipline (= our REFUTE gate)
`wio`'s `review` asks *"does this test provide genuine value?"* — the same question our verifier asks of a finding. Apply it: a probe that can't distinguish vulnerable from safe behavior proves nothing. Every edge-case probe must have a **falsifiable expected outcome** before you fire it.

## Workflow
1. Enumerate every input/state/boundary of the target surface (from recon + code-audit).
2. For each, pick the strategy above most likely to violate a security invariant.
3. Fire **one** mutation, capture evidence, then VERIFY → REFUTE.
4. Feed confirmed edge-case classes back into `brain.sh learn`.

**Not installed:** the full `wio` plugin (QA/test-suite tooling) is out of scope for offensive work — only this methodology is folded in.
