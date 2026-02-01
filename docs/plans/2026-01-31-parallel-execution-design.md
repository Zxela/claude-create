# Parallel Execution Design

**Date:** 2026-01-31
**Status:** Draft
**Author:** zxela + Claude

## Overview

Enhance the homerun conductor to support parallel task execution, allowing independent tasks to run concurrently while respecting dependencies, subtask hierarchies, and failure handling.

## Goals

1. Execute independent tasks in parallel to reduce total workflow time
2. Respect task dependencies (blocked_by) with reactive scheduling
3. Handle subtasks with parallel execution within parent scope
4. Manage conductor context to prevent token bloat
5. Provide structured recovery options via TUI on failures

## Non-Goals

- Parallel reviews (reviews remain sequential for clearer feedback)
- Parallel execution across different worktrees
- Distributed execution across machines

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Parallelism scope | Independent tasks only (reactive) | Tasks start ASAP when blockers complete |
| Subtask handling | Parallel within parent | Parent completes when all subtasks complete |
| Concurrency limits | Configurable + model-based | `max_parallel_tasks` + per-model defaults |
| Failure handling | Severity-based | High = stop, Low/Med = continue |
| Review parallelism | Sequential | Avoid cascading issues |
| Conductor context | Refresh every N tasks | Spawn fresh conductor to prevent bloat |

---

## State Schema Changes

### Config Extensions

```json
{
  "config": {
    "timeout_minutes": 30,
    "max_identical_rejections": 3,
    "max_iterations_without_progress": 3,
    "max_total_attempts": 5,
    "max_parallel_tasks": 3,
    "max_parallel_by_model": {
      "haiku": 5,
      "sonnet": 3,
      "opus": 1
    },
    "conductor_refresh_interval": 5,
    "conductor_model": "haiku"
  }
}
```

### Model Allocation

