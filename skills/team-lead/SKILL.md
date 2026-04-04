---
name: team-lead
description: "Guide implementation orchestration — dispatch implementers, track progress, run quality gate"
model: inherit
color: cyan
---

# Team Lead Skill

## Overview

Orchestrate Phase 3 (Implementation) **inline in main session**. Dispatch implementers, track via native tasks, run quality gate. Announce: "Starting implementation — dispatching tasks from the DAG."

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

If `feedback_patterns.json` exists: inject `common_patterns` and `session_patterns` into implementer prompts. Absent/empty → skip.

### Iteration Caps

Per-task: max 3 rejections → `needs_user_input`, escalate. Session: max 5 total retries → pause, present status. Caps supersede per-section limits.

### 3. Dispatch Loop

Work through the DAG by dispatching implementers for ready tasks.

**For each iteration:**

1. **Find ready tasks** — status "pending", all dependencies completed
2. **Decide parallelism:**
   - Independent tasks (no shared files, no dependency) → dispatch in parallel using `run_in_background: true` with `isolation: "worktree"`
   - Dependent tasks → dispatch sequentially (wait for result before next)
   - Cap at 3 concurrent implementers
3. **Select model by task type** — Read `references/model-routing.json` to determine the correct model. Haiku tasks (`add_field`, `add_method`, `add_validation`, `rename_refactor`, `add_test`, `add_config`, `add_endpoint`) use haiku. Sonnet tasks (`create_model`, `create_service`, `add_endpoint_complex`, `create_middleware`, `bug_fix`, `integration_test`) use sonnet. Architectural tasks use opus. **Always pass `model:` in the Task call** — the implementer agent defaults to sonnet, so haiku tasks will waste cost without the override.

4. **Dispatch implementer(s):**
   - Build synthesis context (see Context Synthesis section below)
   - Determine model from task type
   - Pass synthesized upstream context in the prompt

```javascript
// Determine model from task_type (see references/model-routing.json)
const HAIKU_TYPES = ["add_field", "add_method", "add_validation", "rename_refactor", "add_test", "add_config", "add_endpoint"];
const taskModel = HAIKU_TYPES.includes(task.task_type) ? "haiku" : "sonnet";

// Build synthesis context for tasks with completed dependencies
const synthesisContext = buildSynthesisContext(task, tasksJson);

Task({
  description: `Implement [${task.id}] ${task.title}`,
  subagent_type: "homerun:implementer",
  model: taskModel,
  isolation: "worktree",  // Only needed for parallel dispatch
  prompt: `Implement this task using TDD.

  Worktree: ${worktreePath}
  Task ID: ${task.id}
  Title: ${task.title}
  Objective: ${task.objective}

  ${synthesisContext ? `Context from upstream tasks:\n  ${synthesisContext}\n` : ''}
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

#### Context Synthesis for Dependent Tasks

When dispatching a task that has completed dependencies (`depends_on` with status "completed"), synthesize context from upstream work before building the dispatch prompt.

**Synthesis depth by downstream task tier:**

**Haiku-tier downstream tasks:**
1. Read `implementation_notes` from each completed dependency in tasks.json
2. Build a bullet-point context block:
   ```
   Context from upstream tasks:
   - [${dep.id}] ${dep.title}: Changed ${notes.files_changed.join(', ')}. ${notes.key_decisions || ''}
     ${notes.gotchas ? 'Watch out: ' + notes.gotchas : ''}
   ```
3. Prepend this block to the implementer prompt

**Sonnet/opus-tier downstream tasks:**
1. Read `implementation_notes` from each completed dependency
2. Read the actual diff: `git log --oneline -1 ${dep_commit_hash} && git diff ${dep_commit_hash}~1..${dep_commit_hash}`
3. Build a detailed context block:
   ```
   Context from [${dep.id}] ${dep.title}:
   Files changed: ${notes.files_changed}
   Key decisions: ${notes.key_decisions}
   Interfaces established: ${notes.interfaces_established}
   Gotchas: ${notes.gotchas}
   
   Relevant diff sections:
   ${filtered_diff}  // Only sections touching files in downstream task's context_refs
   ```
4. Replace generic JIT context_refs with synthesized paths for any files that appear in upstream `implementation_notes.files_changed`
5. Prepend the full context block to the implementer prompt

**Important:** Only include diff sections relevant to the downstream task. Filter by files that appear in the downstream task's `context_refs` or `acceptance_criteria`. Do not dump the entire upstream diff.

5. **After each implementer returns:**
   - **If `NEEDS_REWORK`:** Re-dispatch the implementer immediately with the self-review findings as `previous_feedback`. No reviewer is needed — the implementer caught its own issues. Include the `findings` array so the implementer knows exactly what to fix. This counts toward the retry limit (max 2 retries per task).
   - **If `IMPLEMENTATION_COMPLETE`:**
     1. Read `implementation_notes` from the signal payload
     2. Write `implementation_notes` to the task entry in docs/tasks.json
     3. Write `agent_id` to the task entry (for potential rework continuation)
     4. Mark native task completed
     5. If `hard_gate_results` present with all exit codes 0: dispatch reviewer with `skip_hard_gates: true` (see Section 3.5)
     6. Otherwise: dispatch reviewer normally (no `skip_hard_gates`)
   - Update tasks.json if the implementer didn't already
   - Find next batch of ready tasks
   - Repeat until no pending tasks remain

