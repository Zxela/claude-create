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

### Phase 1: Lint & Format

Run project linter/formatter on changed files:

```bash
cd "$WORKTREE_PATH"

# Detect linter from project config
if [ -f biome.json ] || [ -f biome.jsonc ]; then
  npx biome check --write "${FILES[@]}" 2>&1 | tail -20
elif [ -f .eslintrc* ] || grep -q '"eslint"' package.json 2>/dev/null; then
  npx eslint --fix "${FILES[@]}" 2>&1 | tail -20
elif [ -f .prettierrc* ] || grep -q '"prettier"' package.json 2>/dev/null; then
  npx prettier --write "${FILES[@]}" 2>&1 | tail -20
fi
```

**If issues found and fix_mode=auto:** Apply fixes, record what changed.
**If no linter found:** Skip phase, note in report.

### Phase 2: Type Checking

```bash
cd "$WORKTREE_PATH"

# TypeScript
if [ -f tsconfig.json ]; then
  npx tsc --noEmit 2>&1 | grep -E "error TS" | head -20
fi

# Python (if applicable)
if command -v mypy &>/dev/null && [ -f pyproject.toml ]; then
  mypy "${FILES[@]}" 2>&1 | tail -20
fi
```

**If type errors found and fix_mode=auto:** Fix type errors in changed files only.
**Scope constraint:** Only fix errors in files from `files_changed`. Do not fix pre-existing errors in other files.

### Phase 3: Structural Checks

Check for common structural issues in changed files:

```bash
cd "$WORKTREE_PATH"

for file in "${FILES[@]}"; do
  # Unused imports (TypeScript/JavaScript)
  if [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]]; then
    # Check for imports not referenced in file body
    grep -E "^import " "$file" | while read -r import_line; do
      imported_name=$(echo "$import_line" | grep -oE '\b[A-Z][a-zA-Z]+\b' | head -1)
      if [ -n "$imported_name" ]; then
        count=$(grep -c "$imported_name" "$file")
        if [ "$count" -le 1 ]; then
          echo "UNUSED_IMPORT: $file: $imported_name"
        fi
      fi
    done
  fi
done
```

### Phase 4: Tests

```bash
cd "$WORKTREE_PATH"

# Run tests related to changed files
if [ -f package.json ]; then
  npm test 2>&1 | tee /tmp/test-output.txt
  echo "Tests: $(grep -c 'PASS\|FAIL' /tmp/test-output.txt) suites"
  grep -A 2 'FAIL' /tmp/test-output.txt | head -20
elif [ -f Cargo.toml ]; then
  cargo test 2>&1 | tail -30
elif [ -f pyproject.toml ]; then
  pytest 2>&1 | tail -30
fi
```

**If tests fail and fix_mode=auto:** Attempt to fix failing tests (max 2 attempts).
**If tests still fail after 2 attempts:** Report as unresolved.

### Phase 5: Final Recheck

After all auto-fixes, verify everything still passes:

```bash
cd "$WORKTREE_PATH"

# Re-run all checks
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
