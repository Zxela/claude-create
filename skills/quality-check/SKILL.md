---
name: quality-check
description: "[sonnet/haiku-tier] Multi-phase quality pipeline: lint, types, structure, tests, recheck. Haiku-tier tasks skip LLM phases."
model: sonnet
color: teal
---

# Quality Check Skill

## References

`references/signal-contracts.json` · `references/context-engineering.md` · `references/quality-gates.md`

## Overview

5-phase quality pipeline on changed files. Complements review (spec compliance) with code health validation. Invoked after review approval or as standalone gate. **Model: sonnet. Budget: < 15K tokens (< 5K for haiku-tier).** Haiku-tier sessions skip LLM phases (Phase 3, Phase 5) entirely.

---

## Input Schema (JSON)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["worktree_path", "files_changed"],
  "properties": {
    "worktree_path": { "type": "string" },
    "files_changed": {
      "type": "array",
      "items": { "type": "string" }
    },
    "task_id": { "type": "string" },
    "fix_mode": {
      "type": "string",
      "enum": ["auto", "report_only"],
      "default": "auto",
      "description": "auto: fix issues and recommit. report_only: report without changing files."
    },
    "tier": {
      "type": "string",
      "enum": ["haiku", "sonnet", "opus"],
      "default": "sonnet",
      "description": "Execution tier of the tasks in this session. haiku: skip LLM phases (Phase 3 structural review, Phase 5 recheck). sonnet/opus: full pipeline."
    }
  }
}
```

### Example Input

```json
{
  "worktree_path": "../myapp-create-user-auth-a1b2c3d4",
  "files_changed": ["src/services/auth.ts", "tests/services/auth.test.ts"],
  "task_id": "002",
  "fix_mode": "auto",
  "tier": "sonnet"
}
```

---

## Tier Routing

Before starting, determine which phases to run:

```
tier == "haiku"  → run Phase 1 (lint), Phase 2 (types), Phase 4 (tests, report_only)
                   SKIP Phase 3 (structural review — LLM)
                   SKIP Phase 5 (recheck — nothing to recheck when no auto-fixes run)
                   OVERRIDE fix_mode to "report_only" for Phase 4 (no LLM auto-fix)

tier == "sonnet" → full pipeline (all 5 phases, fix_mode as specified)
tier == "opus"   → full pipeline (all 5 phases, fix_mode as specified)
```

**Why skip for haiku?** Haiku-tier tasks (`add_field`, `add_method`, `add_validation`, etc.) are mechanical single-focus changes. The structural review phase adds LLM cost (~3K tokens) but provides minimal signal for tasks that don't involve new abstractions, dead code risks, or naming decisions. Deterministic checks (lint, types, tests) are sufficient.

---

## Process

### Phase 1-2: Lint & Types (HOOKS — zero LLM cost)

Handled by `scripts/homerun-quality-lint.sh` and `scripts/homerun-quality-typecheck.sh`. Skip with `skipped_by_hooks` if git hooks (husky/pre-commit) already enforce. Agent reads exit codes only.

### Phase 3: Structural Review (LLM — skipped for haiku-tier)

**Tier check:** If `tier == "haiku"`, skip this phase entirely. Emit `"status": "skipped", "reason": "haiku_tier"` and proceed to Phase 4.

Review changed files for: unused imports, dead code, debug artifacts (console.log, debugger), naming consistency, file organization. Grep for artifacts first.

**Blocking** (fail): debug artifacts, genuine dead code. **Advisory** (pass): naming, organization, benign TODOs.

### Phase 4: Tests (DETERMINISTIC — haiku-tier uses report_only)

**Tier check:** If `tier == "haiku"`, override `fix_mode` to `"report_only"`. Do not attempt LLM auto-fix — just run tests and report.

Run test suite, check exit code. If fail + fix_mode=auto → attempt fix (max 2). Still failing → report unresolved.

### Phase 5: Final Recheck (DETERMINISTIC — skipped for haiku-tier)

**Tier check:** If `tier == "haiku"`, skip this phase entirely. Emit `"status": "skipped", "reason": "haiku_tier"`. No auto-fixes ran, so there is nothing to recheck.

Re-run phases 1-2 after auto-fixes. New issues from fixes → revert, report `needs_manual_fix`.

---

## Output Schema (JSON)

### Success: QUALITY_CHECK_COMPLETE

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["signal", "verdict", "phases"],
  "properties": {
    "signal": { "const": "QUALITY_CHECK_COMPLETE" },
    "verdict": { "enum": ["pass", "pass_with_fixes", "fail"] },
    "phases": {
      "type": "object",
      "properties": {
        "lint": { "$ref": "#/definitions/phase_result" },
        "types": { "$ref": "#/definitions/phase_result" },
        "structure": { "$ref": "#/definitions/phase_result" },
        "tests": { "$ref": "#/definitions/phase_result" },
        "recheck": { "$ref": "#/definitions/phase_result" }
      }
    },
    "fixes_applied": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "phase": { "type": "string" },
          "description": { "type": "string" },
          "file": { "type": "string" }
        }
      }
    },
    "unresolved": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "phase": { "type": "string" },
          "description": { "type": "string" },
          "file": { "type": "string" }
        }
      }
    }
  },
  "definitions": {
    "phase_result": {
      "type": "object",
      "properties": {
        "status": { "enum": ["pass", "fixed", "fail", "skipped"] },
        "issues_found": { "type": "integer" },
        "issues_fixed": { "type": "integer" },
        "reason": { "type": "string", "description": "Why this phase was skipped (e.g. 'haiku_tier', 'skipped_by_hooks')" }
      }
    }
  }
}
```

