# Changelog

## [5.0.0] - 2026-02-27

### Added
- **Pre-commit quality gate hook** (`scripts/homerun-pre-commit.sh`) — PreToolUse hook that blocks `git commit`/`git push` if lint or typecheck fails. Auto-detects project tools (biome, eslint, prettier, ruff, tsc, mypy).
- **Auto-lint hook** (`scripts/homerun-auto-lint.sh`) — PostToolUse hook that auto-formats files after Edit/Write operations.
- **Setup quality gates skill** (`homerun:setup-quality-gates`) — Configures `.claude/settings.json` with hook entries for target projects. Idempotent, haiku model.
- **Archived specs** (`references/archived-specs/hooks-quality-gates/`) — PRD, ADR, and TECHNICAL_DESIGN from the comprehensive hooks session, preserved for future reference.

### Changed
- **Team-lead converted from agent to inline skill** — Runs at depth 0 in the main session instead of as a constrained depth-1 agent. Leverages Claude's native orchestration. Reduced from ~700 lines to ~120 lines.
- `/create` and `/build` commands now invoke team-lead via `Skill()` instead of `Task()`.
- Architecture diagrams updated to reflect inline team-lead at depth 0.

### Fixed
- **Parallel session state.json collisions** — Hook scripts (`homerun-worktree-setup.sh`, `homerun-post-implement.sh`, `homerun-task-completed.sh`) now match `session_id` from branch name instead of grabbing the first `state.json` found across worktrees.
- **Shared `/tmp/` path collisions** — Replaced hardcoded `/tmp/test-output.txt` and `/tmp/criteria.txt` with `mktemp` in implement, planning, and quality-check skills.

### Removed
- **Team-lead agent** (`agents/team-lead.md`) — Replaced by inline skill.
- **`CONDUCTOR_FALLBACK` signal** — No longer needed with inline team-lead.

## [4.0.0] - 2026-02-25

### Added
- **maxTurns limits** on all 11 agents — prevents runaway token consumption (discovery:30, spec-review:10, planner:20, implementer:25, reviewer:15, quality-checker:15, team-lead:50, diagnostician:20, reverse-engineer:30, test-skeleton:15, walkthrough:15)
- **Effort-proportional routing** (triage gate) in team-lead — small tasks (1-2 files) skip Agent Teams, spec-review, and separate reviewer; medium tasks cap at 2 concurrent; large uses full pipeline
- **Two-tier review evaluation** — Tier 1: deterministic hard gates (tests/types/lint exit codes), Tier 2: LLM judgment with 0.0-1.0 scoring. Approval threshold >= 0.7. Reduces false rejections.
- **JIT context references** (`context_refs`) replace `embedded_context` — planner provides file paths, section names, and grep patterns instead of stale embedded excerpts. Implementers load current code at runtime.
- **Fresh-context-first retries** — first retry uses fresh agent with structured failure summary (not accumulated context). Order: fresh_agent → same_agent → escalate.
- **Deterministic quality gate hooks** — PostToolUse auto-lint hook, SubagentStop type-check+test hook. Phases 1/2/4 of quality pipeline are now zero-cost deterministic checks.
- **Auto-compaction for orchestrators** — team-lead compacts every 10 monitoring iterations, recommends CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50
- **Scale-based pipeline routing** in `references/scale-determination.md` and `references/model-routing.json`
- **Planner determinism rules** — instructions to produce identical decompositions given identical inputs
- `skip_step_0` flag in model-routing.json for haiku tasks — pre-implementation analysis skipped for mechanical tasks
- `scale_routing` and `agent_limits` sections in model-routing.json
- `score` and `hard_gates` fields in review APPROVED/REJECTED signals
- New anti-patterns documented in context-engineering.md (embedded snapshots, LLM for deterministic checks, retrying with accumulated context)

### Changed
- **Reviewer agent** now has `background: true` — runs concurrently with implementers, reducing wall-clock time
- **Quality-checker agent** restructured — phases 1/2/4 explicitly marked DETERMINISTIC (no LLM judgment), phase 3 is the only LLM phase
- **Implementer agent** — Step 0 pre-implementation analysis now gated by task type (skipped for haiku-level tasks)
- **Retry order inverted** — fresh_agent(1x) → same_agent(1x) → escalate (was: same_agent(2x) → fresh_agent(1x))
- **model-routing.json** bumped to v2.0.0 with retry_strategy, agent_limits, and scale_routing sections
- **Planner** uses JIT context references instead of embedded excerpts

### Removed
- `embedded_context` field from task schema (replaced by `context_refs`)

## [3.1.5] - 2026-02-25

### Fixed
- **Flatten `/create` spawn chain** — all phases now run at depth 1 (direct child of main session), fixing `CONDUCTOR_FALLBACK` Tool Unavailability Error where Task tool was inaccessible to deeply nested agents
- `/create` command rewritten as flat state machine loop: spawns each phase, reads `state.json`, spawns next phase
- Discovery skill no longer chains to spec-reviewer or planner — returns after setting `phase: "spec_review"`
- Planning skill no longer chains to team-lead — sets `phase: "implementing"` and returns
- Team-lead fallback simplified: Task tool guaranteed available at depth 1, no secondary Skill fallback needed
- Reverted `invoked_conductor_skill` signal action (no longer needed)

