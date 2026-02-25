# Hooks Configuration Reference

Homerun provides hook scripts that integrate with Claude Code's hook system. Add these to your project's `.claude/settings.json` or user-level settings.

## Required Hooks

### WorktreeCreate — Worktree initialization

Initializes new worktrees created for implementer agents.

```json
{
  "hooks": {
    "WorktreeCreate": [{
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-worktree-setup.sh"
      }]
    }]
  }
}
```

### SubagentStop — Post-implementation progress tracking

Logs progress after an implementer finishes.

```json
{
  "hooks": {
    "SubagentStop": [{
      "matcher": "implementer",
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-post-implement.sh"
      }]
    }]
  }
}
```

## Agent Teams Hooks (Level 2 — requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`)

### TaskCompleted — Implementation validation gate

Runs tests before allowing a native task to complete. Exit code 2 blocks completion.

```json
{
  "hooks": {
    "TaskCompleted": [{
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-task-completed.sh"
      }]
    }]
  }
}
```

## Deterministic Quality Gate Hooks (v4.0)

These hooks replace LLM judgment for phases 1, 2, and 4 of the quality pipeline. They run deterministic CLI checks on every file edit, providing zero-cost, reproducible quality gates.

### PostToolUse — Auto-lint after file edits

Runs linter automatically after every Edit/Write operation. Zero LLM tokens consumed.

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-auto-lint.sh"
      }]
    }]
  }
}
```

Example `homerun-auto-lint.sh`:
```bash
#!/bin/bash
# Auto-lint changed files after edit
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0
if [ -f biome.json ] || [ -f biome.jsonc ]; then
  npx biome check --write "$FILE" 2>/dev/null
elif command -v eslint &>/dev/null; then
  npx eslint --fix "$FILE" 2>/dev/null
fi
exit 0  # Don't block on lint failures
```

### SubagentStop — Run type check + tests after implementer finishes

Validates implementation before the reviewer even sees it. Catches obvious failures early.

```json
{
  "hooks": {
    "SubagentStop": [{
      "matcher": "implementer",
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-post-implement-validate.sh"
      }]
    }]
  }
}
```

Example `homerun-post-implement-validate.sh`:
```bash
#!/bin/bash
# Run deterministic checks after implementer finishes
cd "${CLAUDE_WORKTREE_PATH:-.}"
echo "=== Post-implementation validation ==="
# Type check
if [ -f tsconfig.json ]; then
  npx tsc --noEmit 2>&1 | tail -5
fi
# Test suite
if [ -f package.json ]; then
  npm test 2>&1 | tail -10
fi
exit 0  # Log results but don't block — reviewer will handle failures
```

## Combined Configuration

Add all hooks together in `.claude/settings.json`:

```json
{
  "hooks": {
    "WorktreeCreate": [{
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-worktree-setup.sh"
      }]
    }],
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-auto-lint.sh"
      }]
    }],
    "SubagentStop": [{
      "matcher": "implementer",
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-post-implement-validate.sh"
      }]
    }],
    "TaskCompleted": [{
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-task-completed.sh"
      }]
    }]
  }
}
```

## Hook Exit Codes

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success — proceed normally |
| 1 | Error — log but don't block |
| 2 | Block — prevent the action (TaskCompleted only) |

## Environment Variables

Hooks receive these environment variables from Claude Code:

| Variable | Description |
|----------|-------------|
| `CLAUDE_WORKTREE_PATH` | Path to the worktree being operated on |
| `CLAUDE_AGENT_NAME` | Name of the agent that triggered the hook |
| `CLAUDE_TASK_ID` | ID of the native task (TaskCompleted only) |
