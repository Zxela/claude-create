# Homerun Plugin

Orchestrated development workflow from idea to implementation with native Claude Code subagents and Agent Teams.

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

Homerun transforms a rough idea into a fully implemented feature through automated phases. Each phase runs as a **named native subagent** with enforced tool restrictions and dedicated context.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           /create "feature idea"                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: DISCOVERY                                    [discovery-agent]    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  User ◄──── One question at a time ────► Discovery Agent           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Outputs: PRD.md, ADR.md, TECHNICAL_DESIGN.md, WIREFRAMES.md               │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 2: SPEC REVIEW                                  [spec-reviewer]     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Specs ────► Review Agent ────► Verdict (approved / needs_revision) │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Checks: cross-document consistency, completeness, testability             │
│  Tools: Read, Grep, Glob only (read-only — cannot modify specs)            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 3: PLANNING                                     [planner]           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Specs ────► Planning Agent ────► tasks.json (DAG-validated)        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Outputs: docs/tasks.json with test-bounded, commit-sized tasks            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 4: EXECUTION                                    [team-lead]         │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │                     TEAM LEAD (Agent Teams)                        │     │
│  │                                                                    │     │
│  │  1. Convert tasks.json → native TaskCreate with DAG               │     │
│  │  2. Scale teammates based on DAG width (1-5 implementers)         │     │
│  │  3. Monitor progress, handle escalations                          │     │
│  │                                                                    │     │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐    ┌──────────┐          │     │
│  │  │Implement-│ │Implement-│ │Implement-│    │ Reviewer │          │     │
│  │  │er A      │ │er B      │ │er C      │    │          │          │     │
│  │  │          │ │          │ │          │    │ Reviews  │          │     │
│  │  │Self-claim│ │Self-claim│ │Self-claim│───►│completed │          │     │
│  │  │tasks from│ │tasks from│ │tasks from│    │tasks     │          │     │
│  │  │DAG queue │ │DAG queue │ │DAG queue │    │          │          │     │
│  │  └──────────┘ └──────────┘ └──────────┘    └──────────┘          │     │
│  │       │             │            │                │               │     │
│  │       │      TDD: RED → GREEN → REFACTOR → COMMIT                │     │
│  │       │                                                           │     │
│  │  Fallback: conductor skill if Agent Teams unavailable             │     │
│  └───────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 5: QUALITY CHECK                                [quality-checker]   │
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

Start or resume implementation via team-lead (or conductor fallback).

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

Homerun uses **11 native Claude Code subagents** defined in `agents/*.md`. Each agent has enforced tool restrictions, a dedicated model, and references one or more skills.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          MAIN SESSION                                     │
│                         /create "idea"                                    │
│                     (flat state machine loop)                             │
└──┬────────────┬────────────┬────────────┬────────────────────────────────┘
   │            │            │            │
   │ Task()     │ Task()     │ Task()     │ Task()
   ▼            ▼            ▼            ▼
