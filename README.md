# Homerun Plugin

Orchestrated development workflow from idea to implementation with native Claude Code subagents.

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

Homerun transforms a rough idea into a fully implemented feature through automated phases. Each phase runs as a **named native subagent** with enforced tool restrictions and dedicated context. The team-lead runs as an **inline skill** at depth 0 for reliable orchestration.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           /create "feature idea"                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: DISCOVERY                                    [discovery-agent]    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  User ◄──── Batched questions ────► Discovery Agent                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  Auto mode: skips dialogue, generates specs from prompt + codebase scan   │
│  Outputs: PRD.md, ADR.md, TECHNICAL_DESIGN.md, WIREFRAMES.md              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 2: SPEC REVIEW                                  [spec-reviewer]     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Specs ────► Review Agent ────► Verdict (approved / needs_revision) │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  Checks: cross-document consistency, completeness, testability            │
│  Tools: Read, Grep, Glob only (read-only — cannot modify specs)           │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 3a: SCOPE ANALYSIS                              [scope-analyzer]    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Specs ────► Scope Analyzer (sonnet) ────► scope-analysis.json     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  Mechanical extraction: components, validated ACs, JIT context refs       │
│  Skipped for small-scale features (< 3 files)                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 3b: TASK DECOMPOSITION                         [task-decomposer]    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  scope-analysis.json ────► Task Decomposer (opus) ────► tasks.json │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  Outputs: docs/tasks.json with test-bounded, commit-sized tasks + DAG     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 3c: DAG VALIDATION                              [bash script]       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  validate-dag.sh: cycles, coverage, fields, ordering               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  Zero LLM cost — pure algorithmic validation                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 4: EXECUTION                                    [team-lead skill]   │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │                     TEAM LEAD (inline skill)                      │     │
│  │                                                                    │     │
│  │  1. Convert tasks.json → native TaskCreate with DAG               │     │
│  │  2. Dispatch implementers in parallel based on DAG                │     │
│  │  3. Continuous incremental review (max 2 concurrent reviewers)    │     │
│  │  4. Inject session feedback patterns into implementer prompts     │     │
│  │                                                                    │     │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐    ┌──────────┐          │     │
│  │  │Implement-│ │Implement-│ │Implement-│    │ Reviewer │          │     │
│  │  │er A      │ │er B      │ │er C      │    │(up to 2  │          │     │
│  │  │          │ │          │ │          │    │concurrent)│          │     │
│  │  │ TDD:     │ │ TDD:     │ │ TDD:     │───►│          │          │     │
│  │  │ red→green│ │ red→green│ │ red→green│    │ Reviews  │          │     │
│  │  │ →refactor│ │ →refactor│ │ →refactor│    │ per-task │          │     │
│  │  └──────────┘ └──────────┘ └──────────┘    └──────────┘          │     │
│  └───────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 5: QUALITY CHECK                                [quality-checker]   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Lint (hook) ──► Types (hook) ──► Structure (LLM) ──► Tests ──► ✓ │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  Sonnet/opus: full 5-phase pipeline. Haiku-tier: 3 phases only            │
│  (lint, types, tests) — skips Structure (LLM) and Recheck (LLM).         │
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
| `--auto` | Skip all confirmations — dialogue, validation, phase transitions |
| `--resume` | Resume interrupted session |
| `--retries N,M` | Retry limits: N=fresh agent, M=same agent (default: 1,1) |

**Plan-then-stop (default):** In interactive mode, `/create` stops after DAG validation and prints a task summary. Run `/build <worktree>` to start implementation. In `--auto` mode, execution continues immediately.

### `/plan` — Jump to Planning

Skip discovery and plan directly from existing specs. Runs the 3-layer pipeline: scope analysis → task decomposition → DAG validation.

```bash
/plan <worktree-path> [--auto]
/plan --find
```

### `/build` — Jump to Execution

Start or resume implementation via the team-lead skill.

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

### `/status` — View Workflow Progress

List homerun worktrees with phase, feature, scale, and task progress.

