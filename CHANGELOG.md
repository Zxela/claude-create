# Changelog

## [5.7.0] - 2026-03-27

### Added
- **Hooks auto-registration** — `hooks/hooks.json` and `hooks/run-hook.cmd` register all hooks automatically when the plugin is installed. No manual `.claude/settings.json` configuration needed.
- **Cross-platform hook runner** — `hooks/run-hook.cmd` is a polyglot wrapper that works on both Windows (cmd.exe with Git Bash) and Unix.
- **Eval expansion** — New evals for scope-analysis (3), team-lead (2), quality-check (2), and DAG validation scripts (2). Total eval count: 27 across 8 categories.
- **Review calibration** — Scope decomposition gates and placeholder prevention for acceptance criteria.
- **Verification enforcement** — Self-review fast-path for implementers; placeholder scan before completion signal.
- **NEEDS_REWORK signal** — Registered in signal-contracts.json with full envelope example.

### Fixed
- **Conductor → team-lead migration** — Replaced all conductor references across diagrams, cookbooks, references, and templates with team-lead (#8-#11).
- **Script hardening** — DAG validator, pkg manager detection, sponge dependency removal, scope-analyzer edge cases (#15).
- **Diagram corrections** — Retry order, missing phases, spec-review skill placement (#18).
- **Worktree setup** — Restored unconditional `mkdir` to prevent race condition on fresh worktrees (#17).
- **Signal alignment** — Agent signal names now match signal-contracts.json exactly (#14).
- **Stale references** — Removed dead skill references and stale paths in templates and skills (#9).
- **Quality-gates** — Corrected phase ordering and retry defaults (#10).
- **Eval config** — Updated `homerun:planning` to `homerun:task-decomposition` (#12).
- **README** — Fixed file structure listing, added missing refs (#13).
- **Templates** — Bumped remaining templates to v1.1, added risk_level to task-decomposition example.
- **.gitignore** — Added `.claude/` to prevent orphaned worktrees from appearing as untracked files.

### Changed
- **Hooks documentation rewrite** — `references/hooks-configuration.md` and `skills/setup-quality-gates/SKILL.md` updated to reflect auto-registration model instead of manual setup instructions.

## [5.6.1] - 2026-02-28

### Added
- **Code quality reference files** — 6 compact reference files (278 lines total) for JIT loading by skills, not global context:
  - `anti-patterns.md` — Red flag checklist: Rule of Three, SRP, DRY, error suppression, YAGNI
  - `impact-analysis.md` — 3-stage procedure (Discovery → Understanding → Identification) before modifying existing code
  - `duplication-matrix.md` — 5-dimension similarity scoring with escalation thresholds
  - `test-assertion-rules.md` — Literal expected values, verify results not invocation order, no dead tests
  - `five-whys.md` — Structured root cause analysis with common failure patterns
  - `quality-gates.md` — Sequential zero-error phase model (lint → structure → types → tests → recheck)
- Wired references into skill definitions: `implement` (4 files), `diagnose` (1 file), `quality-check` (1 file)

## [5.6.0] - 2026-02-28

### Added
- **EARS format for acceptance criteria** — PRD template, scope-analysis validation, and discovery dialogue now enforce EARS (Easy Approach to Requirements Syntax): When/While/If-then/Unconditional/Quantitative patterns. Legacy Given/When/Then still accepted.
- **Test granularity rules** — "Observable Behavior Only" guidance added to implement skill and TDD skill. MUST test public APIs/return values/side effects. MUST NOT test private methods/internal state/call order. Mocking rules: external boundaries only.
- **Functional/Non-functional requirements** — PRD template now has FR section with MoSCoW prioritization (Must/Should/Could/Won't) and NFR section with quantified targets. TECHNICAL_DESIGN has NFR Implementation section (Performance/Security/Reliability approaches).
- **Includes/Excludes on all templates** — PRD, ADR, and TECHNICAL_DESIGN templates now have HTML comment headers declaring what belongs in each document and what goes elsewhere, preventing information bleed.
- **Existing Codebase Analysis** — TECHNICAL_DESIGN template now includes Related Functionality, Patterns to Follow, and Integration Point Map sections to prevent duplication and ensure alignment with existing code.
- **Change Impact Map** — TECHNICAL_DESIGN template now requires Direct Impact, Indirect Impact, and No Ripple Effect sections.
- **Agreement Checklist** — TECHNICAL_DESIGN template now includes pre-implementation sign-off on Scope, Non-scope, Constraints, Testing, and Rollback.
- **Requirement change detection** — Team-lead skill now has explicit checklist for detecting mid-implementation requirement shifts (new features, constraint additions, tech changes, scope expansion, behavioral pivots) with stop-and-assess protocol.
- **Strategy justification** — Implement skill Step 0a now requires explicit strategy selection for sonnet/opus tasks: vertical-slice, horizontal-layer, outside-in, inside-out, or risk-first, with 2-3 sentence rationale.

### Changed
- Template versions bumped 1.0 → 1.1 (PRD, TECHNICAL_DESIGN, ADR)
- Implement skill Step 0 sub-steps renumbered: 0a (strategy) → 0b (metacognitive) → 0c (impact) → 0d (duplication)
- Context budget for Step 0 increased from ~2K to ~2.5K tokens to accommodate strategy selection

## [5.5.0] - 2026-02-28

### Changed
- **Discovery skill rewrite** — Complete rewrite of discovery SKILL.md (880 → 397 lines). Codebase-first approach: analyzes project deeply before asking questions, presents findings then asks gaps instead of rigid 5-category questionnaire.
- **Structured dialogue UI** — Discovery now uses `AskUserQuestion` for all user interaction, presenting clickable options instead of text-based Q&A. Added to discovery-agent tool list.
- **Simplified AC guidance** — Replaced EARS format prescription (When/While/If-Then/None) with simpler "observable outcome" principle and good/bad examples.
- **Simplified validation flow** — Documents presented for review at once instead of section-by-section 200-word chunks. User verdict collected via `AskUserQuestion`.
- **Fixed dialogue contradictions** — Agent config and question reference previously said "one question at a time" while SKILL.md said "batch 2-4". All now consistently say batch.

### Added
- `references/state-schema.md` — State.json schema, field descriptions, and scale-based initialization examples (extracted from SKILL.md where it appeared twice).
- `references/validation-gates.md` — PRD/ADR/user-story validation scripts and handling rules (extracted from SKILL.md).

## [5.4.0] - 2026-02-28

### Added
- **Plan-then-stop default** — In interactive mode, `/create` now stops after DAG validation and prints a task summary, directing the user to `/build <worktree>` to start implementation. Auto mode continues as before.
- **AC risk-level classification** — Acceptance criteria are now classified as `must_test`, `verify_only`, or `structural` in task decomposition. Test budgets by scale (small: 2-4, medium: 4-8, large: 10-20) reduce test bloat.
- **`/status` command** — Read-only command that lists homerun worktrees with phase, feature, scale, and task progress. Supports detailed mode with per-task status and feedback patterns.
- **Git hook framework detection** — Setup-quality-gates now detects existing hook frameworks (husky, pre-commit, custom) before configuring Claude Code hooks, avoiding duplication.
- **Template versioning** — All 9 templates now include YAML front-matter (`template_version`, `template_name`, `compatible_homerun`). Spec-review includes informational (non-blocking) version check.
- **`test_requirements` map** in model-routing.json — Per-tier test requirements (haiku tasks like `add_field`, `add_config`, `rename_refactor` are `optional`).

### Changed
- **Spec-review skip in auto mode** — When `--auto` is set and scale is not `"large"`, spec review is skipped to reduce cost.
- **Mutation testing narrowed** — Step 5.5 mutation verification now only runs for `bug_fix` and `create_service` task types (previously ran for all complex types).
- **Review severity rubric** — "Missing test" is only `medium` severity for `must_test` ACs; `verify_only`/`structural` ACs are `low`.
- **Quality-check hook detection** — Phases 1-2 (lint/typecheck) skip with `"skipped_by_hooks"` when git hooks already enforce these.
- **Implement exit criteria** — Updated to reference risk levels: `must_test` ACs need dedicated tests, `verify_only` confirmed in integration tests, `structural` confirmed by types/lint.

### Removed
- **Conductor skill** (`skills/conductor/SKILL.md`) — Fully removed (deprecated since v5.0.0).
- **Conductor evals** (`evals/conductor/`) — 5 eval files removed.
- **State machine reference** (`references/state-machine.md`) — Removed (superseded by team-lead).
- **Stale dev-notes** (`.dev-notes/2026-01-31-session-pickup-notes.md`) — All tasks done or superseded.
- **TDD skill reference** in implement SKILL.md — Removed redundant cross-reference.
- All remaining `"conductor"` references replaced with `"team-lead"` across skills, agents, references, templates, and evals config.

## [5.3.0] - 2026-02-27

### Added
- **Auto mode support in discovery** — When `--auto` flag is set, discovery skips interactive dialogue entirely and generates specs from the initial prompt + codebase scan. Skips section-by-section validation and proceeds directly through phases.
- **Auto mode support in /build** — Skips "Ready to start?" confirmation prompt when `--auto` is set.
- **Auto mode in validation gates** — Discovery validation warnings auto-proceed instead of prompting in auto mode.

### Changed
- **Discovery dialogue format** — Changed from one-question-at-a-time to batched questions (2-4 related questions per message) for faster interactive discovery.
- **README.md rewritten** — Updated to reflect v5.2.0 architecture: 3-layer planning pipeline (scope-analyzer → task-decomposer → validate-dag.sh), inline team-lead skill, continuous incremental review, deterministic quality hooks, feedback accumulation, all current scripts and agents.
- **Architecture diagrams updated** — Fixed Discovery model (inherit not opus), added scope-analyzer and task-decomposer agents, updated phase transitions, fixed component relationships.
- **Sequence diagrams updated** — Simplified flow now shows full 3-layer pipeline with scope analyzer and task decomposer as separate participants.
- **Hooks configuration updated** — Added standalone quality-lint and quality-typecheck hook documentation, feedback aggregation docs, fixed combined configuration example.
- **Context engineering reference** — Updated version header to v5.2.0, reflects current pipeline architecture.

## [5.2.0] - 2026-02-27

### Added
- **Session-level feedback accumulation** (`scripts/lib/feedback-aggregator.sh`) — Extracts reviewer rejection patterns from tasks.json and writes `feedback_patterns.json`. Team-lead injects accumulated patterns into each implementer's prompt, enabling session-wide learning from rejections.
- **Deterministic lint hook** (`scripts/homerun-quality-lint.sh`) — Standalone bash script for lint auto-fix at zero LLM cost. Auto-detects project lint tool (biome, eslint, prettier, ruff).
- **Deterministic typecheck hook** (`scripts/homerun-quality-typecheck.sh`) — Standalone bash script for type checking at zero LLM cost. Auto-detects type checker (tsc, mypy, pyright).
- **Test mutation verification gate** (implement skill Step 5.5) — Before signaling completion, implementers comment out one critical line and re-run the test. If test still passes, blocks with `IMPLEMENTATION_BLOCKED(blocker_type: "tautological_test")`. Only for complex task types.
- **Scale-aware discovery haiku fast path** — Early scale estimation in discovery dialogue. When scope < 3 files, skips PRD/ADR/WIREFRAMES, skips scope-analysis phase, and routes to haiku model. Adds `scale` field to state.json.
- **Continuous incremental review** (team-lead Section 3.5) — Reviewers spawn as each task completes (max 2 concurrent), running in parallel with remaining implementers. Rejected tasks retry immediately with feedback context.
- **`REVIEW_DISPATCHED` signal** — New signal contract for incremental review dispatch with `reviewer_slot` and `max_concurrent` metadata.
- `tautological_test` blocker type added to `IMPLEMENTATION_BLOCKED` signal schema.
- `skip_scope_analysis: true` added to `scale_routing.small` in model-routing.json.

### Changed
- **Quality-checker agent maxTurns reduced from 15 to 10** — Phases 1 (lint) and 2 (typecheck) now handled by standalone bash hooks, not the LLM agent. Agent focuses on Phase 3 (structural review), Phase 4 (tests), and Phase 5 (recheck). ~30-40% cost reduction.
- **Quality-check skill** — Phases 1 and 2 updated to reference hook scripts instead of inline bash.
- **Post-implement hook** — Now calls feedback-aggregator after logging progress (non-blocking).
- **Reviewer agent** — Added incremental review mode documentation for single-task lifecycle.
- **Implementer agent** — Added Step 5.5 mutation test verification documentation.

## [5.1.0] - 2026-02-27

### Added
- **Scope analysis skill** (`homerun:scope-analysis`) — Sonnet-powered mechanical extraction of components, AC validation, JIT context refs from spec documents. Produces `docs/scope-analysis.json`.
- **Scope analyzer agent** (`scope-analyzer`, sonnet, cyan) — Runs scope analysis at ~10 turns, 5x cheaper than opus.
- **DAG validation script** (`scripts/homerun-validate-dag.sh`) — Pure bash/jq validation at zero LLM cost: cycle detection (Kahn's algorithm), test path validation, AC coverage, dependency ordering, required fields check. Exit codes: 0=pass, 1=warnings, 2=block.
- **`SCOPE_ANALYSIS_COMPLETE` signal** — New signal contract for scope analysis phase completion.
- New phases in `/create` flow: `scope_analysis` and `task_decomposition` replace single `planning` phase.

### Changed
- **Planning pipeline split into 3 layers** — The single planner agent (opus, ~20 turns) is replaced by: scope-analyzer (sonnet, ~10 turns) for mechanical work + task-decomposer (opus, ~8 turns) for judgment work + validate-dag.sh for structural validation. ~50% cost reduction.
- **Planner agent renamed to task-decomposer** (`agents/planner.md` → `agents/task-decomposer.md`) — maxTurns reduced from 20 to 10, reads `docs/scope-analysis.json` instead of raw specs.
- **Planning skill renamed to task-decomposition** (`skills/planning/` → `skills/task-decomposition/`) — Phases 1 (scope analysis), 1.5 (AC validation), and 2.5 (JIT ref creation) moved to scope-analysis skill. Validation gate moved to bash script.
- `/create` command phase loop updated: `spec_review` → `scope_analysis` → `task_decomposition` → `validate-dag.sh` → `implementing`.
- `/plan` command updated to invoke scope-analyzer then task-decomposer sequentially, plus validation script.
- `PLANNING_COMPLETE` signal producer updated from `homerun:planning` to `homerun:task-decomposition`.
- Model routing updated: `scope_analysis: sonnet`, `task_decomposition: opus` replace `planning: opus`.
- Agent limits updated: `scope_analyzer: 12`, `task_decomposer: 10` replace `planner: 20`.
- Architecture diagrams, sequence diagrams, and debugging flowchart updated to reflect 3-layer pipeline.
- Spec reviewer now points to scope-analyzer as next phase instead of planner.

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
