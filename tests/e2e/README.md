# tests/e2e — operator-integration regression suite

Distinct from `tests/intelligence/` (retrieval-layer measurement). This suite exercises the actual `/mad-hunt` **organism** at the pipeline level. Per the operator-integration audit:

> Your system is now stronger as an intelligence/retrieval subsystem than as a complete security operator. The brain/router architecture is becoming quite good — but the thing users actually care about is: "Give it an authorized target and does it reliably execute the security workflow without skipping, hallucinating, leaking scope, losing evidence, or depending on my personal machine state?" You haven't proven that yet.

This suite proves it. **365 assertions across 3 suites**, runs in ~60 seconds.

---

## Run

```bash
bash tests/e2e/run-all.sh
```

Individual:
```bash
python3 tests/e2e/test_scope_boundary.py --verbose     # 45  scope gate
python3 tests/e2e/test_agent_portability.py --verbose  # 255 fresh-machine reproducibility
python3 tests/e2e/test_engagement_e2e.py --verbose     # 65  full pipeline chain
```

Exit `0` on all-green, `1` on any failure.

---

## What each suite proves

### `test_scope_boundary.py` — 45 assertions

The authorization gate treated as a **security boundary**, per audit priority #2. Two layers:

**Layer A — matcher correctness (`scope.py`)** — 14 adversarial variants:

