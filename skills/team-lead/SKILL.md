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
