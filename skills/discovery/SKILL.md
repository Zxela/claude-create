---
name: discovery
description: Use when starting /create workflow to refine ideas into PRD, ADR, Technical Design, and Wireframes through structured dialogue
---

# Discovery Skill

## Overview

Guide the user from a rough idea to complete specification documents through structured, one-question-at-a-time dialogue. This skill is the first phase of the `/create` workflow, transforming initial concepts into formal PRD, ADR, Technical Design, and Wireframe documents.

The discovery process is conversational and iterative. You ask focused questions, synthesize responses, and progressively build understanding until you have enough information to generate comprehensive specification documents.

---

## Process

### 1. Context Gathering

Before engaging the user, gather project context silently:

```bash
# Read project configuration and conventions
cat CLAUDE.md 2>/dev/null || echo "No CLAUDE.md found"

# Scan project structure to understand codebase
find . -type f -name "*.md" | head -20
ls -la src/ lib/ app/ 2>/dev/null || ls -la

# Check recent development activity
git log --oneline -10 2>/dev/null || echo "Not a git repository"

# Identify technology stack
cat package.json pyproject.toml Cargo.toml go.mod 2>/dev/null | head -50
```

Use this context to:
- Understand existing patterns and conventions
- Identify relevant technologies and dependencies
- Frame questions appropriately for the project

---

### 2. Refinement Dialogue

Engage the user with **ONE question at a time**. Prefer multiple-choice options when possible to reduce cognitive load and speed up the process.

**Question Categories (cover all):**

#### Purpose & Goals
- "What problem does this solve?"
- "Who benefits from this feature?"
- "What does success look like?"

Example:
```
What is the primary goal of this feature?

A) Add new functionality that doesn't exist yet
B) Improve or extend existing functionality
C) Fix a bug or address a limitation
D) Refactor for maintainability or performance
E) Something else (please describe)
```

#### Users & Personas
- "Who are the primary users?"
- "What's their technical level?"
- "How frequently will they use this?"

Example:
```
Who will primarily use this feature?

A) End users (customers/public)
B) Internal team members
C) API consumers / developers
D) Administrators / operators
E) Multiple user types (please specify)
```

#### Scope & Boundaries
- "What's in scope for v1?"
- "What should we explicitly NOT do?"
- "Are there related features we should avoid?"

Example:
```
Which scope level fits best for the initial implementation?

A) Minimal - Core functionality only, bare essentials
B) Standard - Core plus common use cases
C) Comprehensive - Full feature set with edge cases
D) Let me describe the specific scope...
```

#### Technical Constraints
- "Any performance requirements?"
- "Security or compliance needs?"
- "Must integrate with specific systems?"

Example:
```
Are there specific technical constraints to consider?

A) Must integrate with existing [system/API]
B) Has performance requirements (latency, throughput)
C) Security/compliance requirements (auth, encryption, audit)
D) Must support specific platforms/browsers
E) No special constraints
F) Multiple constraints (please list)
```

#### Edge Cases & Error Handling
- "What happens when X fails?"
- "How should we handle invalid input?"
- "What are the boundary conditions?"

Example:
```
How should the feature handle errors?

A) Fail fast with clear error messages
B) Gracefully degrade with fallback behavior
C) Retry automatically with backoff
D) Queue for manual review
E) Depends on the error type (let's discuss)
```

**Dialogue Guidelines:**
- Ask only ONE question per message
- Acknowledge the previous answer before asking the next question
- Build on previous answers - make connections visible
- If an answer is unclear, ask a clarifying follow-up
- Summarize understanding periodically (every 3-4 questions)

**Testability Guidance for Acceptance Criteria:**

When gathering acceptance criteria, guide users toward testable patterns. If a user provides vague criteria, help them refine it.

| User Says | Problem | Guide Toward |
|-----------|---------|--------------|
| "Should be user-friendly" | Adjective only, not testable | "What specific action should users complete easily? E.g., 'User can complete checkout in under 3 clicks'" |
| "Should work correctly" | No observable outcome | "What does 'correctly' look like? E.g., 'Returns HTTP 200 with user data'" |
| "Must be fast" | No threshold | "How fast? E.g., 'Response time < 200ms for 95th percentile'" |
| "Handle errors properly" | Vague handling | "What should happen on error? E.g., 'Display error message and preserve form input'" |

**Valid Testable Patterns:**

```
Behavioral (Given/When/Then):
"Given a logged-in user, when they click logout, then their session is destroyed"

Assertion (should/must/can + verb + outcome):
"User must see an error message when submitting an empty form"

Quantitative (comparison + threshold):
"API response time must be < 500ms for 99% of requests"
```

When a user provides vague criteria, respond with:
```
That criterion might be hard to verify in tests. Could we make it more specific?

Instead of: "{{vague_criterion}}"
Consider: "{{suggested_testable_version}}"

Would that work, or did you have something else in mind?
```

---

### 3. Document Generation

Once sufficient information is gathered, create the worktree and generate documents.

#### Create Worktree