| Attack | Assertion |
|---|---|
| Suffix confusion (`notexample.com` when `example.com` is scope) | Rejected |
| Prefix confusion (`example.com.evil.com`) | Rejected |
| Lookalike (`exanple.com`) | Rejected |
| Sibling TLD (`example.org`) | Rejected |
| IP outside CIDR | Rejected |
| URL with credentials (`user:pass@in-scope`) | Correct host classified |
| Creds-injection (`in-scope@evil.com`) | Rejected (real host = evil.com) |
| Alt-port (`:8443`, `:80`) | Port-agnostic classification |
| IPv6 (`[::1]`) | Rejected (no matching pattern) |
| IPv6-mapped IPv4 (`[::ffff:10.0.0.1]`) | Rejected (IPv4 CIDR doesn't match) |
| Trailing-dot (`example.com.`) | Normalized, correct |
| Mixed-case (`ExAmPlE.CoM`) | Case-normalized, correct |
| IDN/punycode (`xn--e1afmkfd.com`) | Rejected (no pattern matches) |
| Wildcard-only (`*.foo.com` doesn't match bare `foo.com`) | Correct depth |
| Deny-wins (explicit exclusion beats in-scope apex rule) | Rejected |
| Junk input (empty, `///`, malformed) | Rejected, no crash |

Plus 9 baseline matcher-correctness assertions (apex, subdomain, wildcard depth, CIDR, regex).

**Layer B — fail-closed side-effect invariant** — 6 assertions:

The critical invariant per audit #2: **OUT_OF_SCOPE ⇒ NO state mutation**.

- `engagement-state.sh init --scope-check <SCOPE.md>` refuses OUT-OF-SCOPE targets (exit 4)
- Refusal does NOT touch `.engagement/<slug>/` filesystem
- stderr names the scope file that rejected
- Positive path: in-scope target initializes state cleanly
- Discoverable `.t3mp3st/SCOPE.md` at CWD auto-gates without explicit flag
- `--no-scope-check` escape hatch works for test fixtures + intentional off-scope research
- `scope.py --selftest` passes (canonical matcher acceptance test)
- Documented behavior: `scope.sh check` uses `grep -qiF` (substring-vulnerable) — human helper only, NOT the runtime gate

### `test_agent_portability.py` — 255 assertions

The 55-agent runtime as a repo-canonical invariant. Per audit priority #3: your runtime behavior depends on artifacts that aren't represented by `git checkout`. Fix: `agents/` becomes canonical, `manifest.json` anchors sha256 for every agent, `agents-sync.sh` + `agents-verify.sh` make the target install match the repo.

The invariant this proves: **`git checkout + bootstrap → same mad-Hacks behavior`**.

Four adversarial scenarios (all use a tempdir target, never touch the real `~/.claude/agents/`):

| Scenario | Setup | Assertion |
|---|---|---|
| **1 · fresh sync** | Empty target dir | `agents-sync.sh` copies all 55 (31 hunters + 24 operators), `agents-verify.sh` exits 0, reports 0/0/0 |
| **2 · corrupted file** | Sync, then append junk to `ssrf-hunter.md` | `agents-verify.sh` exits 1, names `ssrf-hunter` as MODIFIED with both hashes, `--json` output shows `counts.modified == 1` |
| **3 · deleted file** | Sync, then `rm xxe-hunter.md` | `agents-verify.sh` exits 1, names `xxe-hunter` as MISSING, re-sync recovers idempotently |
| **4 · manifest self-consistency** | Read `agents/manifest.json` | Every listed agent exists at declared path, every sha256 matches disk (freshness), every repo agent is listed in manifest, `agents-manifest.py --check` exits 0 (byte-identical reproducibility) |

Plus **dependency satisfaction** (250+ assertions): every `requires_scripts` and `requires_references` declared in the manifest resolves to an existing file. Catches dead links BEFORE the hunter dispatches and tries to bash a nonexistent script.

### `test_engagement_e2e.py` — 65 assertions

Deterministic synthetic walk of the documented `/mad-hunt` pipeline. No real HTTP, no real dispatch, no real exploitation. Hunter dispatch is simulated by calling the exact scripts a hunter's Preflight would call.

11 hops, each asserting its contract:

| Hop | What runs | What's proved |
|---|---|---|
| **1 · scope accepted** | `scope.py --md <fixture>` | In-scope target accepted, `IN-SCOPE` marker emitted |
| **2 · state created** | `engagement-state.sh init --scope-check` | All 7 canonical files initialized (TECH/OBS/TESTED/EXHAUSTED/HYPOTHESES/EVIDENCE.jsonl/LOG.md); tech string persisted |
| **3 · recon observation** | 4× `engagement-state.sh observe` | Each observation lands in `OBSERVED.md` verbatim |
| **4 · class classifier** | Simple signal→class map (real /mad-hunt uses writeups-corpus) | 4 classes selected from seeded observations (ssrf/graphql/auth-session/csrf); hunter context assembled |
| **5 · intelligence recall** | `intelligence-recall.sh --target --class --json` | Valid JSON, `results` array + `state` block, `engaged=True`, non-empty results |
| **6 · exhausted not prioritized** | Diff filter-on vs filter-off | Top-5 ordering differs; ≥1 row demoted; `_state_adj.exhausted_penalty=0.4`; same-row `_final_score` drops ≥50% under filter (**soft demote — rank may stay if raw score dominates**, by design) |
| **7 · hypothesis surfaced** | Add HIGH hypothesis + recall | `state.hypotheses_active=1`; ≥1 row has `hypothesis_boost>0` and `hypothesis_tokens_matched` populated; class-vocab token `ssrf` detected |
| **8 · evidence captured** | `engagement-state.sh evidence add --epistemic DERIVED --confidence HIGH` | Row appended, epistemic/confidence preserved (no silent upgrade), observation persists raw ground-truth |
| **9 · verifier input** | `engagement-state.sh recall` (adversarial context) | All required fields (observation/evidence/interpretation) present; recall surfaces hypothesis + observation + exhausted markers |
| **10 · report input** | Compose recall + evidence + LOG.md | Report input has exhausted_classes + hypotheses_active; ≥1 evidence row; LOG timeline has all 5 markers (init/observe/exhausted/hypothesis-add/evidence-add) |
| **11 · brain learns** | `brain.sh learn <marker>` | Lesson persists in `brain/lessons.md`; test cleans up its own marker |

---

## Real gap this suite closed on landing

**`engagement-state.sh init` had no scope check.** The doctrine (per `/mad-hunt.md`) says the operator runs `scope.py` before `engagement-state.sh init`, but nothing enforced that in code — a buggy or malicious hunter that skipped scope.py could initialize state for any target.

**Fix landed in the same commit:**

```
engagement-state.sh init [--scope-check <path>] [--no-scope-check]
```

Behavior (default fail-closed):
- `--scope-check <path>` — explicit gate. Requires `python3 scope.py --md <path> <target>` to exit 0 (in-scope). Rejection → exit 4, no state touched.
- No explicit flag but `.t3mp3st/SCOPE.md` exists at CWD → auto-gates.
- No SCOPE.md AND no `--no-scope-check` → proceeds (backwards-compat for intelligence tests; the operator's upstream `scope.py` call remains the primary gate per `/mad-hunt.md`).
- `--no-scope-check` — explicit escape hatch for tests + intentional off-scope research (loud in the log).

Exit codes:
- `0` — state created
- `2` — usage error
- `3` — missing/unreadable scope file
- `4` — scope rejected the target (new — distinct from usage errors)

---

## What this suite does NOT catch (yet)

Per the audit's remaining priority stack (post-`a51cf07` + this commit):

- ~~**Hunter portability** (audit #3)~~ ✅ **LANDED THIS COMMIT** — 55 agents now repo-canonical under `agents/{hunters,operators}/`, `manifest.json` with sha256, `agents-sync.sh` + `agents-verify.sh`, 255-assertion regression suite.
- **State-mutation invariant matrix** (audit refinement) — my scope-check fix in `engagement-state.sh init` was necessary but only closes ONE of 7 state-mutating subcommands. Every mutating path (`observe`, `evidence`, `exhausted`, `hypothesis`, `tested`, `log`) needs the same gate. **Next commit.**
- **Ranking ablation** (audit #4) — the state filter is verified end-to-end but the CONTRIBUTIONS of exhausted-demote vs hypothesis-boost aren't decomposed. Need: `baseline / +exhausted / +hypothesis / +both` × 5 categories × 5 metrics matrix. Follow-up.
- **Hypothesis poisoning** (audit #5) — the boost can currently be gamed by keyword-stuffed hypotheses. Test: adversarial `"ssrf ssrf ssrf ssrf"` HYPOTHESES.md entry — does it hijack retrieval? Follow-up.
- **CONFIRMED semantics** (audit #6) — deliberately deferred until the ablation makes the current 2-mechanism scoring model transparent.
- **Behavioral compliance across all 55 hunters** — Preambles reference the router, but whether every hunter actually calls it during a real Agent() dispatch requires runtime probes (out of scope for this deterministic suite).
- **Real HTTP / real recon / real probes** — this suite is deliberately synthetic. A live-network smoke test would need scope + rate-limit permission on a specific target (deferred to per-engagement).

---

## Baseline (frozen at portability commit)

```
tests/e2e/run-all.sh
  1/3  scope adversarial boundary        PASSED: 45   FAILED: 0
  2/3  agent portability + provenance    PASSED: 255  FAILED: 0
  3/3  end-to-end engagement chain       PASSED: 65   FAILED: 0
  ✓ ALL E2E SUITES PASSED  (3/3)
```

Combined with `tests/intelligence/`:
- Intelligence retrieval (`test_retrieval.py`): 3 configs measured, per-category floors enforced
- State adversarial (`test_state.py`): **37/37**
- Retrieval end-to-end (`test_end_to_end.py`): **12/12**
- Scope boundary (`test_scope_boundary.py`): **45/45**
- Agent portability (`test_agent_portability.py`): **255/255**
- Engagement chain (`test_engagement_e2e.py`): **65/65**

Total: **414+ assertions** across retrieval + state + operator + portability layers.
