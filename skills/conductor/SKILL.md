---
name: conductor
description: "[haiku] Orchestrate the implementation loop - spawning implementer and reviewer agents"
model: haiku
color: green
---

# Conductor Skill

## Reference Documents

Before executing, read these reference documents as needed:
- `docs/references/state-machine.md` - Detailed algorithms, pseudocode, and state transitions

## Overview

The conductor orchestrates Phase 3 (Implementation) of the workflow using a **reactive scheduler** that supports parallel task execution. Its responsibilities:

1. **Poll running tasks** - Check which implementer agents have completed
2. **Process reviews sequentially** - Review completed implementations one at a time
3. **Handle failures by severity** - Low/medium go to retry queue, high blocks and escalates
4. **Find ready tasks** - Identify tasks with resolved dependencies
5. **Spawn implementers in parallel** - Launch multiple agents within concurrency limits
6. **Manage context** - Refresh conductor after N completed tasks to prevent bloat
7. **Transition to Phase 4** - When all tasks complete or deadlock detected

The conductor uses **haiku** by default (configurable via `config.conductor_model`) since scheduling is mechanical work that doesn't require deep reasoning.

## Loop Flow (Reactive Scheduler)

See `docs/references/state-machine.md` for the full loop diagram and pseudocode.

**Key steps:**
1. Poll running tasks for completions
2. Process reviews sequentially
3. Handle failures by severity
4. Find ready tasks
5. Spawn implementers (respecting concurrency limits)
6. Refresh context periodically

### Key Behavioral Changes from Sequential to Parallel

| Aspect | Sequential (Old) | Parallel (New) |
|--------|------------------|----------------|
| Task selection | One task at a time | Multiple ready tasks in parallel |
| Implementation | Wait for each to complete | Spawn in background, poll for completion |
| Reviews | Immediately after each implementation | Queued, processed sequentially |
| Failure handling | Retry or escalate per task | Severity-based: low/med continue, high blocks |
| Context management | None | Refresh conductor every N tasks |

## State Management

The conductor reads and updates `state.json` throughout the implementation loop.

### Example State Structure

