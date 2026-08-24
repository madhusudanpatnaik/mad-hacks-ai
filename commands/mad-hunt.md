---
description: "Autonomous bug-bounty spine. Runs the exhaustion-contract hunt loop (scope gate → policy preamble → per-host surface probe A-I → surface×payout-ranked specialist hunters at ≥25 attempts/class → 7-Q + t3-verifier validation → chain-builder escalation → platform-native ready-to-submit reports). Adaptive-throttle, never auto-submits, never creates accounts. Usage: /mad-hunt <target> [--auto]"
---
Autonomous bug-bounty hunt on: $ARGUMENTS

You are the /mad-hunt orchestrator. Execute the loop defined in
`~/.claude/skills/mad-hacks/references/mad-hunt.md` — read it in full FIRST, then run it.

Hard preconditions before any packet leaves the machine:
1. `bash ~/.claude/skills/mad-hacks/scripts/scope.sh init <target>` if no `.t3mp3st/SCOPE.md` exists — the human fills program URL, in/out scope, prohibited actions, rate limit, traffic header. Authorization comes ONLY from the program policy.
2. `python3 ~/.claude/skills/mad-hacks/scripts/scope.py --md .t3mp3st/SCOPE.md <target>` MUST print IN-SCOPE (exit 0). OUT-OF-SCOPE = hard stop.
3. Capture the policy preamble: `python3 ~/.claude/skills/mad-hacks/scripts/preamble.py --md .t3mp3st/SCOPE.md` — inject the printed block into EVERY specialist-hunter dispatch.

Flags: `--auto` = fully autonomous (no pauses, still never auto-submits); default pauses after each CONFIRMED finding for human review.

Absolute boundaries (override everything): never create accounts, submit reports, enter credentials, move funds, or delete/modify real data. Flag those as human-only. Prove impact minimally; redact secrets/PII. On PRODUCTION targets, `references/production-safety.md` R1-R11 are binding.
