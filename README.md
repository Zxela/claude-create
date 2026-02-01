# Homerun Plugin

Orchestrated development workflow from idea to implementation with isolated agent contexts.

## Usage

```bash
/create "Build a user authentication system"
/create --auto "Add dark mode toggle"
/create --resume
```

## Overview

Homerun transforms a rough idea into a fully implemented feature through 4 automated phases. Each phase runs in an isolated agent context for optimal performance.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           /create "feature idea"                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: DISCOVERY                                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  User ◄──── One question at a time ────► Discovery Agent           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Outputs: PRD.md, ADR.md, TECHNICAL_DESIGN.md, WIREFRAMES.md               │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 2: PLANNING                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Specs ────► Planning Agent ────► tasks.json                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Outputs: docs/tasks.json with test-bounded, commit-sized tasks            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 3: IMPLEMENTATION LOOP                                               │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │                        CONDUCTOR                                   │     │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐           │     │
│  │  │ Find Task   │───►│   Spawn     │───►│   Spawn     │           │     │
│  │  │ (pending)   │    │ Implementer │    │  Reviewer   │           │     │
│  │  └─────────────┘    └──────┬──────┘    └──────┬──────┘           │     │
│  │         ▲                  │                  │                   │     │
│  │         │                  ▼                  ▼                   │     │
│  │         │           ┌─────────────┐    ┌─────────────┐           │     │
│  │         │           │  TDD Cycle  │    │   Verify    │           │     │
│  │         │           │  RED→GREEN  │    │  Criteria   │           │     │
│  │         │           │  →REFACTOR  │    │             │           │     │
│  │         │           └──────┬──────┘    └──────┬──────┘           │     │
│  │         │                  │                  │                   │     │
│  │         │                  ▼                  ▼                   │     │
│  │         │           ┌─────────────┐    ┌─────────────┐           │     │
│  │         │           │   Commit    │    │  APPROVED?  │           │     │
│  │         │           └─────────────┘    └──────┬──────┘           │     │
│  │         │                                     │                   │     │
│  │         │              ┌──────────────────────┼──────────────┐   │     │
│  │         │              │                      │              │   │     │
│  │         │          REJECTED              APPROVED        BLOCKED │     │
│  │         │              │                      │              │   │     │
│  │         │              ▼                      ▼              ▼   │     │
│  │         │        ┌──────────┐          ┌──────────┐    ┌────────┐│     │
│  │         │        │  Retry   │          │  Mark    │    │Escalate││     │
│  │         │        │  Logic   │          │ Complete │    │ to User││     │
│  │         │        └────┬─────┘          └────┬─────┘    └────────┘│     │
│  │         │             │                     │                     │     │
│  │         └─────────────┴─────────────────────┘                     │     │
│  │                                                                   │     │
│  │  Loop until: All tasks complete OR escalation required            │     │
│  └───────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 4: COMPLETION                                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Options: Merge to main │ Create PR │ Continue development          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Agent Architecture

Each phase spawns fresh agents to maintain optimal context window usage:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          MAIN SESSION                                     │
│                         /create "idea"                                    │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
                                │ Task()
                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  DISCOVERY AGENT                                                          │
│  Skill: homerun:discovery                                                 │
│  Context: ~10-20K tokens (grows during dialogue)                          │
│  Model: sonnet                                                            │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
                                │ Task()  ← Fresh context
                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  PLANNING AGENT                                                           │
│  Skill: homerun:planning                                                  │
│  Context: ~10K tokens (specs + state only)                                │
│  Model: sonnet                                                            │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
                                │ Task()  ← Fresh context
                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  CONDUCTOR AGENT                                                          │
