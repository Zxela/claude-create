---
name: team-lead
description: "Guide implementation orchestration — dispatch implementers, track progress, run quality gate"
model: inherit
color: cyan
---

# Team Lead Skill

## Overview

You are orchestrating Phase 3 (Implementation). This skill runs **inline in the main session** — you dispatch implementers directly, track progress via native tasks, and run a quality gate at the end.

**Why inline?** Claude naturally handles coordination (ordering, parallelism, failure recovery) better than a constrained subagent with monitoring loops. This skill provides structure, not algorithms.

**Announce at start:** "Starting implementation — dispatching tasks from the DAG."

---

## Process

### 1. Load Tasks

```bash
cd "$WORKTREE_PATH"

TASKS_FILE=$(jq -r '.tasks_file' state.json)
TASK_COUNT=$(jq '.tasks | length' "$TASKS_FILE")
PENDING=$(jq '[.tasks[] | select(.status == "pending")] | length' "$TASKS_FILE")

echo "$PENDING pending of $TASK_COUNT total tasks"
```

Read the full tasks to understand the DAG:

```bash
jq '.tasks[] | {id, title, status, depends_on, type}' "$TASKS_FILE"
```

### 2. Create Native Tasks (Progress Tracking)

Convert each task to a native Claude Code task using TaskCreate. This gives the user visibility into progress.

**Two-pass approach** (create all, then add dependencies):

```
Pass 1: For each task in tasks.json:
  TaskCreate({
    subject: "[task.id] task.title",
    description: "Objective: ...\nAcceptance criteria: ...\nTest hints: ...",
    activeForm: "Implementing task.title"
  })
  Record the mapping: homerun_id → native_id

Pass 2: For each task with depends_on:
  TaskUpdate({
    taskId: native_id,
    addBlockedBy: [native_ids of dependencies]
  })
```

### 2.5. Feedback Pattern Injection

Before dispatching implementers, check for accumulated feedback patterns from prior rejections in this session.

```bash
FEEDBACK_FILE="$WORKTREE_PATH/feedback_patterns.json"
if [ -f "$FEEDBACK_FILE" ] && [ -s "$FEEDBACK_FILE" ]; then
  PATTERNS=$(jq -r '.common_patterns // [] | join(", ")' "$FEEDBACK_FILE")
  REJECTION_COUNT=$(jq -r '.total_rejections // 0' "$FEEDBACK_FILE")
  echo "Session has $REJECTION_COUNT prior rejections. Common patterns: $PATTERNS"
fi
```

**When feedback_patterns.json exists and is non-empty:**
- Read the `common_patterns` and `session_patterns` arrays
- Include a `previous_rejections` block in each implementer's task prompt:
  ```
  **Previous rejection patterns in this session (apply proactively):**
  ${session_patterns.map(p => `- Task ${p.task_id}: ${p.rejection_reasons.join(', ')}`).join('\n')}

  Common issues to avoid: ${common_patterns.join(', ')}
  ```
- This enables implementers to learn from earlier rejections without re-experiencing them

**When feedback_patterns.json does not exist or is empty:**
- Proceed normally — no injection needed
- This is the common case for the first task in a session

### 3. Dispatch Loop

Work through the DAG by dispatching implementers for ready tasks.

**For each iteration:**

1. **Find ready tasks** — status "pending", all dependencies completed
2. **Decide parallelism:**
   - Independent tasks (no shared files, no dependency) → dispatch in parallel using `run_in_background: true` with `isolation: "worktree"`
   - Dependent tasks → dispatch sequentially (wait for result before next)
   - Cap at 3 concurrent implementers
3. **Dispatch implementer(s):**

```javascript
Task({
  description: `Implement [${task.id}] ${task.title}`,
  subagent_type: "homerun:implementer",
  isolation: "worktree",  // Only needed for parallel dispatch
  prompt: `Implement this task using TDD.

  Worktree: ${worktreePath}
  Task ID: ${task.id}
  Title: ${task.title}
  Objective: ${task.objective}

  Acceptance criteria:
  ${task.acceptance_criteria.map(c => '- ' + c).join('\n')}

  Test hints:
  ${task.test_hints.map(h => '- ' + h).join('\n')}

  Spec documents: ${JSON.stringify(specPaths)}

  Previous session feedback: ${feedbackContext || 'None (first task)'}

  Use commit message format: [${task.id}] <description>
  Update docs/tasks.json status to "completed" when done.`
});
```

4. **After each implementer returns:**
   - Mark the native task completed: `TaskUpdate({ taskId, status: "completed" })`
   - Update tasks.json if the implementer didn't already
   - Find next batch of ready tasks
   - Repeat until no pending tasks remain

