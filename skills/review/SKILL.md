---
name: review
description: "[sonnet] Verify implementation against specification and approve or reject"
model: sonnet
color: blue
---

# Review Skill

## References

`cookbooks/review-feedback-examples.md`

## Overview

Reviewer agent. Verify implementation meets specification → approve or reject with specific feedback.

## Input Schema

Validate before proceeding. Required: `task` (id, title, acceptance_criteria with risk_level), `implementation` (commit_hash, files_changed, test_file, verification_level/attempted/details), `spec_paths` (technical_design, adr), `worktree_path`.

Optional: `previous_rejections[]` (on re-reviews), `skip_hard_gates` (bool), `hard_gate_results` ({tests, types, lint} exit codes).

Validation: required fields present, commit_hash exists in git, files_changed in commit, spec files exist. Fail → `VALIDATION_ERROR`.

## Two-Tier Evaluation Process

### Tier 1: Hard Gate (Deterministic — FIRST)

**Fast-path:** `skip_hard_gates: true` + all exit codes 0 → skip to Tier 2, use cached results. Otherwise run tests, tsc --noEmit, eslint. Any failure → reject immediately (no Tier 2).

**Verification level check:** L1/L2 → pass. L3 with valid justification → pass (note as finding). L3 without justification → medium severity finding. Missing fields → treat as L3-unjustified.

### Tier 2: Soft Review (LLM — score-based)

Score 0.0-1.0. **Threshold: >= 0.7 = APPROVE.** 0.9+ = clean, 0.7-0.89 = minor issues (approve), 0.5-0.69 = missing edge case (reject), <0.5 = core issues (reject). Only flag edge cases causing silent wrong output, not explicit errors.

### Diff-Based File Reading (Token Optimization)

**Use `git diff` as the primary review input instead of reading full files.** This dramatically reduces token consumption for tasks touching large files.

```bash
cd "$WORKTREE_PATH"
# Get the diff for the implementation commit
git diff ${COMMIT_HASH}~1..${COMMIT_HASH} -- ${FILES_CHANGED[@]}
```

**Review workflow:**
1. Read the diff output first — this shows exactly what changed with surrounding context
2. Only read full files when the diff is insufficient to evaluate an AC (e.g., need to understand broader control flow)
3. For test files, read the full test file since test structure matters for evaluating coverage
4. For spec comparison, use targeted grep on spec sections (not full spec reads)

**When to fall back to full file reads:**
- Diff shows changes to a function signature → read callers to verify no breakage
- AC requires understanding data flow across multiple functions → read relevant functions
- Security review requires understanding the full request handling chain

### Review Checklist (Tier 2)

**Acceptance criteria** by risk_level: must_test → implemented + dedicated test + test verifies it | verify_only → implemented + consolidated test | structural → implemented + types/lint confirm.

**Technical alignment:** matches spec_paths.technical_design patterns, data models, API contracts.
**Security:** follows spec_paths.adr decisions, no vulnerabilities, sensitive data handled.

## Severity Classification

**high:** Fails AC, security flaw, violates ADR → blocks spawning, escalates. **medium:** Missing must_test coverage, unhandled edge case → retry with feedback. **low:** Style/naming → retry with feedback. Overall severity = highest among all issues.

## Output Signals

All output: valid JSON in ```json code block. **Use envelope format** with `signal`, `timestamp`, `source`, `payload` wrapper (see `references/signal-contracts.json`).

### APPROVED

```json
{
  "signal": "APPROVED",
  "timestamp": "<ISO8601>",
  "source": { "skill": "homerun:review", "task_id": "<task.id>" },
  "payload": {
    "summary": "<one-line summary>",
    "score": 0.85,
    "hard_gates": { "tests": "pass", "types": "pass", "lint": "pass" },
    "verified": [
      { "criterion": "AC-001", "description": "...", "implementation_file": "src/x.ts:45", "test_file": "tests/x.test.ts:12" }
    ]
  },
  "envelope_version": "1.0.0"
}
```

### REJECTED

```json
{
  "signal": "REJECTED",
  "timestamp": "<ISO8601>",
  "source": { "skill": "homerun:review", "task_id": "<task.id>" },
  "payload": {
    "summary": "<one-line summary>",
    "score": 0.45,
    "hard_gates": { "tests": "fail", "types": "pass", "lint": "pass" },
    "issues": [
      { "criterion": "AC-002", "description": "...", "file": "src/x.ts", "line": 45, "severity": "high" }
    ],
    "required_fixes": ["Fix the boundary check at src/x.ts:45"]
  },
  "envelope_version": "1.0.0"
}
```

Omit `score` from payload if rejection is due to hard gate failure (Tier 2 was not run).

### VALIDATION_ERROR

```json
{
  "signal": "VALIDATION_ERROR",
  "timestamp": "<ISO8601>",
  "source": { "skill": "homerun:review" },
  "payload": {
    "error_type": "invalid_input",
    "errors": [{ "path": "$.task.id", "message": "...", "expected": "...", "received": "..." }]
  },
  "envelope_version": "1.0.0"
}
```

## Re-Review Process

When `previous_rejections` non-empty: verify each prior issue first (check specific file:line). Persists → re-raise as "recurring issue" (signals escalation). Fixed → move on. Then run full checklist. Approve only if all prior issues resolved AND no new high/medium issues.

---

## Review Principles

Be specific (cite file:line + AC). Reference specs (quote expected vs actual). Actionable feedback (specific fix, not "needs more X").

## Red Flags — Immediate REJECT

Missing test for AC. Test passes without implementation. Diverges from TECHNICAL_DESIGN. Violates ADR security decisions.

**Tautological test blocker:** Don't re-dispatch same test. Guide: "strengthen assertions to verify actual behavior." Include mutated file:line. Max 2 retries → escalate.

## Exit Criteria

- [ ] All ACs checked; verification level validated; APPROVED or REJECTED emitted
- [ ] REJECTED: every issue has file:line + required fix. APPROVED: every AC has impl + test locations
