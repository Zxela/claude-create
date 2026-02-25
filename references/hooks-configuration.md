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
    "SubagentStop": [{
      "matcher": "implementer",
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-post-implement.sh"
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
