---
name: implement
description: Use when assigned a task by the conductor to implement it using TDD
---

# Implement Skill

## Overview

You are an **implementer agent**. Your job: implement ONE task, commit, and signal completion.

The conductor specifies the methodology (e.g., TDD) in the input JSON.

## Input Schema (JSON)

The conductor provides input as a JSON object. **Validate input before proceeding.**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["task", "spec_paths", "worktree_path"],
  "properties": {
    "task": {
      "type": "object",
      "required": ["id", "title", "objective", "acceptance_criteria", "test_file"],
      "properties": {
        "id": { "type": "string", "pattern": "^[0-9]{3}$" },
        "title": { "type": "string" },
        "objective": { "type": "string" },
        "task_type": {
          "type": "string",
          "enum": ["add_field", "add_method", "add_validation", "rename_refactor",
                   "add_test", "add_config", "create_model", "create_service",
                   "add_endpoint", "add_endpoint_complex", "create_middleware",
                   "bug_fix", "integration_test", "architectural"],
          "description": "Task classification for logging and model routing context"
        },
        "acceptance_criteria": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["id", "criterion"],
            "properties": {
              "id": { "type": "string", "pattern": "^AC-[0-9]{3}$" },
              "criterion": { "type": "string" }
            }
          }
        },
        "test_file": { "type": ["string", "null"] }
      }
    },
    "spec_paths": {
      "type": "object",
      "required": ["technical_design", "adr"],
      "properties": {
        "technical_design": { "type": "string" },
        "adr": { "type": "string" }
      }
    },
    "methodology": {
      "type": "string",
      "enum": ["tdd", "direct"],
      "default": "tdd",
      "description": "Implementation approach: 'tdd' for test-driven, 'direct' for config-only changes"
    },
    "previous_feedback": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "attempt": { "type": "integer" },
          "issues": { "type": "array", "items": { "type": "string" } },
          "required_fixes": { "type": "array", "items": { "type": "string" } }
        }
      }
    },
    "worktree_path": { "type": "string" }
  }
}
```

### Example Input

```json
{
  "task": {
    "id": "002",
    "title": "Implement user authentication service",
    "objective": "Create auth service with login and session management",
    "task_type": "create_service",
    "acceptance_criteria": [
      {"id": "AC-001", "criterion": "User can log in with valid credentials"},
      {"id": "AC-002", "criterion": "Invalid credentials return 401 error"}
    ],
    "test_file": "tests/services/auth.test.ts"
  },
  "methodology": "tdd",
  "spec_paths": {
    "technical_design": "docs/specs/TECHNICAL_DESIGN.md",
    "adr": "docs/specs/ADR.md"
  },
  "previous_feedback": [],
  "worktree_path": "/path/to/worktree"
}
```

### Input Validation

**Before any implementation work, validate the input:**

1. Check all required fields are present
2. Verify `task.id` matches pattern `^[0-9]{3}$`
3. Verify `acceptance_criteria` is non-empty array
4. Verify `spec_paths.technical_design` and `spec_paths.adr` files exist

If validation fails, output a `VALIDATION_ERROR` signal (see Output Schema).

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

### 3. Apply Methodology

Follow the methodology specified in the input JSON (default: `tdd`).

#### If methodology is `tdd` (default):

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

#### If methodology is `direct`:

For config-only or documentation tasks with no testable behavior:
- Implement the change directly
- Verify the change works as expected
- No test required (task should have `test_file: null`)

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

Output the completion signal in **JSON format** (required for conductor parsing).

---

## Output Schema (JSON)

All output MUST be valid JSON wrapped in a code block with language `json`.

### Success: IMPLEMENTATION_COMPLETE

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["signal", "files_changed", "test_file", "commit_hash", "acceptance_criteria_met"],
  "properties": {
    "signal": { "const": "IMPLEMENTATION_COMPLETE" },
    "files_changed": { "type": "array", "items": { "type": "string" } },
    "test_file": { "type": "string" },
    "commit_hash": { "type": "string", "pattern": "^[a-f0-9]{7,40}$" },
    "acceptance_criteria_met": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["criterion", "test"],
        "properties": {
          "criterion": { "type": "string" },
          "test": { "type": "string" }
        }
      }
    }
  }
}
```

