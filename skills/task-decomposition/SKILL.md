---
name: task-decomposition
description: "[opus] Decompose scope analysis into test-bounded, commit-sized tasks with DAG dependencies"
model: opus
color: purple
---

# Task Decomposition Skill

## References

`references/model-routing.json` · `cookbooks/task-decomposition-examples.md` · `references/context-engineering.md`

## Overview

Decompose pre-analyzed scope → test-bounded tasks. Each task = one commit + verifying test(s). Input: `docs/scope-analysis.json` from scope-analyzer (or user prompt for small-scale flat list mode). Output: executable implementation units in `docs/tasks.json`.

**Model: opus** — decomposition is high-leverage; poor boundaries cascade into implementation failures. Does NOT read raw specs, validate ACs, or extract components (scope-analysis handles those).

### Flat List Mode (Small Scale)

When dispatched with `flat_list_mode: true` (small-scale tasks, 2-4 files):
- Produce a **flat task list** with no dependencies (`depends_on: []` for all tasks)
- Skip DAG construction — tasks will be dispatched sequentially
- Read the user prompt and codebase directly instead of `docs/scope-analysis.json` (which won't exist for small tasks)
- Still produce valid `docs/tasks.json` with all required fields per the schema below

---

## Input

### Primary Input: docs/scope-analysis.json

The scope-analyzer produces this file with:
- `components` — Identified components with layer classification
- `data_models` — Extracted data models with fields and relationships
- `api_contracts` — API endpoints with request/response schemas
- `external_dependencies` — Third-party dependencies
- `acceptance_criteria` — Validated ACs with testability patterns and test assertion templates
- `jit_context_refs` — Pre-computed JIT references by component
- `non_scope` — Explicit exclusions
- `change_impact_map` — Direct and indirect impact areas
- `testing_strategy` — Overall testing approach
- `traceability` — Links from state.json

### Secondary Input: state.json

Read `state.json` for:
- `session_id` — Session identifier
- `spec_paths` — Paths to spec documents (for targeted reads if needed)
- `config` — Auto mode, retry settings

### Input Schema (JSON)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": [],
  "properties": {
    "session_id": { "type": "string" },
    "spec_paths": {
      "type": "object",
      "properties": {
        "prd": { "type": "string" },
        "adr": { "type": "string" },
        "technical_design": { "type": "string" },
        "wireframes": { "type": ["string", "null"] }
      }
    },
    "config": {
      "type": "object",
      "properties": {
        "auto_mode": { "type": "boolean" }
      }
    }
  }
}
```

---

## Output Schema (JSON)

When task decomposition completes, output a JSON signal:

### Success: PLANNING_COMPLETE

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["signal", "tasks_count", "tasks_file"],
  "properties": {
    "signal": { "const": "PLANNING_COMPLETE" },
    "tasks_count": { "type": "integer" },
    "tasks_file": { "type": "string" },
    "tasks": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "title": { "type": "string" },
          "depends_on": { "type": "array", "items": { "type": "string" } }
        }
      }
    },
    "dependency_graph_valid": { "type": "boolean" },
    "coverage": {
      "type": "object",
      "properties": {
        "user_stories": { "type": "integer" },
        "acceptance_criteria": { "type": "integer" }
      }
    }
  }
}
```

**Example:**

```json
{
  "signal": "PLANNING_COMPLETE",
  "tasks_count": 8,
  "tasks_file": "docs/tasks.json",
  "tasks": [
    {"id": "001", "title": "Setup database schema", "depends_on": []},
    {"id": "002", "title": "Create User model", "depends_on": ["001"]},
    {"id": "003", "title": "Add auth service", "depends_on": ["002"]}
  ],
  "dependency_graph_valid": true,
  "coverage": {
    "user_stories": 3,
    "acceptance_criteria": 12
  }
}
```

---

## Task Decomposition Rules

### Task Requirements

Each task: single commit, test-bounded, clearly scoped (ACs from scope analysis), dependency-aware.

**Sizing:** Too big (multiple stories, 4+ files, multi-concern ACs) → split. Right size (single change, one AC, testable alone). Too small (single constant, no testable behavior) → combine with consumer.

**No-test exceptions:** docs-only, config files, type definitions, dependency updates, dead code removal. Set `test_file: null` + `no_test_reason`.

### AC Risk-Level Classification

| Risk Level | When | Test Requirement |
|---|---|---|
| `must_test` (default) | Core behavior, security, data mutations, user input | Dedicated test per AC |
| `verify_only` | Secondary behavior, simple CRUD, happy-path | Consolidate into integration test |
| `structural` | Type/field existence, config presence | Types/lint only |

Test budget: Small 2-4, Medium 4-8, Large 10-20. Same-layer subtasks share test files.

