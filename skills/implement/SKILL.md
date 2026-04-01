---
name: implement
description: "[haiku/sonnet] Implement a task using TDD (model set by team-lead based on task complexity)"
color: yellow
---

# Implement Skill

## References

`references/context-engineering.md` · `references/scale-determination.md` · `references/anti-patterns.md` · `references/impact-analysis.md` · `references/duplication-matrix.md` · `references/test-assertion-rules.md`

## Overview

Implementer agent. Job: implement ONE task → commit → signal completion. Methodology (TDD/direct) set by team-lead. **Context budget: < 20K tokens.** Apply observation masking.

## Input Schema (JSON)

Validate input before proceeding. Required fields: `task` (id, title, objective, acceptance_criteria, test_file), `spec_paths` (technical_design, adr), `worktree_path`.

Key task fields:
- `task_type`: Classification for model routing — haiku types: `add_field`, `add_method`, `add_validation`, `rename_refactor`, `add_test`, `add_config`, `add_endpoint`. Sonnet types: `create_model`, `create_service`, `add_endpoint_complex`, `create_middleware`, `bug_fix`, `integration_test`. Opus: `architectural`.
- `acceptance_criteria[]`: Each has `id` (AC-NNN), `criterion`, `risk_level` (must_test|verify_only|structural, default: must_test)
- `context_refs`: JIT references — `interface_locations` (file:section), `pattern_files`, `grep_patterns`, `constraints_section`
- `methodology`: tdd (default) or direct
- `previous_feedback[]`: Prior rejection issues/fixes (on retries)

### Input Validation

Validate before proceeding: required fields present, `task.id` matches `^[0-9]{3}$`, `acceptance_criteria` non-empty, spec files exist. On failure → `VALIDATION_ERROR` signal.

### AC Placeholder Gate (All Task Types — No Exceptions)

Scan every AC for placeholder language. Reject: "TBD/TODO", "add appropriate error handling", "similar to Task N", vague objectives without testable assertions. If ANY AC is a placeholder → emit `VALIDATION_ERROR` with `semantic_error` type. Do not attempt implementation.

## Process

### 0. Pre-Implementation Analysis

**Skip for haiku tasks** (add_field, add_method, add_validation, rename_refactor, add_test, add_config, add_endpoint) → jump to Step 1. **Sonnet/opus tasks only.** Budget: ~2.5K tokens.

#### 0a. Strategy Selection
Pick one: vertical-slice | horizontal-layer | outside-in | inside-out | risk-first. Document rationale in 2-3 sentences. Risk-first if uncertain, horizontal if extending patterns, vertical-slice if greenfield.

#### 0b. Metacognitive Questions
3-5 self-interrogation questions by task type. Answer briefly. "I don't know" → investigate via targeted grep before coding.

- create_model/add_field: existing references? migrations? serialization breaks?
- create_service/add_method: call chain? consumers? error states?
- add_endpoint: middleware? auth? response contract?
- bug_fix: reproducible? root cause vs symptom? regression test?
- create_middleware: execution order? downstream data? failure modes?

#### 0c. Impact Analysis (3-Stage)
1. **Discovery** — grep for related functions/classes/constants in src/ and tests/
2. **Understanding** — classify each match: Calls/Called-by/Shares-state/Tests
3. **Identification** — label files: Direct (must modify) / Indirect (verify) / Unaffected (ignore)

#### 0d. Duplication Check (Rule of Three)
1st occurrence → implement inline. 2nd → note similarity. 3rd+ → must consolidate (extract shared logic). Exception: different bounded contexts or superficial similarity. If 3+ real matches with same semantics → emit `IMPLEMENTATION_BLOCKED` with `blocker_type: "duplication_detected"`.

---

### 1. Understand the Task

Use `task.context_refs` for JIT context loading:
1. Read `context_refs.interface_locations` (targeted section reads, not full files)
2. Check `context_refs.pattern_files` (signatures only: `grep -A 5 "function\|class\|export"`)
3. Run `context_refs.grep_patterns` to discover related code
4. Read `context_refs.constraints_section` for constraints

**Avoid:** reading entire directories, files you won't modify, full spec files, or re-reading files already in context.

### 2. Read Reference Docs (Targeted Extraction)

Extract only relevant spec sections via grep. By task type: create_model → "## Data Model", add_endpoint → "## API Contracts", create_service → "## Components", bug_fix → component section. If `traces_to.adr_decisions` exists → grep that specific decision. Use absolute paths from `spec_paths`.