```bash
# Generate session ID
SESSION_UUID=$(cat /proc/sys/kernel/random/uuid | cut -c1-8)
FEATURE_SLUG=$(echo "{{FEATURE_NAME}}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
BRANCH_NAME="create/${FEATURE_SLUG}-${SESSION_UUID}"

# Get repository info
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
WORKTREE_PATH="${REPO_ROOT}/../${REPO_NAME}-create-${FEATURE_SLUG}-${SESSION_UUID}"

# Create branch and worktree
git branch "$BRANCH_NAME"
git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"

# Create docs structure
mkdir -p "${WORKTREE_PATH}/docs/specs"
mkdir -p "${WORKTREE_PATH}/docs/tasks"
```

#### Write Specification Documents

Generate all documents to `docs/specs/` in the worktree:

1. **PRD.md** - Product Requirements Document
   - Problem statement from gathered context
   - Goals derived from user responses
   - User stories with acceptance criteria
   - Non-goals explicitly stated
   - Success metrics where applicable

2. **ADR.md** - Architecture Decision Record
   - Context explaining the decision drivers
   - Options considered (at least 2-3)
   - Decision with rationale
   - Consequences (positive and negative)

3. **TECHNICAL_DESIGN.md** - Technical Design Document
   - Architecture overview
   - Data models and schemas
   - API contracts if applicable
   - Dependencies (internal and external)
   - Security considerations
   - Testing strategy outline

4. **WIREFRAMES.md** - UI Wireframes (if applicable)
   - Skip for CLI, API, or library projects
   - ASCII/box diagrams for screen layouts
   - User flow diagrams
   - Component hierarchy

#### Initialize State

Create `state.json` in the worktree root with traceability structure:

```json
{
  "session_id": "user-auth-a1b2c3d4",
  "branch": "create/user-auth-a1b2c3d4",
  "worktree": "../myapp-create-user-auth-a1b2c3d4",
  "feature": "user-auth",
  "created_at": "2026-01-25T10:00:00Z",
  "phase": "discovery",
  "traceability": {
    "user_stories": {
      "US-001": {
        "title": "User can register with email and password",
        "acceptance_criteria": ["AC-001", "AC-002", "AC-003"],
        "tasks": []
      },
      "US-002": {
        "title": "User can log in with credentials",
        "acceptance_criteria": ["AC-004", "AC-005"],
        "tasks": []
      }
    },
    "acceptance_criteria": {
      "AC-001": {
        "description": "User must provide valid email format",
        "story": "US-001",
        "pattern": "assertion",
        "tasks": []
      },
      "AC-002": {
        "description": "Password must be at least 8 characters",
        "story": "US-001",
        "pattern": "quantitative",
        "tasks": []
      }
    },
    "adr_decisions": {
      "ADR-001": {
        "title": "Use bcrypt for password hashing",
        "rationale": "Industry standard, configurable work factor",
        "tasks_affected": []
      }
    },
    "non_goals": [
      "NG-001: Social login (OAuth) is out of scope",
      "NG-002: Two-factor authentication is out of scope"
    ]
  },
  "tasks": {},
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

**Traceability Fields:**
| Field | Purpose |
|-------|---------|
| `traceability.user_stories` | Maps story IDs to titles, criteria, and implementing tasks |
| `traceability.acceptance_criteria` | Maps criteria IDs to descriptions, source story, and tasks |
| `traceability.adr_decisions` | Maps ADR decision IDs to affected tasks |
| `traceability.non_goals` | List of explicitly out-of-scope items for boundary checking |

---

### 4. Validation

Present each document section-by-section for user confirmation.

**Validation Guidelines:**
- Present sections in 200-300 word chunks
- After each section, ask: "Does this accurately capture your intent?"
- Accept one of:
  - **Confirmed** - Move to next section
  - **Minor edits** - Apply changes, re-present
  - **Major revision** - Return to dialogue for that topic
- Track which sections are confirmed

**Validation Flow:**

```
1. Present PRD Problem Statement (200-300 words)
   → Ask for confirmation

2. Present PRD Goals and Non-Goals
   → Ask for confirmation

3. Present PRD User Stories
   → Ask for confirmation

4. Present ADR Context and Decision
   → Ask for confirmation

5. Present Technical Design Architecture
   → Ask for confirmation

6. Present Technical Design Data Models
   → Ask for confirmation

7. Present Wireframes (if applicable)
   → Ask for confirmation
```

After all sections confirmed:
- Commit all documents to the branch
- Update state.json

```bash
cd "$WORKTREE_PATH"
git add docs/specs/ state.json
git commit -m "docs: add specification documents for ${FEATURE_SLUG}

- PRD.md: Product requirements and user stories
- ADR.md: Architecture decision record
- TECHNICAL_DESIGN.md: Technical design and data models
- WIREFRAMES.md: UI wireframes (if applicable)

