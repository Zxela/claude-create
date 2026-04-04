# Retry Patterns Reference

Extracted from team-lead orchestration logic for token efficiency.

## Retry Queue Structure

```json
{
  "retry_queue": [
    {
      "task_id": "002",
      "attempt": 1,
      "last_error": "Test assertion failed: expected 200, got 404",
      "retry_type": "fresh_agent",
      "scheduled_at": "2026-01-25T11:00:00Z"
    }
  ]
}
```

## Retry Strategy (v6 — Continue-on-Rework)

### Order of retry approaches:

1. **First rejection (low/med severity):** Continue original agent via SendMessage
   - Agent has full context: files read, code written, tests run
   - Send reviewer's required_fixes as targeted instructions
   - Fallback: if agent terminated, use fresh spawn (step 2)

2. **Second rejection or SendMessage failure:** Fresh agent with clean context
   - Build structured failure summary from all attempts
   - Include specific rejection issues and required fixes
   - Give fresh perspective on the problem

3. **Third rejection:** Escalate
   - If haiku task: escalate model to sonnet, fresh agent
   - If sonnet/opus task: escalate to user with full attempt history

4. **Placeholder pattern detected (>2 rejections citing vagueness):**
   - Root cause is AC quality, not implementation
   - Escalate to re-decomposition, not retry

## Retry Type Logic

```javascript
function getRetryType(task, state) {
  const attempts = task.attempts || [];

  // FIRST rejection (low/med): continue original agent via SendMessage
  // Agent retains full context — targeted fix is faster than fresh start
  if (attempts.length === 1 && attempts[0].severity !== 'high') {
    return {
      type: 'continue_agent',
      agent_id: task.agent_id,
      message: task.attempts[0].feedback,
      fallback: 'fresh_agent'  // if SendMessage fails
    };
  }

  // SECOND rejection or SendMessage failure: fresh agent with structured summary
  if (attempts.length === 2) {
    return {
      type: 'fresh_agent',
      model: task.model,
      context: buildStructuredFailureSummary(task)
    };
  }

  // THIRD rejection: escalate
  if (attempts.length >= 3) {
    if (task.model === 'haiku') {
      return { type: 'escalate', model: 'sonnet' };
    }
    // sonnet/opus: escalate to user with full attempt history
    return {
      type: 'human_escalation',
      attempts: attempts.map(a => ({ severity: a.severity, feedback: a.feedback }))
    };
  }

  return { type: 'human_escalation' };
}

// Build a concise summary of what failed and why
function buildStructuredFailureSummary(task) {
  const lastAttempt = task.attempts[task.attempts.length - 1];
  return {
    task_objective: task.objective,
    attempt_count: task.attempts.length,
    // Structured per-attempt summaries (severity + status only, not raw feedback)
    attempts: task.attempts.map(a => ({
      status: a.status,
      severity: a.severity
    })),
    // Extract actionable fixes from the last rejection's required_fixes,
    // NOT the raw feedback string
    specific_fixes_needed: lastAttempt.required_fixes || lastAttempt.feedback,
    // DO NOT include: raw reviewer output verbatim, previous implementation code,
    // or accumulated context from failed attempts
  };
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

## Retry with Structured Failure Summary

When retrying with a fresh agent, provide a concise failure summary:

```javascript
function buildRetryPrompt(task, previousAttempt, rejection) {
  return {
    task: task,
    retry_context: {
      attempt_number: previousAttempt.attempt + 1,
      // Structured summary — NOT raw accumulated context
      failure_summary: `Previous attempt rejected: ${rejection.summary}`,
      specific_fixes: rejection.required_fixes,
      // Explicitly omit: previous implementation code, full reviewer output,
      // accumulated dialogue context
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
| **Retry with guidance** | Fresh agent with structured failure summary | Fixable issues |
| **Mark as fixed** | User fixed manually, re-review | External fix applied |
| **Skip task** | Mark skipped, unblock dependents | Non-critical task |
| **Return to planning** | Re-decompose the task | Fundamental design issue |
| **User takeover** | Exit team-lead, user continues | Complex judgment needed |
