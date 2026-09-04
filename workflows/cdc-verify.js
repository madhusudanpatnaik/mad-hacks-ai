// CDC Adversarial Verify — parallel DISPROVE pass over N primitives / chain-nodes.
//
// ┌─ RUNTIME ──────────────────────────────────────────────────────────────┐
// │  This file is a Claude Code Workflow-tool script — NOT standalone Node │
// │  Depends on the Workflow runtime globals: agent(), parallel(), phase(),│
// │  log(), args, budget. `node workflows/cdc-verify.js` will throw        │
// │  ReferenceError: args is not defined — that is expected.               │
// │                                                                        │
// │  Invoke via the Claude Code Workflow tool:                             │
// │      Workflow({ scriptPath: 'workflows/cdc-verify.js',                 │
// │                 args: { target, mode, visibility, goal, ... } })       │
// │  Or from within another script:  workflow('cdc-verify', {args})        │
// │                                                                        │
// │  From the CDC root harness this is called every tick when there is    │
// │  ≥1 primitive to validate. See references/cdc-harness.md § verify.    │
// └────────────────────────────────────────────────────────────────────────┘
//
// Called by the CDC root when the tick loop has ≥1 primitive to validate.
// Every verifier spawns independently, receives the DISPROVE contract, and returns
// a structured verdict. Root then writes verdicts via `cdc-state.sh verdict add`.
//
// Invocation shape (from root, one call per tick):
//   Workflow({ name: 'cdc-verify', args: {
//     target: 'api.example.com',
//     mode: 'pentest',            // bug-bounty | pentest | research
//     visibility: 'greybox',      // greybox | blackbox | whitebox
//     goal: 'unauth → RCE on API host',
//     deployment: 'Next.js 14 App Router, Postgres, Cloudflare, defaults',
//     blocked_paths_md: '<verbatim contents of BLOCKED.md>',
//     primitives: [
//       { id:'P260825001', family:'ssrf', name:'webhook-oob',
//         repro_cmd:'curl -X POST target/webhook -d url=…',
//         evidence_path:'.cdc/…/evidence/x.txt',
//         prereqs:'authenticated user', impact_shape:'internal HTTP read',
//         producer_agent:'ssrf-hunter' },
//       …
//     ]
//   }})
//
// Returns:
//   { verdicts: [ { id, verdict, refutation_reason, oracle_evidence,
//                   inspection_degraded, verifier_agent }, … ] }

export const meta = {
  name: 'cdc-verify',
  description: 'CDC adversarial verify — parallel DISPROVE pass over primitives / chain-nodes',
  phases: [
    { title: 'Verify', detail: 'one adversarial agent per primitive, DISPROVE by default' },
  ],
}

// --- Structured verdict schema (enforced at the tool-call layer) ---
const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['id', 'verdict', 'refutation_reason'],
  properties: {
    id: { type: 'string', description: 'echo of the primitive id being verified' },
    verdict: {
      type: 'string',
      enum: ['CONFIRMED', 'DISPROVED', 'INCONCLUSIVE'],
      description: 'DISPROVED is the default; only CONFIRMED if the reproducer fires under DEPLOYMENT and produces the claimed impact_shape; INCONCLUSIVE only if the runtime is unreachable and no oracle can be produced without breaking scope.',
    },
    refutation_reason: {
      type: 'string',
      description: 'For DISPROVED: the concrete refutation (benign explanation, blocking control, dependency version mismatch, docs-vs-runtime gap). For CONFIRMED: why the refutation attempt failed. For INCONCLUSIVE: what was missing.',
    },
    oracle_evidence: {
      type: 'string',
      description: 'Path or short snippet of oracle-grounded evidence you produced yourself (re-ran repro, observed output, dep-source citation). Never a CVE ID, changelog line, or patch diff alone.',
    },
    inspection_degraded: {
      type: 'boolean',
      description: 'True if visibility=blackbox forced you to substitute doc-reading for runtime inspection. Root tags degraded verdicts explicitly in reports.',
    },
    verifier_agent: { type: 'string', description: 'the agent name (or subagent_type) that produced this verdict' },
  },
}

// --- Guardrails ---
if (!args || typeof args !== 'object') {
  throw new Error('cdc-verify: args required (target, primitives, goal, deployment, mode, visibility)')
}
const { target, mode, visibility, goal, deployment, blocked_paths_md, primitives } = args
if (!target || !primitives || !Array.isArray(primitives) || primitives.length === 0) {
  throw new Error('cdc-verify: args.target and args.primitives (non-empty array) are required')
}
if (!['bug-bounty', 'pentest', 'research'].includes(mode || '')) {
  throw new Error(`cdc-verify: mode must be bug-bounty|pentest|research (got '${mode}')`)
}
if (!['greybox', 'blackbox', 'whitebox'].includes(visibility || '')) {
  throw new Error(`cdc-verify: visibility must be greybox|blackbox|whitebox (got '${visibility}')`)
}

log(`cdc-verify: dispatching ${primitives.length} adversarial verifier(s) for ${target}  [mode=${mode} visibility=${visibility}]`)

