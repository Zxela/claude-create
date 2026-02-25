#!/bin/bash
# Hook: SubagentStop (matcher: implementer)
# Purpose: Update task status in tasks.json after an implementer finishes
#
# This script runs when an implementer subagent stops.
# It checks if the task was completed successfully and updates state.
#
# Usage: Add to .claude/settings.json:
#   "hooks": {
#     "SubagentStop": [{
#       "matcher": "implementer",
#       "hooks": [{
#         "type": "command",
#         "command": "./scripts/homerun-post-implement.sh"
#       }]
#     }]
#   }

set -euo pipefail

WORKTREE_PATH="${CLAUDE_WORKTREE_PATH:-$(pwd)}"

# Find state.json
STATE_FILE="$WORKTREE_PATH/state.json"
if [ ! -f "$STATE_FILE" ]; then
  # Try parent directory (implementer may run in a sub-worktree)
  for wt in $(git -C "$WORKTREE_PATH" worktree list | awk '{print $1}'); do
    if [ -f "$wt/state.json" ]; then
      STATE_FILE="$wt/state.json"
      break
    fi
  done
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "homerun-post-implement: No state.json found, skipping" >&2
  exit 0
fi

# Read tasks file path from state
TASKS_FILE=$(jq -r '.tasks_file // "docs/tasks.json"' "$STATE_FILE")
FULL_TASKS_PATH="$(dirname "$STATE_FILE")/$TASKS_FILE"

if [ ! -f "$FULL_TASKS_PATH" ]; then
  echo "homerun-post-implement: Tasks file not found at $FULL_TASKS_PATH" >&2
  exit 0
fi

# Count completed vs total for a progress summary
TOTAL=$(jq '.tasks | length' "$FULL_TASKS_PATH")
COMPLETED=$(jq '[.tasks[] | select(.status == "completed")] | length' "$FULL_TASKS_PATH")
IN_PROGRESS=$(jq '[.tasks[] | select(.status == "in_progress")] | length' "$FULL_TASKS_PATH")
PENDING=$(jq '[.tasks[] | select(.status == "pending")] | length' "$FULL_TASKS_PATH")

echo "homerun-post-implement: Progress — $COMPLETED/$TOTAL completed, $IN_PROGRESS in progress, $PENDING pending"
