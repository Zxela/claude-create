# Quality Gate Phases

> Sequential zero-error gate model. Each phase must reach zero errors before advancing. Reference for quality-check skill.

## Phase Progression

```
Phase 1 ──0 errors──→ Phase 2 ──0 errors──→ Phase 3 ──0 errors──→ Phase 4 ──0 errors──→ Phase 5
  ↑ fix & retry          ↑ fix & retry          ↑ fix & retry          ↑ fix & retry
```

**Rule:** Do not start Phase N+1 until Phase N reports zero errors. Fixing a later phase may reintroduce earlier errors, so re-run from the earliest failed phase after any fix.

## Phases

| Phase | What | Tool | Blocking? |
|-------|------|------|-----------|
| **1. Lint + Format** | Code style, auto-fixable issues | Linter/formatter | Yes — fix before proceeding |
| **2. Structure** | Unused exports, circular dependencies | Static analysis | Yes — architectural issues |
| **3. Type Check + Build** | Type errors, compilation | TypeScript/compiler | Yes — broken code |
| **4. Tests** | All tests passing | Test runner | Yes — broken behavior |
| **5. Code Recheck** | Final quality sweep | LLM review | Advisory — flag but don't block |

## Why Sequential Matters

- Lint errors cause false type errors → fix lint first
- Type errors cause test failures → fix types before running tests
- Running all phases simultaneously wastes cycles on cascading failures
- Each gate narrows the problem space for the next phase

## Integration with Hooks

Phases 1-2 run via bash hooks at zero LLM cost:
- `homerun-quality-lint.sh` → Phase 1
- `homerun-quality-typecheck.sh` → Phase 3

Phases 4-5 require LLM turns:
- Phase 4: Run test suite, analyze failures
- Phase 5: Structural review of implementation quality

## Statuses

| Status | Meaning |
|--------|---------|
| `approved` | All 5 phases passed with zero errors |
| `needs_fixes` | Errors found — fix and re-run from earliest failed phase |
| `blocked` | Specification unclear — escalate to user |