### 3. Apply Methodology

#### TDD (default): RED → GREEN → REFACTOR → REPEAT per AC
- Write test BEFORE implementation. Each test must initially FAIL.
- Simple tasks (add_field, etc.) may use `direct` methodology instead.

#### Direct: Implement → verify. For config/docs with `test_file: null`.

**Test output masking** (saves 5-10K tokens/run): `npm test -- --reporter=dot 2>&1 | tail -30`. Keep: pass/fail summary + first failure. Discard: passing details, duplicates, coverage reports.

### 4. Address Rejection Feedback

On retry: fix EXACT issues from rejection first. No new features until all rejection points resolved.

### 5. Commit

Stage and commit: `feat(<feature>): <task title>`

### 5.5. Mutation Test Verification

**Only for `bug_fix` and `create_service` tasks.** Skip all other types.

Catches tautological tests. Procedure: comment out one critical implementation line → re-run test → if test still passes, emit `IMPLEMENTATION_BLOCKED` with `blocker_type: "tautological_test"`. Always restore the line. Scope: ONE line, ONE AC (the most critical).

### 5.6. Self-Review Checklist

Run before signaling completion:

1. **Placeholder scan** — grep changed files for TODO/FIXME/console.log/debugger and 3+ consecutive commented lines
2. **Scope check** — `git diff --name-only HEAD~1` — flag unexpected files not in context_refs
3. **AC coverage** — must_test ACs have dedicated tests, verify_only in consolidated tests, structural covered by types/lint
4. **Hard gates** — run tests, tsc --noEmit, eslint; capture exit codes

All pass → `IMPLEMENTATION_COMPLETE` with `hard_gate_results`. Any fail → `NEEDS_REWORK` with findings.

### 6. Signal Completion

Output JSON signal wrapped in a ```json code block.

---

## Output Signals

All output MUST be valid JSON in a ```json code block. Four possible signals:

### IMPLEMENTATION_COMPLETE
Required fields: `signal`, `files_changed`, `test_file`, `commit_hash`, `hard_gate_results` ({tests, types, lint} exit codes), `verification_level` (L1|L2|L3), `verification_attempted` (array), `acceptance_criteria_met` (array of {criterion, implementation_file, test_location} with file:line format).

Include `verification_details` if L3-only (explain why L1/L2 impossible). If any AC cannot be addressed → use IMPLEMENTATION_BLOCKED instead. Never omit criteria silently.

### IMPLEMENTATION_BLOCKED
Required: `signal`, `reason`, `blocker_type` (missing_dependency|unclear_requirements|technical_constraint|test_failure|tautological_test|duplication_detected), `suggested_resolution`. Optional: `details[]`.

### NEEDS_REWORK
Self-review failed. Required: `signal`, `findings[]` ({check, description, files}), `hard_gate_results`. Team-lead re-dispatches without reviewer.

### VALIDATION_ERROR
Required: `signal`, `error_type` (invalid_input|semantic_error), `errors[]` ({path, message, expected, received}).

## Red Flags — STOP

**TDD:** No code before test. Test passes immediately → rewrite. Never skip ACs. Never modify code to make a failing test pass.
**All:** Stay within task scope. No unrelated changes.

## Test Granularity

Test observable behavior only (return values, side effects, error responses, state changes). Do NOT test private methods, internal state, or call order. Mock external boundaries only (DB, HTTP, filesystem). If mocking 3+ internal modules → design is too coupled.

## Context Budget: < 20K tokens

Pre-impl ~2.5K | Task input ~1K | Spec extraction ~2K | Code reads ~3K | Test output ~0.5K | Implementation ~4K | Buffer ~7K. If approaching 20K: stop reading, summarize, complete or signal BLOCKED.

## Verification Levels

Attempt in order: **L1** (feature works e2e) → **L2** (tests pass) → **L3** (builds clean). Only fall back when higher level is genuinely impossible. L3-only without justification is a review finding.

---

## Exit Criteria

- [ ] All ACs addressed (must_test → dedicated tests, verify_only → integration tests, structural → types/lint)
- [ ] TDD: tests written before implementation
- [ ] Verification attempted L1 → L2 → L3; L3-only justified
- [ ] Committed with `feat(<feature>): <task title>`
- [ ] Signal emitted with files, test file, commit hash, verification level
- [ ] No unaddressed rejection feedback (if retry)
- [ ] Context < 20K tokens
