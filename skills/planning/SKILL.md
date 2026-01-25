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
---

# 001: Setup database schema for users

## Objective

Create the database schema for the users table with all required fields
for authentication as specified in TECHNICAL_DESIGN.md.

## Acceptance Criteria

- [ ] Users table created with id, email, password_hash, created_at, updated_at
- [ ] Email has unique constraint
- [ ] Indexes added for email lookup
- [ ] Migration file created and tested

## Technical Notes

From TECHNICAL_DESIGN.md:
- Use UUID for primary key
- Password hash using bcrypt (from ADR.md decision)
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

---

### 4. Update State

After creating all task files, update state.json:

```json
{
  "session_id": "user-auth-a1b2c3d4",
  "branch": "create/user-auth-a1b2c3d4",
  "worktree": "../myapp-create-user-auth-a1b2c3d4",
  "feature": "user-auth",
  "created_at": "2026-01-25T10:00:00Z",
  "phase": "implementing",
  "tasks": {
    "001": { "status": "pending", "file": "docs/tasks/001-setup-schema.md" },
    "002": { "status": "pending", "file": "docs/tasks/002-user-model.md" },
    "003": { "status": "pending", "file": "docs/tasks/003-session-model.md" },
    "004": { "status": "pending", "file": "docs/tasks/004-auth-service.md" },
    "005": { "status": "pending", "file": "docs/tasks/005-login-endpoint.md" },
    "006": { "status": "pending", "file": "docs/tasks/006-register-endpoint.md" },
    "007": { "status": "pending", "file": "docs/tasks/007-auth-middleware.md" },
    "008": { "status": "pending", "file": "docs/tasks/008-integration-tests.md" }
  },
  "current_task": null,
  "config": {
    "auto_mode": false,
    "retries": {
      "same_agent": 2,
      "fresh_agent": 1
    }
  }
}
```

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