### Placeholder Rejection (No Vague ACs)

Every AC must suggest a specific test assertion. Reject: TBD/TODO, "add appropriate error handling", "similar to Task N", vague objectives. Detection: if AC doesn't suggest a test check → placeholder. On detection → `VALIDATION_ERROR` with `semantic_error`. Do NOT output tasks.json with placeholders.

### Task Type Classification

See `references/model-routing.json`. Default haiku for mechanical tasks, sonnet for design/security decisions, opus for architectural. If `decomposable=true` → break into haiku-sized subtasks.

---

## Subtask Decomposition Rules

**MUST decompose:** ACs > 3, files > 4, 2+ architectural layers, decomposable in model-routing.json, title contains "and".
**SHOULD decompose:** Multiple test files, mixed methodologies, external deps, risk concentration.
**MUST NOT decompose:** Already haiku-level, single AC, pure refactoring, docs-only.

**Patterns:** Vertical slice (model→service→endpoint), by AC, by layer. Subtask IDs: parent + letter (001a, 001b). Each subtask: max 1 AC preferred, single file focus, haiku model unless judgment needed, clear dependency chain.

---

## Process

### 1. Read Scope Analysis

Read the scope analysis produced by the scope-analyzer:

```bash
# Read scope analysis (state.json and docs/ are in cwd during planning)
cat docs/scope-analysis.json | jq .

# Summary of components
jq '.components[] | "\(.name) [\(.layer)]: \(.responsibility)"' docs/scope-analysis.json

# Summary of acceptance criteria
jq '.acceptance_criteria[] | "\(.id): \(.criterion) [testable=\(.testable)]"' docs/scope-analysis.json

# Non-scope boundaries
jq '.non_scope[]' docs/scope-analysis.json
```

Also read `state.json` for session context and traceability:

```bash
jq '{session_id, branch, spec_paths, traceability}' state.json
```

### 2. Create Dependency Graph

Order: foundation (schemas, types, configs) → data layer → business logic → API/UI → integration tests → docs. Map component dependencies from scope-analysis.json.

### 3. Populate Task Context Refs

For each task, copy JIT refs from `scope-analysis.json → jit_context_refs.by_component[X]`: interface_locations, pattern_files, grep_patterns, constraints_section.

### 4. Write tasks.json

Create a single `tasks.json` file containing all tasks:

```
docs/
├── scope-analysis.json   # Input from scope-analyzer
├── specs/
│   ├── PRD.md
│   ├── ADR.md
│   └── TECHNICAL_DESIGN.md
└── tasks.json            # Output from task-decomposer
```

