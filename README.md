# Homerun Plugin

Orchestrated development workflow from idea to implementation with isolated agent contexts.

## Usage

```bash
# Full workflow: idea → specs → plan → build → complete
/create "Build a user authentication system"
/create --auto "Add dark mode toggle"
/create --resume

# Jump into specific phases
/plan ../myapp-create-feature-uuid
/build ../myapp-create-feature-uuid
/review ../myapp-create-feature-uuid --all
/diagnose "Registration endpoint returns 500"
/reverse-engineer ~/projects/legacy-api
```

## Overview

Homerun transforms a rough idea into a fully implemented feature through automated phases. Each phase runs in an isolated agent context for optimal performance.

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
│  PHASE 2: SPEC REVIEW                                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Specs ────► Review Agent ────► Verdict (approved / needs_revision) │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Checks: cross-document consistency, completeness, testability             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 3: PLANNING                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Specs ────► Planning Agent ────► tasks.json                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Outputs: docs/tasks.json with test-bounded, commit-sized tasks            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 4: IMPLEMENTATION LOOP                                               │
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
│  │         │           │  0. Similar │    │   Verify    │           │     │
│  │         │           │  Function   │    │  Criteria   │           │     │
│  │         │           │  Discovery  │    │             │           │     │
│  │         │           ├─────────────┤    └──────┬──────┘           │     │
│  │         │           │  TDD Cycle  │           │                  │     │
│  │         │           │  RED→GREEN  │    ┌──────┴──────┐           │     │
│  │         │           │  →REFACTOR  │    │  APPROVED?  │           │     │
│  │         │           └──────┬──────┘    └──────┬──────┘           │     │
│  │         │                  │                  │                   │     │
│  │         │                  ▼           ┌──────┼──────┐           │     │
│  │         │           ┌─────────────┐   │      │      │           │     │
│  │         │           │   Commit    │ REJECT  APPROVE BLOCK       │     │
│  │         │           └─────────────┘   │      │      │           │     │
│  │         │                             ▼      ▼      ▼           │     │
│  │         │                          Retry   Mark   Escalate      │     │
│  │         │                          Logic  Complete to User       │     │
│  │         │                             │      │                   │     │
│  │         └─────────────────────────────┴──────┘                   │     │
│  │                                                                   │     │
│  │  Loop until: All tasks complete OR escalation required            │     │
│  └───────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 5: QUALITY CHECK                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Lint ──► Types ──► Structure ──► Tests ──► Recheck                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Auto-fixes issues, re-runs checks until clean                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 6: COMPLETION                                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Options: Merge to main │ Create PR │ Keep branch │ Discard        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Commands

### `/create` — Full Workflow

Start an orchestrated workflow from idea through implementation.

```bash
/create "description of what to build" [--auto] [--resume] [--retries N,M]
```

| Flag | Description |
|------|-------------|
| `--auto` | Skip confirmations between phases |
| `--resume` | Resume interrupted session |
| `--retries N,M` | Retry limits: N=same agent, M=fresh agent (default: 2,1) |

### `/plan` — Jump to Planning

Skip discovery and plan directly from existing specs.

```bash
/plan <worktree-path> [--auto]
/plan --find
```

### `/build` — Jump to Execution

Start or resume the implementation loop from existing tasks.

```bash
/build <worktree-path> [--auto]
/build --find
```

### `/review` — Review Specs or Code Quality

Run spec review, quality checks, or both.

```bash
/review <worktree-path> --specs       # Spec consistency & completeness
/review <worktree-path> --quality     # Lint, types, structure, tests
/review <worktree-path> --all         # Both (default)
```

### `/diagnose` — Structured Bug Investigation

Launch the 3-phase evidence pipeline: investigate, verify, solve.

```bash
/diagnose "problem description" [--file <path>] [--error <message>] [--type <type>]
```

### `/reverse-engineer` — Generate Specs from Code

Analyze existing codebase and generate PRD, ADR, TECHNICAL_DESIGN.