```bash
/status              # Summary of all sessions
/status --detailed   # Per-task status and feedback patterns
```

## Agent Architecture

Homerun uses **11 native Claude Code subagents** defined in `agents/*.md`. Each agent has enforced tool restrictions, a dedicated model, and references one or more skills. The team-lead runs as an **inline skill** (not a spawned agent) for reliable orchestration.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          MAIN SESSION                                     │
│                         /create "idea"                                    │
│                     (flat state machine loop)                             │
└──┬──────────┬──────────┬──────────┬──────────┬───────────────────────────┘
   │          │          │          │          │
   │ Task()   │ Task()   │ Task()   │ Task()   │ bash
   ▼          ▼          ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌─────────┐
│discover│ │spec-   │ │scope-  │ │task-   │ │validate │
│y-agent │ │reviewer│ │analyzer│ │decomp- │ │-dag.sh  │
│        │ │        │ │        │ │oser    │ │         │
│Model:  │ │Model:  │ │Model:  │ │Model:  │ │Zero LLM │
│inherit │ │sonnet  │ │sonnet  │ │opus    │ │cost     │
│Color:  │ │Color:  │ │Color:  │ │Color:  │ │         │
│yellow  │ │orange  │ │cyan    │ │purple  │ │         │
└─┬──────┘ └─┬──────┘ └─┬──────┘ └─┬──────┘ └─┬───────┘
  │          │          │          │          │
  └──────────┴──────────┴──────────┴──────────┘
        All return to Main Session
                    │
                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  TEAM-LEAD SKILL (inline, depth 0)                                       │
