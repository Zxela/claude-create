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

Before starting, verify Agent Teams is available:

```bash
# Check for Agent Teams experimental flag
if [ -n "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" ]; then
  echo "AGENT_TEAMS_AVAILABLE"
else
  echo "AGENT_TEAMS_UNAVAILABLE"
fi
```

**If unavailable:** Fall back to conductor skill. Log the decision:

```javascript
// Update state.json
state.orchestration_mode = "conductor_fallback";
state.orchestration_reason = "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS not set";
saveState(state);

// Spawn conductor instead
Task({
  description: "Execute implementation loop (conductor fallback)",
  subagent_type: "general-purpose",
  model: "haiku",
  prompt: `Use the homerun:conductor skill.

  Worktree: ${state.worktree}
  State file: ${state.worktree}/state.json

  Read state.json, find pending tasks, and orchestrate parallel implementation.`
});
```

**If available:** Proceed with Agent Teams orchestration below.

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

### 4. Determine Teammate Count

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
    3. Update the task status to "in_progress" in both tasks.json and state.json
    4. Implement the task using TDD
    5. When done, update task status to "review_pending"
    6. Claim the next available task and repeat
    7. If no tasks available, report idle and exit

    IMPORTANT: Before claiming a task, re-read tasks.json to avoid conflicts with other teammates.
    Use file locking pattern: write your teammate ID to state.json before claiming.`
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
// Claim protocol with optimistic locking
function claimTask(teammateId, tasksFile) {
  // 1. Read current state
  const tasks = JSON.parse(readFile(tasksFile));

  // 2. Find first ready task
  const ready = tasks.tasks.find(t =>
    t.status === "pending" &&
    (!t.depends_on || t.depends_on.every(dep =>
      tasks.tasks.find(d => d.id === dep)?.status === "completed"
    ))
  );

  if (!ready) return null;

  // 3. Claim by writing immediately
  ready.status = "in_progress";
  ready.claimed_by = teammateId;
  ready.started_at = new Date().toISOString();
  writeFile(tasksFile, JSON.stringify(tasks, null, 2));

  // 4. Re-read and verify claim (optimistic locking)
  const verify = JSON.parse(readFile(tasksFile));
  const verifiedTask = verify.tasks.find(t => t.id === ready.id);
  if (verifiedTask.claimed_by !== teammateId) {
    // Another teammate claimed it first — try again
    return claimTask(teammateId, tasksFile);
  }

  // 5. Also update native task
  TaskUpdate({ id: nativeTaskIdMap[ready.id], status: "in_progress" });

  return ready;
}
```

**Note:** File-based locking has race condition windows. In practice, the DAG structure and task count make conflicts rare — most teammates work on different tasks. If conflicts become an issue, add a `.lock` file protocol.

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
