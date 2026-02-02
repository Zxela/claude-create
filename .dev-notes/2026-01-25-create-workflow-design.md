# /create Workflow Design

> Orchestrated development workflow from idea to implementation with isolated agent contexts

## Overview

The `/create` workflow automates the full development lifecycle:
1. **Discovery** - Refine ideas into formal specifications
2. **Planning** - Break specifications into test-bounded tasks
3. **Implementation** - Execute tasks with verification loops
4. **Completion** - Merge, PR, or continue development

Each phase runs in isolated context. State persists via git worktrees and `state.json`.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         /create <prompt>                            │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 1: DISCOVERY AGENT                                           │
│  - Guides user through requirements refinement                      │
│  - Outputs: PRD, ADR, Technical Design, Wireframes (if needed)      │
│  - Ends with: "Ready to break this into tasks?"                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │ (context clear)
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 2: PLANNER AGENT                                             │
│  - Reads docs from Phase 1                                          │
│  - Creates test-bounded, commit-sized task files                    │
│  - Outputs: docs/tasks/*.md + docs/tasks/state.json                 │
│  - Ends with: "Ready to start implementation?"                      │
└─────────────────────────────────────────────────────────────────────┘
                                  │ (context clear)
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 3: IMPLEMENTATION LOOP                                       │
│  ┌────────────┐    ┌────────────┐    ┌────────────┐                │
│  │ Implementer│───▶│  Reviewer  │───▶│   Next?    │                │
│  │   Agent    │    │   Agent    │    │            │                │
│  └────────────┘    └────────────┘    └─────┬──────┘                │
│        ▲                │                   │                       │
│        └────────────────┘                   │                       │
│         (retry if rejected)                 ▼                       │
│                              [Loop until all tasks complete]        │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 4: COMPLETION                                                │
│  - Summary of what was built                                        │
│  - Trigger finishing-a-development-branch skill                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Discovery Agent

**Invocation:**
```bash
/create "Build a user authentication system with OAuth support"
/create --auto "Add dark mode toggle to settings page"
```

**Process:**
1. Context gathering - Reads existing project structure, CLAUDE.md, recent commits
2. Refinement dialogue - Asks one question at a time
   - Purpose and goals
   - Constraints and non-goals
   - User flows and edge cases
   - Technical constraints
3. Document generation - Produces four artifacts

**Documentation outputs:**

| Document | Purpose | Key Sections |
|----------|---------|--------------|
| `PRD.md` | What and why | Problem statement, goals, user stories, success metrics, non-goals |
| `ADR.md` | Key decisions | Context, options considered, decision, consequences |
| `TECHNICAL_DESIGN.md` | How | Architecture, data models, API contracts, dependencies, security |
| `WIREFRAMES.md` | Visual (if UI) | ASCII/Mermaid diagrams, screen flows, component hierarchy |

**Exit criteria:**
- All four docs written (wireframes skipped if no UI)
- User confirms docs accurately capture intent
- Docs committed to git

---

## Phase 2: Planner Agent

**Branch & Worktree Creation:**

Each `/create` session gets isolated git worktree:

```
Branch: create/<feature>-<short-uuid>
Worktree: ../<repo>-create-<feature>-<short-uuid>/
```

**Directory structure within worktree:**
```
docs/
├── specs/
│   ├── PRD.md
│   ├── ADR.md
│   ├── TECHNICAL_DESIGN.md
│   └── WIREFRAMES.md
└── tasks/
    ├── state.json
    ├── 001-setup-auth-models.md
    ├── 002-implement-oauth-client.md
    └── ...
```

**Task decomposition rules:**
- Each task completable in single commit
- Each task has at least one test that verifies it
- Clear acceptance criteria
- Dependencies declared between tasks

**Task file format:**
```markdown
---
id: "001"
title: "Set up authentication data models"
status: pending
depends_on: []
test_file: "tests/models/test_auth.py"
---

## Objective
Create User and Session models with required fields.

## Acceptance Criteria
- [ ] User model with email, password_hash, created_at
- [ ] Session model with user_id, token, expires_at
- [ ] Test file validates model creation and relationships

## Technical Notes
Reference: TECHNICAL_DESIGN.md#data-models
```

**state.json format:**
```json
{
  "session_id": "user-auth-a1b2c3",
  "branch": "create/user-auth-a1b2c3",
  "worktree": "../myapp-create-user-auth-a1b2c3",
  "feature": "user-auth",
  "created_at": "2026-01-25T10:00:00Z",
  "phase": "implementing",
  "tasks": {
    "001": { "status": "completed", "attempts": 1 },
    "002": { "status": "in_progress", "attempts": 1 }
  },
  "current_task": "002",
  "config": {
    "auto_mode": false,
    "retries": { "same_agent": 2, "fresh_agent": 1 }
  }
}
```

---

## Phase 3: Implementation Loop

**Orchestration:**
```
1. Read state.json → find next pending task
2. Spawn Implementer Agent with task context
3. On completion → Spawn Reviewer Agent
4. If approved → mark complete, goto 1
5. If rejected → retry logic (tiered)
6. If all complete → Phase 4
```

**Implementer Agent receives:**
```markdown
## Your Task
[Contents of task file]

## Reference Documents
- docs/specs/TECHNICAL_DESIGN.md (relevant sections)
- docs/specs/ADR.md (for decision context)

## Previous Attempts (if retry)
Attempt 1 rejected: "OAuth token refresh not implemented per spec"

## Instructions
1. Read the task and referenced docs
2. Implement using TDD (superpowers:test-driven-development)
3. Commit with message: "feat(<feature>): <task title>"
4. Signal completion for review
```

**Reviewer Agent receives:**
```markdown
## Task Specification
[Contents of task file]

## Implementation to Review
- Commit: abc123
- Files changed: [list]
- Test file: tests/auth/test_oauth.py

## Review Checklist
1. Does implementation satisfy all acceptance criteria?
2. Does the test verify the acceptance criteria?
3. Does code align with TECHNICAL_DESIGN.md?
4. Any security concerns per ADR.md decisions?

## Output
- APPROVED: Brief summary of what was verified
- REJECTED: Specific issues that must be fixed
```

**Retry flow:**
```
Rejection → attempts < 2?  → Same agent retries
         → attempts == 2? → Fresh implementer (attempts resets)
         → attempts == 3? → Human escalation, loop pauses
```

---

## Phase 4: Completion

1. Run full test suite as final verification
2. Generate summary of what was built
3. Invoke `superpowers:finishing-a-development-branch` skill
4. User chooses: merge to main, create PR, or keep branch

---

## Error Handling & Resumability

**Resume command:**
```bash
/create --resume
```

**state.json phase values:**
- `discovery` - Resume Phase 1
- `planning` - Resume Phase 2
- `implementing` - Resume Phase 3
- `review` - Reviewer interrupted
- `escalated` - Awaiting human intervention
- `completing` - Phase 4 in progress
- `done` - Workflow complete

**Failure handling:**

| Failure | Detection | Response |
|---------|-----------|----------|
| Agent crashes mid-task | `current_task` set, no commit | Retry from task start |
| Tests fail | Reviewer catches | Rejection → retry flow |
| Human escalation timeout | `phase: "escalated"` | `/create --resume` reminds user |
| Worktree deleted | Missing from `git worktree list` | Error with recovery instructions |
| Merge conflicts | Git reports conflict | Pause, notify user |

---

## Configuration

**Command-line arguments:**
- `<prompt>` - Required: description of what to build
- `--auto` - Fully automated mode (no confirmations between phases)
- `--resume` - Resume interrupted session
- `--retries N,M` - Configure retry limits (default: 2,1)

**User config file (`~/.claude/create-workflow.json`):**
```json
{
  "auto_mode": false,
  "retries": { "same_agent": 2, "fresh_agent": 1 },
  "doc_templates": "~/.claude/plugins/local/create-workflow/templates/",
  "skip_wireframes_for": ["cli", "api", "library"]
}
```

---

## Plugin Structure

```
~/.claude/plugins/local/create-workflow/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── discovery/SKILL.md
│   ├── planning/SKILL.md
│   ├── conductor/SKILL.md
│   ├── implement/SKILL.md
│   └── review/SKILL.md
├── commands/
│   └── create.md
├── templates/
│   ├── PRD.md
│   ├── ADR.md
│   ├── TECHNICAL_DESIGN.md
│   ├── WIREFRAMES.md
│   └── TASK.md
└── docs/
    └── 2026-01-25-create-workflow-design.md
```

**Skills:**

| Skill | Purpose |
|-------|---------|
| `create:discovery` | Phase 1 - requirements refinement, doc generation |
| `create:planning` | Phase 2 - task breakdown |
| `create:conductor` | Phase 3 - orchestrates implementation loop |
| `create:implement` | Implementer agent instructions |
| `create:review` | Reviewer agent instructions |

---

## Dependencies

**Required skills (from superpowers):**
- `superpowers:test-driven-development` - TDD during implementation
- `superpowers:using-git-worktrees` - Worktree creation
- `superpowers:finishing-a-development-branch` - Completion handling

**Optional integrations:**
- `context7` - Version-specific documentation lookup
- `github` - PR creation if chosen at completion
