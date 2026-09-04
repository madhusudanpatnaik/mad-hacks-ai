# workflows/ — Claude Code Workflow-tool scripts

Scripts in this directory are **NOT standalone Node.js** and cannot be executed with `node <file>.js`. They depend on the Claude Code Workflow runtime globals (`agent()`, `parallel()`, `pipeline()`, `phase()`, `log()`, `args`, `budget`, `workflow()`).

## How to run

From within a Claude Code session that has the Workflow tool available:

```javascript
Workflow({
  scriptPath: 'workflows/cdc-verify.js',
  args: { target: 'api.example.com', primitives: [...] }
})
```

From within another Workflow script:

```javascript
workflow('cdc-verify', { target, primitives })
```

## Why the scripts look "broken" outside the runtime

Each file references globals that only exist under the runtime:
- `agent(prompt, opts)` — spawn a subagent (returns text or a schema-validated object)
- `parallel(thunks)` — barrier-await N thunks concurrently
- `pipeline(items, ...stages)` — independent per-item stages, no cross-stage barrier
- `phase(title)` — group subsequent `agent()` calls under a progress heading
- `log(msg)` — narrator output above the progress tree
- `args` — the object passed to Workflow's `args` input
- `budget` — turn-level token target (may be `null`)

`node workflows/cdc-verify.js` throws `ReferenceError: args is not defined` — that is EXPECTED. If you want to test-load the module structure without executing the workflow, you can `node --check workflows/cdc-verify.js` (syntax check only).

## Current scripts

| Script | Purpose | Invoked by |
|---|---|---|
| `cdc-verify.js` | Parallel DISPROVE pass over N primitives/chain-nodes | `/cdc-research` root when tick has ≥1 primitive to validate |

## Related

- `commands/cdc-research.md` — the `/cdc-research` slash command that drives this
- `references/cdc-harness.md` — the CDC doctrine + tick loop spec
- `scripts/cdc-state.sh` — the state manager these scripts write verdicts through
- `SKILL.md` (workflow-authoring skill in ~/.claude) — full Workflow tool reference

## Authoring guidance

New workflows should:
1. Begin with `export const meta = { name, description, phases }` — pure literal, no interpolation
2. Prefer `pipeline()` over `parallel()` — barrier-latency is real
3. Use structured output (`schema: {...}` on `agent()`) whenever the return will be programmatically consumed
4. Document invocation shape at the top of the file, matching the header convention in `cdc-verify.js`