│  Dispatches at depth 1:                                                   │
│                                                                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐       │
│  │ implementer      │  │ reviewer          │  │ quality-checker   │       │
│  │ Model: haiku/    │  │ Model: sonnet     │  │ Model: sonnet     │       │
│  │   sonnet (by     │  │ Skills: review    │  │ Skills: quality   │       │
│  │   task type)     │  │ × 1-2 concurrent │  │ × 1 (final gate)  │       │
│  │ × 1-3 parallel   │  │                   │  │                   │       │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘       │
└──────────────────────────────────────────────────────────────────────────┘
```

**Key architectural property:** Every phase agent runs at **depth 1** (direct child of main session). Agents do NOT chain to the next phase — they update `state.json` and return. The `/create` loop reads `state.json` and spawns the next phase. The team-lead runs inline (depth 0) and dispatches implementers/reviewers at depth 1.

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
| Scope Analysis | `scope-analyzer` | sonnet | Mechanical extraction (5x cheaper than opus) |
| Task Decomposition | `task-decomposer` | opus | Bad decomposition cascades |
| DAG Validation | `validate-dag.sh` | bash | Zero LLM cost |
| Test Skeletons | `test-skeleton-generator` | sonnet | Spec comprehension |
| Execution | team-lead skill | inherit | Inline coordination |
| Implementation | `implementer` | haiku/sonnet | Model set by team-lead per task type |
| Review | `reviewer` | sonnet | Quality judgment |
| Quality Check | `quality-checker` | sonnet | Fix reasoning |
| Diagnose | `diagnostician` | sonnet | Evidence analysis |
| Reverse Engineer | `reverse-engineer` | opus | Deep codebase understanding |
| Walkthrough | `walkthrough-generator` | sonnet | User flow comprehension |

**Escalation:** Task rejected with high severity → retry with sonnet. Sonnet fails 3x → escalate to user.

## Prerequisites

- **jq** — Required by all hook scripts for JSON parsing. Install via `apt install jq`, `brew install jq`, or equivalent.
- **A linter and/or typechecker** — Hooks auto-detect project tools (biome, eslint, prettier, ruff, tsc, mypy). Without one, quality gates pass silently.

## Hooks

Hooks auto-register via `hooks/hooks.json` when the homerun plugin is installed. No manual `.claude/settings.json` configuration needed.

| Hook | Script | Purpose |
|------|--------|---------|
| `PreToolUse` | `homerun-pre-commit.sh` | Block git commit/push if lint or typecheck fails |
| `PostToolUse` | `homerun-auto-lint.sh` | Auto-format after Edit/Write operations |
| `PostToolUse` | `homerun-quality-lint.sh` | Standalone lint check (zero LLM cost) |
| `PostToolUse` | `homerun-quality-typecheck.sh` | Standalone typecheck (zero LLM cost) |
| `WorktreeCreate` | `homerun-worktree-setup.sh` | Initialize implementer worktrees |
| `SubagentStop` | `homerun-post-implement.sh` | Log progress + aggregate feedback patterns |
| `TaskCompleted` | `homerun-task-completed.sh` | Validate tests before task completion |

## State Management

All workflow state is tracked in `state.json` in the worktree root:

```
state.json
├── session_id              # Unique workflow identifier
├── branch                  # Git branch name
├── worktree                # Path to isolated worktree
├── phase                   # discovery → spec_review → scope_analysis → task_decomposition → implementing → completing
├── scale                   # "small" | "medium" | "large"
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
│   ├── auto_mode
│   ├── timeout_minutes
│   ├── max_identical_rejections
│   ├── max_iterations_without_progress
│   └── retries { same_agent, fresh_agent }
└── skill_log               # Audit trail of skill invocations
```

## File Structure

**Plugin:**
```
homerun/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata
├── agents/                       # Native Claude Code subagent definitions
│   ├── discovery-agent.md
│   ├── spec-reviewer.md
│   ├── scope-analyzer.md
│   ├── task-decomposer.md
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
│   ├── scope-analysis/SKILL.md
│   ├── task-decomposition/SKILL.md
│   ├── team-lead/SKILL.md
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
│   ├── build.md
│   ├── create.md
│   ├── diagnose.md
│   ├── plan.md
│   ├── reverse-engineer.md
│   ├── review.md
│   └── status.md
├── references/                   # Configuration and contracts
│   ├── anti-patterns.md
│   ├── archived-specs/
│   ├── context-engineering.md
│   ├── debugging-flowchart.md
│   ├── discovery-questions.md
│   ├── duplication-matrix.md
│   ├── five-whys.md
│   ├── hooks-configuration.md    # Hook setup guide
│   ├── impact-analysis.md
│   ├── model-routing.json        # Task-to-model assignments
│   ├── quality-gates.md
│   ├── retry-patterns.md
│   ├── scale-determination.md
│   ├── signal-contracts.json     # Typed signal envelopes
│   ├── state-schema.md
│   ├── test-assertion-rules.md
│   ├── token-estimation.md
│   └── validation-gates.md
├── scripts/                      # Hook scripts
│   ├── homerun-pre-commit.sh     # PreToolUse: block commit on lint/type errors
│   ├── homerun-auto-lint.sh      # PostToolUse: auto-format after edits
│   ├── homerun-quality-lint.sh   # Standalone lint (zero LLM cost)
│   ├── homerun-quality-typecheck.sh  # Standalone typecheck (zero LLM cost)
│   ├── homerun-validate-dag.sh   # DAG validation (zero LLM cost)
│   ├── homerun-worktree-setup.sh # WorktreeCreate hook
│   ├── homerun-post-implement.sh # SubagentStop hook + feedback aggregation
│   ├── homerun-task-completed.sh # TaskCompleted validation gate
│   └── lib/
│       ├── tasks-bridge.js       # tasks.json → native TaskCreate reference
│       ├── feedback-aggregator.sh # Extract rejection patterns for session learning
│       ├── session-state.sh      # Session-aware state.json lookup
│       └── pkg-manager.sh        # Auto-detect npm/yarn/pnpm/bun
├── hooks/                        # Auto-registered hook configuration
│   ├── hooks.json                # Hook declarations (auto-registered on install)
│   └── run-hook.cmd              # Cross-platform hook dispatcher (Windows + Unix)
├── templates/                    # Document templates
├── evals/                        # Skill evaluation suites
└── cookbooks/                    # Example dialogues and patterns
```

**Worktree (project-specific):**
```
../project-create-feature-uuid/
├── docs/
│   ├── tasks.json             # All tasks in single JSON file
│   └── scope-analysis.json    # Extracted components, ACs, JIT refs
├── feedback_patterns.json     # Accumulated rejection patterns (generated)
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
| `SCOPE_ANALYSIS_COMPLETE` | scope-analyzer | Components, ACs, JIT refs extracted |
| `PLANNING_COMPLETE` | task-decomposer | Tasks decomposed, ready for implementation |
| `TEST_SKELETONS_COMPLETE` | test-skeleton-generator | Test scaffolding generated |
| `IMPLEMENTATION_COMPLETE` | implementer | Task done, ready for review |
| `NEEDS_REWORK` | implementer | Self-review failed; implementer re-dispatched by team-lead |
| `IMPLEMENTATION_BLOCKED` | implementer | Task blocked (missing dep, unclear reqs, duplication, tautological test) |
| `REVIEW_DISPATCHED` | team-lead | Reviewer spawned for completed task |
| `APPROVED` | reviewer | Task passed review |
| `REJECTED` | reviewer | Task failed review with feedback |
| `QUALITY_CHECK_COMPLETE` | quality-checker | Quality pipeline results |
| `TEAM_LEAD_COMPLETE` | team-lead | All tasks orchestrated, quality gate passed |
| `DIAGNOSIS_COMPLETE` | diagnostician | Root cause identified with solutions |
| `DIAGNOSIS_INCONCLUSIVE` | diagnostician | Needs more investigation |
| `REVERSE_ENGINEER_COMPLETE` | reverse-engineer | Specs generated from code |
| `WALKTHROUGH_COMPLETE` | walkthrough-generator | Demo scripts generated |
| `VALIDATION_ERROR` | any | Input validation failed |

