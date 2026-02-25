---
name: build
description: "Jump directly into the execution phase with existing tasks. Use when you have a tasks.json and want to start or resume implementation."
argument-hint: "<worktree-path> [--auto]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, MultiEdit, Skill, Task
---

# /build Command

Jump directly into the execution/implementation phase. Use when you already have a `tasks.json` and want to start or resume the conductor loop.

## Usage

```
/build <worktree-path> [--auto]
/build --find
```

## Arguments

- `worktree-path`: Path to an existing worktree with `state.json` and `docs/tasks.json` (required unless `--find`)
- `--auto`: Skip confirmation prompts
- `--find`: Search for existing homerun worktrees ready for build

## Workflow

### 1. Find or Validate Worktree

If `--find`:
```bash
git worktree list | grep create/
```

Otherwise validate:
```bash
cat "$WORKTREE_PATH/state.json" | jq '.phase'
cat "$WORKTREE_PATH/docs/tasks.json" | jq '.tasks | length'
```

### 2. Validate Prerequisites

- `state.json` exists with `phase` = "planning" or "implementing"
- `docs/tasks.json` exists with at least 1 task
- At least 1 task has `status: "pending"`

```bash
PENDING=$(jq '[.tasks[] | select(.status == "pending")] | length' "$WORKTREE_PATH/docs/tasks.json")
echo "Pending tasks: $PENDING"
```

### 3. Show Status

Before starting, display current progress:

```
Build status for: user-auth
  Total tasks: 8
  Completed: 3
  Pending: 4
  Failed: 1

Ready to start conductor? [Y/n]
```

### 4. Invoke Conductor

```javascript
Task({
  description: "Execute implementation loop",
  subagent_type: "general-purpose",
  model: "haiku",
  prompt: `Use the homerun:conductor skill.

  Worktree: ${worktree_path}
  State file: ${worktree_path}/state.json

  Read state.json, find pending tasks, and orchestrate parallel implementation.`
});
```

## Examples

```
/build ../myapp-create-user-auth-a1b2c3d4
/build ../myapp-create-user-auth-a1b2c3d4 --auto
/build --find
```
