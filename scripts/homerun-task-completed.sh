#!/bin/bash
# Hook: TaskCompleted (for Agent Teams mode)
# Purpose: Validate implementation before marking a native task as complete
#
# Exit codes:
#   0 — Allow task completion
#   2 — Block task completion (validation failed)
#
# Usage: Add to .claude/settings.json:
#   "hooks": {
#     "TaskCompleted": [{
#       "hooks": [{
#         "type": "command",
#         "command": "./scripts/homerun-task-completed.sh"
#       }]
#     }]
#   }

set -euo pipefail

WORKTREE_PATH="${CLAUDE_WORKTREE_PATH:-$(pwd)}"

# Find state.json
STATE_FILE=""
for wt in $(git -C "$WORKTREE_PATH" worktree list 2>/dev/null | awk '{print $1}'); do
  if [ -f "$wt/state.json" ]; then
    STATE_FILE="$wt/state.json"
    break
  fi
done

if [ -z "$STATE_FILE" ]; then
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
