---
name: team-lead
description: "[sonnet] Orchestrate parallel implementation using Agent Teams with native task DAG"
model: sonnet
color: cyan
---

# Team Lead Skill

## Reference Documents

- `references/state-machine.md` — State transitions and loop logic
- `references/retry-patterns.md` — Retry queue, circuit breaker, escalation
- `references/context-engineering.md` — Agent spawning patterns
- `references/signal-contracts.json` — Signal envelope format

## Overview

The team lead orchestrates Phase 3 (Implementation) as a replacement for the conductor skill. It uses Claude Code's **Agent Teams** feature for true parallel execution with native task management.

**Key differences from conductor:**

| Aspect | Conductor | Team Lead |
|--------|-----------|-----------|
| Task tracking | Custom `state.json` + polling | Native TaskCreate/TaskUpdate with DAG |
| Parallelism | Manual background Task + TaskOutput polling | Agent Teams teammates self-claim |
| Communication | Filesystem (state.json) | Direct inter-agent messaging |
| Context refresh | Self-spawn new conductor every N tasks | Teammates have independent contexts |
| Reviewer dispatch | Conductor spawns sequentially | Reviewer teammate processes queue |
| Fallback | N/A | Falls back to conductor if Agent Teams disabled |

**Model Selection:** Sonnet — team lead makes coordination decisions (teammate count, escalation, quality gate timing) that require more judgment than conductor's mechanical scheduling.

---

## Prerequisite Check

Before starting, verify Agent Teams is available using a **two-step check**:

### Step 1: Environment variable check

```bash
# Check for Agent Teams experimental flag
if [ -n "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" ]; then
  echo "AGENT_TEAMS_AVAILABLE"
else
  echo "AGENT_TEAMS_UNAVAILABLE"
fi
```

### Step 2: Tool availability check

Even if the env var is set, verify that the Agent Teams tools are actually loadable:

```
ToolSearch({ query: "select:TaskCreate" })
```

If TaskCreate is found and available, Agent Teams is confirmed working.
If TaskCreate is NOT found or returns an error, Agent Teams is NOT available regardless of the env var.

**Both checks must pass** to proceed with Agent Teams orchestration.

### If either check fails: MANDATORY conductor fallback

**CRITICAL: You must NEVER implement tasks yourself. The ONLY fallback is the conductor.**

If Agent Teams is unavailable for any reason, follow these exact steps and then STOP:

1. Log the decision to state.json
2. Spawn the conductor
3. Exit

```javascript
// Update state.json
state.orchestration_mode = "conductor_fallback";
state.orchestration_reason = "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS not set or TaskCreate tool unavailable";
saveState(state);

// Spawn conductor instead — this is the ONLY valid fallback
Task({
  description: "Execute implementation loop (conductor fallback)",
  subagent_type: "general-purpose",
  model: "haiku",
  prompt: `Use the homerun:conductor skill.

  Worktree: ${state.worktree}
  State file: ${state.worktree}/state.json

  Read state.json, find pending tasks, and orchestrate parallel implementation.`
});

// EXIT HERE. Do not continue. The conductor handles everything from this point.
```

**NEVER implement tasks yourself. The ONLY valid fallback is the conductor.**

**If both checks pass:** Proceed with Agent Teams orchestration below.

---

## Input Schema (JSON)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["worktree_path"],
  "properties": {
    "worktree_path": { "type": "string" },
    "config": {
      "type": "object",
      "properties": {
        "auto_mode": { "type": "boolean", "default": false },
        "max_teammates": { "type": "integer", "default": 3 },
        "reviewer_count": { "type": "integer", "default": 1 }
      }
    }
  }
}
```

---

## Process

### 1. Load State and Tasks

```bash
cd "$WORKTREE_PATH"

# Read current state
STATE=$(cat state.json)
TASKS_FILE=$(echo "$STATE" | jq -r '.tasks_file')
TASKS=$(cat "$TASKS_FILE")