| Role | Model | Rationale |
|------|-------|-----------|
| Conductor | haiku | Scheduling logic, state management, JSON parsing |
| Implementer (simple) | haiku | Mechanical, pattern-following tasks |
| Implementer (complex) | sonnet | Design decisions, security implications |
| Reviewer | sonnet | Quality judgment, acceptance verification |
```

### Parallel State Tracking

```json
{
  "parallel_state": {
    "running_tasks": ["001a", "001c"],
    "pending_review": ["001a"],
    "retry_queue": [
      { "task_id": "002", "attempts": 1, "feedback": [...] }
    ],
    "blocked_by_failure": false,
    "failure_severity": null,
    "tasks_since_refresh": 3
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `running_tasks` | string[] | Task IDs currently being implemented |
| `pending_review` | string[] | Completed implementations awaiting review |
| `retry_queue` | object[] | Failed tasks awaiting retry |
| `blocked_by_failure` | boolean | Whether high-severity failure has paused execution |
| `failure_severity` | string? | Severity of blocking failure (if any) |
| `tasks_since_refresh` | number | Counter for conductor refresh |

---

## Parallel Dispatch Algorithm

The conductor loop changes from sequential to a reactive scheduler:

```
┌─────────────────────────────────────────────────────────────┐
│                    CONDUCTOR LOOP                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Check for completed agents (poll running_tasks)         │
│     └─► Move completed to pending_review queue              │
│                                                             │
│  2. Process review queue (sequential)                       │
│     ├─► APPROVED: mark complete, unblock dependents         │
│     ├─► REJECTED (low/med): add to retry queue              │
│     └─► REJECTED (high): set blocked_by_failure=true, STOP  │
│                                                             │
│  3. If not blocked, find ready tasks:                       │
│     └─► Ready = pending + no unresolved blocked_by          │
│                                                             │
│  4. Respect concurrency limits:                             │
│     └─► slots = min(max_parallel_tasks,                     │
│                     max_parallel_by_model[task.model])      │
│                     - len(running_tasks)                    │
│                                                             │
│  5. Spawn up to 'slots' implementer agents                  │
│     └─► Add to running_tasks, loop back to step 1           │
│                                                             │
│  6. If running_tasks empty + no ready tasks:                │
│     ├─► All complete? → Phase 4 (finishing)                 │
│     └─► Deadlocked? → Escalate to user                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Pseudocode

```javascript
async function conductorLoop(state) {
  while (true) {
    // 1. Poll for completed implementations
    const completed = await pollRunningTasks(state.parallel_state.running_tasks);
    for (const task of completed) {
      removeFromRunning(state, task.id);
      state.parallel_state.pending_review.push(task.id);
    }

    // 2. Process review queue (sequential)
    while (state.parallel_state.pending_review.length > 0) {
      const taskId = state.parallel_state.pending_review.shift();
      const result = await spawnReviewer(state, taskId);

      if (result.signal === "APPROVED") {
        markTaskComplete(state, taskId);
        unblockDependents(state, taskId);
      } else if (result.signal === "REJECTED") {
        if (result.severity === "high") {
          state.parallel_state.blocked_by_failure = true;
          state.parallel_state.failure_severity = "high";
          await handleHighSeverityFailure(state, taskId, result);
          return; // Exit loop, wait for user
        } else {
          addToRetryQueue(state, taskId, result.feedback);
        }
      }
    }

    // 3. Check if blocked
    if (state.parallel_state.blocked_by_failure) {
      await waitForUserRecovery(state);
      continue;
    }

    // 4. Find ready tasks
    const readyTasks = findReadyTasks(state);

    // 5. Calculate available slots
    const slots = calculateSlots(state, readyTasks);

    // 6. Spawn implementers
    for (let i = 0; i < slots && i < readyTasks.length; i++) {
      const task = readyTasks[i];
      spawnImplementer(state, task); // async, don't await
      state.parallel_state.running_tasks.push(task.id);
    }

    // 7. Check for completion or deadlock
    if (state.parallel_state.running_tasks.length === 0 && readyTasks.length === 0) {
      if (allTasksComplete(state)) {
        await transitionToPhase4(state);
        return;
      } else {
        await handleDeadlock(state);
        return;
      }
    }

    // 8. Check conductor refresh
    if (state.parallel_state.tasks_since_refresh >= state.config.conductor_refresh_interval) {
      await spawnFreshConductor(state);
      return; // This conductor exits
    }

    await saveState(state);
    await sleep(1000); // Poll interval
  }
}
```

### Slot Calculation

```javascript
function calculateSlots(state, readyTasks) {
  const config = state.config;
  const running = state.parallel_state.running_tasks.length;

  // Global limit
  let slots = config.max_parallel_tasks - running;

  // Model-based limits (count running tasks per model)
  const runningByModel = countRunningByModel(state);

  for (const task of readyTasks) {
    const modelLimit = config.max_parallel_by_model[task.model] || config.max_parallel_tasks;
    const modelRunning = runningByModel[task.model] || 0;
    const modelSlots = modelLimit - modelRunning;
    slots = Math.min(slots, modelSlots);
  }

  return Math.max(0, slots);
}
```

---

## Subtask Parallelism

When a parent task has subtasks, the conductor treats the parent as a coordination wrapper.

### Rules

1. **Parent never runs directly** - Only subtasks execute
2. **Subtask deps resolved locally first** - `001b.blocked_by: ["001a"]` within parent
3. **Subtasks share parent's concurrency slot** - Respect model limits
4. **Parent auto-completes** - When all subtasks complete

### State Example

```json
{
  "tasks": [{
    "id": "001",
    "title": "Create User model",
    "status": "in_progress",
    "model": "sonnet",
    "subtasks": [
      { "id": "001a", "title": "Create class", "status": "completed", "blocked_by": [] },
      { "id": "001b", "title": "Add validation", "status": "in_progress", "blocked_by": ["001a"] },
      { "id": "001c", "title": "Add serialization", "status": "in_progress", "blocked_by": ["001a"] }
    ]
  }, {
    "id": "002",
    "title": "Create Auth service",
    "status": "pending",
    "blocked_by": ["001"]
  }]
}
```

### Subtask Scheduling

```javascript
function findReadyTasks(state) {
  const ready = [];

  for (const task of state.tasks) {
    if (task.status !== "pending" && task.status !== "in_progress") continue;

    // Check if parent's dependencies are met
    const parentDepsResolved = task.blocked_by?.every(depId =>
      isTaskComplete(state, depId)
    ) ?? true;

    if (!parentDepsResolved) continue;

    if (task.subtasks?.length > 0) {
      // Find ready subtasks
      for (const subtask of task.subtasks) {
        if (subtask.status !== "pending") continue;

        const subtaskDepsResolved = subtask.blocked_by?.every(depId => {
          // Check within parent's subtasks first
          const sibling = task.subtasks.find(s => s.id === depId);
          if (sibling) return sibling.status === "completed";
          // Then check parent-level deps
          return isTaskComplete(state, depId);
        }) ?? true;

        if (subtaskDepsResolved) {
          ready.push({ ...subtask, parent_id: task.id, model: task.model });
        }
      }
    } else {
      // No subtasks, parent is directly executable
      if (task.status === "pending") {
        ready.push(task);
      }
    }
  }

  return ready;
}

function markTaskComplete(state, taskId) {
  // Find task (could be subtask)
  for (const task of state.tasks) {
    if (task.id === taskId) {
      task.status = "completed";
      task.completed_at = new Date().toISOString();
      return;
    }

    const subtask = task.subtasks?.find(s => s.id === taskId);
    if (subtask) {
      subtask.status = "completed";
      subtask.completed_at = new Date().toISOString();

      // Check if all subtasks complete → parent complete
      const allSubtasksComplete = task.subtasks.every(s => s.status === "completed");
      if (allSubtasksComplete) {
        task.status = "completed";
        task.completed_at = new Date().toISOString();
      }
      return;
    }
  }
}
```

---

## Conductor Context Management

To prevent token bloat, the conductor refreshes itself after completing N tasks.

### Refresh Flow

```
┌──────────────────────────────────────────────────────┐
│  Conductor A (fresh context)                         │
│  ├─► Complete tasks 1, 2, 3, 4, 5                    │
│  ├─► tasks_since_refresh = 5                         │
│  └─► Spawn Conductor B, exit                         │
└──────────────────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────┐
│  Conductor B (fresh context)                         │
│  ├─► Read state.json, resume from current state      │
│  ├─► Complete tasks 6, 7, 8, 9, 10                   │
│  └─► Spawn Conductor C, exit                         │
└──────────────────────────────────────────────────────┘
```

### Implementation

```javascript
async function checkConductorRefresh(state) {
  state.parallel_state.tasks_since_refresh++;

  if (state.parallel_state.tasks_since_refresh >= state.config.conductor_refresh_interval) {
    // Reset counter
    state.parallel_state.tasks_since_refresh = 0;
    await saveState(state);

    // Spawn fresh conductor (haiku by default - scheduling is mechanical)
    Task({
      description: "Continue conductor loop",
      subagent_type: "general-purpose",
      model: state.config.conductor_model || "haiku",
      prompt: `Use the homerun:conductor skill.

Worktree: ${state.worktree}

Continue the implementation loop from the current state.`
    });

    return true; // Signal to exit current conductor
  }

  return false;
}
```

### Context Hygiene

- Conductor stores task IDs only, not full outputs
- Agent outputs parsed immediately; only signals/summaries retained
- Full details written to state.json
- Avoid accumulating conversation history within conductor

---

## Failure Handling

### Severity-Based Response

| Severity | Behavior |
|----------|----------|
| Low | Add to retry queue, continue other tasks |
| Medium | Add to retry queue, continue other tasks |
| High | Pause new spawns, let running finish, escalate |

### Retry Queue

```json
{
  "parallel_state": {
    "retry_queue": [
      {
        "task_id": "001b",
        "attempts": 1,
        "last_feedback": {
          "summary": "Missing null check",
          "issues": ["No validation for empty input"],
          "severity": "medium"
        }
      }
    ]
  }
}
```

Retry processing:
- Lower priority than fresh tasks
- Same escalation: attempts 0-1 same agent, attempt 2 fresh, 3+ user
- High-severity in retry blocks all work

### Recovery TUI

When blocked by high-severity failure, present structured options:

```javascript
AskUserQuestion({
  questions: [{
    question: "Task 001b failed with high severity: 'Missing authentication check'. How would you like to proceed?",
    header: "Recovery",
    options: [
      {
        label: "Retry with guidance",
        description: "Provide additional context and retry implementation"
      },
      {
        label: "Mark as fixed",
        description: "I manually fixed the issue, continue from here"
      },
      {
        label: "Skip task",
        description: "Skip this task and unblock dependents"
      },
      {
        label: "Escalate to plan",
        description: "Return to planning phase to restructure tasks"
      }
    ],
    multiSelect: false
  }]
});
```

### Recovery Handling

```javascript
async function handleRecoveryChoice(state, taskId, choice) {
  switch (choice) {
    case "Retry with guidance":
      // Ask for guidance text
      const guidance = await AskUserQuestion({
        questions: [{
          question: "What guidance should the implementer follow?",
          header: "Guidance",
          options: [
            { label: "Add auth check", description: "Verify user is authenticated before proceeding" },
            { label: "Add validation", description: "Validate input before processing" },
            { label: "Custom", description: "Provide custom guidance" }
          ]
        }]
      });
      addToRetryQueue(state, taskId, { guidance });
      state.parallel_state.blocked_by_failure = false;
      break;

    case "Mark as fixed":
      markTaskComplete(state, taskId);
      unblockDependents(state, taskId);
      state.parallel_state.blocked_by_failure = false;
      break;

    case "Skip task":
      state.tasks.find(t => t.id === taskId).status = "skipped";
      unblockDependents(state, taskId);
      state.parallel_state.blocked_by_failure = false;
      break;

    case "Escalate to plan":
      state.phase = "planning";
      state.parallel_state.blocked_by_failure = false;
      // Return to planning skill
      break;
  }

  await saveState(state);
}
```

---

## Implementation Plan

### Phase 1: State Schema
- Add `parallel_state` to state.json schema
- Add config options for concurrency limits
- Update conductor to read new config

### Phase 2: Ready Task Detection
- Implement `findReadyTasks()` with dependency resolution
- Add subtask support to ready detection
- Add slot calculation with model limits

### Phase 3: Parallel Dispatch
- Change conductor loop to reactive scheduler
- Implement background agent spawning
- Add completion polling

### Phase 4: Review Queue
- Implement sequential review processing
- Add retry queue management
- Connect to existing retry logic

### Phase 5: Failure Handling
- Add severity detection
- Implement blocking behavior
- Add TUI recovery flow

### Phase 6: Conductor Refresh
- Add refresh counter
- Implement self-spawning on threshold
- Test context isolation

---

## Testing Strategy

### Unit Tests
- `findReadyTasks()` with various dependency graphs
- Slot calculation with different model mixes
- Subtask completion rollup

### Integration Tests
- Full parallel workflow with 5+ tasks
- High-severity failure recovery
- Conductor refresh across 10+ tasks

### Edge Cases
- All tasks independent (max parallelism)
- Linear dependencies (sequential fallback)
- Mixed subtask depths
- Failure during parallel execution

---

## Open Questions

1. **Poll interval** - How often to check for agent completion? (Currently 1s)
2. **Agent output format** - How do we detect completion from Task agents?
3. **Subtask retry** - If subtask fails, retry just subtask or whole parent?

---

## References

- `skills/conductor/SKILL.md` - Current conductor implementation
- `skills/planning/SKILL.md` - Task and subtask schema
- `superpowers:dispatching-parallel-agents` - Parallel dispatch patterns
- `superpowers:subagent-driven-development` - Subagent orchestration patterns
