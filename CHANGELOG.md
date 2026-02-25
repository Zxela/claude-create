# Changelog

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
