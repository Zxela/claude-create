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
│  Phases 1-2 run as bash hooks (zero LLM cost), Phase 3 uses LLM          │
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
| `--retries N,M` | Retry limits: N=same agent, M=fresh agent (default: 2,1) |

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
│  │ Model: sonnet    │  │ Model: sonnet     │  │ Model: sonnet     │       │
│  │ Skills: implement│  │ Skills: review    │  │ Skills: quality   │       │
│  │ × 1-3 parallel   │  │ × 1-2 concurrent │  │ × 1 (final gate)  │       │
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
│   ├── create.md
│   ├── plan.md
│   ├── build.md
│   ├── review.md
│   ├── diagnose.md
│   └── reverse-engineer.md
├── references/                   # Configuration and contracts
│   ├── signal-contracts.json     # Typed signal envelopes
│   ├── model-routing.json        # Task-to-model assignments
│   ├── hooks-configuration.md    # Hook setup guide
│   ├── context-engineering.md
│   ├── discovery-questions.md
│   ├── scale-determination.md
│   ├── retry-patterns.md
│   └── retry-patterns.md
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
│       └── feedback-aggregator.sh # Extract rejection patterns for session learning
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
Task rejected
      │
      ▼
  attempts < fresh_agent_limit (default: 1)
      │ YES → Spawn fresh agent (clean slate + failure summary)
      │ NO ↓
  attempts < fresh + same_agent_limit (default: 1)
      │ YES → Retry with same agent + accumulated context
      │ NO ↓
  Escalate model (sonnet → opus)
      │ NO ↓
  Escalate to user
```

**Circuit breaker:** 3 consecutive failures or same feedback 3x → stop spawning, escalate.

## Credits

See [CREDITS.md](CREDITS.md) for inspiration and sources.