```json
{
  "workflow_id": "feature-auth-system",
  "phase": "implementation",
  "current_task": null,
  "spec_paths": {
    "prd": "docs/specs/PRD.md",
    "adr": "docs/specs/ADR.md",
    "technical_design": "docs/specs/TECHNICAL_DESIGN.md",
    "wireframes": "docs/specs/WIREFRAMES.md"
  },
  "tasks_file": "docs/tasks.json",
  "tasks": [
    {
      "id": "task-001",
      "title": "Create user model",
      "status": "completed",
      "attempts": 1,
      "implementer_commits": ["abc1234"],
      "files_changed": ["src/models/user.ts"],
      "test_file": "tests/models/user.test.ts"
    },
    {
      "id": "task-002",
      "title": "Implement authentication service",
      "status": "in_progress",
      "attempts": 1,
      "started_at": "2026-01-25T14:30:00Z",
      "feedback": []
    },
    {
      "id": "task-003",
      "title": "Add login endpoint",
      "status": "pending",
      "attempts": 0,
      "blocked_by": ["task-002"]
    }
  ],
  "parallel_state": {
    "running_tasks": ["task-002"],
    "pending_review": [],
    "retry_queue": [],
    "blocked_by_failure": false,
    "failure_severity": null,
    "tasks_since_refresh": 0
  },
  "created_at": "2026-01-25T10:00:00Z",
  "updated_at": "2026-01-25T14:30:00Z",
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

### Key State Fields

| Field | Purpose |
|-------|---------|
| `phase` | Current workflow phase (`planning`, `implementation`, `completion`) |
| `current_task` | Deprecated in parallel mode; use `parallel_state.running_tasks` |
| `spec_paths` | Explicit paths to spec documents (PRD, ADR, technical_design, wireframes) |
| `tasks_file` | Path to JSON file with all tasks (e.g., `docs/tasks.json`) |
| `tasks[].status` | Task status: `pending`, `in_progress`, `completed`, `escalated`, `skipped` |
| `tasks[].attempts` | Number of implementation attempts for retry logic |
| `tasks[].feedback` | Array of reviewer feedback from rejected attempts |
| `tasks[].blocked_by` | Array of task IDs that must complete before this task can start |
| `parallel_state.running_tasks` | Task IDs currently being implemented (parallel) |
| `parallel_state.pending_review` | Completed implementations awaiting sequential review |
| `parallel_state.retry_queue` | Failed tasks awaiting retry (lower priority than fresh tasks) |
| `parallel_state.blocked_by_failure` | Whether high-severity failure has paused execution |
| `parallel_state.tasks_since_refresh` | Counter for conductor context refresh |
| `config.max_parallel_tasks` | Global concurrency limit (default: 3) |
| `config.max_parallel_by_model` | Per-model concurrency limits: haiku=5, sonnet=3, opus=1 |
| `config.conductor_refresh_interval` | Tasks between conductor refresh (default: 5) |
| `config.conductor_model` | Model for conductor itself (default: haiku) |

---

## Finding Ready Tasks

See `docs/references/state-machine.md` for the full `findReadyTasks` algorithm.

**Ready task criteria:**
1. Status is `pending` (not already running or complete)
2. All `blocked_by` dependencies have status `completed`
3. Not already in `parallel_state.running_tasks`

**Subtask handling:**
- Parent never executes directly - only subtasks run
- Subtask deps resolve locally first (check siblings before parent-level deps)
- Subtasks inherit parent's model for concurrency limits
- Parent auto-completes when all subtasks complete

---

## Concurrency Control

See `docs/references/state-machine.md` for the slot calculation algorithm.

The conductor limits parallel execution using:
- **Global limit**: `config.max_parallel_tasks` (default: 3)
- **Per-model limits**: `config.max_parallel_by_model` (haiku: 5, sonnet: 3, opus: 1)

| Role | Default Model | Rationale |
|------|---------------|-----------|
| Conductor | haiku | Scheduling is mechanical, low-cost |
| Implementer (simple) | haiku | add_field, add_method, refactor tasks |
| Implementer (complex) | sonnet | create_model, bug_fix, architecture tasks |
| Reviewer | sonnet | Quality judgment requires stronger model |

---

## Parallel Task Spawning

Spawn multiple implementers in parallel using the Task tool with `run_in_background: true`.

### Spawning Multiple Tasks

```javascript
function spawnReadyTasks(state, readyTasks, slots) {
  const tasksToSpawn = readyTasks.slice(0, slots);

  for (const task of tasksToSpawn) {
    // Build input
    const input = buildImplementerInput(state, task);

    // Log invocation
    logSkillInvocation(state, "homerun:implement", task.id);

    // Mark as running
    state.parallel_state.running_tasks.push(task.id);
    updateTaskStatus(state, task.id, 'in_progress');

    // Spawn in background - don't wait for completion
    Task({
      description: `Implement: ${task.title}`,
      subagent_type: "general-purpose",
      model: task.model || "sonnet",
      run_in_background: true,
      prompt: `Use the homerun:implement skill.

Input:
\`\`\`json
${JSON.stringify(input, null, 2)}
\`\`\`
`
    });
  }

  return tasksToSpawn.length;
}
```

### Polling for Completion

After spawning, poll for completed tasks using TaskOutput:

```javascript
function pollCompletedTasks(state) {
  const completed = [];

  for (const taskId of state.parallel_state.running_tasks) {
    // Use TaskOutput with block=false to check without waiting
    const output = TaskOutput({
      task_id: taskId,
      block: false,
      timeout: 1000
    });

    if (output && output.status === 'completed') {
      completed.push({
        id: taskId,
        output: output.result
      });
    }
  }

  return completed;
}
```

### Processing Completions

```javascript
function processCompletions(state, completedTasks) {
  for (const { id, output } of completedTasks) {
    // Remove from running
    state.parallel_state.running_tasks =
      state.parallel_state.running_tasks.filter(t => t !== id);

    // Parse implementer output
    try {
      const result = parseImplementerOutput(output);

      if (result.signal === "IMPLEMENTATION_COMPLETE") {
        // Queue for sequential review
        state.parallel_state.pending_review.push({
          task_id: id,
          implementation: result
        });
      } else if (result.signal === "IMPLEMENTATION_BLOCKED") {
        // Handle blocked task - escalate immediately
        handleBlockedTask(state, id, result);
      }
    } catch (error) {
      // Parse error - add to retry queue
      addToRetryQueue(state, id, { error: error.message });
    }
  }
}
```

---

## Sequential Review Queue

Reviews are processed one at a time to avoid cascading issues and provide clearer feedback loops.

### Processing Reviews

```javascript
function processReviewQueue(state) {
  // Process one review at a time
  if (state.parallel_state.pending_review.length === 0) {
    return { action: 'continue' };
  }

  const review = state.parallel_state.pending_review.shift();
  const task = findTask(state, review.task_id);

  // Build reviewer input
  const reviewerInput = buildReviewerInput(state, task, review.implementation);

  // Log invocation
  logSkillInvocation(state, "homerun:review", review.task_id);

  // Spawn reviewer (blocking - wait for result)
  const result = Task({
    description: `Review: ${task.title}`,
    subagent_type: "general-purpose",
    model: "sonnet",  // Always sonnet for reviews
    prompt: `Use the homerun:review skill.

Input:
\`\`\`json
${JSON.stringify(reviewerInput, null, 2)}
\`\`\`
`
  });

  return handleReviewResult(state, task, result);
}
```

### Handling Review Results with Severity

```javascript
function handleReviewResult(state, task, result) {
  const reviewResult = parseReviewerOutput(result);

  if (reviewResult.signal === "APPROVED") {
    // Validate traceability before marking complete
    const validation = validateTaskTraceability(task, reviewResult);

    if (!validation.valid) {
      // Return to implementer with validation error
      return {
        action: 'return_to_implementer',
        signal: 'VALIDATION_ERROR',
        errors: validation.errors,
        message: 'Implementation approved but traceability validation failed'
      };
    }

    // Log any warnings
    if (validation.warnings.length > 0) {
      state.skill_log.push({
        event: 'traceability_warnings',
        task: task.id,
        warnings: validation.warnings
      });
    }

    // Mark complete and unblock dependents
    markTaskComplete(state, task.id);
    unblockDependents(state, task.id);

    // Increment refresh counter
    state.parallel_state.tasks_since_refresh++;

    return { action: 'continue' };
  }

  if (reviewResult.signal === "REJECTED") {
    // Check severity - default to 'medium' if not specified
    const severity = reviewResult.severity || 'medium';

    if (severity === 'high') {
      // Block all execution
      state.parallel_state.blocked_by_failure = true;
      state.parallel_state.failure_severity = 'high';

      return {
        action: 'blocked',
        task_id: task.id,
        feedback: reviewResult
      };
    }

    // Low/medium severity - add to retry queue, continue
    addToRetryQueue(state, task.id, reviewResult);
    return { action: 'continue' };
  }
}
```

---

## Traceability Validation

### Per-Task Validation

Before marking a task `completed`, validate acceptance criteria coverage:

```javascript
function validateTaskTraceability(task, implementerOutput) {
  const errors = [];
  const warnings = [];

  // 1. All acceptance criteria addressed
  for (const ac of task.acceptance_criteria) {
    const met = implementerOutput.acceptance_criteria_met
      ?.find(m => m.criterion === ac.id || m.criterion === ac.text);

    if (!met) {
      errors.push({
        type: 'ac_not_addressed',
        criterion: ac.id,
        message: `Acceptance criterion "${ac.id}" not in implementation output`
      });
    } else if (!met.test_location) {
      warnings.push({
        type: 'ac_no_test',
        criterion: ac.id,
        message: `Acceptance criterion "${ac.id}" has no test reference`
      });
    }
  }

  // 2. Test file exists (if specified)
  if (task.test_file && !implementerOutput.test_file) {
    errors.push({
      type: 'test_file_missing',
      message: `Task specifies test_file but none in output`
    });
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings
  };
}
```

### Marking Tasks Complete with Subtask Rollup

```javascript
function markTaskComplete(state, taskId) {
  // Find task (top-level or subtask)
  for (const task of state.tasks) {
    if (task.id === taskId) {
      task.status = 'completed';
      task.completed_at = new Date().toISOString();
      return;
    }

    // Check subtasks
    const subtask = task.subtasks?.find(s => s.id === taskId);
    if (subtask) {
      subtask.status = 'completed';
      subtask.completed_at = new Date().toISOString();

      // Check if all subtasks complete → parent auto-completes
      if (task.subtasks.every(s => s.status === 'completed')) {
        task.status = 'completed';
        task.completed_at = new Date().toISOString();
      }
      return;
    }
  }
}
```

---

## Severity-Based Failure Handling

The conductor responds differently based on rejection severity.

### Severity Levels

| Severity | Response | Rationale |
|----------|----------|-----------|
| Low | Add to retry queue, continue other tasks | Minor issues, isolated to task |
| Medium | Add to retry queue, continue other tasks | Moderate issues, doesn't affect others |
| High | Block new spawns, let running finish, escalate | May affect architecture, needs human judgment |

### Retry Queue Management

```javascript
function addToRetryQueue(state, taskId, feedback) {
  const task = findTask(state, taskId);

  state.parallel_state.retry_queue.push({
    task_id: taskId,
    attempts: (task.attempts || 0) + 1,
    feedback: feedback,
    added_at: new Date().toISOString()
  });

  // Reset task status for retry
  task.status = 'pending';
  task.feedback = task.feedback || [];
  task.feedback.push(feedback);
}