### Changed
- `/build`, `/plan`, `/review`, `/diagnose`, `/reverse-engineer` unchanged — already spawn at depth 1

## [3.1.4] - 2026-02-25

### Fixed
- Self-claim protocol checks git log before claiming — prevents race condition where two teammates implement the same task
- Claim function uses `committedTaskIds` as source of truth for both task availability and dependency resolution

## [3.1.3] - 2026-02-25

### Fixed
- Added ToolSearch to team-lead tools — required to load deferred Agent Teams tools (TaskCreate, TaskUpdate, TeamCreate, etc.)

## [3.1.2] - 2026-02-25

### Fixed
- Added git-vs-tasks.json reconciliation to team-lead monitoring loop — detects tasks with commits but stale status and promotes to `review_pending`
- Self-claim protocol reordered: teammates update tasks.json BEFORE committing so status and code ship together, preventing drift at the source

## [3.1.1] - 2026-02-24

### Fixed
- Team-lead agent no longer self-implements when Agent Teams is unavailable — falls back to conductor instead
- Removed Grep and Glob from team-lead tools (structural enforcement against codebase investigation)
- Added two-step Agent Teams detection: env var check AND ToolSearch for TaskCreate
- Added Tool Constraints section restricting Bash to coordination-only commands
- Strengthened Fallback Protocol with mandatory conductor spawn and prohibited behavior list

## [3.1.0] - 2026-02-24

### Added
- **13 behavioral patterns** adopted from claude-code-config analysis:
  - **Discovery/Spec phase:** EARS acceptance criteria, scale-based flow determination, document segregation, non-scope declaration with Change Impact Map, failure scenario coverage
  - **Planning phase:** Inline context embedding (interfaces, patterns, constraints pre-extracted into each task)
  - **Implementation phase:** Metacognitive questions, 3-stage impact analysis, Rule of Three duplication check, verification levels (L1/L2/L3)
  - **Orchestration phase:** Orchestrator prohibition list, parallel independence gate, scope saturation check
- `references/scale-determination.md` — Scale matrix, ADR triggers, document segregation rules, non-scope requirements
- `embedded_context` field in task schema (planning + implement skills)
- Verification level hierarchy (L1=functional, L2=tests, L3=build) in implement skill output signal

### Changed
- Discovery skill: EARS format replaces generic testable patterns; Step 2.5 scale estimation added; scope questions now include non-scope
- Implement skill: Step 0 expanded from similar function discovery to full pre-implementation analysis (0a metacognitive, 0b impact analysis, 0c duplication check)
- Team-lead agent: prohibited actions section; parallel independence gate (3 conditions before concurrent execution)
- Reviewer agent: verification level validation; failure scenario coverage dimension
- Spec-reviewer agent: EARS testability check; document segregation validation; failure scenario coverage
- Planner agent: embeds context in tasks; includes non-scope in constraints
- Discovery, reverse-engineer, diagnostician agents: scope saturation check (3 sources with no new info → stop)

## [3.0.0] - 2026-02-24

### Added
- **Team lead skill** (`homerun:team-lead`) — Agent Teams orchestrator that replaces the conductor for parallel implementation. Uses native TaskCreate/TaskUpdate with DAG dependencies, self-claiming implementer teammates, and automatic quality gate.
- **Team lead agent** (`team-lead`, sonnet, cyan) — Named subagent wrapping the team-lead skill with Task tool access for spawning implementer/reviewer/quality-checker teammates.
- **Tasks bridge** (`scripts/lib/tasks-bridge.js`) — Reference implementation for converting homerun tasks.json to native Claude Code tasks with two-pass DAG dependency wiring.
- **Hook scripts** — `homerun-worktree-setup.sh` (WorktreeCreate), `homerun-post-implement.sh` (SubagentStop), `homerun-task-completed.sh` (TaskCompleted validation gate)
- **Hooks configuration reference** (`references/hooks-configuration.md`) — Setup documentation for all homerun hooks
- **New signals:** `TEAM_LEAD_COMPLETE`, `CONDUCTOR_FALLBACK`

### Changed
- `/create` execution phase now spawns `team-lead` agent instead of conductor directly
- `/build` command now invokes `team-lead` agent with automatic conductor fallback
- Planning skill transitions to `team-lead` agent after task decomposition
- Phase flow diagram updated: execution phase shows Agent Teams orchestration

### Deprecated
- **Conductor skill** (`homerun:conductor`) — Retained as fallback when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not set. The team-lead agent auto-detects and falls back to conductor when needed.

## [2.1.0] - 2026-02-24