## Retry Logic & Circuit Breakers

```
Task rejected (attempt 1 failed)
      │
      ▼
  fresh_agent retries remaining? (default: 1)
      │ YES → Spawn fresh agent (clean slate + structured failure summary)
      │ NO ↓
  same_agent retries remaining? (default: 1)
      │ YES → Retry with same agent + targeted guidance
      │ NO ↓
  Model is haiku? → Escalate to sonnet
      │ NO ↓
  Escalate to user
```

**Circuit breaker:** 3 consecutive failures or same feedback 3x → stop spawning, escalate.

## Evals

30 evaluation files across 8 categories in `evals/`:

| Category | Evals | Coverage |
|----------|-------|----------|
| discovery | 5 | Dialogue flow, document generation, signal envelope |
| planning | 5 | Task decomposition, DAG validation, model routing |
| scope-analysis | 3 | AC validation, component extraction |
| team-lead | 4 | Dispatch loop, scale routing (trivial/small/medium/large), context synthesis, auto-classifier |
| implement | 4 | TDD workflow, signal completion, implementation notes, blocked signals |
| review | 5 | Approve/reject scenarios, re-review flows |
| quality-check | 2 | Phase ordering, signal envelope |
| scripts | 2 | DAG validation (valid + cycle detection) |

LLM judge evals use haiku for cost control (max 500 tokens per call).

### Running Evals

Evals are run with [prompteval](https://github.com/Zxela/prompteval), a skill benchmarking framework for Claude Code:

```bash
# Install prompteval
git clone https://github.com/Zxela/prompteval.git
cd prompteval && npm install && npm run build

# Run all homerun evals
node dist/cli/index.js run --plugin /path/to/homerun --verbose

# Run by tag
node dist/cli/index.js run --plugin /path/to/homerun --tags team-lead
node dist/cli/index.js run --plugin /path/to/homerun --tags routing
node dist/cli/index.js run --plugin /path/to/homerun --tags signals

# Dry run (list evals without executing)
node dist/cli/index.js run --plugin /path/to/homerun --dry-run
```

## Credits

See [CREDITS.md](CREDITS.md) for inspiration and sources.
