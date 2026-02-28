---
name: quality-check
description: "[sonnet] Multi-phase quality pipeline: lint, types, structure, tests, recheck"
model: sonnet
color: teal
---

# Quality Check Skill

## Reference Materials

- Signal contracts: `references/signal-contracts.json`
- Context patterns: `references/context-engineering.md`

## Overview

You are a **quality assurance agent**. Your job: run a structured 5-phase quality pipeline on changed files and fix issues autonomously. This skill complements the `review` skill — review checks spec compliance, quality-check validates code health.

The conductor can invoke this after review approval or as a standalone gate before completion.

**Model Selection:** Sonnet — quality checks require judgment for fixes but not deep reasoning.

**Context Budget:** Target < 15K tokens.

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
  "fix_mode": "auto"
}
```

---

## Process

### Phase 1: Lint & Format (DETERMINISTIC — no LLM judgment)

Run CLI tools and check exit codes. The LLM adds no value here — just execute and report.

```bash
cd "$WORKTREE_PATH"

# Detect linter from project config and run with auto-fix
if [ -f biome.json ] || [ -f biome.jsonc ]; then
  npx biome check --write "${FILES[@]}" 2>&1 | tail -20
  LINT_EXIT=$?
elif [ -f .eslintrc* ] || grep -q '"eslint"' package.json 2>/dev/null; then
  npx eslint --fix "${FILES[@]}" 2>&1 | tail -20
  LINT_EXIT=$?
elif [ -f .prettierrc* ] || grep -q '"prettier"' package.json 2>/dev/null; then
  npx prettier --write "${FILES[@]}" 2>&1 | tail -20
  LINT_EXIT=$?
else
  echo "No linter found — skipping"
  LINT_EXIT=0
fi

# Result: LINT_EXIT == 0 means pass. No LLM analysis needed.
```

### Phase 2: Type Checking (DETERMINISTIC — no LLM judgment)

```bash
cd "$WORKTREE_PATH"

# TypeScript
if [ -f tsconfig.json ]; then
  TYPE_OUTPUT=$(npx tsc --noEmit 2>&1)
  TYPE_EXIT=$?
  echo "$TYPE_OUTPUT" | grep -E "error TS" | head -20
fi

# Python (if applicable)
if command -v mypy &>/dev/null && [ -f pyproject.toml ]; then
  TYPE_OUTPUT=$(mypy "${FILES[@]}" 2>&1)
  TYPE_EXIT=$?
  echo "$TYPE_OUTPUT" | tail -20
fi

# Result: TYPE_EXIT == 0 means pass. No LLM analysis needed.
```

**If type errors found and fix_mode=auto:** Fix type errors in changed files only. This is the ONE place in phases 1/2/4 where LLM judgment helps (choosing HOW to fix a type error).
**Scope constraint:** Only fix errors in files from `files_changed`. Do not fix pre-existing errors in other files.

### Phase 3: Structural Review (LLM JUDGMENT — this is where you add value)

This is the ONLY phase that requires LLM reasoning. The other phases are deterministic CLI checks.

Review changed files for:

1. **Unused imports** — imports not referenced in the file body
2. **Dead code** — functions, variables, or classes that are defined but never used
3. **Debug artifacts** — `console.log`, `debugger`, `TODO`/`FIXME` comments left behind
4. **Naming consistency** — do new names follow the existing codebase conventions?
5. **File organization** — are new files in the right directories?

```bash
cd "$WORKTREE_PATH"

for file in "${FILES[@]}"; do
  # Quick checks the LLM can interpret
  if [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]]; then
    echo "=== $file ==="
    grep -n "console\.\(log\|debug\|warn\)" "$file" | head -5
    grep -n "debugger" "$file" | head -5
    grep -n "TODO\|FIXME\|HACK\|XXX" "$file" | head -5
  fi
done
```

### Phase 4: Tests (DETERMINISTIC — no LLM judgment)

```bash
cd "$WORKTREE_PATH"

# Run full test suite and check exit code (use mktemp to avoid cross-session collisions)
if [ -f package.json ]; then
  TEST_OUT=$(mktemp)
  npm test 2>&1 | tee "$TEST_OUT"
  TEST_EXIT=$?
  echo "Exit code: $TEST_EXIT"
  grep -A 2 'FAIL' "$TEST_OUT" | head -20
  rm -f "$TEST_OUT"
elif [ -f Cargo.toml ]; then
  cargo test 2>&1 | tail -30
  TEST_EXIT=$?
elif [ -f pyproject.toml ]; then
  pytest 2>&1 | tail -30
  TEST_EXIT=$?
fi

# Result: TEST_EXIT == 0 means pass. No LLM analysis needed.
```

**If tests fail and fix_mode=auto:** Attempt to fix failing tests (max 2 attempts). This requires LLM judgment.
**If tests still fail after 2 attempts:** Report as unresolved.

### Phase 5: Final Recheck (DETERMINISTIC — no LLM judgment)

After all auto-fixes, re-run deterministic checks to confirm no regressions:

```bash
cd "$WORKTREE_PATH"

# Re-run phases 1 and 2
npx tsc --noEmit 2>&1 | grep "error" | wc -l
npm test 2>&1 | grep -E "Tests:.*failed" || echo "All tests pass"
```

If new issues introduced by auto-fixes, revert auto-fixes and report as `needs_manual_fix`.

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
        "issues_fixed": { "type": "integer" }
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
| Unresolved issues remain | `fail` |

When verdict is `pass_with_fixes`:
- Amend the task's commit with quality fixes: `git add -A && git commit --amend --no-edit`

When verdict is `fail`:
- Report unresolved issues to conductor
- Conductor decides whether to retry or escalate

---

## Exit Criteria

- [ ] All 5 phases executed (or skipped with reason)
- [ ] Auto-fixes applied where possible (if fix_mode=auto)
- [ ] Recheck confirms no regressions from fixes
- [ ] Verdict determined
- [ ] Signal emitted with phase-by-phase results

---

## Context Budget

| Component | Budget | Strategy |
|-----------|--------|----------|
| Input + file reads | ~3K | Changed files only |
| Phase execution | ~6K | Command output masked (tail -20) |
| Auto-fixes | ~3K | Targeted changes only |
| Report | ~1K | Structured output |
| **Buffer** | ~2K | Retries |