```bash
/reverse-engineer [project-path] [--scope full|module|feature] [--target <name>]
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
│  DISCOVERY AGENT        Model: inherits     Context: ~10-20K tokens      │
│  homerun:discovery                                                        │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │ Task()  ← Fresh context
                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  SPEC REVIEW AGENT      Model: sonnet       Context: ~15K tokens         │
│  homerun:spec-review                                                      │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │ Task()  ← Fresh context
                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  PLANNING AGENT         Model: opus         Context: ~10K tokens         │
│  homerun:planning                                                         │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │ Task()  ← Fresh context
                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  CONDUCTOR AGENT        Model: haiku        Context: ~5K tokens          │
│  homerun:conductor                                                        │
│                                                                           │
│     ┌────────────────────┐         ┌────────────────────┐                │
│     │  Task()            │         │  Task()            │                │
│     ▼                    │         ▼                    │                │
│  ┌──────────────────┐    │      ┌──────────────────┐    │                │
│  │ IMPLEMENTER      │    │      │ REVIEWER         │    │                │
│  │ homerun:implement│    │      │ homerun:review   │    │                │
│  │ Model: haiku/    │◄───┘      │ Model: sonnet    │◄───┘                │
│  │        sonnet    │           │ (always)         │                     │
│  └──────────────────┘           └──────────────────┘                     │
│                                                                           │
│  ┌──────────────────┐                                                    │
│  │ QUALITY CHECKER  │                                                    │
│  │ homerun:quality- │  After all tasks complete                          │
│  │ check            │                                                    │
│  │ Model: sonnet    │                                                    │
│  └──────────────────┘                                                    │
└──────────────────────────────────────────────────────────────────────────┘
```

## Model Routing

> **Note:** The authoritative source for model routing is `references/model-routing.json`.

Tasks are automatically assigned to the appropriate model based on complexity:

| Model | Task Types | Characteristics |
|-------|-----------|----------------|
| **Haiku** | add_field, add_method, add_validation, rename_refactor, add_test, add_config, add_endpoint | Mechanical, single-focus, <15 min |
| **Sonnet** | create_model, create_service, add_endpoint_complex, create_middleware, bug_fix, integration_test | Multi-file, requires judgment, 15-45 min |
| **Opus** | architectural | High-leverage decisions |

**Phase models:**

| Phase | Model | Rationale |
|-------|-------|-----------|
| Discovery | inherit | User-facing dialogue |
| Spec Review | sonnet | Judgment for consistency checks |
| Planning | opus | Bad decomposition cascades |
| Test Skeletons | sonnet | Spec comprehension |
| Conductor | haiku | Mechanical scheduling |
| Implementer | haiku/sonnet | Per task complexity |
| Reviewer | sonnet | Quality judgment |
| Quality Check | sonnet | Fix reasoning |
| Diagnose | sonnet | Evidence analysis |
| Reverse Engineer | opus | Deep codebase understanding |
| Walkthrough | sonnet | User flow comprehension |

**Escalation:** haiku task rejected with high severity → sonnet. Sonnet fails 3x → user.

## State Management

All workflow state is tracked in `state.json` in the worktree root:

```
state.json
├── session_id          # Unique workflow identifier
├── branch              # Git branch name
├── worktree            # Path to isolated worktree
├── phase               # discovery → spec_review → planning → implementing → completing
├── homerun_docs_dir    # Centralized docs location (absolute path)
├── spec_paths          # Explicit paths to spec documents (in homerun_docs_dir)
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
│   └── retries { same_agent, fresh_agent }
└── skill_log           # Audit trail of skill invocations
```

## File Structure

**Worktree (project-specific):**
```
../project-create-feature-uuid/
├── docs/
│   └── tasks.json             # All tasks in single JSON file
└── state.json                 # Workflow state & configuration
```

**Centralized docs (not in project repo):**
```
$HOME/.claude/homerun/<project-hash>/<feature-slug>/
├── PRD.md                     # Product requirements & user stories
├── ADR.md                     # Architecture decision record
├── TECHNICAL_DESIGN.md        # Technical design & data models
└── WIREFRAMES.md              # UI wireframes (if applicable)
```