**Example:**

```json
{
  "signal": "IMPLEMENTATION_COMPLETE",
  "files_changed": ["src/models/user.ts", "src/services/auth.ts"],
  "test_file": "tests/services/auth.test.ts",
  "commit_hash": "abc1234",
  "acceptance_criteria_met": [
    {"criterion": "AC-001", "test": "should create user with valid email"},
    {"criterion": "AC-002", "test": "should reject duplicate emails"}
  ]
}
```

### Blocked: IMPLEMENTATION_BLOCKED

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["signal", "reason", "blocker_type", "suggested_resolution"],
  "properties": {
    "signal": { "const": "IMPLEMENTATION_BLOCKED" },
    "reason": { "type": "string" },
    "blocker_type": { "enum": ["missing_dependency", "unclear_requirements", "technical_constraint", "test_failure"] },
    "details": { "type": "array", "items": { "type": "string" } },
    "suggested_resolution": { "type": "string" }
  }
}
```

**Example:**

```json
{
  "signal": "IMPLEMENTATION_BLOCKED",
  "reason": "Cannot find the User model referenced in TECHNICAL_DESIGN.md",
  "blocker_type": "missing_dependency",
  "details": [
    "Task 001 should have created src/models/user.ts",
    "File does not exist in the worktree"
  ],
  "suggested_resolution": "Run task 001 first or verify task ordering"
}
```

**Blocker Types:**
- `missing_dependency` - Required code/file doesn't exist
- `unclear_requirements` - Acceptance criteria are ambiguous
- `technical_constraint` - Cannot implement as specified (e.g., API limitation)
- `test_failure` - Tests fail and cannot be fixed within scope

### Validation Error: VALIDATION_ERROR

Return this if input validation fails:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["signal", "error_type", "errors"],
  "properties": {
    "signal": { "const": "VALIDATION_ERROR" },
    "error_type": { "enum": ["invalid_input", "semantic_error"] },
    "errors": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["path", "message"],
        "properties": {
          "path": { "type": "string", "description": "JSON path to invalid field, e.g., $.task.id" },
          "message": { "type": "string" },
          "expected": { "type": "string" },
          "received": { "type": "string" }
        }
      }
    }
  }
}
```

**Example:**

```json
{
  "signal": "VALIDATION_ERROR",
  "error_type": "invalid_input",
  "errors": [
    {
      "path": "$.task.acceptance_criteria",
      "message": "acceptance_criteria array is empty",
      "expected": "non-empty array",
      "received": "[]"
    }
  ]
}
```

## Red Flags - STOP

If you find yourself in any of these situations, STOP and correct course:

**For TDD methodology:**
- **About to write code before test** - You must write the failing test first
- **Test passes immediately** - The test is not testing new behavior; rewrite it
- **Skipping acceptance criterion** - Every criterion needs a corresponding test
- **"I'll add tests later"** - This violates TDD; tests come first, always
- **Modifying code to make a test pass that should fail** - Tests drive implementation, not the reverse

**For all methodologies:**
- **Implementing beyond the task scope** - Stick to the assigned task only

## Exit Criteria

Before signaling completion, verify this checklist:

**For TDD methodology:**
- [ ] All acceptance criteria have corresponding passing tests
- [ ] Tests were written BEFORE implementation code

**For direct methodology:**
- [ ] All acceptance criteria are implemented
- [ ] Change verified to work as expected

**For all methodologies:**
- [ ] Code is committed with proper message format: `feat(<feature>): <task title>`
- [ ] `IMPLEMENTATION_COMPLETE` signal sent with files, test file, and commit hash
- [ ] No rejection feedback items remain unaddressed (if retry)
