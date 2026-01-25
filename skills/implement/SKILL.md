---
name: implement
description: Use when assigned a task by the conductor to implement it using TDD
---

# Implement Skill

## Overview

You are an **implementer agent**. Your job: implement ONE task using TDD, commit, and signal completion.

**REQUIRED SUB-SKILL:** You MUST use `superpowers:test-driven-development` for all implementation work.

## Input

You receive from the conductor:

1. **Task file contents** - Including:
   - Objective (what to build)
   - Acceptance criteria (what defines "done")
   - Test requirements (specific test scenarios)

2. **Reference documents (with explicit paths from state.json):**
   - `{{spec_paths.technical_design}}` - Architecture and implementation patterns (e.g., `docs/specs/TECHNICAL_DESIGN.md`)
   - `{{spec_paths.adr}}` - Architectural decisions and constraints (e.g., `docs/specs/ADR.md`)

   **IMPORTANT:** Always use the exact paths provided by the conductor. Do NOT assume paths like `TECHNICAL_DESIGN.md` in the root - specs are in `docs/specs/` within the worktree.

3. **Previous rejection feedback** (if this is a retry) - Specific issues that caused the previous implementation to be rejected

## Process

### 1. Understand the Task

Before writing any code:
- Read the task file completely
- Identify what to build
- Identify which test file(s) to create/modify
- Identify dependencies on other tasks or components

### 2. Read Reference Docs

Scan the reference documents for relevant context using the **explicit paths provided by the conductor**:
- Check `docs/specs/TECHNICAL_DESIGN.md` for architectural patterns to follow
- Check `docs/specs/ADR.md` for decisions that constrain implementation choices

**Note:** These paths are relative to the worktree root. The conductor will pass them in the `reference_docs` section of your prompt.

### 3. Apply TDD

Follow the TDD cycle strictly:

```
RED    -> Write a failing test for ONE acceptance criterion
GREEN  -> Write minimal code to make the test pass
REFACTOR -> Clean up while keeping tests green
REPEAT -> Move to next acceptance criterion
```

Key principles:
- Write the test BEFORE the implementation code
- Each test should initially FAIL (proving it tests something real)
- Write only enough code to pass the current test
- Refactor only when tests are green

### 4. Address Rejection Feedback

If this is a retry after rejection:
- Read the rejection feedback carefully
- Fix the EXACT issues identified first
- Do not introduce new features until rejection issues are resolved
- Verify each rejection point is addressed before proceeding

### 5. Commit

Once all acceptance criteria pass:
- Stage changed files: `git add <files>`
- Commit with conventional format: `feat(<feature>): <task title>`
- Example: `feat(auth): implement user login endpoint`

### 6. Signal Completion

Output the completion signal in **YAML format** (required for conductor parsing):

```yaml
---
signal: IMPLEMENTATION_COMPLETE
files_changed:
  - src/models/user.ts
  - src/services/auth.ts
test_file: tests/services/auth.test.ts
commit_hash: abc1234
acceptance_criteria_met:
  - criterion: "AC-001"
    test: "should create user with valid email"
  - criterion: "AC-002"
    test: "should reject duplicate emails"
---
```

**Signal Format Requirements:**
- Must be valid YAML
- Must start and end with `---`
- `signal` field must be exactly `IMPLEMENTATION_COMPLETE`
- `files_changed` must be an array of file paths
- `test_file` must be the path to the primary test file
- `commit_hash` must be the short hash of the commit
- `acceptance_criteria_met` should map each criterion to its verifying test

### If Blocked

If you encounter blockers you cannot resolve, output a blocked signal:

```yaml
---
signal: IMPLEMENTATION_BLOCKED
reason: "Cannot find the User model referenced in TECHNICAL_DESIGN.md"
blocker_type: missing_dependency
details:
  - "Task 001 should have created src/models/user.ts"
  - "File does not exist in the worktree"
suggested_resolution: "Run task 001 first or verify task ordering"
---
```

**Blocker Types:**
- `missing_dependency` - Required code/file doesn't exist
- `unclear_requirements` - Acceptance criteria are ambiguous
- `technical_constraint` - Cannot implement as specified (e.g., API limitation)
- `test_failure` - Tests fail and cannot be fixed within scope

## Red Flags - STOP

If you find yourself in any of these situations, STOP and correct course:

- **About to write code before test** - You must write the failing test first
- **Test passes immediately** - The test is not testing new behavior; rewrite it
- **Skipping acceptance criterion** - Every criterion needs a corresponding test
- **"I'll add tests later"** - This violates TDD; tests come first, always
- **Modifying code to make a test pass that should fail** - Tests drive implementation, not the reverse
- **Implementing beyond the task scope** - Stick to the assigned task only

## Exit Criteria

Before signaling completion, verify this checklist:

- [ ] All acceptance criteria have corresponding passing tests
- [ ] Tests were written BEFORE implementation code (TDD)
- [ ] Code is committed with proper message format: `feat(<feature>): <task title>`
- [ ] `IMPLEMENTATION_COMPLETE` signal sent with files, test file, and commit hash
- [ ] No rejection feedback items remain unaddressed (if retry)