Generated by /create workflow discovery phase"
```

---

### 5. Transition

After validation is complete:

1. Update state.json:
   ```json
   {
     "phase": "planning",
     ...
   }
   ```

2. Commit the state update:
   ```bash
   git add state.json
   git commit -m "chore: transition to planning phase"
   ```

3. **If auto_mode is enabled:**
   - Invoke `create-workflow:planning` skill directly
   - Pass the worktree path and session context

4. **If auto_mode is disabled:**
   - Present summary of what was created
   - Ask: "Ready to break this into implementation tasks? (This will start the planning phase)"
   - On confirmation, invoke `create-workflow:planning`

---

## State Initialization Example

When starting a new discovery session, initialize state with this structure:

```json
{
  "session_id": "feature-name-a1b2c3d4",
  "branch": "create/feature-name-a1b2c3d4",
  "worktree": "../repo-create-feature-name-a1b2c3d4",
  "feature": "feature-name",
  "created_at": "2026-01-25T10:00:00Z",
  "phase": "discovery",
  "traceability": {
    "user_stories": {},
    "acceptance_criteria": {},
    "adr_decisions": {},
    "non_goals": []
  },
  "tasks": {},
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

**Field Descriptions:**
| Field | Description |
|-------|-------------|
| session_id | Unique identifier combining feature slug and UUID |
| branch | Git branch name for this workflow |
| worktree | Path to the git worktree directory |
| feature | Slugified feature name |
| created_at | ISO 8601 timestamp of session creation |
| phase | Current workflow phase (discovery, planning, implementing, etc.) |
| traceability | Links between user stories, acceptance criteria, ADR decisions, and tasks |
| tasks | Map of task IDs to status objects (populated in planning) |
| current_task | ID of task currently being worked on (null in discovery) |
| config | Configuration including timeouts and retry limits |
| progress | Iteration tracking for deadlock detection |

---

## Exit Criteria

Before transitioning to the planning phase, verify all criteria are met:

- [ ] CLAUDE.md and project structure reviewed for context
- [ ] All five question categories addressed (Purpose, Users, Scope, Constraints, Edge Cases)
- [ ] PRD.md created with problem statement, goals, non-goals, and user stories
- [ ] ADR.md created with context, options, decision, and consequences
- [ ] TECHNICAL_DESIGN.md created with architecture, data models, and API contracts
- [ ] WIREFRAMES.md created (or explicitly skipped for non-UI features)
- [ ] All document sections validated by user (200-300 word chunks confirmed)
- [ ] Git worktree created with proper branch naming
- [ ] state.json initialized with session configuration
- [ ] All documents committed to the feature branch
- [ ] User confirmed ready to proceed to planning phase (or auto_mode enabled)

---

## Phase Transition Validation Gate

**REQUIRED:** Before transitioning to planning phase, run these automated validations:

### PRD Validation

Verify the PRD meets quality standards:

```bash
cd "$WORKTREE_PATH"

# Check for measurable success metrics (must have at least one with target value)
grep -E "Target.*[0-9]|[0-9]+%|< ?[0-9]|> ?[0-9]" docs/specs/PRD.md || echo "VALIDATION_FAILED: No measurable success metrics found"

# Check for explicit non-goals section with content
grep -A 5 "## Non-Goals" docs/specs/PRD.md | grep -E "^- " || echo "VALIDATION_FAILED: Non-goals section empty"
```

### User Story Testability Validation

Every user story acceptance criterion MUST match one of these testable patterns:

| Pattern | Example | Regex |
|---------|---------|-------|
| Behavioral (Given/When/Then) | "Given a logged-in user, when they click logout, then session is destroyed" | `(Given|When|Then)` |
| Assertion (should/must/can) | "User should see an error message" | `(should|must|can|will) [a-z]+ [a-z]+` |
| Quantitative | "Response time < 2s" | `[<>=≤≥] ?[0-9]` |

**Reject these vague patterns:**
- Adjective-only: "should be user-friendly" (no observable outcome)
- No outcome: "should work correctly" (what does "correctly" mean?)
- Passive/vague: "is handled properly" (what does "properly" mean?)

Run validation:
```bash
# Extract acceptance criteria and check for testable patterns
grep -E "^\s*-\s*\[" docs/specs/PRD.md | while read -r criterion; do
  if ! echo "$criterion" | grep -qE "(Given|When|Then|should|must|can|will) [a-z]+|[<>=≤≥] ?[0-9]"; then
    echo "VALIDATION_WARNING: Potentially untestable criterion: $criterion"
  fi
done
```

### ADR Validation

Verify the ADR has required sections:

```bash
# Check for explicit non-goals or constraints in ADR
grep -E "## (Non-Goals|Constraints|Out of Scope)" docs/specs/ADR.md || echo "VALIDATION_WARNING: ADR missing non-goals/constraints section"

# Check decision has rationale
grep -A 10 "## Decision" docs/specs/ADR.md | grep -E "(because|due to|since|rationale)" || echo "VALIDATION_WARNING: Decision lacks explicit rationale"
```

### Validation Response

If any `VALIDATION_FAILED` errors occur:
1. **Do not transition** to the planning phase
2. Present the specific validation failures to the user
3. Return to the relevant dialogue section to address the issues
4. Re-run validation after corrections

If only `VALIDATION_WARNING` items occur:
1. Present warnings to the user
2. Ask: "These items may cause issues during implementation. Would you like to address them now or proceed with caution?"
3. On "proceed", continue to planning phase
4. On "address", return to dialogue to refine the content
