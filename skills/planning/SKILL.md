---
name: planning
description: "[opus] Break specifications into test-bounded, commit-sized tasks"
model: opus
color: purple
---

# Planning Skill

## Overview

Read specification documents and decompose the feature into a sequence of test-bounded tasks. Each task represents exactly one commit with at least one verifying test (unless explicitly exempted). This skill transforms high-level specifications into executable implementation units.

The planning process analyzes the technical design, identifies dependencies between components, and produces task files that can be worked on independently or in sequence by the conductor.

---

## Input Schema (JSON)

The discovery skill provides input as a JSON object:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["worktree_path", "spec_paths"],
  "properties": {
    "worktree_path": { "type": "string" },
    "session_id": { "type": "string" },
    "branch": { "type": "string" },
    "spec_paths": {
      "type": "object",
      "required": ["prd", "adr", "technical_design"],
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

### Example Input

```json
{
  "worktree_path": "../myapp-create-user-auth-a1b2c3d4",
  "session_id": "user-auth-a1b2c3d4",
  "branch": "create/user-auth-a1b2c3d4",
  "spec_paths": {
    "prd": "docs/specs/PRD.md",
    "adr": "docs/specs/ADR.md",
    "technical_design": "docs/specs/TECHNICAL_DESIGN.md",
    "wireframes": "docs/specs/WIREFRAMES.md"
  },
  "config": { "auto_mode": false }
}
```

---

## Output Schema (JSON)

When planning completes, output a JSON signal:

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

## Input Documents

Read the following documents from the worktree's `docs/specs/` directory:

| Document | Purpose |
|----------|---------|
| PRD.md | User stories, acceptance criteria, success metrics |
| ADR.md | Architecture decisions and rationale |
| TECHNICAL_DESIGN.md | Components, data models, API contracts, dependencies |
| WIREFRAMES.md | UI layouts and user flows (if applicable) |

Also read:
- `state.json` - Current workflow state and configuration
- `CLAUDE.md` - Project conventions and patterns

### Load Traceability from State

Planning MUST preserve traceability links from discovery:

```javascript
// Load state.json and extract traceability
const state = JSON.parse(fs.readFileSync('state.json'));
const traceability = state.traceability;

// When creating each task, populate traces_to:
function createTask(taskData, traceability) {
  return {
    ...taskData,
    traces_to: {
      user_stories: findMatchingStories(taskData, traceability),
      acceptance_criteria: findMatchingCriteria(taskData, traceability),
      adr_decisions: findMatchingDecisions(taskData, traceability)
    }
  };
}

function findMatchingCriteria(task, traceability) {
  // Match task objective/acceptance_criteria to traceability.acceptance_criteria
  const matches = [];
  for (const [acId, ac] of Object.entries(traceability.acceptance_criteria)) {
    if (task.acceptance_criteria.some(tc =>
      tc.criterion.toLowerCase().includes(ac.description.toLowerCase().slice(0, 20))
    )) {
      matches.push(acId);
    }
  }
  return matches;
}
```

**Validation:** After creating tasks.json, verify coverage:

```bash
# Check every AC from state.json maps to at least one task
jq -r '.traceability.acceptance_criteria | keys[]' state.json | while read ac; do
  if ! jq -e ".tasks[] | select(.traces_to.acceptance_criteria | contains([\"$ac\"]))" docs/tasks.json > /dev/null; then
    echo "COVERAGE_GAP: $ac has no implementing task"
  fi
done
```

---

## Task Decomposition Rules

### Each Task Must Be:

1. **Completable in a single commit** - No partial implementations
2. **Test-bounded** - At least one test verifies the task is done
3. **Clearly scoped** - Acceptance criteria derived from specs
4. **Dependency-aware** - Explicitly declares what it depends on

### Task Sizing Guide

**Too Big (split it):**
- Implements multiple user stories
- Touches more than 3-4 files substantially
- Would take more than ~1 hour to implement
- Has acceptance criteria spanning multiple concerns
- Example: "Implement user authentication" (split into: schema, model, routes, middleware, tests)

**Right Size:**
- Single focused change
- One clear acceptance criterion
- Testable in isolation
- 15-45 minutes of implementation
- Example: "Add User model with password hashing"

**Too Small (combine it):**
- Adds a single constant or type
- Changes only whitespace or formatting
- Cannot be meaningfully tested alone
- Example: "Add USER_ROLES constant" (combine with model that uses it)

### No-Test Exceptions

The following task types may skip the test requirement:

| Exception | Reason | Verification Alternative |
|-----------|--------|-------------------------|
| Documentation only | No code behavior to test | Manual review |
| Configuration files | Static data, no logic | Schema validation |
| Type definitions only | TypeScript/Flow types | Type checker passes |
| Dependency updates | Third-party code | Existing tests pass |
| Delete dead code | Removal only | Existing tests pass |

When using an exception, the task must include:
```yaml
test_file: null
no_test_reason: "documentation only"
```

### Task Type Classification (Model Routing)

Classify each task to determine which model executes it:

| Task Type | Model | Decomposable | Examples |
|-----------|-------|--------------|----------|
| `add_field` | haiku | no | Add email field to User model |
| `add_method` | haiku | no | Add validateEmail() to User |
| `add_validation` | haiku | no | Add input validation to handler |
| `rename_refactor` | haiku | no | Rename userId to id across files |
| `add_test` | haiku | no | Add unit test for existing function |
| `add_config` | haiku | no | Add environment variable |
| `create_model` | sonnet | yes | Create User model with validation |
| `create_service` | sonnet | yes | Create AuthService with methods |
| `add_endpoint` | haiku | no | Add GET /users route (simple) |
| `add_endpoint_complex` | sonnet | yes | Add POST /auth/login with JWT |
| `create_middleware` | sonnet | yes | Create auth middleware |
| `bug_fix` | sonnet | no | Fix race condition in cache |
| `integration_test` | sonnet | no | Add e2e test for auth flow |
| `architectural` | opus | no | Design plugin system |

**Classification Rules:**
1. Default to `haiku` for mechanical, pattern-following tasks
2. Use `sonnet` when task requires design decisions or security implications
3. Use `opus` only for architectural tasks requiring broad context
4. If `decomposable=true`, break into haiku-sized subtasks

**Decomposition Patterns:**

| Parent Type | Subtask Pattern |
|-------------|-----------------|
| `create_model` | create_class → add_field (each) → add_method (each) |
| `create_service` | create_interface → implement_method (each) → add_error_handling |
| `add_endpoint_complex` | add_route → add_validation → add_auth_check → add_handler |
| `create_middleware` | create_function → add_token_validation → add_error_response |

---

## Process

### 1. Analyze Scope

Read TECHNICAL_DESIGN.md and extract:

```bash
cd "$WORKTREE_PATH"

# Parse the technical design
cat docs/specs/TECHNICAL_DESIGN.md

# Identify components mentioned
grep -E "^#{1,3} " docs/specs/TECHNICAL_DESIGN.md

# Check for data models
grep -A 20 "Data Model" docs/specs/TECHNICAL_DESIGN.md

# Check for API endpoints
grep -A 20 "API" docs/specs/TECHNICAL_DESIGN.md
```

Create a mental model of:
- Core components and their responsibilities
- Data flow between components
- External dependencies and integrations
- Testing strategy from specs

---

### 1.5 Validate Acceptance Criteria Testability

Before creating tasks, validate that all acceptance criteria from the PRD are testable.

#### Testable Pattern Recognition

| Pattern | Regex | Example |
|---------|-------|---------|
| Behavioral | `(Given\|When\|Then)` | "Given a user, when they log in, then session is created" |
| Assertion | `(should\|must\|can\|will) [a-z]+ [a-z]+` | "User must see error message" |
| Quantitative | `[<>=≤≥] ?[0-9]` | "Response time < 500ms" |

#### Invalid Patterns to Reject

| Pattern | Example | Problem |
|---------|---------|---------|
| Adjective-only | "should be user-friendly" | No observable outcome |
| Vague outcome | "should work correctly" | "correctly" is undefined |
| No threshold | "must be fast" | No measurable target |
| Passive/vague | "errors are handled" | What handling? |

#### Validation Process

```bash
cd "$WORKTREE_PATH"

# Extract all acceptance criteria from PRD
grep -E "^\s*-\s*\[" docs/specs/PRD.md > /tmp/criteria.txt

# Check each criterion for testable patterns
while read -r line; do
  criterion=$(echo "$line" | sed 's/^[^]]*\] *//')

  # Check for valid patterns
  if echo "$criterion" | grep -qE "(Given|When|Then)"; then
    pattern="behavioral"
  elif echo "$criterion" | grep -qE "(should|must|can|will) [a-z]+ [a-z]+"; then
    pattern="assertion"
  elif echo "$criterion" | grep -qE "[<>=≤≥] ?[0-9]"; then
    pattern="quantitative"
  else
    echo "UNTESTABLE: $criterion"
    pattern="invalid"
  fi

  echo "$pattern: $criterion"
done < /tmp/criteria.txt
```

#### Transform to Test Assertions

For each valid criterion, generate a corresponding test assertion:

| Criterion Pattern | Test Assertion Template |
|-------------------|------------------------|
| "User must see X" | `expect(screen.getByText('X')).toBeVisible()` |
| "API returns X" | `expect(response.body).toEqual(X)` |
| "X < N" | `expect(X).toBeLessThan(N)` |
| "Given A, when B, then C" | `describe('given A', () => { it('when B, should C', ...) })` |

**Example Transformation:**

| Criterion | Test Assertion |
|-----------|----------------|
| "User must see error message on invalid email" | `expect(screen.getByRole('alert')).toHaveTextContent(/invalid email/i)` |
| "Password must be >= 8 characters" | `expect(validatePassword('1234567')).toBe(false)` |
| "API response < 200ms" | `expect(responseTime).toBeLessThan(200)` |

Include these transformations in task files under the "Acceptance Criteria" table.

---

### 2. Create Dependency Graph

Map out which components depend on others. Visualize as ASCII:

```
                    ┌─────────────┐
                    │   Schema    │
                    │  (001-xxx)  │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  Model   │ │  Model   │ │  Types   │
        │ (002-xx) │ │ (003-xx) │ │ (004-xx) │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │            │            │
             └────────────┼────────────┘
                          │
                          ▼
                   ┌────────────┐
                   │  Service   │
                   │  (005-xx)  │
                   └──────┬─────┘
                          │
             ┌────────────┼────────────┐
             │            │            │
             ▼            ▼            ▼
       ┌──────────┐ ┌──────────┐ ┌──────────┐
       │  Route   │ │  Route   │ │Middleware│
       │ (006-xx) │ │ (007-xx) │ │ (008-xx) │
       └──────────┘ └──────────┘ └──────────┘
```

**Rules for ordering:**
1. Foundation tasks first (schemas, types, configs)
2. Data layer before business logic
3. Business logic before API/UI
4. Integration tests after unit tests
5. Documentation last

---

### 3. Write tasks.json

Create a single `tasks.json` file containing all tasks:

```
docs/
├── specs/
│   ├── PRD.md
│   ├── ADR.md
│   └── TECHNICAL_DESIGN.md
└── tasks.json          # All tasks in one file
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
              "test_assertion": { "type": "string" }
            }
          }
        },
        "test_file": { "type": ["string", "null"] },
        "no_test_reason": { "type": "string" },
        "status": { "enum": ["pending", "in_progress", "completed", "blocked", "failed"] },
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
        "model": { "enum": ["opus", "sonnet", "haiku"], "default": "sonnet" },
        "subtasks": { "type": "array", "items": { "$ref": "#/definitions/task" } }
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
          "test_assertion": "expect(columns).toContain(['id', 'email', 'password_hash'])"
        },
        {
          "id": "AC-002",
          "criterion": "Email has unique constraint",
          "test_assertion": "expect(insertDuplicate).toThrow(/unique/i)"
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
      "model": "haiku"
    },
    {
      "id": "002",
      "title": "Create User model with validation",
      "objective": "Implement User model class with email validation and password hashing.",
      "task_type": "create_model",
      "methodology": "tdd",
      "acceptance_criteria": [
        {
          "id": "AC-003",
          "criterion": "User model validates email format",
          "test_assertion": "expect(User.validate({email: 'invalid'})).toBe(false)"
        },
        {
          "id": "AC-004",
          "criterion": "Password is hashed on creation",
          "test_assertion": "expect(user.password_hash).not.toBe(plainPassword)"
        }
      ],
      "test_file": "tests/models/user.test.ts",
      "status": "pending",
      "depends_on": ["001"],
      "traces_to": {
        "user_stories": ["US-001"],
        "acceptance_criteria": ["AC-003", "AC-004"]
      },
      "model": "sonnet"
    }
  ]
}
```

#### Task Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | Yes | Sequential ID: "001", "002", or subtask "001a", "001b" |
| title | string | Yes | Brief, imperative task description |
| objective | string | Yes | What this task accomplishes |
| task_type | enum | Yes | Classification for model routing (see Task Type Classification) |
| methodology | enum | No | `tdd` (default) or `direct` for config/docs only |
| acceptance_criteria | array | Yes | List of criteria with test assertions |
| test_file | string | Conditional | Path to test file, null if exception applies |
| no_test_reason | string | Conditional | Required if test_file is null |
| status | enum | Yes | pending, in_progress, completed, blocked, failed |
| depends_on | array | Yes | Task IDs that must complete first |
| traces_to | object | Yes | Links to user stories, acceptance criteria, ADR decisions |
| technical_notes | string | No | Implementation hints from specs |
| model | enum | No | Which model executes: opus, sonnet (default), haiku |
| subtasks | array | No | Decomposed subtasks for Haiku execution |

#### Model Selection Guidelines

| Task Complexity | Model | Examples |
|-----------------|-------|----------|
| **Complex** | opus | Architecture decisions, complex algorithms, refactoring |
| **Standard** | sonnet | Most implementation tasks (default) |
| **Simple** | haiku | Single-file changes, straightforward CRUD, config updates |

#### Subtask Decomposition for Haiku

When a task is too complex for Haiku, decompose into subtasks:

```json
{
  "id": "002",
  "title": "Create User model with validation",
  "model": "sonnet",
  "status": "pending",
  "subtasks": [
    {
      "id": "002a",
      "title": "Create User class with fields",
      "objective": "Define User class with id, email, password_hash fields",
      "acceptance_criteria": [
        {"id": "AC-003a", "criterion": "User class exists with required fields"}
      ],
      "test_file": "tests/models/user.test.ts",
      "status": "pending",
      "depends_on": ["001"],
      "model": "haiku"
    },
    {
      "id": "002b",
      "title": "Add email validation to User",
      "objective": "Add validateEmail() method that checks format",
      "acceptance_criteria": [
        {"id": "AC-003b", "criterion": "validateEmail returns false for invalid format"}
      ],
      "test_file": "tests/models/user.test.ts",
      "status": "pending",
      "depends_on": ["002a"],
      "model": "haiku"
    },
    {
      "id": "002c",
      "title": "Add password hashing to User",
      "objective": "Hash password on User creation using bcrypt",
      "acceptance_criteria": [
        {"id": "AC-004", "criterion": "Password is hashed, not stored in plain text"}
      ],
      "test_file": "tests/models/user.test.ts",
      "status": "pending",
      "depends_on": ["002a"],
      "model": "haiku"
    }
  ]
}
```

**Subtask Rules:**
- Subtask IDs use parent ID + letter suffix: "002a", "002b"
- Each subtask should be completable in ~5-10 minutes
- Subtasks can depend on each other or parent's dependencies
- Parent task completes when all subtasks complete

---

### 4. Update State

After creating tasks.json, update state.json to reference it:

```json
{
  "session_id": "user-auth-a1b2c3d4",
  "branch": "create/user-auth-a1b2c3d4",
  "worktree": "../myapp-create-user-auth-a1b2c3d4",
  "feature": "user-auth",
  "created_at": "2026-01-25T10:00:00Z",
  "phase": "implementing",
  "spec_paths": {
    "prd": "docs/specs/PRD.md",
    "adr": "docs/specs/ADR.md",
    "technical_design": "docs/specs/TECHNICAL_DESIGN.md",
    "wireframes": "docs/specs/WIREFRAMES.md"
  },
  "tasks_file": "docs/tasks.json",
  "current_task": null,
  "config": {
    "auto_mode": false,
    "timeout_minutes": 30,
    "max_identical_rejections": 3,
    "max_iterations_without_progress": 3,
    "retries": {
      "same_agent": 2,
      "fresh_agent": 1
    }
  },
  "progress": {
    "iteration": 0,
    "tasks_completed_this_iteration": 0,
    "last_completion_iteration": 0
  },
  "skill_log": []
}
```

**Key changes from markdown approach:**
- `tasks_file` replaces `tasks_dir` - points to single JSON file
- Task status lives in tasks.json, not state.json
- Traceability links are embedded in each task's `traces_to` field

#### Conductor jq Queries

The conductor uses jq to efficiently query tasks.json:

```bash
# Get next pending task (respecting dependencies)
jq -r '
  .tasks[] |
  select(.status == "pending") |
  select(
    .depends_on | length == 0 or
    all(. as $dep | $tasks | map(select(.id == $dep and .status == "completed")) | length > 0)
  ) |
  .id
' docs/tasks.json | head -1

# Get task by ID
jq '.tasks[] | select(.id == "002")' docs/tasks.json

# Get task input for implementer (minimal fields)
jq '{
  task: (.tasks[] | select(.id == "002") | {id, title, objective, acceptance_criteria, test_file}),
  spec_paths: $state.spec_paths,
  worktree_path: $state.worktree
}' --slurpfile state state.json docs/tasks.json

# Update task status
jq '(.tasks[] | select(.id == "002")).status = "completed"' docs/tasks.json > tmp.json && mv tmp.json docs/tasks.json

# Count pending tasks
jq '[.tasks[] | select(.status == "pending")] | length' docs/tasks.json

# Get all subtasks for a parent
jq '.tasks[] | select(.id == "002") | .subtasks // []' docs/tasks.json
```

---

### 5. Transition

After creating tasks.json:

1. **Commit the tasks file:**
   ```bash
   cd "$WORKTREE_PATH"

   # Count tasks
   TASK_COUNT=$(jq '.tasks | length' docs/tasks.json)
   SUBTASK_COUNT=$(jq '[.tasks[].subtasks // [] | length] | add' docs/tasks.json)

   git add docs/tasks.json state.json
   git commit -m "plan: create ${TASK_COUNT} tasks for implementation

   Tasks: ${TASK_COUNT} (${SUBTASK_COUNT} subtasks)
   Ready for implementation phase.

   Task list:
   $(jq -r '.tasks[] | "- \(.id): \(.title)"' docs/tasks.json)"
   ```

2. **Spawn Conductor Agent (Fresh Context)**

   Use the Task tool to spawn conductor in a fresh agent context:

   ```javascript
   Task({
     description: "Execute implementation loop",
     subagent_type: "general-purpose",
     model: "haiku",  // Conductor uses haiku - scheduling is mechanical
     prompt: `Use the homerun:conductor skill.

     Worktree: ${state.worktree}
     State file: ${state.worktree}/state.json

     Read state.json, find pending tasks, and orchestrate parallel implementation.`
   });
   ```

   **Why haiku for conductor:**
   - Conductor does mechanical scheduling, not deep reasoning
   - Reading state, finding ready tasks, spawning agents
   - Cost-effective for the orchestration loop
   - Implementers/Reviewers use appropriate models per task complexity

   **Why Task agent instead of direct invocation:**
   - Planning deliberation no longer consuming tokens
   - Conductor starts fresh with ~5-10K tokens
   - Implementer/Reviewer agents also spawn fresh (nested Task agents)
   - Each phase runs at optimal context capacity

3. **Output signal to main session:**

   ```json
   {
     "signal": "PLANNING_COMPLETE",
     "task_count": N,
     "message": "Spawned conductor agent. Implementation loop started."
   }
   ```

---

## Output Structure

After planning completes, the worktree should contain:

```
docs/
├── specs/
│   ├── PRD.md
│   ├── ADR.md
│   ├── TECHNICAL_DESIGN.md
│   └── WIREFRAMES.md
└── tasks/
    ├── 001-setup-schema.md
    ├── 002-user-model.md
    ├── 003-session-model.md
    ├── 004-auth-service.md
    ├── 005-login-endpoint.md
    ├── 006-register-endpoint.md
    ├── 007-auth-middleware.md
    └── 008-integration-tests.md
```

---

## Exit Criteria

Before transitioning to implementation, verify all criteria are met:

- [ ] All specification documents read and analyzed
- [ ] Dependency graph created showing task relationships
- [ ] Each task is single-commit sized
- [ ] Each task has test file specified (or valid exception documented)
- [ ] Acceptance criteria trace back to specs
- [ ] Task files written in docs/tasks/NNN-slug.md format
- [ ] Task frontmatter includes id, title, status, depends_on, test_file
- [ ] state.json updated with phase: "implementing" and tasks object
- [ ] All task files committed to the feature branch
- [ ] User confirmed ready to proceed (or auto_mode enabled)

---

## Phase Transition Validation Gate

**REQUIRED:** Before transitioning to implementation phase, run these automated validations:

### DAG Cycle Detection (REQUIRED)

Task dependencies MUST form a Directed Acyclic Graph. **This validation is REQUIRED before transition.**

If cycle detection fails:
1. **Do not output PLANNING_COMPLETE**
2. Fix the cycle by reordering tasks
3. Re-validate

Task dependencies must form a Directed Acyclic Graph (no circular dependencies):

```bash
cd "$WORKTREE_PATH"

# Extract task dependencies and check for cycles
# Build adjacency list from task frontmatter
declare -A deps
for task_file in docs/tasks/*.md; do
  task_id=$(grep "^id:" "$task_file" | sed 's/id: *"\([^"]*\)".*/\1/')
  depends_on=$(grep "^depends_on:" "$task_file" | sed 's/depends_on: *\[\(.*\)\]/\1/' | tr -d '"' | tr ',' '\n')
  deps[$task_id]="$depends_on"
done

# Simple cycle detection via DFS
detect_cycle() {
  local node=$1
  local -n visited=$2
  local -n rec_stack=$3

  visited[$node]=1
  rec_stack[$node]=1

  for neighbor in ${deps[$node]}; do
    if [[ -z ${visited[$neighbor]} ]]; then
      if detect_cycle "$neighbor" visited rec_stack; then
        return 0
      fi
    elif [[ ${rec_stack[$neighbor]} -eq 1 ]]; then
      echo "VALIDATION_FAILED: Cycle detected involving task $neighbor"
      return 0
    fi
  done

  rec_stack[$node]=0
  return 1
}

# Run cycle detection on all nodes
declare -A visited rec_stack
for task_id in "${!deps[@]}"; do
  if [[ -z ${visited[$task_id]} ]]; then
    detect_cycle "$task_id" visited rec_stack
  fi
done
```

**Alternative: JavaScript validation using Kahn's algorithm:**

```javascript
function validateDAG(tasks) {
  // Build adjacency list
  const graph = new Map();
  tasks.forEach(t => graph.set(t.id, t.depends_on || []));

  // Kahn's algorithm for cycle detection
  const inDegree = new Map();
  tasks.forEach(t => inDegree.set(t.id, 0));

  graph.forEach((deps, id) => {
    deps.forEach(dep => {
      inDegree.set(dep, (inDegree.get(dep) || 0) + 1);
    });
  });

  const queue = [...inDegree.entries()].filter(([_, d]) => d === 0).map(([id]) => id);
  const sorted = [];

  while (queue.length) {
    const node = queue.shift();
    sorted.push(node);
    (graph.get(node) || []).forEach(neighbor => {
      inDegree.set(neighbor, inDegree.get(neighbor) - 1);
      if (inDegree.get(neighbor) === 0) queue.push(neighbor);
    });
  }

  if (sorted.length !== tasks.length) {
    const inCycle = tasks.filter(t => !sorted.includes(t.id)).map(t => t.id);
    return { valid: false, cycle: inCycle };
  }
  return { valid: true, order: sorted };
}

// Usage:
const result = validateDAG(tasks);
if (!result.valid) {
  console.error('VALIDATION_FAILED: Cycle detected involving tasks:', result.cycle);
  // DO NOT proceed to PLANNING_COMPLETE
}
```

### Test File Path Validation

Every task with a `test_file` specified must have a valid path pattern:

```bash
# Validate test file paths are reasonable
for task_file in docs/tasks/*.md; do
  test_file=$(grep "^test_file:" "$task_file" | sed 's/test_file: *//')

  # Skip if test_file is null or empty
  if [[ "$test_file" == "null" ]] || [[ -z "$test_file" ]]; then
    no_test_reason=$(grep "^no_test_reason:" "$task_file")
    if [[ -z "$no_test_reason" ]]; then
      echo "VALIDATION_FAILED: $task_file has no test_file and no no_test_reason"
    fi
    continue
  fi

  # Check test file path follows common patterns
  if ! echo "$test_file" | grep -qE "(test|spec|_test|\.test\.|\.spec\.)" ; then
    echo "VALIDATION_WARNING: $task_file test_file '$test_file' may not be a test file"
  fi
done
```

### Acceptance Criteria Coverage

Every acceptance criterion from the PRD must map to at least one task:

```bash
# Extract acceptance criteria IDs from PRD
prd_criteria=$(grep -E "^\s*-\s*\[" docs/specs/PRD.md | wc -l)

# Count criteria referenced across all tasks
task_criteria=$(grep -E "^\s*-\s*\[" docs/tasks/*.md | wc -l)

if [[ $task_criteria -lt $prd_criteria ]]; then
  echo "VALIDATION_WARNING: PRD has $prd_criteria criteria but tasks only cover $task_criteria"
fi

# Check each task references its source criteria
for task_file in docs/tasks/*.md; do
  if ! grep -q "From PRD\|traces_to\|Acceptance Criteria" "$task_file"; then
    echo "VALIDATION_WARNING: $task_file does not reference source acceptance criteria"
  fi
done
```

### Dependency Ordering Validation

Tasks must be ordered so dependencies come first:

```bash
# Check that no task depends on a higher-numbered task
for task_file in docs/tasks/*.md; do
  task_id=$(grep "^id:" "$task_file" | sed 's/id: *"\([^"]*\)".*/\1/')
  task_num=${task_id//[!0-9]/}

  depends_on=$(grep "^depends_on:" "$task_file" | sed 's/depends_on: *\[\(.*\)\]/\1/')
  for dep in $(echo "$depends_on" | tr ',' '\n' | tr -d '"' | tr -d ' '); do
    dep_num=${dep//[!0-9]/}
    if [[ -n "$dep_num" ]] && [[ $dep_num -ge $task_num ]]; then
      echo "VALIDATION_FAILED: Task $task_id depends on $dep which comes later in sequence"
    fi
  done
done
```

### Validation Response

If any `VALIDATION_FAILED` errors occur:
1. **Do not transition** to the implementation phase
2. Present the specific validation failures to the user
3. Fix the task files (reorder, remove cycles, add missing test files)
4. Re-run validation after corrections

If only `VALIDATION_WARNING` items occur:
1. Present warnings to the user
2. Ask: "These items may cause issues during implementation. Would you like to address them now or proceed with caution?"
3. On "proceed", continue to implementation phase
4. On "address", fix the identified issues