│  Skill: homerun:conductor                                                 │
│  Context: ~5K tokens (state + current task)                               │
│  Model: sonnet                                                            │
│                                                                           │
│     ┌────────────────────┐         ┌────────────────────┐                │
│     │  Task()            │         │  Task()            │                │
│     ▼                    │         ▼                    │                │
│  ┌──────────────────┐    │      ┌──────────────────┐    │                │
│  │ IMPLEMENTER      │    │      │ REVIEWER         │    │                │
│  │ homerun:implement│    │      │ homerun:review   │    │                │
│  │ Context: ~10K    │    │      │ Context: ~10K    │    │                │
│  │ Model: haiku/    │◄───┘      │ Model: sonnet    │◄───┘                │
│  │        sonnet    │           │ (always)         │                     │
│  └──────────────────┘           └──────────────────┘                     │
└──────────────────────────────────────────────────────────────────────────┘
```

## Model Routing

Tasks are automatically assigned to the appropriate model based on complexity:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         TASK TYPE → MODEL                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────┐                                                │
│  │       HAIKU         │  Fast, cost-effective                          │
│  │                     │                                                │
│  │  • add_field        │  Single-field additions                        │
│  │  • add_method       │  Simple method implementations                 │
│  │  • add_validation   │  Input validation logic                        │
│  │  • rename_refactor  │  Mechanical renames                            │
│  │  • add_test         │  Unit test additions                           │
│  │  • add_config       │  Configuration changes                         │
│  │  • add_endpoint     │  Simple CRUD endpoints                         │
│  └─────────────────────┘                                                │
│                                                                          │
│  ┌─────────────────────┐                                                │
│  │       SONNET        │  Complex reasoning                             │
│  │                     │                                                │
│  │  • create_model     │  New data models with validation               │
│  │  • create_service   │  Business logic services                       │
│  │  • add_endpoint_    │  Endpoints with auth/complex logic             │
│  │      complex        │                                                │
│  │  • create_          │  Request/response middleware                   │
│  │      middleware     │                                                │
│  │  • bug_fix          │  Debugging and fixes                           │
│  │  • integration_test │  E2E test suites                               │
│  └─────────────────────┘                                                │
│                                                                          │
│  ┌─────────────────────┐                                                │
│  │        OPUS         │  Architectural decisions                       │
│  │                     │                                                │
│  │  • architectural    │  System-wide design tasks                      │
│  └─────────────────────┘                                                │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  ESCALATION: haiku task rejected with high severity → sonnet   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  REVIEWS: Always use sonnet for quality assurance               │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

## State Management

All workflow state is tracked in `state.json` in the worktree root:

```
state.json
├── session_id          # Unique workflow identifier
├── branch              # Git branch name
├── worktree            # Path to isolated worktree
├── phase               # discovery → planning → implementing → completing
├── spec_paths          # Explicit paths to spec documents
│   ├── prd
│   ├── adr
│   ├── technical_design
│   └── wireframes
├── tasks_file          # Path to tasks.json
├── traceability        # Links between stories, criteria, and tasks
│   ├── user_stories
│   ├── acceptance_criteria
│   ├── adr_decisions
│   └── non_goals
├── current_task        # Task ID currently being worked on
├── config
│   ├── timeout_minutes
│   ├── max_identical_rejections
│   ├── max_iterations_without_progress
│   └── max_total_attempts
└── skill_log           # Audit trail of skill invocations
```

## Retry Logic & Circuit Breakers

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         REJECTION HANDLING                               │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │      Check Circuit Breaker   │
                    └──────────────┬──────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    ▼                    ▼
    ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
    │  attempts < 5?  │  │  Same feedback  │  │    Neither      │
    │       NO        │  │   3x in a row?  │  │                 │
    └────────┬────────┘  └────────┬────────┘  └────────┬────────┘
             │                    │                    │
             ▼                    ▼                    ▼
    ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
    │    CIRCUIT      │  │    CIRCUIT      │  │  Continue with  │
    │    TRIPPED      │  │    TRIPPED      │  │  retry logic    │
    │                 │  │                 │  │                 │
    │  permanently_   │  │  permanently_   │  │  attempts 0-1:  │
    │  failed         │  │  failed         │  │   same agent    │
    └─────────────────┘  └─────────────────┘  │                 │
                                              │  attempt 2:     │
                                              │   fresh agent   │
                                              │                 │
                                              │  attempt 3+:    │
                                              │   escalate to   │
                                              │   user          │
                                              └─────────────────┘
```

## File Structure

```
docs/
├── specs/
│   ├── PRD.md                 # Product requirements & user stories
│   ├── ADR.md                 # Architecture decision record
│   ├── TECHNICAL_DESIGN.md    # Technical design & data models
│   └── WIREFRAMES.md          # UI wireframes (if applicable)
└── tasks.json                 # All tasks in single JSON file

state.json                     # Workflow state & configuration
```

## Task Schema

Each task in `tasks.json` includes:

```json
{
  "id": "001",
  "title": "Create User model with validation",
  "objective": "Implement User model class with email validation",
  "task_type": "create_model",
  "methodology": "tdd",
  "acceptance_criteria": [
    {
      "id": "AC-001",
      "criterion": "User model validates email format",
      "test_assertion": "expect(User.validate({email: 'invalid'})).toBe(false)"
    }
  ],
  "test_file": "tests/models/user.test.ts",
  "status": "pending",
  "depends_on": [],
  "traces_to": {
    "user_stories": ["US-001"],
    "acceptance_criteria": ["AC-001"],
    "adr_decisions": ["ADR-001"]
  },
  "model": "sonnet"
}
```

## Configuration

| Flag | Description |
|------|-------------|
| `--auto` | Skip confirmations between phases |
| `--resume` | Resume interrupted session |
| `--retries N,M` | Retry limits: N=same agent, M=fresh agent (default: 2,1) |

## Skills Reference

| Skill | Phase | Purpose |
|-------|-------|---------|
| `homerun:discovery` | 1 | Requirements gathering via structured dialogue |
| `homerun:planning` | 2 | Task decomposition with DAG validation |
| `homerun:conductor` | 3 | Implementation loop orchestration |
| `homerun:implement` | 3 | Task execution using TDD methodology |
| `homerun:review` | 3 | Acceptance criteria verification |
| `homerun:finishing-a-development-branch` | 4 | PR/merge handling |

## Bundled Reference Skills

These skills are available for reference during implementation:

- `homerun:tdd` - TDD methodology guide
- `homerun:using-git-worktrees` - Git worktree operations
- `homerun:systematic-debugging` - Debugging methodology
