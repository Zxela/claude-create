#!/bin/bash
# Hook: WorktreeCreate
# Purpose: Initialize a new homerun worktree with required structure
#
# This script runs when Claude Code creates a worktree for an implementer agent.
# It ensures the worktree has the necessary homerun state files.
#
# IMPORTANT: Uses branch-based matching to find the correct parent session's
# state.json, avoiding cross-session contamination when multiple homerun
# sessions run in parallel.
#
# Usage: Add to .claude/settings.json:
#   "hooks": {
#     "WorktreeCreate": [{
#       "hooks": [{
#         "type": "command",
#         "command": "$CLAUDE_PLUGIN_ROOT/scripts/homerun-worktree-setup.sh"
#       }]
#     }]
#   }

set -euo pipefail

WORKTREE_PATH="${CLAUDE_WORKTREE_PATH:-$(pwd)}"

# Only run if this looks like a homerun worktree (branch starts with create/)
BRANCH=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "$BRANCH" != create/* ]]; then
  exit 0  # Not a homerun worktree, skip
fi

# Extract the session ID from the branch name (create/<feature-slug>-<uuid>)
# This is used to find the correct parent session's state.json
SESSION_ID="${BRANCH#create/}"

# Find state.json that belongs to THIS session (not another parallel session)
# Match by session_id field in state.json to avoid cross-session contamination
STATE_FILE=""
for wt in $(git -C "$WORKTREE_PATH" worktree list | awk '{print $1}'); do
  [ "$wt" = "$WORKTREE_PATH" ] && continue  # Skip self
  if [ -f "$wt/state.json" ]; then
    # Verify this state.json belongs to our session
    FILE_SESSION_ID=$(jq -r '.session_id // empty' "$wt/state.json" 2>/dev/null)
    if [ "$FILE_SESSION_ID" = "$SESSION_ID" ]; then
      STATE_FILE="$wt/state.json"
      break
    fi
  fi
done

if [ -z "$STATE_FILE" ]; then
  echo "homerun-worktree-setup: No matching state.json for session $SESSION_ID, skipping" >&2
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

echo "homerun-worktree-setup: Initialized worktree at $WORKTREE_PATH (session: $SESSION_ID)"