function processRetryQueue(state) {
  // Retries have lower priority than fresh tasks
  if (state.parallel_state.retry_queue.length === 0) return [];

  const readyRetries = [];

  for (const retry of state.parallel_state.retry_queue) {
    const task = findTask(state, retry.task_id);

    // Check retry limits
    if (retry.attempts >= state.config.max_total_attempts) {
      task.status = 'escalated';
      continue;
    }

    // Check if deps still resolved
    if (areDependenciesResolved(state, task)) {
      readyRetries.push({
        ...task,
        previous_feedback: retry.feedback,
        is_retry: true,
        attempt_number: retry.attempts
      });
    }
  }

  return readyRetries;
}
```

### High-Severity Escalation with TUI

When blocked by high-severity failure, present structured recovery options using AskUserQuestion:

```javascript
function handleHighSeverityFailure(state, taskId, feedback) {
  AskUserQuestion({
    questions: [{
      question: `Task ${taskId} failed with high severity: "${feedback.summary}". How would you like to proceed?`,
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
          label: "Return to planning",
          description: "Restructure tasks to address the issue"
        }
      ],
      multiSelect: false
    }]
  });
}
```

### Recovery Actions

```javascript
function handleRecoveryChoice(state, taskId, choice) {
  const task = findTask(state, taskId);

  switch (choice) {
    case "Retry with guidance":
      state.parallel_state.blocked_by_failure = false;
      addToRetryQueue(state, taskId, { guidance_requested: true });
      break;

    case "Mark as fixed":
      markTaskComplete(state, taskId);
      unblockDependents(state, taskId);
      state.parallel_state.blocked_by_failure = false;
      break;

    case "Skip task":
      task.status = 'skipped';
      unblockDependents(state, taskId);
      state.parallel_state.blocked_by_failure = false;
      break;

    case "Return to planning":
      state.phase = 'planning';
      state.parallel_state.blocked_by_failure = false;
      // Invoke homerun:planning skill
      break;
  }
}
```

---

## Conductor Context Management

The conductor refreshes itself to prevent token accumulation over long-running workflows.

See `docs/references/token-estimation.md` for detailed token estimation formulas.

### Refresh Triggers

Refresh when ANY of:
1. `tasks_since_refresh >= conductor_refresh_interval` (default: 5)
2. `estimated_tokens > refresh_threshold_percent * window_size` (token-based)
3. `feedback_accumulation > 10KB`

### Token-Aware Refresh Decision

```javascript
function shouldRefreshConductor(state) {
  const tracking = state.token_tracking;
  const config = tracking?.config || {};

  // Task-count trigger (existing)
  if (state.parallel_state.tasks_since_refresh >= 5) {
    return { refresh: true, reason: 'task_count' };
  }

  // Token-based trigger
  if (tracking?.enabled) {
    const estimated = estimateCurrentTokens(state);
    const threshold = (config.refresh_threshold_percent / 100) * config.window_size;

    if (estimated > threshold) {
      return { refresh: true, reason: 'token_threshold', estimated };
    }
  }

  return { refresh: false };
}
```

### Logging Refreshes

When refreshing, log to `token_tracking.refresh_log`:

```javascript
state.token_tracking.refresh_log.push({
  timestamp: new Date().toISOString(),
  reason: refreshDecision.reason,
  tasks_completed: state.parallel_state.tasks_since_refresh,
  estimated_tokens: refreshDecision.estimated
});
```

### Spawn Fresh Conductor

After completing `conductor_refresh_interval` tasks (default: 5), spawn a fresh conductor:

```javascript
function checkConductorRefresh(state) {
  const interval = state.config.conductor_refresh_interval || 5;

  if (state.parallel_state.tasks_since_refresh >= interval) {
    return true;
  }
  return false;
}

function spawnFreshConductor(state) {
  // Reset counter before saving
  state.parallel_state.tasks_since_refresh = 0;
  saveState(state);

  // Spawn fresh conductor with configured model (default haiku)
  Task({
    description: "Continue conductor loop",
    subagent_type: "general-purpose",
    model: state.config.conductor_model || "haiku",
    prompt: `Use the homerun:conductor skill.

Worktree: ${state.worktree}

Continue the implementation loop. A fresh conductor is starting with clean context.
Read state.json to resume from current progress.`
  });

  // Current conductor exits after spawning replacement
  return { action: 'refresh_exit' };
}
```

### Context Hygiene Practices

To minimize token usage in the conductor:

1. **Store IDs, not content** - Keep task IDs in `parallel_state`, read full task from state.json when needed
2. **Parse immediately** - Extract signals from agent output, discard raw text
3. **Write to state** - Persist all important data to state.json, not in-memory
4. **Fresh agents** - Each implementer/reviewer starts with clean context

---

## Skill Invocation Logging

Track all skill invocations in `state.json` for visibility and debugging:

```json
{
  "skill_log": [
    {"skill": "homerun:discovery", "timestamp": "2026-01-25T10:00:00Z", "phase": "discovery"},
    {"skill": "homerun:planning", "timestamp": "2026-01-25T11:00:00Z", "phase": "planning"},
    {"skill": "homerun:implement", "timestamp": "2026-01-25T12:00:00Z", "phase": "implementing", "task": "001"},
    {"skill": "homerun:review", "timestamp": "2026-01-25T12:30:00Z", "phase": "implementing", "task": "001"}
  ]
}
```

### Logging Protocol

**When spawning any agent, log the invocation:**

```javascript
function logSkillInvocation(state, skillName, taskId = null) {
  const entry = {
    skill: skillName,
    timestamp: new Date().toISOString(),
    phase: state.phase
  };
  if (taskId) {
    entry.task = taskId;
  }
  state.skill_log = state.skill_log || [];
  state.skill_log.push(entry);
}

// Usage before spawning implementer:
logSkillInvocation(state, "homerun:implement", task.id);

// Usage before spawning reviewer:
logSkillInvocation(state, "homerun:review", task.id);
```

This provides visibility into which skills are invoked and helps identify missing skills that should be cloned.

---

## Pre-Spawn Verification

**REQUIRED:** Before spawning any agent, verify the git state is clean:

```bash
cd "$WORKTREE_PATH"

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
  echo "ERROR: Working tree has uncommitted changes"
  git status --short
  echo "Aborting agent spawn - resolve uncommitted changes first"
  exit 1
fi

# Verify correct branch
current_branch=$(git branch --show-current)
expected_branch=$(jq -r '.branch' state.json)
if [[ "$current_branch" != "$expected_branch" ]]; then
  echo "ERROR: On branch $current_branch, expected $expected_branch"
  echo "Switching to correct branch..."
  git checkout "$expected_branch"
fi

# Pull latest changes if remote exists
if git remote get-url origin &>/dev/null; then
  git pull --rebase origin "$expected_branch" 2>/dev/null || true
