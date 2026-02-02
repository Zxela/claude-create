# State Machine Diagrams

## Workflow Phase State Machine

```mermaid
stateDiagram-v2
    [*] --> discovery: /create

    discovery --> planning: DISCOVERY_COMPLETE
    discovery --> discovery: User answers question
    discovery --> discovery: Validation failed

    planning --> implementing: PLANNING_COMPLETE
    planning --> planning: DAG cycle detected
    planning --> discovery: Major revision needed

    implementing --> implementing: Task completed
    implementing --> implementing: Task failed (low/med)
    implementing --> blocked: Task failed (high)
    implementing --> completing: All tasks done

    blocked --> implementing: User: retry/skip
    blocked --> planning: User: replan

    completing --> done: Merge/PR created
    completing --> implementing: User: continue

    done --> [*]
```

## Task Status State Machine

```mermaid
stateDiagram-v2
    [*] --> pending: Task created

    pending --> in_progress: Selected by conductor
    pending --> blocked: Dependency failed

    in_progress --> pending_review: Implementation complete
    in_progress --> failed: Implementation blocked

    pending_review --> completed: APPROVED
    pending_review --> retry_queued: REJECTED (low/med)
    pending_review --> failed: REJECTED (high, max attempts)

    retry_queued --> in_progress: Slot available

    blocked --> pending: Blocker resolved
    blocked --> skipped: User skips

    failed --> in_progress: User: retry with guidance
    failed --> skipped: User: skip task
    failed --> pending: User: replan (new task)

    completed --> [*]
    skipped --> [*]
```

## Retry State Machine

```mermaid
stateDiagram-v2
    [*] --> attempt_1: First try

    state attempt_1 {
        [*] --> implementing
        implementing --> review
        review --> success: APPROVED
        review --> rejected: REJECTED
    }

    attempt_1 --> attempt_2: same_agent retry
    attempt_1 --> success_state: success

    state attempt_2 {
        [*] --> implementing_2: With feedback
        implementing_2 --> review_2
        review_2 --> success: APPROVED
        review_2 --> rejected: REJECTED
    }

    attempt_2 --> attempt_3: fresh_agent retry
    attempt_2 --> success_state: success

    state attempt_3 {
        [*] --> implementing_3: Fresh context
        implementing_3 --> review_3
        review_3 --> success: APPROVED
        review_3 --> rejected: REJECTED
    }

    attempt_3 --> escalation: Still failing
    attempt_3 --> success_state: success

    state escalation {
        [*] --> present_options
        present_options --> retry_with_guidance: User choice
        present_options --> mark_fixed: User choice
        present_options --> skip_task: User choice
        present_options --> return_to_planning: User choice
    }

    escalation --> attempt_1: retry_with_guidance
    escalation --> success_state: mark_fixed
    escalation --> skipped_state: skip_task
    escalation --> planning_phase: return_to_planning

    success_state --> [*]
    skipped_state --> [*]
    planning_phase --> [*]
```

## Circuit Breaker State Machine

```mermaid
stateDiagram-v2
    [*] --> closed: Initial state

    closed --> closed: Success (reset counter)
    closed --> closed: Failure (increment counter)
    closed --> open: Failures >= threshold

    open --> open: Reject new tasks
    open --> half_open: User intervention

    half_open --> closed: Next task succeeds
    half_open --> open: Next task fails
```

## Conductor Loop State Machine