┌────────┐  ┌────────┐  ┌────────┐  ┌──────────────────────────────────────┐
│discover│  │spec-   │  │planner │  │  team-lead          Model: sonnet     │
│y-agent │  │reviewer│  │        │  │  Tools: Read, Bash, Write, Edit,     │
│        │  │        │  │        │  │         Task, ToolSearch              │
│Model:  │  │Model:  │  │Model:  │  │  Skills: team-lead                    │
│inherit │  │sonnet  │  │opus    │  │                                       │
│Color:  │  │Color:  │  │Color:  │  │  Spawns teammates:                    │
│yellow  │  │orange  │  │purple  │  │     ┌────────────────────┐            │
│        │  │        │  │        │  │     │  Task(implementer) │ × 1-5      │
│Skills: │  │Skills: │  │Skills: │  │     ▼                    │            │
│discover│  │spec-   │  │planning│  │  ┌──────────────────┐    │            │
│y       │  │review  │  │        │  │  │ implementer      │◄───┘            │
│        │  │        │  │        │  │  │ Model: sonnet    │                 │
│ returns│  │ returns│  │ returns│  │  │ Skills: implement │                 │
│ ▲      │  │ ▲      │  │ ▲      │  │  └──────────────────┘                 │
└─┼──────┘  └─┼──────┘  └─┼──────┘  │                                       │
  │           │           │          │     ┌────────────────────┐            │
  │           │           │          │     │  Task(reviewer)    │ × 1       │
  │           │           │          │     ▼                    │            │
  │           │           │          │  ┌──────────────────┐    │            │
  │           │           │          │  │ reviewer          │◄──┘            │
  │           │           │          │  │ Model: sonnet     │                │
  │           │           │          │  └──────────────────┘                 │
  │           │           │          │                                       │
  │           │           │          │  After all tasks ──► Task(quality)   │
  │           │           │          │  ┌──────────────────┐                 │
  │           │           │          │  │ quality-checker   │                │
  │           │           │          │  │ Model: sonnet     │                │
  │           │           │          │  └──────────────────┘                 │
  │           │           │          │   returns ▲                           │
  └───────────┴───────────┴──────────┴───────────┘
        All agents return to Main Session (depth 1)
