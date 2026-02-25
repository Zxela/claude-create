# Changelog

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