```mermaid
stateDiagram-v2
    [*] --> read_state: Start

    read_state --> check_complete: Load state.json + tasks.json

    check_complete --> workflow_complete: All tasks done
    check_complete --> check_blocked: Tasks remaining

    check_blocked --> escalate: blocked_by_failure = true
    check_blocked --> poll_running: Not blocked

    escalate --> handle_recovery: Present options to user
    handle_recovery --> poll_running: User chose action

    poll_running --> process_completions: Check TaskOutput

    process_completions --> queue_reviews: Completions found
    process_completions --> process_reviews: No completions

    queue_reviews --> process_reviews: Add to review queue

    process_reviews --> handle_review: Queue not empty
    process_reviews --> find_ready: Queue empty

    handle_review --> mark_complete: APPROVED
    handle_review --> queue_retry: REJECTED low/med
    handle_review --> set_blocked: REJECTED high

    mark_complete --> process_reviews: Continue reviews
    queue_retry --> process_reviews: Continue reviews
    set_blocked --> escalate: Block new spawns

    find_ready --> calculate_slots: Find tasks with resolved deps

    calculate_slots --> spawn_tasks: Slots available
    calculate_slots --> update_state: No slots

    spawn_tasks --> update_state: Spawn in background

    update_state --> check_refresh: Write state.json

    check_refresh --> spawn_fresh: Refresh needed
    check_refresh --> read_state: Continue loop

    spawn_fresh --> [*]: New conductor takes over

    workflow_complete --> [*]: Done
```

## Parallel Execution State Machine

```mermaid
stateDiagram-v2
    [*] --> idle: Conductor starts

    state idle {
        [*] --> finding_tasks
        finding_tasks --> no_ready: No tasks ready
        finding_tasks --> has_ready: Tasks found
    }

    idle --> spawning: has_ready AND slots > 0
    idle --> waiting: no_ready OR slots = 0

    state spawning {
        [*] --> spawn_one
        spawn_one --> spawn_more: More tasks AND slots
        spawn_one --> done_spawning: No more
        spawn_more --> spawn_one
    }

    spawning --> polling: All spawned

    state polling {
        [*] --> check_outputs
        check_outputs --> none_complete: No completions
        check_outputs --> has_completions: Found completions
    }

    polling --> waiting: none_complete
    polling --> processing: has_completions

    state processing {
        [*] --> parse_output
        parse_output --> queue_review: IMPLEMENTATION_COMPLETE
        parse_output --> handle_blocked: IMPLEMENTATION_BLOCKED
        queue_review --> more_completions: Check next
        handle_blocked --> more_completions
        more_completions --> parse_output: More to process
        more_completions --> done_processing: All processed
    }

    processing --> reviewing: Done processing

    state reviewing {
        [*] --> pick_review
        pick_review --> none_pending: Queue empty
        pick_review --> do_review: Has pending
        do_review --> handle_result
        handle_result --> pick_review
    }

    reviewing --> idle: none_pending

    waiting --> polling: Short delay
```

## Dialogue State Machine (Discovery)

```mermaid
stateDiagram-v2
    [*] --> init: Start discovery

    init --> asking: Initialize categories

    state asking {
        [*] --> select_category
        select_category --> purpose: purpose remaining
        select_category --> users: users remaining
        select_category --> scope: scope remaining
        select_category --> constraints: constraints remaining
        select_category --> edge_cases: edge_cases remaining
        select_category --> all_done: None remaining

        purpose --> wait_answer
        users --> wait_answer
        scope --> wait_answer
        constraints --> wait_answer
        edge_cases --> wait_answer

        wait_answer --> process_answer: User responds
        process_answer --> increment_turn
        increment_turn --> check_category
        check_category --> mark_complete: Category done
        check_category --> select_category: More questions
        mark_complete --> select_category
    }

    asking --> check_limits: After each answer

    check_limits --> warning: turns >= 15 (first time)
    check_limits --> force_generate: turns >= 20
    check_limits --> asking: Continue

    warning --> asking: User: continue
    warning --> generating: User: generate now

    asking --> generating: all_done

    generating --> validating: Specs generated

    validating --> presenting: Show to user

    presenting --> confirmed: User approves
    presenting --> editing: Minor edits
    presenting --> asking: Major revision

    editing --> presenting: Apply edits

    confirmed --> writing: Write files

    writing --> [*]: DISCOVERY_COMPLETE

    force_generate --> generating: Auto-generate
```
