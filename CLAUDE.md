# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **homerun** Claude Code plugin - an orchestrated development workflow system that automates the journey from idea to implementation. It uses specialized AI agents to handle requirements gathering, task planning, TDD implementation, and code review.

## Architecture

### 4-Phase Workflow

```
/create "feature" → Discovery → Planning → Implementation Loop → Completion
```

1. **Discovery** (`skills/discovery/SKILL.md`) - One-question-at-a-time dialogue to generate PRD, ADR, Technical Design, and Wireframes in `~/.claude/homerun/`
2. **Planning** (`skills/planning/SKILL.md`) - Decomposes specs into test-bounded tasks written to `docs/tasks/NNN-*.md`
3. **Implementation** - Conductor orchestrates implement/review agent pairs:
   - `skills/conductor/SKILL.md` - Manages task queue and retry logic
   - `skills/implement/SKILL.md` - Executes single task using TDD
   - `skills/review/SKILL.md` - Verifies implementation against spec
4. **Completion** - Invokes `homerun:finishing-a-development-branch`

### State Management

- `state.json` in worktree root tracks:
  - session_id, branch, worktree path, phase, tasks array, config
  - **`homerun_docs_dir`** - Centralized docs location (`~/.claude/homerun/<hash>/<feature>/`)
  - **`spec_paths`** - Explicit paths to spec documents (prd, adr, technical_design, wireframes)
  - **`tasks_file`** - Path to tasks.json (replaces tasks_dir)
  - **`traceability`** - Links between user stories, acceptance criteria, ADR decisions, and tasks
  - **`parallel_state`** - Running tasks, pending reviews, retry queue, failure status
- Phases: `discovery` → `planning` → `implementing` → `completing` → `done`
- Enables resumability via `/create --resume`
- **Important**: Implementors must use paths from `spec_paths` in state.json, not hardcoded paths

### Isolation Model

Each workflow creates an isolated git worktree at `../repo-create-feature-uuid/` to prevent conflicts with main workspace.

### Centralized Document Storage

Spec documents (PRD, ADR, TECHNICAL_DESIGN, WIREFRAMES) are stored **outside the project repo** at:

```
$HOME/.claude/homerun/<project-hash>/<feature-slug>/
  ├── PRD.md
  ├── ADR.md
  ├── TECHNICAL_DESIGN.md
  └── WIREFRAMES.md
```

**Path format:** Paths stored in `state.json` are always **absolute** (e.g., `/home/user/.claude/homerun/...`), never using `~` which doesn't expand in JSON.

**Benefits:**
- Keeps project directory clean (no design docs in repo)
- Documents persist for reference across sessions
- No conflicts when running multiple features on same project
- Easy to find: `~/.claude/homerun/` contains all homerun docs

**Important:** Always use paths from `state.json.spec_paths`, not hardcoded paths.

### Parallel Execution

The conductor supports parallel task execution:
- **Independent tasks** run in parallel (up to `config.max_parallel_tasks`, default 3)
- **Subtasks** within a parent run in parallel when their deps resolve
- **Reviews** are sequential to avoid cascade issues
- **Model limits** prevent overloading expensive models:
  - haiku: 5 concurrent
  - sonnet: 3 concurrent
  - opus: 1 concurrent
- **Conductor refresh** every N tasks (default 5) prevents context bloat

### Failure Handling

| Severity | Response |
|----------|----------|
| Low/Medium | Add to retry queue, continue other tasks in parallel |
| High | Block new spawns, let running finish, present TUI recovery options |

Recovery options: Retry with guidance, Mark as fixed, Skip task, Return to planning

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

See `references/model-routing.json` for the authoritative task type to model mapping.

**Quick reference:**
| Role | Model | Notes |
|------|-------|-------|
| Conductor | haiku | Scheduling is mechanical work |
| Implementer (simple) | haiku | add_field, add_method, refactor tasks |
| Implementer (complex) | sonnet | create_model, bug_fix, architecture tasks |
| Reviewer | sonnet | Always sonnet for quality judgment |

- **Reviews always use sonnet** for quality assurance
- **Escalation**: High-severity rejections upgrade haiku tasks to sonnet

### Context Engineering

See `references/context-engineering.md` for full patterns and rationale.

**Core Principles:**

1. **Context Isolation** - Each phase runs in fresh agent context
2. **Filesystem-as-Memory** - Agents communicate via state.json, not message passing
3. **Observation Masking** - Large outputs written to scratch files, summaries in context
4. **Progressive Disclosure** - Skills reference detailed docs, don't inline everything
5. **Model-Appropriate Routing** - Match model capability to task complexity

**Agent Spawning Pattern:**

```
/create (user's model - typically Opus)
   │
   └─> Task(model: "opus")  → Discovery  [dialogue with user]
           │
           └─> Task(model: "opus")  → Planning   [high-leverage decomposition]
                   │
                   └─> Task(model: "haiku") → Conductor [mechanical scheduling]
                           │
                           ├─> Task(model: task.model) → Implementer [varies]
                           │
                           └─> Task(model: "sonnet")   → Reviewer    [judgment]
```

**Why this architecture:**
- Model selection drives 80% of performance variance (research finding)
- Opus for planning prevents cascading decomposition errors
- Haiku for conductor saves cost on mechanical scheduling
- Sonnet for reviews ensures quality judgment
- Each agent starts fresh (~5-10K tokens, not bloated from prior phases)

**Context Budgets:**

| Phase | Typical Size | Refresh Trigger |
|-------|--------------|-----------------|
| Discovery | Grows during dialogue | Phase transition |
| Planning | ~10K (specs + state) | Phase transition |
| Conductor | ~5K (state + current task) | Every 5 tasks or 70% usage |
| Implementer | ~10K (task + specs) | Per-task (always fresh) |
| Reviewer | ~10K (task + impl + specs) | Per-task (always fresh) |

**Observation Masking:**

Tool outputs > 2000 tokens are written to scratch files:
- Git diffs → summary + file path
- Test results → pass/fail + first failure
- Build logs → exit code + last 20 lines

See `references/token-estimation.md` for token budgets and estimation formulas.

## Key Files

| Path | Purpose |
|------|---------|
| `commands/create.md` | `/create` command entry point and argument parsing |
| `skills/*/SKILL.md` | Agent behavior definitions (9 skills total) |
| `templates/*.template.md` | Document templates (PRD, ADR, TECHNICAL_DESIGN) |
| `references/*.json` | Extracted config (model-routing, signal-contracts, discovery-questions) |
| `references/*.md` | Extracted algorithms (state-machine, retry-patterns, debugging-flowchart) |
| `cookbooks/*.md` | Verbose examples extracted from skills |
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

For quick troubleshooting, see `references/debugging-flowchart.md`.

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
