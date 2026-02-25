#!/bin/bash
# Hook: WorktreeCreate
# Purpose: Initialize a new homerun worktree with required structure
#
# This script runs when Claude Code creates a worktree for an implementer agent.
# It ensures the worktree has the necessary homerun state files.
#
# Usage: Add to .claude/settings.json:
#   "hooks": {
#     "WorktreeCreate": [{
#       "hooks": [{
#         "type": "command",
#         "command": "./scripts/homerun-worktree-setup.sh"
#       }]
#     }]
#   }

set -euo pipefail

WORKTREE_PATH="${CLAUDE_WORKTREE_PATH:-$(pwd)}"

# Only run if this looks like a homerun worktree (has state.json in parent or is a create/ branch)
BRANCH=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "$BRANCH" != create/* ]]; then
  exit 0  # Not a homerun worktree, skip
fi

# Find the main worktree's state.json
MAIN_WORKTREE=$(git -C "$WORKTREE_PATH" worktree list | head -1 | awk '{print $1}')

# Look for state.json in the main worktree or sibling worktrees
STATE_FILE=""
for wt in $(git -C "$WORKTREE_PATH" worktree list | awk '{print $1}'); do
  if [ -f "$wt/state.json" ]; then
    STATE_FILE="$wt/state.json"
    break
  fi
done

if [ -z "$STATE_FILE" ]; then
  echo "homerun-worktree-setup: No state.json found, skipping" >&2
  exit 0
fi

# Ensure docs directory exists
mkdir -p "$WORKTREE_PATH/docs"

# Copy tasks.json if it exists in the source worktree
TASKS_FILE=$(jq -r '.tasks_file // "docs/tasks.json"' "$STATE_FILE")
SOURCE_DIR=$(dirname "$STATE_FILE")
if [ -f "$SOURCE_DIR/$TASKS_FILE" ]; then
  cp "$SOURCE_DIR/$TASKS_FILE" "$WORKTREE_PATH/$TASKS_FILE"
fi

echo "homerun-worktree-setup: Initialized worktree at $WORKTREE_PATH"