# Count tasks by status
TOTAL=$(echo "$TASKS" | jq '.tasks | length')
PENDING=$(echo "$TASKS" | jq '[.tasks[] | select(.status == "pending")] | length')
COMPLETED=$(echo "$TASKS" | jq '[.tasks[] | select(.status == "completed")] | length')
```

### 2. Convert Tasks to Native Task System

Convert each task from `docs/tasks.json` to a native Claude Code task using TaskCreate. This gives us platform-managed DAG enforcement and cross-session visibility.

```javascript
// Build mapping from homerun task IDs to native task IDs
const nativeTaskIdMap = {};

// First pass: create all tasks (without dependencies)
for (const task of tasks) {
  const nativeTask = TaskCreate({
    title: `[${task.id}] ${task.title}`,
    description: `Objective: ${task.objective}

Acceptance criteria:
${task.acceptance_criteria.map(c => `- ${c}`).join('\n')}

Test hints:
${task.test_hints.map(h => `- ${h}`).join('\n')}

Type: ${task.type} | Linked stories: ${task.linked_stories.join(', ')}`,
    status: task.status === "completed" ? "completed" : "pending"
  });

  nativeTaskIdMap[task.id] = nativeTask.id;
}

// Second pass: add DAG dependencies
for (const task of tasks) {
  if (task.depends_on && task.depends_on.length > 0) {
    TaskUpdate({
      id: nativeTaskIdMap[task.id],
      addBlockedBy: task.depends_on.map(dep => nativeTaskIdMap[dep])
    });
  }
}
```

**Important:** Create all tasks first, then add dependencies in a second pass. This avoids referencing tasks that don't exist yet.

### 3. Log Orchestration Mode

```javascript
state.orchestration_mode = "agent_teams";
state.orchestration_started_at = new Date().toISOString();
state.native_task_mapping = nativeTaskIdMap;
saveState(state);
```

### 4. Parallel Independence Check and Teammate Count

Before running tasks in parallel, verify independence. Then scale teammates.

#### 4a. Independence Gate

For each pair of tasks that could run concurrently, check ALL three conditions:

```javascript
function canRunInParallel(taskA, taskB) {
  // Condition 1: Zero shared target files
  const sharedFiles = taskA.target_files.filter(f => taskB.target_files.includes(f));
  if (sharedFiles.length > 0) return false;

  // Condition 2: No input/output data dependency
  // (one task's output is not the other's input)
  const aOutputs = taskA.creates || [];
  const bOutputs = taskB.creates || [];
  const aInputs = taskA.depends_on_files || taskA.target_files;
  const bInputs = taskB.depends_on_files || taskB.target_files;
  if (aOutputs.some(f => bInputs.includes(f))) return false;
  if (bOutputs.some(f => aInputs.includes(f))) return false;

  // Condition 3: No build order requirement
  // (neither task must compile before the other)
  if (taskA.depends_on?.includes(taskB.id)) return false;
  if (taskB.depends_on?.includes(taskA.id)) return false;

  return true;
}
```

**If any condition fails:** Fall back to sequential execution for that pair. Do not force parallel execution.

**Maximum concurrent teammates:** 3 (regardless of DAG width). More than 3 creates diminishing returns from file contention and context overhead.

#### 4b. Teammate Count

Scale teammates based on task count and DAG width (maximum tasks that can run in parallel):

```javascript
function determineTeammateCount(tasks, config) {
  const pending = tasks.filter(t => t.status === "pending");
  const maxParallel = config.max_teammates || 3;

  // Calculate DAG width: max tasks with no unresolved dependencies at any level
  const dagWidth = calculateDagWidth(tasks);

  // Use the smaller of: pending tasks, DAG width, configured max
  const count = Math.min(pending.length, dagWidth, maxParallel);

  // At least 1, at most 5
  return Math.max(1, Math.min(count, 5));
}

function calculateDagWidth(tasks) {
  // Find tasks with no dependencies (or all deps completed)
  const ready = tasks.filter(t =>
    t.status === "pending" &&
    (!t.depends_on || t.depends_on.length === 0 ||
     t.depends_on.every(dep => tasks.find(d => d.id === dep)?.status === "completed"))
  );
  return ready.length;
}
```

### 5. Spawn Teammates

Launch the implementation team:

```javascript
// Spawn implementer teammates
const implementerCount = determineTeammateCount(tasks, config);

