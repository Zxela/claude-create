# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **homerun** Claude Code plugin - an orchestrated development workflow system that automates the journey from idea to implementation. It uses specialized AI agents to handle requirements gathering, task planning, TDD implementation, and code review.

## Architecture

### 4-Phase Workflow

```
/create "feature" → Discovery → Planning → Implementation Loop → Completion
```

1. **Discovery** (`skills/discovery/SKILL.md`) - One-question-at-a-time dialogue to generate PRD, ADR, Technical Design, and Wireframes in `docs/specs/`
2. **Planning** (`skills/planning/SKILL.md`) - Decomposes specs into test-bounded tasks written to `docs/tasks/NNN-*.md`
3. **Implementation** - Conductor orchestrates implement/review agent pairs:
   - `skills/conductor/SKILL.md` - Manages task queue and retry logic
   - `skills/implement/SKILL.md` - Executes single task using TDD
   - `skills/review/SKILL.md` - Verifies implementation against spec
4. **Completion** - Invokes `homerun:finishing-a-development-branch`

### State Management

- `state.json` in worktree root tracks:
  - session_id, branch, worktree path, phase, tasks array, current_task, config
  - **`spec_paths`** - Explicit paths to spec documents (prd, adr, technical_design, wireframes)
  - **`tasks_file`** - Path to tasks.json (replaces tasks_dir)
  - **`traceability`** - Links between user stories, acceptance criteria, ADR decisions, and tasks
- Phases: `discovery` → `planning` → `implementing` → `completing` → `done`
- Enables resumability via `/create --resume`
- **Important**: Implementors must use paths from `spec_paths` in state.json, not hardcoded paths

### Isolation Model

Each workflow creates an isolated git worktree at `../repo-create-feature-uuid/` to prevent conflicts with main workspace.

### Retry Logic

Progressive escalation: same-agent (default 2x) → fresh-agent (default 1x) → human escalation

### JSON Contracts

All skills communicate via structured JSON:
- **Input schemas** define required fields (task, spec_paths, worktree_path, etc.)
- **Output signals** indicate completion status (DISCOVERY_COMPLETE, IMPLEMENTATION_COMPLETE, APPROVED, REJECTED)
- **Validation errors** provide structured feedback when input is malformed

### Methodology Passing

The conductor explicitly passes methodology to implement skill:
```json
{
  "task": { ... },
  "methodology": "tdd",  // or "direct" for config-only changes
  "spec_paths": { ... }
}
```
This decouples methodology from the implement skill, making it configurable per-task.

### Model Routing

Tasks are assigned models based on `task_type` (set during planning):

| task_type | model | methodology |
|-----------|-------|-------------|
| add_field, add_method, add_config | haiku | tdd |
| rename_refactor, add_test, add_validation | haiku | tdd |
| add_endpoint | haiku | tdd |
| create_model, create_service | sonnet | tdd |
| create_middleware, add_endpoint_complex | sonnet | tdd |
| bug_fix, integration_test | sonnet | tdd |
| architectural | opus | tdd |

- **Reviews always use sonnet** for quality assurance
- **Escalation**: High-severity rejections upgrade haiku tasks to sonnet

### Context Management

**Target: Stay under 50% context window for optimal quality.**

Each phase spawns the next phase as a **Task agent** with fresh context:

```
/create
   │
   ▼
Discovery (main session)
   │ Task({ homerun:planning })
   ▼
Planning (fresh agent)
   │ Task({ homerun:conductor })
   ▼
Conductor (fresh agent)
   │ Task({ homerun:implement })  Task({ homerun:review })
   ▼                              ▼
Implementer (fresh)            Reviewer (fresh)
```

**Why Task agents for phase transitions:**
- Each phase starts with clean context (~5-10K tokens)
- No manual `/create --resume` needed
- Discovery dialogue doesn't bloat planning
- Planning deliberation doesn't bloat implementation
- Automatic, seamless to user

**Context per phase:**
- Discovery: Grows during dialogue, cleared after
- Planning: Just specs + state (~10K)
- Conductor: State + current task (~5K)
- Implementer/Reviewer: Task + specs (~10K each)

## Key Files

| Path | Purpose |
|------|---------|
| `commands/create.md` | `/create` command entry point and argument parsing |
| `skills/*/SKILL.md` | Agent behavior definitions (9 skills total) |
| `templates/*.md` | Document templates for specs and tasks |
| `.claude-plugin/plugin.json` | Plugin metadata |

### Skill Directory Structure

```
skills/
├── conductor/          # Core: orchestrates implementation loop
├── discovery/          # Core: requirements gathering
├── planning/           # Core: task decomposition
├── implement/          # Core: task execution
├── review/             # Core: implementation verification
├── finishing-a-development-branch/  # Bundled: PR/merge handling
├── systematic-debugging/            # Bundled: debugging reference
├── test-driven-development/         # Bundled: TDD reference
└── using-git-worktrees/             # Bundled: worktree reference
```

## Bundled Skills

These skills are bundled locally (cloned from superpowers) for reference and optional use:

| Skill | Path | Purpose |
|-------|------|---------|
| `homerun:tdd` | `skills/test-driven-development/SKILL.md` | TDD methodology reference (implement skill has TDD inline) |
| `homerun:using-git-worktrees` | `skills/using-git-worktrees/SKILL.md` | Worktree reference (discovery has worktree creation inline) |
| `homerun:finishing-a-development-branch` | `skills/finishing-a-development-branch/SKILL.md` | PR/merge handling (invoked by conductor at completion) |
| `homerun:systematic-debugging` | `skills/systematic-debugging/SKILL.md` | Debugging reference for stuck implementations |

**Note:** Core workflow skills (discovery, planning, conductor, implement, review) have key logic inline rather than invoking sub-skills, reducing coupling and making each skill self-contained.

## Conventions

- **Commits**: `feat(feature-name): task title` format during implementation
- **Tasks**: Must be single-commit, test-bounded, with explicit dependencies
- **Specs**: YAML frontmatter for metadata, markdown body for content

## Version Management

**Version is tracked in two places - update both when bumping:**

1. `.claude-plugin/plugin.json` - Plugin metadata (this repo)
2. `../.claude-plugin/marketplace.json` - Parent marketplace registry

Use semantic versioning: `MAJOR.MINOR.PATCH`
