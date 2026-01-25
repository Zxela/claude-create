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

Create `state.json` in the worktree root:

```json
{
  "session_id": "user-auth-a1b2c3d4",
  "branch": "create/user-auth-a1b2c3d4",
  "worktree": "../myapp-create-user-auth-a1b2c3d4",
  "feature": "user-auth",
  "created_at": "2026-01-25T10:00:00Z",
  "phase": "discovery",
  "tasks": {},
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
  "tasks": {},
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

**Field Descriptions:**
| Field | Description |
|-------|-------------|
| session_id | Unique identifier combining feature slug and UUID |
| branch | Git branch name for this workflow |
| worktree | Path to the git worktree directory |
| feature | Slugified feature name |
| created_at | ISO 8601 timestamp of session creation |
| phase | Current workflow phase (discovery, planning, implementing, etc.) |
| tasks | Map of task IDs to status objects (populated in planning) |
| current_task | ID of task currently being worked on (null in discovery) |
| config | Configuration from /create command options |

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