for (let i = 0; i < implementerCount; i++) {
  Task({
    description: `Implementer teammate ${i + 1}`,
    subagent_type: "implementer",
    run_in_background: true,
    prompt: `You are implementer teammate ${i + 1} of ${implementerCount}.

    Worktree: ${state.worktree}
    Tasks file: ${state.worktree}/${state.tasks_file}
    Spec paths: ${JSON.stringify(state.spec_paths)}

    SELF-CLAIM PROTOCOL:
    1. Read docs/tasks.json
    2. Find the first task where:
       - status is "pending"
       - all depends_on tasks have status "completed"
       - no other teammate has claimed it (check state.json parallel_state.running_tasks)
    3. BEFORE claiming, run: git log --oneline | grep "[task-NNN]"
       If commits already exist for this task, SKIP it — another teammate finished it.
       Find the next eligible task instead.
    4. Update the task status to "in_progress" in both tasks.json and state.json
    5. Implement the task using TDD
    6. Update task status to "review_pending" in tasks.json BEFORE committing
    7. Commit implementation AND the tasks.json update together
    8. Claim the next available task and repeat
    9. If no tasks available, report idle and exit

    CRITICAL: Steps 6-7 must happen in that order. Update tasks.json FIRST, then commit
    both the code and the updated tasks.json in the same commit. This ensures tasks.json
    is never out of sync with the git history. Use commit message format: [task-NNN].

    IMPORTANT: Before claiming a task, re-read tasks.json AND check git log to avoid
    conflicts with other teammates. The git log check (step 3) is the definitive source
    of truth — if a commit exists, the task is done regardless of what tasks.json says.`
  });
}

// Spawn reviewer teammate
Task({
  description: "Reviewer teammate",
  subagent_type: "reviewer",
  run_in_background: true,
  prompt: `You are the reviewer teammate.

  Worktree: ${state.worktree}
  Tasks file: ${state.worktree}/${state.tasks_file}
  Spec paths: ${JSON.stringify(state.spec_paths)}

  REVIEW PROTOCOL:
  1. Read docs/tasks.json
  2. Find tasks with status "review_pending"
  3. Review the implementation against spec and acceptance criteria
  4. If APPROVED: update status to "completed", update native task via TaskUpdate
  5. If REJECTED: update status to "pending" with feedback, increment attempts
  6. Repeat until all tasks are either completed or escalated
  7. If no tasks to review, wait briefly then check again
  8. Exit when all tasks are completed or escalated`
});
```

### 6. Monitor Progress

The team lead monitors teammates and handles escalation:

```javascript
// Monitoring loop
while (true) {
  // Check native task list for overall progress
  const taskList = TaskList();
  const allTasks = taskList.filter(t => t.title.startsWith('['));

  const completed = allTasks.filter(t => t.status === "completed").length;
  const total = allTasks.length;

  // Check for completion
  if (completed === total) {
    break; // All tasks done
  }

  // Check for escalations in tasks.json
  const tasksJson = JSON.parse(readFile(`${state.worktree}/${state.tasks_file}`));
  const escalated = tasksJson.tasks.filter(t => t.status === "escalated");

  if (escalated.length > 0) {
    handleEscalations(escalated);
  }

  // Reconcile: detect tasks with git commits but stale status in tasks.json
  reconcileGitVsTasks(state.worktree, tasksJson);

  // Check for deadlock: no running tasks and no pending tasks with resolved deps
  const running = tasksJson.tasks.filter(t => t.status === "in_progress");
  const ready = tasksJson.tasks.filter(t =>
    t.status === "pending" &&
    (!t.depends_on || t.depends_on.every(dep =>
      tasksJson.tasks.find(d => d.id === dep)?.status === "completed"
    ))
  );

  if (running.length === 0 && ready.length === 0 && completed < total) {
    // Deadlock or all remaining tasks are blocked by failures
    handleDeadlock(tasksJson, escalated);
    break;
  }

  // Brief pause before next check
  // (In practice, check TaskOutput for teammate completion signals)
}
```

### 6a. Reconcile Git vs Tasks (Drift Detection)

If a teammate commits code for a task but stalls before updating tasks.json, the monitoring loop
will see a "pending" task that actually has completed work. This causes false deadlocks and
duplicate implementation attempts.

**Run this every monitoring iteration, before the deadlock check:**

```javascript
function reconcileGitVsTasks(worktreePath, tasksJson) {
  // Get task IDs referenced in commit messages (convention: [task-NNN])
  const gitLog = exec(`git -C ${worktreePath} log --oneline --format="%s"`);
  const committedTaskIds = new Set();
  for (const line of gitLog.split('\n')) {
    const match = line.match(/\[task-(\d+)\]/);
    if (match) committedTaskIds.add(match[1]);
  }

  let reconciled = false;
  for (const task of tasksJson.tasks) {
    if ((task.status === "pending" || task.status === "in_progress") &&
        committedTaskIds.has(task.id)) {
      console.log(`RECONCILE: Task ${task.id} has commits but status="${task.status}" — updating to "review_pending"`);
      task.status = "review_pending";
      task.reconciled_at = new Date().toISOString();
      reconciled = true;
    }
  }

  if (reconciled) {
    writeFile(`${worktreePath}/${state.tasks_file}`, JSON.stringify(tasksJson, null, 2));
  }
}
```

**Why `review_pending` and not `completed`?** The commit exists but hasn't been reviewed yet.
The reviewer teammate will validate quality before marking it `completed`. This preserves the
review gate even for reconciled tasks.

### 7. Handle Escalations

```javascript
function handleEscalations(escalatedTasks) {
  for (const task of escalatedTasks) {
    // Check attempt count
    if (task.attempts >= state.config.max_total_attempts) {
      // Skip task — too many failures
      updateTaskStatus(task.id, "skipped");
      console.log(`ESCALATION: Task ${task.id} skipped after ${task.attempts} attempts`);
      continue;
    }

    // Model escalation: try with more capable model
    if (task.attempts >= 3 && !task.escalated_model) {
      task.escalated_model = "opus";
      task.status = "pending"; // Re-queue for a teammate to claim
      console.log(`ESCALATION: Task ${task.id} upgraded to opus model`);
    }
  }
}
```

### 8. Run Quality Check

After all implementation tasks complete:

```javascript
// Spawn quality checker
const qualityResult = Task({
  description: "Final quality check",
  subagent_type: "quality-checker",
  prompt: `Run 5-phase quality pipeline on the full implementation.

  Worktree: ${state.worktree}
  Fix mode: auto

  Run lint, type checks, structural checks, tests, and final recheck.
  Auto-fix issues where possible.`
});

