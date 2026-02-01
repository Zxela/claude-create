# Parallel Execution Scenarios

Reference examples for conductor parallel execution patterns.

## Concurrency Scenarios

### Scenario 1: All Slots Full

**Config:**
- `max_parallel_tasks: 3`
- `max_parallel_by_model: { haiku: 5, sonnet: 3, opus: 1 }`

**Current state:**
- Running: 3 tasks (1 haiku, 2 sonnet)
- Ready: 2 haiku tasks, 1 sonnet task

**Calculation:**
```
Global: 3 - 3 = 0 slots available
Result: 0 slots (wait for completions)
```

### Scenario 2: Model Limit Reached

**Config:**
- `max_parallel_tasks: 5`
- `max_parallel_by_model: { haiku: 5, sonnet: 3, opus: 1 }`

**Current state:**
- Running: 3 sonnet tasks
- Ready: 2 sonnet tasks, 1 haiku task

**Calculation:**
```
Global: 5 - 3 = 2 slots available
Sonnet: 3 - 3 = 0 slots (at limit)
Haiku: 5 - 0 = 5 slots
Result: Only haiku task can be spawned (1 slot used)
```

### Scenario 3: Mixed Model Spawning

**Config:**
- `max_parallel_tasks: 4`
- `max_parallel_by_model: { haiku: 5, sonnet: 3, opus: 1 }`

**Current state:**
- Running: 1 sonnet task
- Ready: 2 haiku, 2 sonnet, 1 opus

**Calculation:**
```
Global: 4 - 1 = 3 slots available
Haiku: 5 - 0 = 5 slots
Sonnet: 3 - 1 = 2 slots
Opus: 1 - 0 = 1 slot

Spawn order (respecting model limits):
1. First haiku task (3 slots -> 2)
2. Second haiku task (2 slots -> 1)
3. First sonnet task (1 slot -> 0)
4. Second sonnet blocked (no global slots)
5. Opus blocked (no global slots)
```

---

## Subtask Parallel Execution

### Within-Parent Parallelism

```
Task 001: Create User model (3 subtasks)
  +-- 001a: Create class (no deps)
  +-- 001b: Add validation (needs 001a)
  +-- 001c: Add serialization (needs 001a)

After 001a completes:
  001b and 001c are BOTH ready -> can run in parallel!
```

### Cross-Parent Dependencies

```
Task 001: Create User model
  +-- 001a, 001b, 001c

Task 002: Create Auth service (needs Task 001)
  +-- 002a: Create interface (needs 001 complete)
  +-- 002b: Add login (needs 002a)

002a cannot start until ALL of 001's subtasks complete
(parent auto-completes when all children complete)
```

---

## Edge Cases

### Deadlock Detection

**Circular dependency (should not happen after DAG validation):**
```
001 blocked_by: [002]
002 blocked_by: [003]
003 blocked_by: [001]  <- Cycle!

Result: No tasks ever become ready
Conductor detects deadlock after 3 iterations without progress
```

### Retry Queue Priority

Fresh tasks take priority over retries:

```
Ready queue: [task-004, task-005] (fresh)
Retry queue: [task-002] (failed once)

Spawn order with 2 slots:
1. task-004 (fresh)
2. task-005 (fresh)
3. task-002 waits for next round
```

### High-Severity Blocking

```
Task 003 reviewed -> REJECTED (high severity)

State change:
  parallel_state.blocked_by_failure = true
  parallel_state.failure_severity = 'high'

Effect:
  - Running tasks (001, 002) allowed to complete
  - No new tasks spawned
  - User presented with recovery options
```

---

## Refresh Scenarios

### Task-Count Refresh

```
conductor_refresh_interval: 5
tasks_since_refresh: 5

Trigger: tasks_since_refresh >= interval
Action: Spawn fresh conductor, exit current
```

### Token-Based Refresh

```
estimated_tokens: 45000
threshold: 40% of 200000 = 80000

estimated_tokens (45000) < threshold (80000)
No refresh triggered
```

```
estimated_tokens: 85000
threshold: 80000

estimated_tokens (85000) > threshold (80000)
Refresh triggered with reason: 'token_threshold'
```