**Example (all pass):**

```json
{
  "signal": "QUALITY_CHECK_COMPLETE",
  "verdict": "pass",
  "phases": {
    "lint": { "status": "pass", "issues_found": 0, "issues_fixed": 0 },
    "types": { "status": "pass", "issues_found": 0, "issues_fixed": 0 },
    "structure": { "status": "pass", "issues_found": 0, "issues_fixed": 0 },
    "tests": { "status": "pass", "issues_found": 0, "issues_fixed": 0 },
    "recheck": { "status": "pass", "issues_found": 0, "issues_fixed": 0 }
  },
  "fixes_applied": [],
  "unresolved": []
}
```

**Example (auto-fixed):**

```json
{
  "signal": "QUALITY_CHECK_COMPLETE",
  "verdict": "pass_with_fixes",
  "phases": {
    "lint": { "status": "fixed", "issues_found": 3, "issues_fixed": 3 },
    "types": { "status": "pass", "issues_found": 0, "issues_fixed": 0 },
    "structure": { "status": "fixed", "issues_found": 1, "issues_fixed": 1 },
    "tests": { "status": "pass", "issues_found": 0, "issues_fixed": 0 },
    "recheck": { "status": "pass", "issues_found": 0, "issues_fixed": 0 }
  },
  "fixes_applied": [
    { "phase": "lint", "description": "Fixed formatting in auth.ts", "file": "src/services/auth.ts" },
    { "phase": "structure", "description": "Removed unused import 'Logger'", "file": "src/services/auth.ts" }
  ],
  "unresolved": []
}
```

---

## Verdict Rules

| Condition | Verdict |
|-----------|---------|
| All phases pass, no fixes needed | `pass` |
| Issues found and auto-fixed, recheck passes | `pass_with_fixes` |
| Only advisory issues remain (no blocking findings) | `pass` |
| Unresolved blocking issues remain | `fail` |

When verdict is `pass_with_fixes`:
- Amend the task's commit with quality fixes: `git add -A && git commit --amend --no-edit`

When verdict is `fail`:
- Report unresolved issues to team-lead
- Team-lead decides whether to retry or escalate

---

## Exit Criteria

- [ ] All phases executed or skipped per tier; auto-fixes applied (if applicable); verdict + signal emitted

## Context Budget: ~15K
Input ~3K | Execution ~6K | Fixes ~3K | Report ~1K | Buffer ~2K