// Parse quality result
if (qualityResult.verdict === "fail") {
  // Report failures to user
  console.log("Quality check failed. Manual intervention needed.");
  state.phase = "quality_failed";
  saveState(state);
  return;
}
```

### 9. Transition to Completion

```javascript
// Update state
state.phase = "completing";
state.orchestration_completed_at = new Date().toISOString();
saveState(state);

// Commit state update
git add state.json;
git commit -m "chore: all tasks complete, transitioning to completion phase";

// Invoke finishing skill
// The team lead returns control to the parent session for completion decisions
```

---

## Output Schema (JSON)

### Success: TEAM_LEAD_COMPLETE

```json
{
  "signal": "TEAM_LEAD_COMPLETE",
  "timestamp": "2026-02-24T15:00:00Z",
  "source": { "skill": "homerun:team-lead" },
  "payload": {
    "orchestration_mode": "agent_teams",
    "tasks_total": 8,
    "tasks_completed": 7,
    "tasks_skipped": 1,
    "teammates_spawned": {
      "implementer": 3,
      "reviewer": 1,
      "quality_checker": 1
    },
    "quality_verdict": "pass_with_fixes",
    "duration_minutes": 12
  },
  "envelope_version": "1.0.0"
}
```

### Fallback: CONDUCTOR_FALLBACK

```json
{
  "signal": "CONDUCTOR_FALLBACK",
  "timestamp": "2026-02-24T15:00:00Z",
  "source": { "skill": "homerun:team-lead" },
  "payload": {
    "reason": "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS not set",
    "action": "spawned_conductor"
  },
  "envelope_version": "1.0.0"
}
```

---

## Task Claiming Protocol

To avoid race conditions when multiple teammates try to claim the same task:

```javascript
// Claim protocol with git-aware optimistic locking
function claimTask(teammateId, tasksFile, worktreePath) {
  // 1. Read current state
  const tasks = JSON.parse(readFile(tasksFile));

  // 2. Check git log for already-committed tasks (definitive source of truth)
  const gitLog = exec(`git -C ${worktreePath} log --oneline --format="%s"`);
  const committedTaskIds = new Set();
  for (const line of gitLog.split('\n')) {
    const match = line.match(/\[task-(\d+)\]/);
    if (match) committedTaskIds.add(match[1]);
  }

  // 3. Find first ready task that has NO existing commits
  const ready = tasks.tasks.find(t =>
    t.status === "pending" &&
    !committedTaskIds.has(t.id) &&
    (!t.depends_on || t.depends_on.every(dep =>
      tasks.tasks.find(d => d.id === dep)?.status === "completed" ||
      committedTaskIds.has(dep)
    ))
  );

  if (!ready) return null;

  // 4. Claim by writing immediately
  ready.status = "in_progress";
  ready.claimed_by = teammateId;
  ready.started_at = new Date().toISOString();
  writeFile(tasksFile, JSON.stringify(tasks, null, 2));

  // 5. Re-read and verify claim (optimistic locking)
  const verify = JSON.parse(readFile(tasksFile));
  const verifiedTask = verify.tasks.find(t => t.id === ready.id);
  if (verifiedTask.claimed_by !== teammateId) {
    // Another teammate claimed it first — try again
    return claimTask(teammateId, tasksFile, worktreePath);
  }

  // 6. Also update native task
  TaskUpdate({ id: nativeTaskIdMap[ready.id], status: "in_progress" });

  return ready;
}
```

**Git log is the source of truth.** The `committedTaskIds` check (step 3) prevents two teammates from working on the same task even if tasks.json hasn't been updated yet. The dependency check (step 3) also considers committed tasks as satisfied, so stale tasks.json statuses don't block the DAG.

---

## Deadlock Detection

```javascript
function handleDeadlock(tasksJson, escalated) {
  const pending = tasksJson.tasks.filter(t => t.status === "pending");
  const blocked = pending.filter(t =>
    t.depends_on && t.depends_on.some(dep => {
      const depTask = tasksJson.tasks.find(d => d.id === dep);
      return depTask && (depTask.status === "escalated" || depTask.status === "skipped");
    })
  );

  if (blocked.length > 0) {
    // Tasks blocked by failed dependencies
    console.log(`DEADLOCK: ${blocked.length} tasks blocked by failed dependencies`);
    console.log("Blocked tasks:", blocked.map(t => t.id));
    console.log("Failed dependencies:", escalated.map(t => t.id));

    // Option 1: Skip blocked tasks
    // Option 2: Ask user to resolve failed tasks
    // Option 3: Attempt failed tasks with opus escalation

    state.phase = "deadlocked";
    state.deadlock_info = {
      blocked_tasks: blocked.map(t => t.id),
      failed_dependencies: escalated.map(t => t.id),
      timestamp: new Date().toISOString()
    };
    saveState(state);
  }
}
```

---

## Context Budget

| Component | Budget | Strategy |
|-----------|--------|----------|
| State + tasks loading | ~2K | Read state.json and tasks.json |
| Native task creation | ~3K | TaskCreate for each task |
| Teammate spawning | ~2K | Task() calls for teammates |
| Monitoring loop | ~3K | Periodic checks |
| Escalation handling | ~2K | Per-escalation decisions |
| Quality check dispatch | ~1K | Spawn quality-checker |
| **Total** | ~13K | Well within context budget |

---

## Exit Criteria

- [ ] Agent Teams availability checked
- [ ] All tasks from tasks.json converted to native tasks with DAG
- [ ] Appropriate number of teammates spawned (1-5 implementers, 1 reviewer)
- [ ] All tasks completed or escalated/skipped with documented reasons
- [ ] Quality check passed (or reported failures)
- [ ] State.json updated with orchestration results
- [ ] Phase transitioned to "completing"
- [ ] Signal emitted (TEAM_LEAD_COMPLETE or CONDUCTOR_FALLBACK)
