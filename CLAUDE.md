# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **create-workflow** Claude Code plugin - an orchestrated development workflow system that automates the journey from idea to implementation. It uses specialized AI agents to handle requirements gathering, task planning, TDD implementation, and code review.

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
4. **Completion** - Invokes `superpowers:finishing-a-development-branch`

### State Management

- `state.json` in worktree root tracks:
  - session_id, branch, worktree path, phase, tasks array, current_task, config
  - **`spec_paths`** - Explicit paths to spec documents (prd, adr, technical_design, wireframes)
  - **`tasks_dir`** - Directory containing task files (default: `docs/tasks`)
- Phases: `discovery` → `planning` → `implementing` → `completing` → `done`
- Enables resumability via `/create --resume`
- **Important**: Implementors must use paths from `spec_paths` in state.json, not hardcoded paths

### Isolation Model

Each workflow creates an isolated git worktree at `../repo-create-feature-uuid/` to prevent conflicts with main workspace.

### Retry Logic

Progressive escalation: same-agent (default 2x) → fresh-agent (default 1x) → human escalation

## Key Files

| Path | Purpose |
|------|---------|
| `commands/create.md` | `/create` command entry point and argument parsing |
| `skills/*/SKILL.md` | Agent behavior definitions (5 skills) |
| `templates/*.md` | Document templates for specs and tasks |
| `.claude-plugin/plugin.json` | Plugin metadata |

## External Dependencies

Skills depend on these superpowers:
- `superpowers:test-driven-development` - Mandatory for implement skill
- `superpowers:using-git-worktrees` - Worktree creation in discovery
- `superpowers:finishing-a-development-branch` - PR/merge handling

## Conventions

- **Commits**: `feat(feature-name): task title` format during implementation
- **Tasks**: Must be single-commit, test-bounded, with explicit dependencies
- **Specs**: YAML frontmatter for metadata, markdown body for content