fi
```

### Input Validation Before Spawn

Before spawning implementer or reviewer, validate the input will be processable:

```javascript
function validateBeforeSpawn(state, task, type) {
  const errors = [];

  // Check task exists and has required fields
  if (!task.id) errors.push("Task missing 'id' field");
  if (!task.title) errors.push("Task missing 'title' field");
  if (!task.acceptance_criteria?.length) errors.push("Task missing acceptance criteria");

  // Check spec files exist
  const specPaths = state.spec_paths;
  if (!fs.existsSync(specPaths.technical_design)) {
    errors.push(`Technical design not found: ${specPaths.technical_design}`);
  }

  // Check tasks.json is valid
  try {
    JSON.parse(fs.readFileSync(state.tasks_file));
  } catch (e) {
    errors.push(`Invalid tasks.json: ${e.message}`);
  }

  // For reviewer: verify commit exists
  if (type === 'reviewer' && task.commit_hash) {
    const result = execSync(`git cat-file -t ${task.commit_hash} 2>/dev/null || echo "missing"`);
    if (result.toString().trim() === 'missing') {
      errors.push(`Commit not found: ${task.commit_hash}`);
    }
  }

  return errors.length ? { valid: false, errors } : { valid: true };
}
```

**Usage before spawning:**

```javascript
const validation = validateBeforeSpawn(state, task, 'implementer');
if (!validation.valid) {
  console.error('Pre-spawn validation failed:', validation.errors);
  return { action: 'validation_failed', errors: validation.errors };
}
// Proceed with spawn...
```

---

## Timeout Detection

Track agent execution time and fail if it exceeds the configured limit.

### Timeout Tracking

When spawning an agent, record the start time in state.json:

```json
{
  "current_task": "task-002",
  "tasks": [
    {
      "id": "task-002",
      "status": "in_progress",
      "started_at": "2026-01-25T14:30:00Z",
      "timeout_at": "2026-01-25T15:00:00Z"
    }
  ]
}
```

### Timeout Check

Before processing agent output, verify the task hasn't timed out:

```javascript
function checkTimeout(task, config) {
  const startedAt = new Date(task.started_at);
  const timeoutMinutes = config.timeout_minutes || 30;
  const timeoutAt = new Date(startedAt.getTime() + timeoutMinutes * 60 * 1000);

  if (new Date() > timeoutAt) {
    return {
      timedOut: true,
      duration: Math.round((new Date() - startedAt) / 60000),
      limit: timeoutMinutes
    };
  }
  return { timedOut: false };
}
```

### Timeout Response

If a task times out:
1. Mark the current attempt as failed with reason "timeout"
2. Increment attempt counter
3. Follow retry logic (same agent → fresh agent → escalate)
4. Log the timeout in feedback array

---

## Deadlock Detection

See `docs/references/state-machine.md` for detailed deadlock detection algorithms.

| Indicator | Detection | Threshold |
|-----------|-----------|-----------|
| Identical rejections | Same feedback hash | 3 consecutive |
| No progress | No tasks completed | 3 iterations |
| Circuit breaker | Max attempts exceeded | 5 attempts |

**Deadlock response:**
1. Do not continue the implementation loop
2. Mark workflow as `needs_intervention`
3. Present detailed report to user
4. Wait for user guidance

---

## Spawning Implementer

When a pending task is found, spawn an implementer agent using the Task tool.

### Loading Spec Paths from State

Before spawning agents, load the explicit spec paths from `state.json`:

```bash
cd "$WORKTREE_PATH"

# Load spec paths from state.json
TECHNICAL_DESIGN_PATH=$(jq -r '.spec_paths.technical_design // "docs/specs/TECHNICAL_DESIGN.md"' state.json)
ADR_PATH=$(jq -r '.spec_paths.adr // "docs/specs/ADR.md"' state.json)
PRD_PATH=$(jq -r '.spec_paths.prd // "docs/specs/PRD.md"' state.json)
TASKS_FILE=$(jq -r '.tasks_file // "docs/tasks.json"' state.json)

# Verify paths exist
for path in "$TECHNICAL_DESIGN_PATH" "$ADR_PATH"; do
  if [[ ! -f "$path" ]]; then
    echo "WARNING: Spec file not found: $path"
  fi
done
```

### Constructing JSON Input for Implementer

Build the JSON input object from state and task file:

```javascript
function buildImplementerInput(state, task) {
  // Get model from task (set by planning based on task_type)
  // Fall back to sonnet if not specified
  const model = task.escalated_model || task.model || "sonnet";

  return {
    task: {
      id: task.id,
      title: task.title,
      objective: task.objective,
      acceptance_criteria: task.acceptance_criteria.map(ac => ({
        id: ac.id,
        criterion: ac.criterion
      })),
      test_file: task.test_file,
      task_type: task.task_type  // Pass through for logging/routing
    },
    methodology: task.methodology || "tdd",  // Explicit methodology (tdd, direct, etc.)
    spec_paths: {
      technical_design: state.spec_paths.technical_design,
      adr: state.spec_paths.adr
    },
    previous_feedback: task.feedback || [],
    worktree_path: state.worktree,
    model: model  // Model for Task agent to use
  };
}
```

### Implementer Prompt Template

```markdown
## Implementation Task

You are implementing a task from the workflow plan. Use the `homerun:implement` skill.

### Input (JSON)

\`\`\`json
{{implementer_input_json}}
\`\`\`

### Instructions

1. **Validate the input** - Check all required fields are present
2. **Read the task** - Understand objective and acceptance criteria
3. **Read reference docs** - Use paths from `spec_paths`
4. **Apply methodology** - Follow the methodology specified in input (default: TDD)
5. **Output JSON** - Return one of: `IMPLEMENTATION_COMPLETE`, `IMPLEMENTATION_BLOCKED`, or `VALIDATION_ERROR`

### Output Format

Your final output MUST be a valid JSON object in a code block:

\`\`\`json
{
  "signal": "IMPLEMENTATION_COMPLETE",
  "files_changed": [...],
  "test_file": "...",
  "commit_hash": "...",
  "acceptance_criteria_met": [...]
}
\`\`\`
```

### Task Tool Invocation