Note: Paths in `state.json` are stored as absolute paths (e.g., `/home/user/.claude/...`).

## Skills Reference

### Workflow Skills

| Skill | Phase | Model | Color | Purpose |
|-------|-------|-------|-------|---------|
| `homerun:discovery` | 1 | inherit | yellow | Requirements gathering via structured dialogue |
| `homerun:spec-review` | 2 | sonnet | orange | Cross-document consistency, completeness, testability validation |
| `homerun:planning` | 3 | opus | purple | Task decomposition with DAG validation |
| `homerun:generate-test-skeletons` | 3.5 | sonnet | lime | ROI-prioritized test skeleton generation (optional) |
| `homerun:conductor` | 4 | haiku | green | Implementation loop orchestration |
| `homerun:implement` | 4 | haiku/sonnet | yellow | Task execution with similar function discovery + TDD |
| `homerun:review` | 4 | sonnet | blue | Acceptance criteria verification |
| `homerun:quality-check` | 5 | sonnet | teal | 5-phase quality pipeline (lint, types, structure, tests, recheck) |
| `homerun:finishing-a-development-branch` | 6 | — | — | PR/merge handling |

### Standalone Skills

| Skill | Model | Color | Purpose |
|-------|-------|-------|---------|
| `homerun:diagnose` | sonnet | red | 3-phase evidence pipeline for bug investigation |
| `homerun:reverse-engineer` | opus | violet | Generate specs from existing codebase |
| `homerun:walkthrough` | sonnet | magenta | Playwright/curl demo scripts from user journeys |

### Reference Skills

| Skill | Purpose |
|-------|---------|
| `homerun:test-driven-development` | TDD methodology guide |
| `homerun:using-git-worktrees` | Git worktree operations |
| `homerun:systematic-debugging` | Debugging methodology |

## Signal Contracts

All inter-skill communication uses typed JSON signal envelopes. See `references/signal-contracts.json` for full schemas.

| Signal | Producer | Purpose |
|--------|----------|---------|
| `DISCOVERY_COMPLETE` | discovery | Phase 1 done, specs ready |
| `SPEC_REVIEW_COMPLETE` | spec-review | Specs validated (approved/needs_revision) |
| `PLANNING_COMPLETE` | planning | Tasks decomposed, ready for implementation |
| `TEST_SKELETONS_COMPLETE` | generate-test-skeletons | Test scaffolding generated |
| `IMPLEMENTATION_COMPLETE` | implement | Task done, ready for review |
| `IMPLEMENTATION_BLOCKED` | implement | Task blocked (missing dep, unclear reqs, duplication) |
| `APPROVED` | review | Task passed review |
| `REJECTED` | review | Task failed review with feedback |
| `QUALITY_CHECK_COMPLETE` | quality-check | Quality pipeline results |
| `DIAGNOSIS_COMPLETE` | diagnose | Root cause identified with solutions |
| `DIAGNOSIS_INCONCLUSIVE` | diagnose | Needs more investigation |
| `REVERSE_ENGINEER_COMPLETE` | reverse-engineer | Specs generated from code |
| `WALKTHROUGH_COMPLETE` | walkthrough | Demo scripts generated |
| `COVERAGE_GAPS_DETECTED` | conductor | Acceptance criteria not covered |
| `VALIDATION_ERROR` | any | Input validation failed |

## Retry Logic & Circuit Breakers

```
Task rejected
      │
      ▼
  attempts < same_agent_limit (default: 2)
      │ YES → Retry with same agent + accumulated context
      │ NO ↓
  attempts < same_agent + fresh_agent_limit (default: 1)
      │ YES → Spawn fresh agent (clean slate)
      │ NO ↓
  task.model === 'haiku'?
      │ YES → Escalate to sonnet
      │ NO ↓
  Escalate to user
```

**Circuit breaker:** 3 consecutive failures or same feedback 3x → stop spawning, escalate.

## Credits

See [CREDITS.md](CREDITS.md) for inspiration and sources.