```

**Key architectural property:** Every phase agent runs at **depth 1** (direct child of main session). Agents do NOT chain to the next phase — they update `state.json` and return. The `/create` loop reads `state.json` and spawns the next phase. This guarantees all agents have full tool access including `Task` for spawning subagents.

### Standalone Agents

These agents can be invoked directly without the full `/create` workflow:

```
┌──────────────────────────────────────────────────────────────────────────┐
│  diagnostician             Model: sonnet    Color: red                    │
│  Tools: Read, Grep, Glob, Bash  (investigation only)                     │
│  Skills: diagnose, systematic-debugging                                   │
├──────────────────────────────────────────────────────────────────────────┤
│  reverse-engineer          Model: opus      Color: violet                 │
│  Tools: Read, Grep, Glob, Bash, Write                                    │
│  Skills: reverse-engineer                                                 │
├──────────────────────────────────────────────────────────────────────────┤
│  test-skeleton-generator   Model: sonnet    Color: lime                   │
│  Tools: Read, Grep, Glob, Bash, Write                                    │
│  Skills: generate-test-skeletons                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  walkthrough-generator     Model: sonnet    Color: magenta                │
│  Tools: Read, Grep, Glob, Bash, Write                                    │
│  Skills: walkthrough                                                      │
└──────────────────────────────────────────────────────────────────────────┘
```

## Agent Teams & Conductor Fallback

The execution phase uses two orchestration modes:

### Agent Teams Mode (default when available)

When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set:

1. **Team lead** converts `tasks.json` to native Claude Code tasks via `TaskCreate` with DAG dependencies (`addBlockedBy`)
2. Implementer teammates **self-claim** tasks from the DAG queue — when a task's dependencies are complete, any idle teammate can pick it up
3. Reviewer teammate processes completed implementations sequentially
4. Quality-checker runs after all tasks pass review
5. Native task system provides DAG enforcement and cross-session visibility

### Conductor Fallback Mode

When Agent Teams is unavailable:

1. Team lead detects the missing env var and spawns a **conductor** agent (haiku model)
2. Conductor uses the legacy `homerun:conductor` skill with manual `Task()` spawning and `TaskOutput` polling
3. Behavior is identical to v2.x — same retry logic, same escalation

The orchestration mode is logged in `state.json` as `orchestration_mode: "agent_teams"` or `"conductor_fallback"`.

## Model Routing

> **Note:** The authoritative source for model routing is `references/model-routing.json`.

Tasks are automatically assigned to the appropriate model based on complexity:

| Model | Task Types | Characteristics |
|-------|-----------|----------------|
| **Haiku** | add_field, add_method, add_validation, rename_refactor, add_test, add_config, add_endpoint | Mechanical, single-focus, <15 min |
| **Sonnet** | create_model, create_service, add_endpoint_complex, create_middleware, bug_fix, integration_test | Multi-file, requires judgment, 15-45 min |
| **Opus** | architectural | High-leverage decisions |

**Phase models:**

| Phase | Agent | Model | Rationale |
|-------|-------|-------|-----------|
| Discovery | `discovery-agent` | inherit | User-facing dialogue |
| Spec Review | `spec-reviewer` | sonnet | Judgment for consistency checks |
| Planning | `planner` | opus | Bad decomposition cascades |
| Test Skeletons | `test-skeleton-generator` | sonnet | Spec comprehension |
| Execution | `team-lead` | sonnet | Coordination decisions |
| Implementation | `implementer` | sonnet | TDD + similar function discovery |
| Review | `reviewer` | sonnet | Quality judgment |
| Quality Check | `quality-checker` | sonnet | Fix reasoning |
| Diagnose | `diagnostician` | sonnet | Evidence analysis |
| Reverse Engineer | `reverse-engineer` | opus | Deep codebase understanding |
| Walkthrough | `walkthrough-generator` | sonnet | User flow comprehension |

**Escalation:** Task rejected with high severity → retry with sonnet. Sonnet fails 3x → escalate to user.

## Hooks

Homerun provides hook scripts for Claude Code integration. See `references/hooks-configuration.md` for full setup.

| Hook | Script | Purpose |
|------|--------|---------|
| `WorktreeCreate` | `scripts/homerun-worktree-setup.sh` | Initialize implementer worktrees |
| `SubagentStop` | `scripts/homerun-post-implement.sh` | Log progress after implementation |
| `TaskCompleted` | `scripts/homerun-task-completed.sh` | Validate tests before task completion |

Add to your `.claude/settings.json`:

```json
{
  "hooks": {
    "WorktreeCreate": [{ "hooks": [{ "type": "command", "command": "./scripts/homerun-worktree-setup.sh" }] }],
    "SubagentStop": [{ "matcher": "implementer", "hooks": [{ "type": "command", "command": "./scripts/homerun-post-implement.sh" }] }],
    "TaskCompleted": [{ "hooks": [{ "type": "command", "command": "./scripts/homerun-task-completed.sh" }] }]
  }
}
```

## State Management

All workflow state is tracked in `state.json` in the worktree root:

```
state.json
├── session_id              # Unique workflow identifier
├── branch                  # Git branch name
├── worktree                # Path to isolated worktree
├── phase                   # discovery → spec_review → planning → implementing → completing
├── orchestration_mode      # "agent_teams" or "conductor_fallback"
├── native_task_mapping     # Homerun task ID → native Claude Code task ID
├── homerun_docs_dir        # Centralized docs location (absolute path)
├── spec_paths              # Explicit paths to spec documents
│   ├── prd
│   ├── adr
│   ├── technical_design
│   └── wireframes
├── tasks_file              # Path to tasks.json
├── traceability            # Links between stories, criteria, and tasks
│   ├── user_stories
│   ├── acceptance_criteria
│   ├── adr_decisions
│   └── non_goals
├── config
│   ├── timeout_minutes
│   ├── max_identical_rejections
│   ├── max_iterations_without_progress
│   ├── max_teammates         # Max parallel implementers (default: 3)
│   └── retries { same_agent, fresh_agent }
└── skill_log               # Audit trail of skill invocations
```

## File Structure

**Plugin:**
```
homerun/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata (v3.0.0)
├── agents/                       # Native Claude Code subagent definitions
│   ├── discovery-agent.md
│   ├── spec-reviewer.md
│   ├── planner.md
│   ├── team-lead.md
│   ├── implementer.md
│   ├── reviewer.md
│   ├── quality-checker.md
│   ├── diagnostician.md
│   ├── reverse-engineer.md
│   ├── test-skeleton-generator.md
│   └── walkthrough-generator.md
├── skills/                       # Skill definitions (source of truth for agent behavior)
│   ├── discovery/SKILL.md
│   ├── spec-review/SKILL.md
│   ├── planning/SKILL.md
│   ├── team-lead/SKILL.md
│   ├── conductor/SKILL.md        # DEPRECATED — fallback only
│   ├── implement/SKILL.md
│   ├── review/SKILL.md
│   ├── quality-check/SKILL.md
│   ├── diagnose/SKILL.md
│   ├── reverse-engineer/SKILL.md
│   ├── generate-test-skeletons/SKILL.md
│   ├── walkthrough/SKILL.md
│   ├── finishing-a-development-branch/SKILL.md
│   ├── test-driven-development/SKILL.md
│   ├── systematic-debugging/SKILL.md
│   └── using-git-worktrees/SKILL.md
├── commands/                     # User-invocable commands
│   ├── create.md
│   ├── plan.md
│   ├── build.md
│   ├── review.md
│   ├── diagnose.md
│   └── reverse-engineer.md
├── references/                   # Configuration and contracts
│   ├── signal-contracts.json     # 17 typed signal envelopes
│   ├── model-routing.json        # Task-to-model assignments
│   ├── hooks-configuration.md    # Hook setup guide
│   ├── context-engineering.md
│   ├── discovery-questions.md
│   ├── retry-patterns.md
│   └── state-machine.md
├── scripts/                      # Hook scripts
│   ├── homerun-worktree-setup.sh
│   ├── homerun-post-implement.sh
│   ├── homerun-task-completed.sh
│   └── lib/
│       └── tasks-bridge.js       # tasks.json → native TaskCreate reference
├── templates/                    # Document templates
├── evals/                        # Skill evaluation suites
└── cookbooks/                    # Example dialogues and patterns
```

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

## Signal Contracts

All inter-agent communication uses typed JSON signal envelopes. See `references/signal-contracts.json` for full schemas.

| Signal | Producer | Purpose |
|--------|----------|---------|
| `DISCOVERY_COMPLETE` | discovery-agent | Phase 1 done, specs ready |
| `SPEC_REVIEW_COMPLETE` | spec-reviewer | Specs validated (approved/needs_revision) |
| `PLANNING_COMPLETE` | planner | Tasks decomposed, ready for implementation |
| `TEST_SKELETONS_COMPLETE` | test-skeleton-generator | Test scaffolding generated |
| `IMPLEMENTATION_COMPLETE` | implementer | Task done, ready for review |
| `IMPLEMENTATION_BLOCKED` | implementer | Task blocked (missing dep, unclear reqs, duplication) |
| `APPROVED` | reviewer | Task passed review |
| `REJECTED` | reviewer | Task failed review with feedback |
| `QUALITY_CHECK_COMPLETE` | quality-checker | Quality pipeline results |
| `TEAM_LEAD_COMPLETE` | team-lead | All tasks orchestrated, quality gate passed |
| `CONDUCTOR_FALLBACK` | team-lead | Fell back to conductor (Agent Teams unavailable) |
| `DIAGNOSIS_COMPLETE` | diagnostician | Root cause identified with solutions |
| `DIAGNOSIS_INCONCLUSIVE` | diagnostician | Needs more investigation |
| `REVERSE_ENGINEER_COMPLETE` | reverse-engineer | Specs generated from code |
| `WALKTHROUGH_COMPLETE` | walkthrough-generator | Demo scripts generated |
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
  Escalate model (sonnet → opus)
      │ NO ↓
  Escalate to user
```

**Circuit breaker:** 3 consecutive failures or same feedback 3x → stop spawning, escalate.

## Credits

See [CREDITS.md](CREDITS.md) for inspiration and sources.