```javascript
// Build JSON input
const implementerInput = buildImplementerInput(state, task);

// Log skill invocation
logSkillInvocation(state, "homerun:implement", task.id);

// Determine model: use task.model (default: sonnet), or escalated_model if set
const implementerModel = task.escalated_model || task.model || "sonnet";

// Spawn implementer agent with appropriate model
Task({
  description: `Implement task: ${task.title}`,
  prompt: `Use the homerun:implement skill.\n\nInput:\n\`\`\`json\n${JSON.stringify(implementerInput, null, 2)}\n\`\`\``,
  model: implementerModel  // haiku for simple tasks, sonnet for complex or escalated
});
```

## Spawning Reviewer

After the implementer signals completion, spawn a reviewer agent.

### Parsing Implementer Output

Parse the JSON output from the implementer. Supports both envelope and legacy formats.

See `docs/references/signal-contracts.json` for the envelope schema.

```javascript
function parseSignal(output) {
  // Find JSON block in output
  const jsonMatch = output.match(/```json\s*([\s\S]*?)\s*```/);
  if (!jsonMatch) {
    throw new Error("No JSON output found in response");
  }

  const result = JSON.parse(jsonMatch[1]);

  // Support both envelope and legacy format
  if (result.envelope_version) {
    // New envelope format - extract and flatten
    return {
      signal: result.signal,
      timestamp: result.timestamp,
      source: result.source,
      ...result.payload
    };
  } else {
    // Legacy format - use as-is
    return result;
  }
}

function parseImplementerOutput(output) {
  const result = parseSignal(output);

  // Validate signal
  const validSignals = ["IMPLEMENTATION_COMPLETE", "IMPLEMENTATION_BLOCKED", "VALIDATION_ERROR"];
  if (!validSignals.includes(result.signal)) {
    throw new Error(`Invalid signal: ${result.signal}`);
  }

  return result;
}
```

### Constructing JSON Input for Reviewer

Build the JSON input from state, task, and implementer output:

```javascript
function buildReviewerInput(state, task, implementerOutput) {
  return {
    task: {
      id: task.id,
      title: task.title,
      acceptance_criteria: task.acceptance_criteria.map(ac => ({
        id: ac.id,
        criterion: ac.criterion
      }))
    },
    implementation: {
      commit_hash: implementerOutput.commit_hash,
      files_changed: implementerOutput.files_changed,
      test_file: implementerOutput.test_file
    },
    spec_paths: {
      technical_design: state.spec_paths.technical_design,
      adr: state.spec_paths.adr
    },
    worktree_path: state.worktree
  };
}
```

### Reviewer Prompt Template

```markdown
## Code Review Task

You are reviewing an implementation for the workflow. Use the `homerun:review` skill.

### Input (JSON)

\`\`\`json
{{reviewer_input_json}}
\`\`\`

### Instructions

1. **Validate the input** - Check all required fields are present
2. **Review the implementation** - Check files, tests, and commit
3. **Verify acceptance criteria** - Each criterion should have implementation and test
4. **Output JSON** - Return one of: `APPROVED`, `REJECTED`, or `VALIDATION_ERROR`

### Output Format

Your final output MUST be a valid JSON object in a code block:

\`\`\`json
{
  "signal": "APPROVED",
  "summary": "...",
  "verified": [...]
}
\`\`\`
```

### Task Tool Invocation

```javascript
// Parse implementer output
const implementerResult = parseImplementerOutput(implementerRawOutput);

// Handle blocked or validation error
if (implementerResult.signal !== "IMPLEMENTATION_COMPLETE") {
  return handleImplementerFailure(task, implementerResult);
}

// Build JSON input for reviewer
const reviewerInput = buildReviewerInput(state, task, implementerResult);

// Log skill invocation
logSkillInvocation(state, "homerun:review", task.id);

// Spawn reviewer agent - ALWAYS use sonnet for reviews
// Sonnet provides better judgment for acceptance criteria verification
Task({
  description: `Review implementation: ${task.title}`,
  prompt: `Use the homerun:review skill.\n\nInput:\n\`\`\`json\n${JSON.stringify(reviewerInput, null, 2)}\n\`\`\``,
  model: "sonnet"  // Reviews always use sonnet for quality assurance
});
```

### Parsing Reviewer Output

```javascript
function parseReviewerOutput(output) {
  const jsonMatch = output.match(/```json\s*([\s\S]*?)\s*```/);
  if (!jsonMatch) {
    throw new Error("No JSON output found in reviewer response");
  }

  const result = JSON.parse(jsonMatch[1]);

  const validSignals = ["APPROVED", "REJECTED", "VALIDATION_ERROR"];
  if (!validSignals.includes(result.signal)) {
    throw new Error(`Invalid signal: ${result.signal}`);
  }

  return result;
}
```

### Handling Review Results

```javascript
function handleReviewResult(state, task, reviewResult) {
  if (reviewResult.signal === "APPROVED") {
    // Mark task complete, update state
    task.status = "completed";
    task.completed_at = new Date().toISOString();
    task.verified = reviewResult.verified;
    return { action: "next_task" };
  }

  if (reviewResult.signal === "REJECTED") {
    // Store feedback, increment attempts
    task.feedback = task.feedback || [];
    task.feedback.push({
      attempt: task.attempts,
      summary: reviewResult.summary,
      issues: reviewResult.issues,
      required_fixes: reviewResult.required_fixes
    });
    return handleRejection(task, reviewResult);
  }

  if (reviewResult.signal === "VALIDATION_ERROR") {
    // Log error, retry with corrected input
    console.error("Reviewer validation error:", reviewResult.errors);
    return { action: "fix_input", errors: reviewResult.errors };
  }
}
```

---

## Legacy Reviewer Prompt (Deprecated)

The following template is deprecated but kept for reference:

```markdown
## Code Review Task (Legacy Format)

Use these exact paths (relative to worktree root) to verify alignment with specifications:

- `{{spec_paths.technical_design}}`: Architecture and implementation patterns
- `{{spec_paths.adr}}`: Architectural decisions and constraints

### Review Checklist

Verify each item:

- [ ] **Functionality** - Implementation meets acceptance criteria
- [ ] **Tests** - Test coverage is adequate and tests pass
- [ ] **Code Quality** - Code is clean, readable, follows conventions
- [ ] **No Regressions** - Existing functionality not broken
- [ ] **Documentation** - Code is appropriately documented
- [ ] **Security** - No obvious security issues introduced

### Instructions

1. Read the task specification carefully
2. Review all changed files and commits
3. Run the tests and verify they pass
4. Check each item on the review checklist
5. Provide detailed feedback

### Output

If the implementation is acceptable, output:

```
APPROVED
summary: [brief summary of what was implemented]
```

If the implementation needs changes, output:

```
REJECTED
summary: [overall assessment]
issues:
- [specific issue 1]
- [specific issue 2]
suggestions:
- [actionable suggestion 1]
- [actionable suggestion 2]
```
```

### Task Tool Invocation

```javascript
// Spawn reviewer agent
Task({
  description: `Review implementation: ${task.title}`,
  model: "sonnet",  // Reviews always use sonnet
  prompt: renderReviewerPrompt(task, implementationDetails)
});
```

## Retry Logic

When a review is rejected, apply progressive retry logic based on attempt count.

| Attempts | Strategy | Rationale |
|----------|----------|-----------|
| 0-1 | Same implementer with feedback | Minor issues, same context helpful |
| 2 | Fresh implementer | New perspective may solve persistent issues |
| 3+ | Escalate to user | Likely needs human judgment or clarification |

### Retry Implementation

```javascript
function handleRejection(task, feedback) {
  task.attempts++;
  task.feedback.push(feedback);

  // Check for high-severity issues - escalate model to sonnet
  const hasHighSeverity = feedback.issues?.some(issue => issue.severity === "high");
  if (hasHighSeverity && task.model === "haiku") {
    task.escalated_model = "sonnet";
    console.log(`High-severity rejection: escalating ${task.id} from haiku to sonnet`);
  }

  if (task.attempts < 2) {
    // Retry with same implementer, include feedback
    // If escalated_model is set, next spawn will use sonnet
    return { action: 'retry_same', feedback, model: task.escalated_model || task.model };
  } else if (task.attempts === 2) {
    // Fresh start with new implementer (always sonnet for fresh attempts)
    task.escalated_model = "sonnet";
    return { action: 'retry_fresh', allFeedback: task.feedback, model: "sonnet" };
  } else {
    // Escalate to user
    task.status = 'escalated';
    return { action: 'escalate', reason: 'Max retries exceeded', feedback: task.feedback };
  }
}
```

### Feedback Accumulation

Each rejected attempt's feedback is preserved:

```json
{
  "feedback": [
    {
      "attempt": 1,
      "summary": "Missing error handling",
      "issues": ["No try-catch around API call", "Missing validation"],
      "suggestions": ["Wrap in try-catch", "Add input validation"]
    },
    {
      "attempt": 2,
      "summary": "Tests incomplete",
      "issues": ["No edge case tests", "Missing mock for external service"],
      "suggestions": ["Add tests for empty input", "Mock the auth service"]
    }
  ]
}
```

---

## Rollback Strategy

When a task permanently fails (circuit breaker tripped, user skips, or unrecoverable error), choose a rollback strategy:

### Option 1: Revert Commits (Clean History)

Use when: Task commits broke something, need clean history

```bash
# Get task's commits from state
TASK_ID="001"
TASK_COMMITS=$(jq -r ".tasks[] | select(.id == \"$TASK_ID\") | .commits // []" tasks.json)

# Revert each commit (newest first to avoid conflicts)
for commit in $(echo "$TASK_COMMITS" | jq -r '.[]' | tac); do
  git revert --no-commit "$commit"
done

# Single revert commit
git commit -m "revert(feature): rollback task $TASK_ID - $FAILURE_REASON"
```

**State update:**
```json
{
  "status": "rolled_back",
  "rollback": {
    "strategy": "revert_commits",
    "reverted_commits": ["abc123", "def456"],
    "revert_commit": "ghi789",
    "reason": "circuit_breaker_max_attempts",
    "rolled_back_at": "2026-01-25T12:00:00Z"
  }
}
```

### Option 2: Soft Skip (Preserve Work)

Use when: Partial work is valuable, can be completed later

```json
{
  "status": "skipped",
  "skip_reason": "blocked_by_external_dependency",
  "preserved_commits": ["abc123"],
  "resume_notes": "Waiting for API v2 release"
}
```

**Effects:**
- Dependents unblocked (may need manual adjustment)
- Work preserved in git history
- Warning added to COMPLETION_REPORT.md
- Can resume with `/create --resume` after resolving blocker

### Option 3: Reset to Planning

Use when: Task was incorrectly specified, needs re-decomposition

```bash
# Mark task for replanning
jq '.tasks[] |= if .id == "001" then .status = "needs_replanning" else . end' tasks.json > tmp && mv tmp tasks.json
```

**State update:**
```json
{
  "phase": "planning",
  "replanning_context": {
    "failed_task": "001",
    "failure_reason": "task_too_large",
    "feedback": ["Consider splitting into 3 subtasks"]
  }
}
```

### Option 4: User Takeover

Use when: Automated recovery not possible, human judgment needed

```json
{
  "status": "user_takeover",
  "takeover_reason": "requires_domain_expertise",
  "handoff_notes": "Need to decide between approach A and B",
  "related_files": ["src/complex.ts", "docs/ADR.md"]
}
```

Present options to user:
1. Implement manually, then mark complete
2. Provide guidance, retry automated
3. Remove from scope (update PRD)
4. Decompose differently (return to planning)

### Choosing Rollback Strategy

```javascript
function chooseRollbackStrategy(task, failure) {
  // Circuit breaker - usually needs revert
  if (failure.type === 'circuit_breaker') {
    if (task.commits?.length > 0) return 'revert_commits';
    return 'soft_skip';
  }

  // External blocker - preserve and skip
  if (failure.type === 'blocked_external') return 'soft_skip';

  // Specification issue - replan
  if (failure.type === 'spec_unclear' || failure.type === 'task_too_large') {
    return 'reset_to_planning';
  }

  // Complex judgment needed
  return 'user_takeover';
}
```

### Recovery Commands

```bash
# Check task status
jq '.tasks[] | select(.status != "completed") | {id, status, attempts}' tasks.json

# Find commits for task
TASK_ID="001"
git log --oneline --grep="task $TASK_ID" --grep="($TASK_ID)" --all-match

# Revert single commit
git revert --no-commit <commit-hash>
git commit -m "revert: undo <commit-hash> due to <reason>"

# Reset task for retry
jq '.tasks[] |= if .id == "001" then .status = "pending" | .attempts = 0 | .feedback = [] else . end' tasks.json > tmp && mv tmp tasks.json

# Force complete task (manual override)
jq '.tasks[] |= if .id == "001" then .status = "completed" | .manual_override = true else . end' tasks.json > tmp && mv tmp tasks.json
```

---

## Model Routing Strategy

See `docs/references/model-routing.json` for the authoritative task type to model mapping.

### Task Model Selection

The planning phase assigns `model` to each task based on `task_type`. The conductor reads this from the task:

```javascript
const implementerModel = task.escalated_model || task.model || "sonnet";
```

### Escalation on High-Severity Rejection

When a reviewer rejects with `severity: "high"`, escalate haiku tasks to sonnet:
1. Detect high-severity issues
2. Set `task.escalated_model = "sonnet"`
3. Next attempt uses sonnet

**Escalation flow:**
```
haiku implements → sonnet reviews → REJECTED (high severity) → sonnet re-implements
```

---

## State Updates

Update `state.json` at each stage of the loop.

### Starting a Task (in_progress)

```json
{
  "current_task": "task-002",
  "tasks": [
    {
      "id": "task-002",
      "status": "in_progress",
      "attempts": 1,
      "started_at": "2026-01-25T14:30:00Z"
    }
  ]
}
```

### Completing a Task (completed)

```json
{
  "tasks": [
    {
      "id": "task-002",
      "status": "completed",
      "attempts": 1,
      "implementer_commits": ["def5678", "ghi9012"],
      "files_changed": ["src/services/auth.ts", "src/middleware/auth.ts"],
      "test_file": "tests/services/auth.test.ts",
      "completed_at": "2026-01-25T15:45:00Z"
    }
  ]
}
```

### Task Completion Validation Gate

**REQUIRED:** Before marking a task as completed, verify these conditions:

#### 1. Test Suite Execution

```bash
cd "$WORKTREE_PATH"