#### tasks.json Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["tasks"],
  "properties": {
    "tasks": {
      "type": "array",
      "items": { "$ref": "#/definitions/task" }
    }
  },
  "definitions": {
    "task": {
      "type": "object",
      "required": ["id", "title", "objective", "acceptance_criteria", "status", "depends_on", "task_type"],
      "properties": {
        "id": { "type": "string", "pattern": "^[0-9]{3}[a-z]?$" },
        "title": { "type": "string" },
        "objective": { "type": "string" },
        "task_type": {
          "type": "string",
          "enum": ["add_field", "add_method", "add_validation", "rename_refactor",
                   "add_test", "add_config", "create_model", "create_service",
                   "add_endpoint", "add_endpoint_complex", "create_middleware",
                   "bug_fix", "integration_test", "architectural"],
          "description": "Task classification for model routing"
        },
        "methodology": {
          "type": "string",
          "enum": ["tdd", "direct"],
          "default": "tdd",
          "description": "Implementation approach - 'direct' for config/docs only"
        },
        "acceptance_criteria": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["id", "criterion"],
            "properties": {
              "id": { "type": "string" },
              "criterion": { "type": "string" },
              "risk_level": {
                "type": "string",
                "enum": ["must_test", "verify_only", "structural"],
                "default": "must_test",
                "description": "Test requirement level — determines testing approach for this AC"
              },
              "test_assertion": { "type": "string" }
            }
          }
        },
        "test_file": { "type": ["string", "null"] },
        "no_test_reason": { "type": "string" },
        "status": { "enum": ["pending", "in_progress", "completed", "approved", "blocked", "failed", "skipped"] },
        "depends_on": { "type": "array", "items": { "type": "string" } },
        "traces_to": {
          "type": "object",
          "properties": {
            "user_stories": { "type": "array", "items": { "type": "string" } },
            "acceptance_criteria": { "type": "array", "items": { "type": "string" } },
            "adr_decisions": { "type": "array", "items": { "type": "string" } }
          }
        },
        "technical_notes": { "type": "string" },
        "context_refs": {
          "type": "object",
          "description": "JIT context references — populated from scope-analysis.json pre-computed refs",
          "properties": {
            "interface_locations": { "type": "array", "items": { "type": "string" }, "description": "File paths + section names for relevant interfaces" },
            "pattern_files": { "type": "array", "items": { "type": "string" }, "description": "Paths to existing implementations showing patterns to follow" },
            "grep_patterns": { "type": "array", "items": { "type": "string" }, "description": "Grep patterns to discover related code at runtime" },
            "constraints_section": { "type": "string", "description": "Section reference in ADR/TECHNICAL_DESIGN for constraints" }
          }
        },
        "model": { "enum": ["opus", "sonnet", "haiku"], "default": "sonnet" },
        "subtasks": { "type": "array", "items": { "$ref": "#/definitions/task" } },
        "implementation_notes": {
          "type": "object",
          "description": "Structured knowledge transfer for dependent tasks — populated on completion",
          "properties": {
            "files_changed": { "type": "array", "items": { "type": "string" }, "description": "Paths of files modified" },
            "key_decisions": { "type": "string", "description": "Non-obvious implementation choices" },
            "interfaces_established": { "type": "string", "description": "Types, exports, contracts created for downstream use" },
            "gotchas": { "type": "string", "description": "Surprises or traps for downstream tasks" }
          }
        },
        "agent_id": {
          "type": "string",
          "description": "ID of the agent currently executing this task — set by team-lead on dispatch, used for SendMessage continuation on rework"
        },
        "attempts": {
          "type": "array",
          "description": "History of execution attempts for rework tracking",
          "items": {
            "type": "object",
            "properties": {
              "agent_id": { "type": "string" },
              "status": { "type": "string", "enum": ["rejected", "completed"] },
              "severity": { "type": "string", "enum": ["low", "medium", "high"] },
              "feedback": { "type": "string" },
              "required_fixes": { "type": "array", "items": { "type": "string" }, "description": "Actionable fix instructions from reviewer's REJECTED signal" }
            }
          }
        }
      }
    }
  }
}
```

#### Example tasks.json

```json
{
  "tasks": [
    {
      "id": "001",
      "title": "Setup database schema for users",
      "objective": "Create the database schema for the users table with all required fields for authentication as specified in TECHNICAL_DESIGN.md.",
      "task_type": "add_config",
      "methodology": "tdd",
      "acceptance_criteria": [
        {
          "id": "AC-001",
          "criterion": "Users table has id, email, password_hash, created_at, updated_at",
          "test_assertion": "expect(columns).toContain(['id', 'email', 'password_hash'])",
          "risk_level": "must_test"
        },
        {
          "id": "AC-002",
          "criterion": "Email has unique constraint",
          "test_assertion": "expect(insertDuplicate).toThrow(/unique/i)",
          "risk_level": "must_test"
        }
      ],
      "test_file": "tests/schema/user.test.ts",
      "status": "pending",
      "depends_on": [],
      "traces_to": {
        "user_stories": ["US-001"],
        "acceptance_criteria": ["AC-001", "AC-002"],
        "adr_decisions": ["ADR-001"]
      },
      "technical_notes": "Use UUID for primary key. Password hash using bcrypt (ADR-001). Soft delete via deleted_at.",
      "context_refs": {
        "interface_locations": ["TECHNICAL_DESIGN.md:## Data Model:Users table"],
        "pattern_files": [],
        "grep_patterns": ["CREATE TABLE.*users", "migration.*user"],
        "constraints_section": "ADR.md:## Decision 1"
      },
      "model": "haiku",
      "agent_id": null,
      "attempts": [],
      "implementation_notes": null
    }
  ]
}
```

Required task fields: id (NNN or NNNx), title, objective, task_type, acceptance_criteria (with risk_level), status, depends_on, traces_to. Optional: methodology (tdd|direct), test_file, no_test_reason, technical_notes, context_refs, model (haiku|sonnet|opus), subtasks.

Model: haiku for simple single-file tasks, sonnet for standard (default), opus for architectural. When too complex for haiku → decompose into subtasks (parent ID + letter: 002a, 002b).

---

### 5. Validate Traceability

Every AC from scope-analysis.json must map to at least one task. Flag coverage gaps.

### 6. Update State & Transition

Update `state.json` phase → "implementing", tasks_file → "docs/tasks.json". Commit tasks.json + state.json. Emit `PLANNING_COMPLETE` signal with tasks_count, tasks_file, dependency_graph_valid, coverage. **Do NOT spawn next phase.**

## Exit Criteria

- [ ] Scope analysis read; dependency graph created; all tasks single-commit sized
- [ ] Test files specified (or valid exceptions); ACs trace to scope analysis; context_refs populated
- [ ] tasks.json + state.json committed; `PLANNING_COMPLETE` emitted
