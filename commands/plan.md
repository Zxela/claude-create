---
name: plan
description: "Jump directly into the planning phase with existing specification documents. Use when you already have PRD/ADR/TECHNICAL_DESIGN and want to decompose into tasks."
argument-hint: "<worktree-path> [--auto]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, MultiEdit, Skill
---

# /plan Command

Jump directly into the planning phase, skipping discovery. Use when you already have specification documents and want to decompose them into implementation tasks.

## Usage

```
/plan <worktree-path> [--auto]
/plan --find
```

## Arguments

- `worktree-path`: Path to an existing worktree with `state.json` (required unless `--find`)
- `--auto`: Skip confirmation prompts, proceed automatically
- `--find`: Search for existing homerun worktrees to plan

## Workflow

### 1. Find or Validate Worktree

If `--find` is specified:
```bash
git worktree list | grep create/
```

Otherwise, validate the provided path:
```bash
# Check state.json exists
cat "$WORKTREE_PATH/state.json" | jq '.phase'
```

### 2. Validate Prerequisites

Read `state.json` and verify:
- `phase` is "discovery" or "planning" (not already "implementing")
- `spec_paths` are populated with valid file paths
- Spec documents exist at the referenced paths

```bash
# Verify spec docs exist
for spec in prd adr technical_design; do
  path=$(jq -r ".spec_paths.$spec" "$WORKTREE_PATH/state.json")
  [ -f "$path" ] && echo "$spec: OK" || echo "$spec: MISSING"
done
```

### 3. Invoke Planning

```javascript
Task({
  description: "Plan implementation tasks",
  subagent_type: "general-purpose",
  model: "opus",
  prompt: `Use the homerun:planning skill.

  Worktree: ${worktree_path}
  State file: ${worktree_path}/state.json

  Read state.json and spec documents, then decompose into tasks.`
});
```

### 4. Report

Display the task summary from the PLANNING_COMPLETE signal.

## Examples

```
/plan ../myapp-create-user-auth-a1b2c3d4
/plan ../myapp-create-user-auth-a1b2c3d4 --auto
/plan --find
```
