---
name: planning
description: Use when discovery phase complete to break specifications into test-bounded, commit-sized tasks
---

# Planning Skill

## Overview

Read specification documents and decompose the feature into a sequence of test-bounded tasks. Each task represents exactly one commit with at least one verifying test (unless explicitly exempted). This skill transforms high-level specifications into executable implementation units.

The planning process analyzes the technical design, identifies dependencies between components, and produces task files that can be worked on independently or in sequence by the conductor.

---

## Input

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

### 3. Write Task Files

Create task files in `docs/tasks/` with this naming convention:

```
docs/tasks/
├── 001-setup-schema.md
├── 002-user-model.md
├── 003-session-model.md
├── 004-auth-service.md
├── 005-login-endpoint.md
├── 006-register-endpoint.md
├── 007-auth-middleware.md
└── 008-integration-tests.md
```

#### Task File Format

Each task file follows this structure:

```markdown
---
id: "001"
title: "Setup database schema for users"
status: pending
depends_on: []
test_file: tests/schema/user.test.ts
traces_to:
  user_stories: ["US-001"]
  acceptance_criteria: ["AC-001", "AC-002"]
  adr_decisions: ["ADR-001"]
---

# 001: Setup database schema for users

## Objective

Create the database schema for the users table with all required fields
for authentication as specified in TECHNICAL_DESIGN.md.

## Acceptance Criteria

| ID | Criterion | Test Assertion |
|----|-----------|----------------|
| AC-001 | User must provide valid email format | `expect(email).toMatch(emailRegex)` |
| AC-002 | Password must be at least 8 characters | `expect(password.length).toBeGreaterThanOrEqual(8)` |

- [ ] Users table created with id, email, password_hash, created_at, updated_at
- [ ] Email has unique constraint
- [ ] Indexes added for email lookup
- [ ] Migration file created and tested

## Technical Notes

From TECHNICAL_DESIGN.md:
- Use UUID for primary key
- Password hash using bcrypt (from ADR.md decision ADR-001)
- Soft delete support via deleted_at column

## Test Requirements

Create `tests/schema/user.test.ts`:
- Test migration applies successfully
- Test unique constraint on email
- Test index exists on email column
```

#### Frontmatter Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | Yes | Three-digit sequential ID ("001", "002") |
| title | string | Yes | Brief, imperative task description |
| status | enum | Yes | One of: pending, in_progress, completed, blocked, failed |
| depends_on | array | Yes | List of task IDs this depends on (empty for root tasks) |
| test_file | string | Conditional | Path to test file, null if exception applies |
| no_test_reason | string | Conditional | Required if test_file is null |
| traces_to | object | Yes | Traceability links to source requirements |
| traces_to.user_stories | array | Yes | List of user story IDs this task implements |
| traces_to.acceptance_criteria | array | Yes | List of AC IDs this task satisfies |
| traces_to.adr_decisions | array | No | List of ADR decision IDs affecting this task |

---

### 4. Update State

After creating all task files, update state.json with tasks and traceability links:

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
  "tasks_dir": "docs/tasks",
  "traceability": {
    "user_stories": {
      "US-001": {
        "title": "User can register with email and password",
        "acceptance_criteria": ["AC-001", "AC-002", "AC-003"],
        "tasks": ["001", "002", "006"]
      },
      "US-002": {
        "title": "User can log in with credentials",
        "acceptance_criteria": ["AC-004", "AC-005"],
        "tasks": ["004", "005", "007"]
      }
    },
    "acceptance_criteria": {
      "AC-001": { "description": "Valid email format", "story": "US-001", "tasks": ["001", "002"] },
      "AC-002": { "description": "Password >= 8 chars", "story": "US-001", "tasks": ["001", "002"] }
    },
    "adr_decisions": {
      "ADR-001": { "title": "Use bcrypt for password hashing", "tasks_affected": ["001", "002", "004"] }
    },
    "non_goals": ["NG-001: Social login (OAuth)", "NG-002: Two-factor authentication"]
  },
  "tasks": {
    "001": {
      "status": "pending",
      "file": "docs/tasks/001-setup-schema.md",
      "traces_to": { "user_stories": ["US-001"], "acceptance_criteria": ["AC-001", "AC-002"] }
    },
    "002": {
      "status": "pending",
      "file": "docs/tasks/002-user-model.md",
      "traces_to": { "user_stories": ["US-001"], "acceptance_criteria": ["AC-001", "AC-002"] }
    },
    "003": { "status": "pending", "file": "docs/tasks/003-session-model.md", "traces_to": { "user_stories": ["US-002"], "acceptance_criteria": ["AC-004"] } },
    "004": { "status": "pending", "file": "docs/tasks/004-auth-service.md", "traces_to": { "user_stories": ["US-001", "US-002"], "acceptance_criteria": ["AC-003", "AC-004"] } },
    "005": { "status": "pending", "file": "docs/tasks/005-login-endpoint.md", "traces_to": { "user_stories": ["US-002"], "acceptance_criteria": ["AC-004", "AC-005"] } },
    "006": { "status": "pending", "file": "docs/tasks/006-register-endpoint.md", "traces_to": { "user_stories": ["US-001"], "acceptance_criteria": ["AC-001", "AC-002", "AC-003"] } },
    "007": { "status": "pending", "file": "docs/tasks/007-auth-middleware.md", "traces_to": { "user_stories": ["US-002"], "acceptance_criteria": ["AC-005"] } },
    "008": { "status": "pending", "file": "docs/tasks/008-integration-tests.md", "traces_to": { "user_stories": ["US-001", "US-002"], "acceptance_criteria": ["AC-001", "AC-002", "AC-003", "AC-004", "AC-005"] } }
  },
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
  }
}
```

**Traceability Update Process:**
1. For each task created, add the task ID to the `tasks` array of each referenced user story
2. For each task created, add the task ID to the `tasks` array of each referenced acceptance criterion
3. For each task referencing an ADR decision, add the task ID to `tasks_affected`

---

### 5. Transition

After all tasks are created:

1. **Commit the task files:**
   ```bash
   cd "$WORKTREE_PATH"
   git add docs/tasks/ state.json
   git commit -m "plan: break feature into implementation tasks

   Created $(ls docs/tasks/*.md | wc -l) tasks with dependency graph.
   Ready for implementation phase.

   Tasks:
   $(ls docs/tasks/*.md | xargs -I{} basename {} .md | sed 's/^/- /')"
   ```

2. **If auto_mode is enabled:**
   - Invoke `create-workflow:conductor` skill directly
   - The conductor will pick up the first unblocked task

3. **If auto_mode is disabled:**
   - Present the task list with dependencies
   - Show the dependency graph
   - Ask: "Ready to start implementation? (This will begin executing tasks)"
   - On confirmation, invoke `create-workflow:conductor`

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

### DAG Cycle Detection

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