// --- Mode-specific rider on the DISPROVE briefing ---
function modeRider(m, v) {
  if (m === 'bug-bounty') {
    return `Bug-bounty mode: honor safe-PoC discipline (R1–R11 from references/production-safety.md). Never run destructive payloads on the live target. A repro that requires damaging output is DISPROVED here; suggest a benign OOB variant instead.`
  }
  if (m === 'pentest') {
    return `Pentest mode: RoE-bound. If the repro requires a step outside the engagement's Rules of Engagement, mark DISPROVED with reason "out-of-RoE" — do not execute it. Impact must be demonstrated within RoE constraints.`
  }
  return `Research mode: greybox/whitebox. Reproduce against the local instance of DEPLOYMENT. Read dependency source when behavior depends on it (\`pip show -f\`, \`go doc -all\`, \`npm view\`, or read the running container). Docs are not oracles; runtime is.`
    + (v === 'blackbox' ? '\nBLACKBOX FALLBACK: If runtime inspection is impossible, tag inspection_degraded=true. Never fabricate a runtime observation.' : '')
}

// --- Build the DISPROVE briefing for one primitive ---
function disproveBrief(p) {
  const producer = p.producer_agent || '(unknown)'
  const bp = (blocked_paths_md || '').trim() || '_(none)_'
  return [
    `You are an INDEPENDENT ADVERSARIAL VERIFIER for a CDC vulnerability-research loop. Your job is to DISPROVE the primitive below. Default to DISPROVED unless the evidence is oracle-grounded, the repro fires on the deployment described, and the impact_shape is produced by your own hands.`,
    ``,
    `## Doctrine (BINDING — from references/cdc-harness.md)`,
    `1. No CVE / patch-diff / changelog shortcuts. Those are hints, never oracles.`,
    `2. Runtime beats docs. When behavior depends on a library / framework / DB / dep — read the SOURCE.`,
    `3. Realistic, common configuration. A repro that only works with debug=true or an exotic version is DISPROVED here.`,
    `4. Chain fitness. If the primitive doesn't compose toward the GOAL under the DEPLOYMENT, it is DISPROVED regardless of technical accuracy.`,
    `5. Independence. You are NOT allowed to reason like the producer agent (${producer}). Use a different angle: different tool, different oracle, different lens.`,
    ``,
    modeRider(mode, visibility),
    ``,
    `## GOAL (starting-privilege → impact)`,
    `> ${goal}`,
    ``,
    `## DEPLOYMENT (must reproduce here)`,
    `> ${deployment}`,
    ``,
    `## BLOCKED paths (do not resurrect these)`,
    bp,
    ``,
    `## Primitive to verify`,
    `- id: ${p.id}`,
    `- family: ${p.family}`,
    `- name: ${p.name}`,
    `- repro_cmd: \`${p.repro_cmd}\``,
    `- evidence_path (producer's): ${p.evidence_path || '(none)'}`,
    `- prereqs: ${p.prereqs || '(none)'}`,
    `- impact_shape (claimed): ${p.impact_shape || '(none)'}`,
    `- producer_agent: ${producer}`,
    ``,
    `## Procedure`,
    `1. Re-run the repro from a clean state. Capture the exact output.`,
    `2. Check the repro against the DEPLOYMENT constraint. If it needs an exotic config, DISPROVED.`,
    `3. Try 2–3 refutations: a benign explanation, a blocking control (WAF, CSP, RLS, feature-flag), a dependency-version guard.`,
    `4. If it still stands, PRODUCE the claimed impact_shape yourself and cite the artifact (file path, HTTP transcript, dep-source line).`,
    `5. Return the structured verdict.`,
    ``,
    `Return the verdict via the StructuredOutput tool. echo the id verbatim.`,
    ``,
    `## MANDATORY: end your response with the visible verdict card`,
    `The last block of your response MUST be the "🛡️  VERIFY / REFUTE VERDICT" card from t3-verifier.md § "Layer 2". Fill every field. If you CONFIRMED, at least one refutation attempt must have been tried and failed — the card proves you tried to kill it.`,
  ].join('\n')
}

phase('Verify')
const verdicts = await parallel(
  primitives.map((p) => () =>
    agent(disproveBrief(p), {
      schema: VERDICT_SCHEMA,
      label: `verify:${p.family}:${p.id}`,
      phase: 'Verify',
      agentType: 't3-verifier',
    })
  )
)

// null slots = agent failed / user-skipped mid-run; expose them explicitly so root can retry
const clean = verdicts.map((v, i) =>
  v || {
    id: primitives[i].id,
    verdict: 'INCONCLUSIVE',
    refutation_reason: 'verifier agent failed or was skipped mid-run',
    oracle_evidence: '',
    inspection_degraded: false,
    verifier_agent: 't3-verifier (skipped)',
  }
)

log(`cdc-verify: ${clean.filter((v) => v.verdict === 'CONFIRMED').length} CONFIRMED / ${clean.filter((v) => v.verdict === 'DISPROVED').length} DISPROVED / ${clean.filter((v) => v.verdict === 'INCONCLUSIVE').length} INCONCLUSIVE`)

return { verdicts: clean }