**Handling failures:** If an implementer fails:
- Check what went wrong (read its output)
- Retry once with the error context added to the prompt
- If still failing after 2 attempts, skip the task and note it
- Continue with remaining tasks (failed tasks may block dependents — that's expected)

### Requirement Change Detection

Watch for: new features, constraint additions, technical changes, scope expansion, behavioral pivots. On detection → pause pending dispatches, inform user, ask: (a) update specs + re-plan, (b) note for follow-up, (c) ignore.

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
const hardGates = task.hard_gate_results; // from implementer's completion signal
const canSkipHardGates = hardGates &&
  hardGates.tests === 0 && hardGates.types === 0 && hardGates.lint === 0;

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

    skip_hard_gates: ${canSkipHardGates}
    hard_gate_results: ${JSON.stringify(hardGates || {})}

    ${canSkipHardGates
      ? 'Hard gates passed in implementer self-review. Skip Tier 1, go straight to Tier 2 soft review.'
      : 'Run Tier 1 hard gates first, then Tier 2 soft review.'}
    Use git diff ${task.commit_hash}~1..${task.commit_hash} as primary review input (diff-based review). Only read full files when diff context is insufficient.
    Emit APPROVED or REJECTED signal.`
  });
} else {
  // Queue for review when a slot opens
  reviewQueue.push(task.id);
}
```

**Handling NEEDS_REWORK (from implementer self-review):**

When an implementer emits `NEEDS_REWORK` instead of `IMPLEMENTATION_COMPLETE`:
1. Read the `findings` array from the signal
2. Re-dispatch the implementer with findings as `previous_feedback` — no reviewer needed
3. This counts toward the retry limit (max 2 retries per task)
4. If the implementer still emits `NEEDS_REWORK` after max retries, skip the task and note it

**Handling rejections (from reviewer) — Continue-on-Rework:**

When a reviewer emits `REJECTED`:
1. Read rejection feedback (severity, issues, required_fixes)
2. Load feedback_patterns.json (updated by post-implement hook)
3. **Placeholder escalation check** (unchanged): If >2 rejections cite "incomplete", "vague", or "placeholder":
   - Mark task as "blocked" in tasks.json with reason "placeholder_ac"
   - Escalate to re-decomposition: re-invoke `homerun:task-decomposition` for affected task(s)
   - Resume only after concrete ACs

4. **Continue-on-rework:**
   - Record attempt in tasks.json `attempts` array: `{ agent_id, status: "rejected", severity, feedback }`
   - **If severity is low/medium AND attempts.length == 1 (first rejection):**
     - Attempt `SendMessage` to the original `agent_id` from tasks.json
     - Message content: the reviewer's `required_fixes` array + specific `issues` with file paths and line numbers
     - If SendMessage succeeds: implementer applies targeted fix, re-runs self-review, re-signals
     - If SendMessage fails (agent terminated): fall through to fresh spawn below
   - **If severity is low/medium AND attempts.length >= 2 (second+ rejection):**
     - Spawn fresh implementer with structured failure summary from all attempts
     - Include all previous rejection feedback
   - **If severity is high:**
     - Escalate to user (unchanged)

5. Iteration caps remain: max 3 rejections per task, max 5 session retries

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
// Determine session tier: if ALL tasks (completed + skipped) were haiku-type, tier = "haiku". Otherwise "sonnet".
const HAIKU_TYPES = ["add_field", "add_method", "add_validation", "rename_refactor", "add_test", "add_config", "add_endpoint"];
const allTasks = [...completedTasks, ...skippedTasks];
const sessionTier = allTasks.length > 0 && allTasks.every(t => HAIKU_TYPES.includes(t.task_type)) ? "haiku" : "sonnet";

Task({
  description: "Final quality check",
  subagent_type: "homerun:quality-checker",
  prompt: `Run the quality pipeline.

  Worktree: ${worktreePath}
  Files changed: ${allChangedFiles}
  Fix mode: ${sessionTier === "haiku" ? "report_only" : "auto"}
  Tier: ${sessionTier}

  ${sessionTier === "haiku"
    ? "Haiku-tier session: run lint, type checks, and tests only. Skip structural review (Phase 3), LLM auto-fix, and final recheck (Phase 5)."
    : "Run lint, type checks, structural review, tests, and final recheck. Auto-fix issues where possible."
  }`
});
```

**Quality check is a blocking gate.** If the quality check returns a `verdict: "fail"`:

1. **Do NOT proceed to merge or PR creation.** The failure blocks forward progress.
2. Surface the unresolved issues to the user with full details.
3. Ask the user to decide: (a) fix the issues and re-run quality check, (b) override and proceed anyway.
4. **Escalation rule:** If quality check fails **twice on the same issues**, escalate to the user with a summary of the recurring failures and a recommendation. Do not attempt a third automatic fix cycle.

### 5. Complete

```bash
# Update state.json
jq '.phase = "completing" | .orchestration_completed_at = now' state.json > state.json.tmp && mv state.json.tmp state.json

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
- [ ] Quality check passed (or user explicitly overrode failures)
- [ ] state.json phase set to "completing"