**Handling failures:** If an implementer fails:
- Check what went wrong (read its output)
- Retry once with the error context added to the prompt
- If still failing after 2 attempts, skip the task and note it
- Continue with remaining tasks (failed tasks may block dependents — that's expected)

### Requirement Change Detection

During the dispatch loop, watch for signals that requirements have shifted. If ANY of these are detected in user messages, **stop the dispatch loop** and return to discovery/re-scoping before continuing:

| Signal | Example | Action |
|--------|---------|--------|
| **New features mentioned** | "Oh, we should also add email notifications" | Stop — new scope needs spec updates |
| **Constraint additions** | "Actually, this needs to work offline too" | Stop — constraint changes ripple through design |
| **Technical requirement changes** | "Let's use WebSockets instead of polling" | Stop — architecture decision needs ADR update |
| **Scope expansion** | "Can we also handle the admin side?" | Stop — new user stories need PRD update |
| **Behavioral pivots** | "Actually the error should retry, not fail" | Assess — minor AC update vs. architectural change |

**When detected:**
1. Pause all pending implementer dispatches (let active ones finish)
2. Inform the user: "I noticed a potential requirement change: [specific signal]. This may affect the current implementation plan."
3. Ask whether to: (a) update specs and re-plan affected tasks, (b) note it for a follow-up, or (c) ignore — it was just thinking out loud
4. If (a): update spec documents, re-run scope analysis for affected tasks only, resume dispatch

### 3.5. Continuous Incremental Review

Instead of waiting for all implementers to finish before reviewing, spawn reviewers **as each task completes**. This parallelizes review with ongoing implementation.

**Review dispatch rules:**

1. **On task completion:** When an implementer finishes and its task status moves to "completed", immediately check for available reviewer slots
2. **Concurrency limit:** Maximum **2 concurrent reviewers** at any time
3. **Parallel with implementers:** Reviewers run alongside remaining implementers — do not wait for all implementations to finish

**Dispatch a reviewer for each completed task:**

```javascript
// When implementer completes task X:
const activeReviewers = countActiveReviewers(); // track spawned reviewer agents
if (activeReviewers < 2) {
  Task({
    description: `Review [${task.id}] ${task.title}`,
    subagent_type: "homerun:reviewer",
    run_in_background: true,
    prompt: `Review this implementation against its specification.

    Worktree: ${worktreePath}
    Task ID: ${task.id}
    Title: ${task.title}
    Objective: ${task.objective}
    Commit hash: ${task.commit_hash}
    Files changed: ${task.files_changed}

    Acceptance criteria:
    ${task.acceptance_criteria.map(c => '- ' + c.criterion).join('\n')}

    Spec documents: ${JSON.stringify(specPaths)}

    Run Tier 1 hard gates first, then Tier 2 soft review.
    Emit APPROVED or REJECTED signal.`
  });
} else {
  // Queue for review when a slot opens
  reviewQueue.push(task.id);
}
```

**Handling rejections:**

When a reviewer emits `REJECTED`:
1. Read the rejection feedback
2. Load feedback_patterns.json (updated by the post-implement hook)
3. Re-dispatch the implementer with:
   - The specific rejection issues from the reviewer
   - The accumulated session feedback patterns (from Section 2.5)
   - A retry counter (max 2 retries per task)
4. The re-dispatched implementer runs alongside other active implementers/reviewers

**Handling approvals:**

When a reviewer emits `APPROVED`:
1. Mark the task as "approved" in tasks.json
2. Check reviewQueue — if tasks are waiting for review, dispatch the next one
3. Check if all tasks are now approved → if yes, proceed to Quality Gate (Section 4)

**Monitoring loop:**

```
while (pendingTasks > 0 || activeImplementers > 0 || activeReviewers > 0):
  1. Check for completed implementers → dispatch reviewers (up to 2)
  2. Check for completed reviewers → handle APPROVED/REJECTED
  3. Dispatch next batch of ready implementers (respecting DAG)
  4. Repeat
```

**Exit condition:** All tasks are either "approved" or "skipped" (after max retries). Then proceed to the final Quality Gate.

### 4. Quality Gate

After all tasks complete (or are skipped):

```javascript
Task({
  description: "Final quality check",
  subagent_type: "homerun:quality-checker",
  prompt: `Run the 5-phase quality pipeline.

  Worktree: ${worktreePath}
  Files changed: ${allChangedFiles}
  Fix mode: auto

  Run lint, type checks, structural review, tests, and final recheck.
  Auto-fix issues where possible.`
});
```

If quality check fails with unresolved issues, report them and let the user decide.

### 5. Complete

```bash
# Update state.json
jq '.phase = "completing" | .orchestration_completed_at = now' state.json | sponge state.json

# Or via Write tool:
# Update state.json phase to "completing"
```

---

## Scale-Based Routing

Before the full dispatch loop, check task count:

| Tasks | Strategy |
|-------|----------|
| 1-2 | Dispatch sequentially, skip worktree isolation |
| 3-5 | Dispatch in parallel batches based on DAG |
| 6+ | Dispatch up to 3 concurrent, process DAG in waves |

For 1-2 tasks, the overhead of worktree creation and merging exceeds the parallelism benefit. Just run them sequentially in the current worktree.

---

## Exit Criteria

- [ ] All tasks from tasks.json dispatched to implementers
- [ ] All tasks completed or skipped with documented reasons
- [ ] Native tasks updated to reflect final status
- [ ] Quality check passed (or failures reported)
- [ ] state.json phase set to "completing"
