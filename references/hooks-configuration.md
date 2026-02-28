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

These hooks replace LLM judgment for phases 1, 2, and 4 of the quality pipeline. They run deterministic CLI checks automatically, providing zero-cost, reproducible quality gates.

### PreToolUse — Block commits if lint/typecheck fails

**This is the primary quality gate.** Intercepts `git commit` and `git push` commands and runs the project's lint and typecheck tools first. Blocks the command (exit 2) if either fails, with error output on stderr so Claude can fix the issues.

Auto-detects quality tools in this order:
1. `package.json` scripts (`lint`, `typecheck`, `type-check`, `check-types`)
2. Config files (biome.json, eslint.config.js, tsconfig.json, pyproject.toml)
3. CLI tools (ruff, mypy)

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "$CLAUDE_PLUGIN_ROOT/scripts/homerun-pre-commit.sh"
      }]
    }]
  }
}
```

See `scripts/homerun-pre-commit.sh` for the full implementation.

### PostToolUse — Auto-lint after file edits

Runs linter with auto-fix after every Edit/Write operation. Non-blocking (always exit 0). Zero LLM tokens consumed. Skips non-source files (markdown, JSON, YAML, lock files).

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "$CLAUDE_PLUGIN_ROOT/scripts/homerun-auto-lint.sh"
      }]
    }]
  }
}
```

See `scripts/homerun-auto-lint.sh` for the full implementation.

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
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "$CLAUDE_PLUGIN_ROOT/scripts/homerun-pre-commit.sh"
      }]
    }],
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "$CLAUDE_PLUGIN_ROOT/scripts/homerun-auto-lint.sh"
      }]
    }],
    "WorktreeCreate": [{
      "hooks": [{
        "type": "command",
        "command": "$CLAUDE_PLUGIN_ROOT/scripts/homerun-worktree-setup.sh"
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
        "command": "$CLAUDE_PLUGIN_ROOT/scripts/homerun-task-completed.sh"
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
| 2 | Block — prevent the action (PreToolUse and TaskCompleted). stderr is fed back to Claude as feedback. |

## Environment Variables

Hooks receive these environment variables from Claude Code:

| Variable | Description |
|----------|-------------|
| `CLAUDE_PROJECT_DIR` | The project root directory |
| `CLAUDE_PLUGIN_ROOT` | The plugin's root directory (for plugin-bundled scripts) |
| `CLAUDE_WORKTREE_PATH` | Path to the worktree being operated on |
| `CLAUDE_AGENT_NAME` | Name of the agent that triggered the hook |
| `CLAUDE_TASK_ID` | ID of the native task (TaskCompleted only) |
