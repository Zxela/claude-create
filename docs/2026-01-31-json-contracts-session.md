# Session: JSON Skill Contracts + Haiku Decomposition

**Date:** 2026-01-31
**Status:** In Progress

## Completed

### Phase 1: Clone Superpowers
- Created `skills/superpowers/` with 4 skills + supporting files:
  - `test-driven-development/` (SKILL.md, testing-anti-patterns.md)
  - `using-git-worktrees/` (SKILL.md)
  - `finishing-a-development-branch/` (SKILL.md)
  - `systematic-debugging/` (SKILL.md + 5 supporting files)

### Phase 2: Rename to "homerun"
- Updated `.claude-plugin/plugin.json` name to "homerun"
- Updated all skill references from `superpowers:X` and `create-workflow:X` to `homerun:X`

### Phase 3: JSON Contracts
- Added JSON input/output schemas to:
  - `skills/implement/SKILL.md` - Input: task, spec_paths, previous_feedback. Output: IMPLEMENTATION_COMPLETE/BLOCKED/VALIDATION_ERROR
  - `skills/review/SKILL.md` - Input: task, implementation, spec_paths. Output: APPROVED/REJECTED/VALIDATION_ERROR
  - `skills/conductor/SKILL.md` - JSON construction, parsing, skill logging
  - `skills/discovery/SKILL.md` - Input: prompt, config. Output: DISCOVERY_COMPLETE
  - `skills/planning/SKILL.md` - Input: worktree_path, spec_paths. Output: PLANNING_COMPLETE

### Phase 4: tasks.json Migration
- Updated planning skill to output single `docs/tasks.json` instead of individual markdown files
- Added jq query examples for conductor
- Added subtask support in schema

### Phase 5: Skill Logging
- Added `skill_log` array to state.json schema
- Added logging protocol to conductor

## Remaining: Haiku Decomposition (B+E+F Approach)

### Approach B: Task Type Classification

Add to planning skill - classify tasks and assign default model:

```json
{
  "task_types": {
    "add_field": {"model": "haiku", "decomposable": false},
    "add_method": {"model": "haiku", "decomposable": false},
    "add_validation": {"model": "haiku", "decomposable": false},
    "create_model": {"model": "sonnet", "decomposable": true},
    "create_service": {"model": "sonnet", "decomposable": true},
    "add_endpoint": {"model": "haiku", "decomposable": false},
    "add_endpoint_with_auth": {"model": "sonnet", "decomposable": true},
    "refactor": {"model": "haiku", "decomposable": false},
    "bug_fix": {"model": "sonnet", "decomposable": false},
    "integration_test": {"model": "sonnet", "decomposable": false}
  }
}
```

### Approach E: Haiku Implements, Sonnet Reviews

Update conductor:
- Implementer model: from task's `model` field (haiku or sonnet)
- Reviewer model: always sonnet
- On rejection with severity=high from sonnet reviewer → re-implement with sonnet

### Approach F: Decomposition Rules

In planning skill, when task_type.decomposable=true:
1. Break into atomic subtasks (single file, single function)
2. Each subtask gets `model: "haiku"`
3. Parent task completes when all subtasks complete

Subtask patterns:
- create_model → [create_class, add_field, add_validation_method...]
- create_service → [create_interface, implement_method...]
- add_endpoint_with_auth → [add_route, add_auth_middleware, add_handler]

## Files Modified This Session

- `.claude-plugin/plugin.json` - name: homerun
- `CLAUDE.md` - updated docs
- `commands/create.md` - homerun references
- `skills/conductor/SKILL.md` - JSON, skill logging
- `skills/discovery/SKILL.md` - JSON schemas, skill_log
- `skills/implement/SKILL.md` - JSON schemas
- `skills/planning/SKILL.md` - tasks.json, subtasks
- `skills/review/SKILL.md` - JSON schemas
- `skills/superpowers/*` - 4 cloned skills + supporting files

## Next Steps

1. Add task_type classification table to planning skill
2. Add decomposition logic to planning skill
3. Update conductor to use task.model for implementer, always sonnet for reviewer
4. Add escalation logic: high-severity rejection → sonnet re-implementation
5. Test end-to-end with a sample workflow
