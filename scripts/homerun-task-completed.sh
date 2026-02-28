#!/bin/bash
# Hook: TaskCompleted (for Agent Teams mode)
# Purpose: Validate implementation before marking a native task as complete
#
# Exit codes:
#   0 — Allow task completion
#   2 — Block task completion (validation failed)
#
# IMPORTANT: Uses session-aware state lookup to avoid reading another
# parallel session's state.json.
#
# Usage: Add to .claude/settings.json:
#   "hooks": {
#     "TaskCompleted": [{
#       "hooks": [{
#         "type": "command",
#         "command": "$CLAUDE_PLUGIN_ROOT/scripts/homerun-task-completed.sh"
#       }]
#     }]
#   }

set -euo pipefail

WORKTREE_PATH="${CLAUDE_WORKTREE_PATH:-$(pwd)}"

# --- Session-aware state.json lookup ---
# First: check the current worktree directly
STATE_FILE="$WORKTREE_PATH/state.json"

if [ ! -f "$STATE_FILE" ]; then
  # Find the parent session's state.json by matching session_id
  BRANCH=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  SESSION_ID="${BRANCH#create/}"

  if [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "$BRANCH" ]; then
    for wt in $(git -C "$WORKTREE_PATH" worktree list 2>/dev/null | awk '{print $1}'); do
      [ "$wt" = "$WORKTREE_PATH" ] && continue
      if [ -f "$wt/state.json" ]; then
        FILE_SESSION_ID=$(jq -r '.session_id // empty' "$wt/state.json" 2>/dev/null)
        if [ "$FILE_SESSION_ID" = "$SESSION_ID" ]; then
          STATE_FILE="$wt/state.json"
          break
        fi
      fi
    done
  fi
fi

if [ ! -f "$STATE_FILE" ]; then
  # Not a homerun project, allow completion
  exit 0
fi

# Check orchestration mode
MODE=$(jq -r '.orchestration_mode // "unknown"' "$STATE_FILE")
if [ "$MODE" != "agent_teams" ]; then
  # Not in Agent Teams mode, allow completion
  exit 0
fi

# Basic validation: check that tests pass in the worktree
TASKS_FILE=$(jq -r '.tasks_file // "docs/tasks.json"' "$STATE_FILE")
SOURCE_DIR=$(dirname "$STATE_FILE")

# Run a quick test check (if test runner is configured)
if [ -f "$SOURCE_DIR/package.json" ]; then
  PKG_MANAGER=$(jq -r '.packageManager // "npm"' "$SOURCE_DIR/package.json" | cut -d@ -f1)
  if jq -e '.scripts.test' "$SOURCE_DIR/package.json" > /dev/null 2>&1; then
    echo "homerun-task-completed: Running tests..."
    cd "$SOURCE_DIR"
    if ! $PKG_MANAGER test 2>&1; then
      echo "homerun-task-completed: Tests failed — blocking task completion" >&2
      exit 2  # Block completion
    fi
  fi
fi

echo "homerun-task-completed: Validation passed"
exit 0
