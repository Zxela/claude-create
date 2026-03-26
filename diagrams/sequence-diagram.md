# Sequence Diagram

## Full Workflow Sequence

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant M as Main Session (/create loop)
    participant D as Discovery Agent
    participant SR as Spec Reviewer
    participant SA as Scope Analyzer
    participant TD as Task Decomposer
    participant TL as Team Lead
    participant I as Implementer Agent
    participant R as Reviewer Agent
    participant FS as Filesystem

    Note over U,FS: Phase 1: Discovery (depth 1)
    U->>M: /create "feature idea"
    M->>D: Task(discovery-agent)
    activate D

    loop 2-4 questions per message
        D->>U: Questions (multiple choice)
        U->>D: Answers
    end

    D->>FS: Write PRD.md, ADR.md, TECHNICAL_DESIGN.md
    Note right of FS: ~/.claude/homerun/<hash>/<feature>/
    D->>FS: Write state.json (phase: spec_review)
    D->>M: DISCOVERY_COMPLETE
    deactivate D

    Note over M: Read state.json → phase: spec_review

    Note over U,FS: Phase 2: Spec Review (depth 1)
    M->>SR: Task(spec-reviewer)
    activate SR
    SR->>FS: Read spec documents
    SR->>SR: Check consistency, completeness, testability
    SR->>M: SPEC_REVIEW_COMPLETE (verdict: approved)
    deactivate SR

    Note over M: Update state.json → phase: scope_analysis

    Note over U,FS: Phase 3a: Scope Analysis (depth 1, sonnet)
    M->>SA: Task(scope-analyzer)
    activate SA
    SA->>FS: Read spec documents
    SA->>SA: Extract components, validate ACs, create JIT refs
    SA->>FS: Write docs/scope-analysis.json
    SA->>FS: Update state.json (phase: task_decomposition)
    SA->>M: SCOPE_ANALYSIS_COMPLETE
    deactivate SA

    Note over M: Read state.json → phase: task_decomposition

    Note over U,FS: Phase 3b: Task Decomposition (depth 1, opus)
    M->>TD: Task(task-decomposer)
    activate TD
    TD->>FS: Read docs/scope-analysis.json
    TD->>TD: Decompose into tasks with DAG
    TD->>FS: Write docs/tasks.json
    TD->>FS: Update state.json (phase: implementing)
    TD->>M: PLANNING_COMPLETE
    deactivate TD

    Note over M: Run validate-dag.sh (zero LLM cost)
    M->>FS: bash: validate-dag.sh docs/tasks.json docs/scope-analysis.json

    Note over M: Read state.json → phase: implementing

    Note over U,FS: Phase 4: Implementation Loop (depth 1)
    M->>TL: Skill(team-lead)
    activate TL

    loop Until all tasks complete
        TL->>FS: Read state.json, tasks.json
        TL->>TL: Find ready tasks (deps resolved)

        par Parallel Implementation (depth 1)
            TL->>I: Task(implementer, background: true)
            activate I
            I->>FS: Read extracted spec context
            I->>I: TDD: Write test → Implement → Refactor
            I->>FS: git commit
            I->>TL: IMPLEMENTATION_COMPLETE
            deactivate I
        end

        loop Sequential Reviews (depth 1)
            TL->>R: Task(reviewer)
            activate R
            R->>FS: Read implementation + specs
            R->>R: Verify acceptance criteria
            alt Approved
                R->>TL: APPROVED
            else Rejected
                R->>TL: REJECTED (severity, issues)
            end
            deactivate R
        end

        alt High Severity Rejection
            TL->>U: Present recovery options
            U->>TL: Choice (retry/skip/replan)
        end

        TL->>FS: Update task statuses
    end

    TL->>FS: Update state.json (phase: completing)
    TL->>M: TEAM_LEAD_COMPLETE
    deactivate TL

    Note over U,FS: Phase 5: Completion
    M->>U: Options: Merge / Create PR / Continue
    U->>M: Choice
    M->>FS: Execute choice
```

## Simplified Flow

```mermaid
sequenceDiagram
    participant User
    participant Main as /create loop
    participant Discovery as Discovery (inherit)
    participant SR as Spec Review (sonnet)
    participant SA as Scope Analyzer (sonnet)
    participant TD as Task Decomposer (opus)
    participant TL as Team Lead (inline)
    participant Impl as Implementer (sonnet)
    participant Review as Reviewer (sonnet)

    User->>Main: /create "idea"
    Main->>Discovery: Task()
    Discovery->>User: Questions (batched)
    User->>Discovery: Answers
    Discovery->>Main: Specs ready

    Main->>SR: Task()
    SR->>Main: Approved

    Main->>SA: Task() [sonnet]
    SA->>Main: scope-analysis.json

    Main->>TD: Task() [opus]
    TD->>Main: tasks.json

    Note over Main: validate-dag.sh (zero LLM cost)

    Main->>TL: Skill() [inline]
    loop Per Task
        TL->>Impl: Implement task
        Impl->>Review: Code ready (incremental)
        Review->>TL: Approved/Rejected
    end
    TL->>Main: All done!

    Main->>User: Options: Merge / PR / Continue
```

## Retry Sequence

```mermaid
sequenceDiagram
    participant C as Team Lead
    participant I as Implementer
    participant R as Reviewer
    participant U as User

    C->>I: Task (attempt 1)
    I->>R: Implementation
    R->>C: REJECTED (medium severity)

    Note over C: Same-agent retry
    C->>I: Task (attempt 2, with feedback)
    I->>R: Implementation v2
    R->>C: REJECTED (medium severity)

    Note over C: Fresh-agent retry
    C->>I: Task (attempt 3, fresh context)
    I->>R: Implementation v3
    R->>C: REJECTED (high severity)

    Note over C: Escalate to user
    C->>U: Recovery options
    U->>C: "Skip task"
    C->>C: Unblock dependents
```

## Parallel Execution Sequence

```mermaid
sequenceDiagram
    participant C as Team Lead
    participant I1 as Implementer 1
    participant I2 as Implementer 2
    participant I3 as Implementer 3
    participant R as Reviewer

    Note over C: 3 slots available, 3 ready tasks

    par Spawn in parallel
        C->>I1: Task 001 (background)
        C->>I2: Task 002 (background)
        C->>I3: Task 003 (background)
    end

    Note over C: Polling loop

    I1->>C: IMPLEMENTATION_COMPLETE
    C->>R: Review Task 001
    R->>C: APPROVED

    I3->>C: IMPLEMENTATION_COMPLETE
    Note over C: Queue for review

    I2->>C: IMPLEMENTATION_COMPLETE
    Note over C: Queue for review

    C->>R: Review Task 003
    R->>C: APPROVED

    C->>R: Review Task 002
    R->>C: REJECTED

    Note over C: Add 002 to retry queue
```
