# tests/intelligence — regression + adversarial suite for the retrieval layer

**Why this exists (per the architecture audit):** *"RRF working ≠ retrieval working well."* This suite freezes measurable behavior so every future router/schema change can be compared numerically instead of "looks good on toy queries."

Every metric here is against `queries.jsonl` — 64 canonical queries spanning 5 attack categories, hand-labeled with expected classes.

---

## Run

```bash
bash tests/intelligence/run-all.sh
```

Individual suites:
```bash
python3 tests/intelligence/test_retrieval.py                        # aggregate MRR / R@5 / R@10 / P@5 / nDCG@10
python3 tests/intelligence/test_retrieval.py --category synonym     # per-category
python3 tests/intelligence/test_retrieval.py --json                  # machine-readable
python3 tests/intelligence/test_state.py --verbose                   # state adversarial (9 assertions)
python3 tests/intelligence/test_end_to_end.py --verbose              # full observe→recall→exhaust loop (12 assertions)
```

Exit `0` on pass, `1` on regression.

---

## Baseline (frozen at commit landing this suite — no FAISS, tight-fallback expansion)

| Config | MRR | R@5 | R@10 | P@5 | nDCG@10 |
|---|:---:|:---:|:---:|:---:|:---:|
| **FTS5 only** | 0.464 | 0.484 | 0.484 | 0.435 | 0.440 |
| **RRF lex+writeups+target** | 0.468 | 0.500 | 0.531 | 0.331 | 0.340 |
| RRF lex+sem+writeups+target | *(FAISS opt-in — not measured)* | | | | |

**Per-category MRR (RRF):**

| Category | MRR | R@10 | Notes |
|---|:---:|:---:|---|
| direct | 0.588 | 0.588 | strong — canonical vuln-class queries hit their agents/refs/payloads |
| synonym | 0.378 | 0.700 | expansion map rescues previously-impossible queries (BOLA, "server-side request forgery", etc.) |
| ambiguous | 0.357 | 0.500 | multi-class queries land at least one expected class |
| tech-cross | 0.750 | 0.750 | technology + class combos land accurately (WordPress+XSS, Next.js+RCE) |
| indirect | 0.100 | 0.100 | **known weakness — needs FAISS**. Queries describing symptoms ("backend fetches user URL" for SSRF) can't be reached lexically |

**Known trade-off (measured):** without the fallback expansion, RRF MRR was 0.367. With too-loose fallback (`<5 hits`), it dropped to 0.343. Zero-threshold fallback + tight OR pool (`K_RAW/3`) lifted it to 0.468. The suite caught and guided this trade-off — see `scripts/intelligence-recall.sh` `source_lex` for the rationale comments.

---

## Query corpus (`queries.jsonl`)

64 queries labeled `{id, query, expected_classes, expected_types, category, notes}`. Categories:

| Category | # | Purpose |
|---|:---:|---|
| direct | 30 | Canonical vocabulary — should hit trivially |
| synonym | 10 | Same concept, different phrasing (BOLA↔IDOR, SSRF↔"server-side request forgery") |
| indirect | 10 | Describes symptoms not vocabulary ("backend makes a request based on user URL") |
| ambiguous | 6 | Multi-class ("token confusion" — could be JWT or OAuth) |
| tech-cross | 4 | Technology + class combos |
| edge cases | 4 | punycode, PKCE downgrade, testssl, pastejacking |

Extend by appending JSONL rows. Re-run to measure.

---

## State adversarial (`test_state.py`)

9 assertions from the audit's `#5` (negative-knowledge granularity) and `#7` (state-as-filter):

- 4 epistemic statuses (`OBSERVED`/`DERIVED`/`INFERRED`/`HYPOTHESIS`) distinguishable in the ledger
- Scope preserved: `SSRF @ /api/import exhausted` does NOT poison `SSRF @ /api/avatar`
- Distinct variants persist as separate rows (no collapse)
- INFERRED evidence rows never upgrade to OBSERVED on re-read
- `--epistemic BOGUS` rejected
- `--confidence MAYBE` rejected
- Router's `target` source surfaces engagement-state files (state IS visible to fusion)

**Current: 9/9 passing.**

---

## End-to-end (`test_end_to_end.py`)

12 assertions walking the full loop: init → observe → recall (baseline) → hypothesis → tested → exhaust → recall (post-exhaust) → evidence add → new hypothesis → ruflo export. If any step regresses (state schema breaks, router loses source, ruflo export drops provenance), the test fails and blocks the commit.

**Current: 12/12 passing.**

---

## What this suite catches

| Regression | Test that fires |
|---|---|
| Router drops a source | test_end_to_end (baseline recall returns 0) |
| RRF fusion breaks | test_retrieval (MRR drops) |
| Query expansion floods top-K | test_retrieval per-category (direct MRR drops) |
| EXHAUSTED collapses different-scope entries | test_state (scope preservation) |
| Router forgets to consult state | test_end_to_end (target-source hits drop) |
| Evidence ledger silently upgrades epistemic status | test_state (no-upgrade) |
| Ruflo export drops provenance | test_end_to_end (last_verified missing) |

---

## What this suite does NOT catch (yet)

Per the audit's remaining points:

- **Hunt-efficiency measurement (#12)** — repeat-test rate, time-to-first-hypothesis. Requires real engagement runs. Suite provides the sensor (engagement-state.sh log); the metric emerges over sessions.
- **Next-best-action planner (#9)** — expected-value ranking of hypotheses. Doesn't exist yet; suite provides the baseline to compare a future planner against.
- **Behavioral compliance across all 19 hunters (#11)** — the preambles reference the router; whether every hunter actually calls it during a real run requires runtime probes (out of scope for a unit-test suite).
- **Registry relationship graph (`chains_with`, `depends_on`)** — future work.

These are the P3-D through P3-E items deferred from this commit per your "no large feature dump" directive.

---

## Extending the suite

- **Add a query:** append a JSONL row to `queries.jsonl`, re-run.
- **Add a state assertion:** add a `test_*` method to `Test` class in `test_state.py`; wire it into `run_all()`.
- **Add an end-to-end step:** append to `run()` in `test_end_to_end.py`; add matching `assert_(name, cond)` calls.
- **Track over time:** the aggregate table above is a snapshot — copy it into commit messages when routing changes, so regression/improvement is legible in git history.
