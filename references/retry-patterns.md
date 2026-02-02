# Retry Patterns Reference

Extracted from conductor/SKILL.md for token efficiency.

## Retry Queue Structure

```json
{
  "retry_queue": [
    {
      "task_id": "002",
      "attempt": 1,
      "last_error": "Test assertion failed: expected 200, got 404",
      "retry_type": "same_agent",
      "scheduled_at": "2026-01-25T11:00:00Z"
    }
  ]
}
```

## Retry Precedence (Priority Order)

1. **Fresh pending tasks** - Always prefer unstarted work
2. **Same-agent retries** - Retry with accumulated context
3. **Fresh-agent retries** - Clean slate after same-agent exhausted
4. **Model escalation** - Upgrade haiku to sonnet on persistent failure

## Retry Type Logic

```javascript
function getRetryType(task, state) {
  const attempts = getAttemptCount(task.id, state);
  const config = state.config.retries;

  if (attempts < config.same_agent) {
    return { type: 'same_agent', model: task.model };
  }

  if (attempts < config.same_agent + config.fresh_agent) {
    return { type: 'fresh_agent', model: task.model };
  }

  // Escalate haiku to sonnet
  if (task.model === 'haiku') {
    return { type: 'escalate', model: 'sonnet' };
  }

  return { type: 'human_escalation' };
}
```

## Circuit Breaker Pattern

Prevents cascading failures when something is fundamentally broken:

```javascript
const circuitBreaker = {
  consecutive_failures: 0,
  threshold: 3,
  state: 'closed', // closed, open, half-open

  recordFailure() {
    this.consecutive_failures++;
    if (this.consecutive_failures >= this.threshold) {
      this.state = 'open';
      return { action: 'stop_spawning', reason: 'circuit_open' };
    }
    return { action: 'continue' };
  },

  recordSuccess() {
    this.consecutive_failures = 0;
    this.state = 'closed';
  },

  canSpawn() {
    return this.state !== 'open';
  }
};
```

## Failure Severity Classification

| Severity | Examples | Response |
|----------|----------|----------|
| **low** | Style issues, missing docstring | Retry with guidance |
| **medium** | Logic error, missing validation | Retry + add to technical notes |
| **high** | Security flaw, architectural violation | Block spawning, escalate |

## High-Severity Blocking

When a high-severity rejection occurs:

```javascript
function handleHighSeverityRejection(task, rejection, state) {
  // Stop spawning new tasks
  state.parallel_state.blocked_by_failure = true;
  state.parallel_state.failure_severity = 'high';
  state.parallel_state.blocking_task = task.id;

  // Let running tasks complete
  // Don't kill in-flight work

  // Present recovery options
  return {
    signal: 'HIGH_SEVERITY_FAILURE',
    task_id: task.id,
    issues: rejection.issues,
    options: [
      'retry_with_guidance',
      'mark_fixed',
      'skip_task',
      'return_to_planning'
    ]
  };
}
```

## Retry with Accumulated Context

When retrying same-agent, include previous attempt context:

```javascript
function buildRetryPrompt(task, previousAttempt, rejection) {
  return {
    task: task,
    retry_context: {
      attempt_number: previousAttempt.attempt + 1,
      previous_issues: rejection.issues,
      reviewer_feedback: rejection.required_fixes,
      guidance: `Previous attempt failed due to: ${rejection.summary}.
                 Focus on: ${rejection.required_fixes.join(', ')}`
    }
  };
}
```

## Progress Tracking

Detect stalls with iteration tracking:

```javascript
function checkProgress(state) {
  const { iteration, tasks_completed_this_iteration, last_completion_iteration } = state.progress;

  // No completions in 3 iterations = potential deadlock
  if (iteration - last_completion_iteration >= 3 && tasks_completed_this_iteration === 0) {
    return {
      stalled: true,
      reason: 'no_progress',
      action: 'trigger_deadlock_recovery'
    };
  }

  return { stalled: false };
}
```

## Recovery Options

When blocked or stalled, present these options:

| Option | Action | When to Use |
|--------|--------|-------------|
| **Retry with guidance** | Add reviewer feedback to task, retry | Fixable issues |
| **Mark as fixed** | User fixed manually, re-review | External fix applied |
| **Skip task** | Mark skipped, unblock dependents | Non-critical task |
| **Return to planning** | Re-decompose the task | Fundamental design issue |
| **User takeover** | Exit conductor, user continues | Complex judgment needed |