### Added
- **Native subagent definitions** (`agents/` directory) — 10 named agents wrapping existing skills with enforced tool restrictions, model selection, and color identifiers:
  - `discovery-agent` (inherit, yellow) — Requirements gathering dialogue
  - `spec-reviewer` (sonnet, orange) — Read-only spec validation
  - `planner` (opus, purple) — Task decomposition with DAG
  - `implementer` (sonnet, yellow) — TDD implementation with similar function discovery
  - `reviewer` (sonnet, blue) — Read-only implementation verification
  - `quality-checker` (sonnet, teal) — 5-phase quality pipeline with auto-fix
  - `diagnostician` (sonnet, red) — 3-phase evidence pipeline for bug investigation
  - `reverse-engineer` (opus, violet) — Generate specs from existing code
  - `test-skeleton-generator` (sonnet, lime) — ROI-prioritized test scaffolding
  - `walkthrough-generator` (sonnet, magenta) — Playwright/curl demo scripts

### Changed
- All commands now reference named subagents via `Task({ subagent_type: "agent-name" })` instead of generic `Task({ subagent_type: "general-purpose", model: "...", prompt: "Use the homerun:skill-name skill..." })`
- Commands updated with `Task` in `allowed-tools` for subagent spawning
- Conductor skill spawns `implementer` and `reviewer` agents by name
- Discovery skill spawns `spec-reviewer` agent by name
- Planning skill documents conductor → team-lead migration path (Level 2)
- Conductor self-refresh still uses `general-purpose` (pending Level 2 team-lead replacement)

## [2.0.0] - 2026-02-24

### Added
- **Spec Review skill** (`homerun:spec-review`) — Cross-document consistency, completeness, and testability validation between discovery and planning phases. Catches contradictions before they cascade into bad tasks.
- **Diagnose skill** (`homerun:diagnose`) — 3-phase evidence pipeline (investigate → verify → solve) for structured bug diagnosis with evidence matrix, alternative hypothesis testing, and tradeoff analysis.
- **Quality Check skill** (`homerun:quality-check`) — 5-phase quality pipeline (lint, types, structure, tests, recheck) with auto-fix capability. Complements the review skill's spec compliance checks.
- **Reverse Engineer skill** (`homerun:reverse-engineer`) — Generate PRD, ADR, and TECHNICAL_DESIGN from an existing codebase. Supports full project, module, and feature scopes with confidence annotations.
- **Generate Test Skeletons skill** (`homerun:generate-test-skeletons`) — ROI-prioritized test skeleton generation from specs. Runs optionally between planning and implementation.
- **Walkthrough skill** (`homerun:walkthrough`) — Generate Playwright walkthrough scripts (or curl scripts for APIs) from user journeys for demo recordings.
- **Similar Function Discovery** — Pre-implementation step in the implement skill that searches for existing similar code to prevent duplication. Blocks with `duplication_detected` if high overlap found.
- **New commands:** `/plan`, `/build`, `/review`, `/diagnose`, `/reverse-engineer` — Allow jumping directly into specific phases without running the full `/create` workflow.
- **New signals:** `SPEC_REVIEW_COMPLETE`, `DIAGNOSIS_COMPLETE`, `DIAGNOSIS_INCONCLUSIVE`, `QUALITY_CHECK_COMPLETE`, `REVERSE_ENGINEER_COMPLETE`, `TEST_SKELETONS_COMPLETE`, `WALKTHROUGH_COMPLETE`
- New phase models in model-routing.json for all new skills

### Changed
- `/create` phase flow now includes spec review between discovery and planning, optional test skeleton generation after planning, and quality check before completion
- Discovery skill now transitions to spec-review phase instead of directly to planning
- `/create` resume mode handles new phases (spec_review, completing)
- Implement skill context budget adjusted to accommodate similar function discovery step

## [1.2.4] - 2026-02-10

### Added
- Simulated responses to discovery eval scenarios for dialogue-flow and signal-envelope

## [1.2.3] - 2026-02-09

### Added
- Greeting function

## [1.2.2] - 2026-02-09

### Added
- Comprehensive eval suite for all skills

### Fixed
- Conductor agent ID tracking for proper TaskOutput polling

### Changed
- Reorganized project structure and fixed critical issues
- Implemented 10 workflow improvement plans

## [1.2.0] - 2026-02-09

### Changed
- Upgraded planning phase to use opus model

## [1.1.0] - 2026-02-09

### Added
- Color field to skill frontmatter
- Model indicators to skill descriptions

## [1.0.0] - 2026-02-09

### Fixed
- Missing model parameters in Task invocations

### Changed
- Updated model assignments in README and CLAUDE.md

### Added
- Recommended frontmatter fields to `/create` command header
- CI workflow to update parent repo on new tags

## [0.3.0] - 2026-01-31

### Added
- Parallel execution for conductor (spawning, sequential reviews, failure handling, context refresh)
- Ready task detection and concurrency control
- Reactive scheduler diagram for conductor

### Changed
- Planning phase now spawns conductor with haiku model

## [0.2.0] - 2026-01-31

Initial tagged release.