# Get the test file from the task
test_file=$(grep "^test_file:" "docs/tasks/${TASK_ID}-*.md" | sed 's/test_file: *//')

# Run the specific test file and capture result
if [[ -n "$test_file" ]] && [[ "$test_file" != "null" ]]; then
  # Detect test runner
  if [[ -f "package.json" ]]; then
    npm test -- "$test_file" 2>&1 || echo "VALIDATION_FAILED: Tests failed for $test_file"
  elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]]; then
    pytest "$test_file" 2>&1 || echo "VALIDATION_FAILED: Tests failed for $test_file"
  elif [[ -f "Cargo.toml" ]]; then
    cargo test 2>&1 || echo "VALIDATION_FAILED: Tests failed"
  else
    echo "VALIDATION_WARNING: Could not detect test runner"
  fi
fi
```

#### 2. Git State Verification

```bash
# Verify working tree is clean
if [[ -n $(git status --porcelain) ]]; then
  echo "VALIDATION_FAILED: Working tree has uncommitted changes"
  git status --short
fi

# Verify we're on the correct branch
current_branch=$(git branch --show-current)
expected_branch=$(jq -r '.branch' state.json)
if [[ "$current_branch" != "$expected_branch" ]]; then
  echo "VALIDATION_FAILED: On branch $current_branch, expected $expected_branch"
fi
```

#### 3. Commit Message Validation

```bash
# Get the latest commit message
last_commit_msg=$(git log -1 --pretty=%B)

# Validate conventional commit format: feat(<feature>): <description>
if ! echo "$last_commit_msg" | grep -qE "^(feat|fix|docs|refactor|test|chore)\([a-z-]+\): .+"; then
  echo "VALIDATION_FAILED: Commit message does not follow format 'feat(<feature>): <description>'"
  echo "Got: $last_commit_msg"
fi
```

#### 4. Mark Task File Checkboxes Complete

**After all validations pass**, update the task file to check off completed items:

```bash
task_file="docs/tasks/${TASK_ID}-*.md"
task_file=$(ls $task_file 2>/dev/null | head -1)

if [[ -f "$task_file" ]]; then
  # Check off all acceptance criteria checkboxes
  sed -i 's/- \[ \]/- [x]/g' "$task_file"

  # Update frontmatter status to completed
  sed -i 's/^status: .*/status: completed/' "$task_file"

  # Add completion timestamp if not present
  if ! grep -q "^completed_at:" "$task_file"; then
    sed -i "/^status: completed/a completed_at: $(date -Iseconds)" "$task_file"
  fi

  # Commit the task file update
  git add "$task_file"
  git commit -m "chore(${FEATURE}): mark task ${TASK_ID} complete

- All acceptance criteria verified
- Tests passing
- Task file checkboxes checked"

  echo "Task file updated: $task_file"
fi
```

**Verification:**
```bash
# Confirm all checkboxes are checked
unchecked=$(grep -c '\- \[ \]' "$task_file" 2>/dev/null || echo "0")
if [[ "$unchecked" -gt 0 ]]; then
  echo "WARNING: $unchecked unchecked items remain in $task_file"
