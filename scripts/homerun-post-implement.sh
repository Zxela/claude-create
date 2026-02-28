#!/bin/bash
# Hook: SubagentStop (matcher: implementer)
# Purpose: Log progress after an implementer finishes
#
# This script runs when an implementer subagent stops.
# It reads tasks.json to report progress.
#
# IMPORTANT: Uses session-aware state lookup to avoid reading another
# parallel session's state.json.
#
# Usage: Add to .claude/settings.json:
#   "hooks": {
#     "SubagentStop": [{
#       "matcher": "implementer",
#       "hooks": [{
#         "type": "command",
#         "command": "$CLAUDE_PLUGIN_ROOT/scripts/homerun-post-implement.sh"
#       }]
#     }]
#   }

set -euo pipefail

WORKTREE_PATH="${CLAUDE_WORKTREE_PATH:-$(pwd)}"

# --- Session-aware state.json lookup ---
# First: check the current worktree directly
STATE_FILE="$WORKTREE_PATH/state.json"

if [ ! -f "$STATE_FILE" ]; then
  # Implementer may run in a sub-worktree. Find the parent session's state.json
  # by matching the branch prefix (create/<session-id>).
  BRANCH=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  SESSION_ID="${BRANCH#create/}"

  if [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "$BRANCH" ]; then
    # Branch is create/*, search for matching session
    for wt in $(git -C "$WORKTREE_PATH" worktree list | awk '{print $1}'); do
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
  echo "homerun-post-implement: No state.json found for this session, skipping" >&2
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