fi
```

#### Validation Response

If any validation fails:
1. **Do not mark task as completed**
2. Return to implementer with specific failure reason
3. Increment attempt counter
4. Follow retry logic

### Phase Completion

When all tasks are complete:

```json
{
  "phase": "completion",
  "current_task": null,
  "tasks": [
    { "id": "task-001", "status": "completed" },
    { "id": "task-002", "status": "completed" },
    { "id": "task-003", "status": "completed" }
  ],
  "implementation_completed_at": "2026-01-25T16:00:00Z"
}
```

## Transition to Phase 4

When all tasks are completed, transition to the completion phase.

### Transition Steps

1. **Verify all tasks complete**
   ```javascript
   const allComplete = state.tasks.every(t => t.status === 'completed');
   ```

2. **Run Workflow Coverage Validation** (REQUIRED)

   Before running PRD verification, validate full traceability coverage:

   ```javascript
   function validateWorkflowTraceability(state) {
     const errors = [];
     const coverage = {
       user_stories: { total: 0, covered: 0 },
       acceptance_criteria: { total: 0, covered: 0 }
     };

     const traceability = state.traceability;
     const tasks = loadTasks(state.tasks_file);
     const completedTasks = tasks.filter(t => t.status === 'completed');

     // Check each user story
     for (const [storyId, story] of Object.entries(traceability.user_stories)) {
       coverage.user_stories.total++;
       const storyTasks = completedTasks.filter(t =>
         t.traces_to?.user_story === storyId
       );
       if (storyTasks.length > 0) {
         coverage.user_stories.covered++;
       } else {
         errors.push({
           type: 'story_uncovered',
           story: storyId,
           message: `User story "${storyId}" has no completed tasks`
         });
       }
     }

     // Check each acceptance criterion
     for (const [acId, ac] of Object.entries(traceability.acceptance_criteria)) {
       coverage.acceptance_criteria.total++;
       const acTasks = completedTasks.filter(t =>
         t.traces_to?.acceptance_criteria?.includes(acId) ||
         t.acceptance_criteria?.some(c => c.id === acId)
       );
       if (acTasks.length > 0) {
         coverage.acceptance_criteria.covered++;
       } else {
         errors.push({
           type: 'ac_uncovered',
           criterion: acId,
           message: `Acceptance criterion "${acId}" has no completed tasks`
         });
       }
     }

     return { valid: errors.length === 0, errors, coverage };
   }
   ```

   If coverage gaps are found, present options:
   - Create additional tasks for uncovered criteria
   - Mark criteria as out-of-scope (update PRD)
   - Proceed anyway (document gaps in COMPLETION_REPORT.md)

3. **Run PRD Verification Gate** (REQUIRED)

   Before transitioning to completion, verify the implementation meets PRD requirements.

   #### 2.1 User Story Coverage

   Check that all user stories have completed tasks:

   ```bash
   cd "$WORKTREE_PATH"

   # Load traceability from state
   stories=$(jq -r '.traceability.user_stories | keys[]' state.json)

   for story_id in $stories; do
     tasks=$(jq -r ".traceability.user_stories[\"$story_id\"].tasks[]" state.json 2>/dev/null)

     if [[ -z "$tasks" ]]; then
       echo "COVERAGE_GAP: $story_id has no implementing tasks"
       continue
     fi

     for task_id in $tasks; do
       status=$(jq -r ".tasks[\"$task_id\"].status" state.json)
       if [[ "$status" != "completed" ]]; then
         echo "COVERAGE_GAP: $story_id task $task_id is $status, not completed"
       fi
     done
   done
   ```

   #### 2.2 Acceptance Criteria Coverage

   Verify all acceptance criteria are addressed:

   ```bash
   # Check each acceptance criterion has a completed task
   criteria=$(jq -r '.traceability.acceptance_criteria | keys[]' state.json)

   for ac_id in $criteria; do
     tasks=$(jq -r ".traceability.acceptance_criteria[\"$ac_id\"].tasks[]" state.json 2>/dev/null)

     if [[ -z "$tasks" ]]; then
       echo "COVERAGE_GAP: $ac_id has no implementing tasks"
     fi
   done
   ```

   #### 2.3 Success Metrics Verification

   Prompt user to measure quantitative metrics:

   ```markdown
   ## Success Metrics Verification

   Please verify the following success metrics from the PRD:

   | ID | Metric | Target | Actual | Status |
   |----|--------|--------|--------|--------|
   | SM-001 | {{metric_name}} | {{target}} | _Enter actual_ | ⏳ Pending |
   | SM-002 | {{metric_name}} | {{target}} | _Enter actual_ | ⏳ Pending |

   For each metric, please provide the actual measured value.
   ```

   #### 2.4 Non-Goal Boundary Check

   Scan for scope creep - flag any task that appears to implement a non-goal:

   ```bash
   # Load non-goals
   non_goals=$(jq -r '.traceability.non_goals[]' state.json)

   # Check task titles and descriptions against non-goals
   for task_file in docs/tasks/*.md; do
     task_content=$(cat "$task_file")

     for non_goal in $non_goals; do
       # Extract keywords from non-goal (e.g., "OAuth", "two-factor")
       keywords=$(echo "$non_goal" | grep -oE '[A-Za-z]{4,}' | tr '[:upper:]' '[:lower:]')

       for keyword in $keywords; do
         if echo "$task_content" | grep -qi "$keyword"; then
           echo "SCOPE_CREEP_WARNING: $task_file may implement non-goal: $non_goal"
         fi
       done
     done
   done
   ```

   #### 2.5 Generate Completion Report

   Create `docs/COMPLETION_REPORT.md` with verification results:

   ```bash
   cat > docs/COMPLETION_REPORT.md << 'EOF'
   # Completion Report: {{FEATURE_NAME}}

   Generated: {{TIMESTAMP}}

   ## Coverage Summary

   | Category | Total | Covered | Coverage |
   |----------|-------|---------|----------|
   | User Stories | {{total_stories}} | {{covered_stories}} | {{story_coverage}}% |
   | Acceptance Criteria | {{total_ac}} | {{covered_ac}} | {{ac_coverage}}% |
   | Tasks | {{total_tasks}} | {{completed_tasks}} | {{task_coverage}}% |

   ## User Story Coverage Matrix

   | Story ID | Title | Tasks | Status |
   |----------|-------|-------|--------|
   {{#each user_stories}}
   | {{id}} | {{title}} | {{tasks}} | {{status}} |
   {{/each}}

   ## Acceptance Criteria Verification

   | AC ID | Description | Task | Verified |
   |-------|-------------|------|----------|
   {{#each acceptance_criteria}}
   | {{id}} | {{description}} | {{task}} | {{verified}} |
   {{/each}}

   ## Success Metrics

   | ID | Metric | Target | Actual | Met? |
   |----|--------|--------|--------|------|
   {{#each success_metrics}}
   | {{id}} | {{name}} | {{target}} | {{actual}} | {{met}} |
   {{/each}}

   ## Scope Verification

   ### Non-Goals Preserved
   {{#each non_goals}}
   - ✅ {{this}}
   {{/each}}

   ### Scope Creep Warnings
   {{#if scope_warnings}}
   {{#each scope_warnings}}
   - ⚠️ {{this}}
   {{/each}}
   {{else}}
   No scope creep detected.
   {{/if}}

   ## Recommendation

   {{#if all_verified}}
   ✅ **Ready for merge.** All user stories implemented, acceptance criteria verified, success metrics met.
   {{else}}
   ⚠️ **Review required.** See gaps above before proceeding.
   {{/if}}
   EOF

   git add docs/COMPLETION_REPORT.md
   git commit -m "docs: add completion verification report"
   ```

   #### Verification Response

   If coverage gaps are found:
   1. Present the gaps to the user
   2. Ask: "Would you like to add tasks to address these gaps, or proceed with partial coverage?"
   3. On "add tasks", return to planning to create missing tasks
   4. On "proceed", continue to Phase 4 with documented gaps

3. **Update state phase**
   ```json
   {
     "phase": "completion",
     "implementation_completed_at": "2026-01-25T16:00:00Z",
     "verification": {
       "story_coverage": 100,
       "ac_coverage": 100,
       "scope_creep_warnings": [],
       "verified_at": "2026-01-25T16:00:00Z"
     }
   }
   ```

4. **Invoke finishing skill**
   ```
   Use the Skill tool to invoke: homerun:finishing-a-development-branch
   ```

5. **Provide summary**
   ```markdown
   ## Implementation Complete

   All {{task_count}} tasks have been implemented and reviewed.

   ### Summary
   - Tasks completed: {{completed_count}}
   - Total commits: {{commit_count}}
   - Files changed: {{files_changed_count}}
   - User Story Coverage: {{story_coverage}}%
   - Acceptance Criteria Coverage: {{ac_coverage}}%

   ### Verification Report
   See `docs/COMPLETION_REPORT.md` for detailed coverage matrix.

   Transitioning to Phase 4: Finishing the development branch.
   ```

## Error Recovery

Handle errors gracefully to maintain workflow integrity.

| Error | Detection | Recovery Action |
|-------|-----------|-----------------|
| State file missing | File read fails | Create new state from plan, warn user |
| State file corrupt | JSON parse fails | Attempt backup recovery, or reinitialize |
| Implementer timeout | Task exceeds time limit | Mark attempt failed, retry with fresh agent |
| Implementer blocked | `IMPLEMENTATION_BLOCKED` output | Log blocker, escalate to user immediately |
| Reviewer timeout | Task exceeds time limit | Retry review with fresh agent |
| Invalid task reference | Task ID not in state | Log error, skip to next valid task |
| Git conflicts | Commit/merge fails | Pause workflow, notify user for resolution |

### Error Handling Implementation

See `docs/references/state-machine.md` for the full `conductorLoop` implementation with parallel support.

**Key behaviors:**
- Initialize `parallel_state` if missing
- Poll for completions, process review queue sequentially
- Block on high-severity failures, continue on low/medium
- Detect deadlock when no tasks running, none ready, but not all complete
- Refresh conductor after N completed tasks
