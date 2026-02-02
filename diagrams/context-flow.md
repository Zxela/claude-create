# Context Flow Diagrams

## Token Budget Flow

```mermaid
graph TB
    subgraph Window["Context Window (200K tokens)"]
        subgraph Target["Target: 50% Usage (100K)"]
            subgraph Safe["Safe Zone (< 80K)"]
                Active[Active Context]
            end
            Warning[Warning Zone<br/>80-100K]
        end
        Danger[Danger Zone<br/>> 100K]
    end

    subgraph Triggers["Refresh Triggers"]
        T1["> 70% usage"]
        T2["5 tasks completed"]
        T3["> 10KB feedback"]
    end

    Triggers --> Refresh[Spawn Fresh Agent]
    Refresh --> Active
```

## Per-Phase Context Budgets

```mermaid
graph LR
    subgraph Discovery["Discovery (~10-20K)"]
        D1[Skill: 2K]
        D2[Project context: 2K]
        D3[Dialogue: 10K growing]
        D4[Spec drafts: 5K]
    end

    subgraph Planning["Planning (~10K)"]
        P1[Skill: 3K]
        P2[Specs: 5K]
        P3[State: 1K]
        P4[Tasks output: 2K]
    end

    subgraph Conductor["Conductor (~5K)"]
        C1[Skill: 2K]
        C2[State: 1K]
        C3[Current tasks: 1K]
        C4[Feedback buffer: 1K]
    end

    subgraph Implementer["Implementer (~15K target)"]
        I1[Skill: 1K]
        I2[Task: 1K]
        I3[Extracted specs: 1K]
        I4[File reads: 3K]
        I5[Test output: 0.5K masked]
        I6[Implementation: 5K]
        I7[Buffer: 3.5K]
    end

    subgraph Reviewer["Reviewer (~10K)"]
        R1[Skill: 1K]
        R2[Task: 1K]
        R3[Specs: 2K]
        R4[Implementation: 4K]
        R5[Analysis: 2K]
    end

    Discovery -->|"Task(opus)"| Planning
    Planning -->|"Task(haiku)"| Conductor
    Conductor -->|"Task(varies)"| Implementer
    Conductor -->|"Task(sonnet)"| Reviewer
```

## Observation Masking Flow

```mermaid
graph TB
    subgraph Input["Tool Output"]
        Raw[Raw Output<br/>5-10K tokens]
    end

    subgraph Check["Size Check"]
        Threshold{"> 2000 tokens?"}
    end

    subgraph Keep["Keep in Context"]
        Small[Small Output<br/>< 2K tokens]
    end

    subgraph Mask["Mask Large Output"]
        Write[Write to scratch file]
        Summary[Generate summary]
        Ref[Return reference]
    end

    subgraph Result["Masked Result (~100-200 tokens)"]
        MaskedOut["{ masked: true,<br/>summary: '3 files, +45/-12',<br/>full_output_path: '/tmp/...' }"]
    end

    Raw --> Threshold
    Threshold -->|No| Small
    Threshold -->|Yes| Write
    Write --> Summary
    Summary --> Ref
    Ref --> Result
```

## Spec Extraction Flow

```mermaid
graph TB
    subgraph Full["Full Spec Files"]
        TD[TECHNICAL_DESIGN.md<br/>~5-10K tokens]
        ADR[ADR.md<br/>~2-3K tokens]
    end

    subgraph TaskType["Task Type Routing"]
        Type{task_type?}
        Model[create_model] --> DM[Extract: Data Model section]
        Endpoint[add_endpoint] --> API[Extract: API Contracts section]
        Service[create_service] --> Comp[Extract: Components section]
        Other[other] --> Min[Minimal extraction]
    end

    subgraph Extracted["Extracted Context"]
        Section[Relevant Section Only<br/>~500-1000 tokens]
    end

    subgraph TracesTo["traces_to References"]
        ADRRef[adr_decisions] --> ADRSection[Extract ADR decision<br/>~200 tokens]
    end

    TD --> Type
    Type --> Model
    Type --> Endpoint
    Type --> Service
    Type --> Other

    DM --> Section
    API --> Section
    Comp --> Section
    Min --> Section

    ADR --> TracesTo
    ADRSection --> Section
```

## Agent Spawning with Context Isolation

```mermaid
sequenceDiagram
    participant M as Main (User Context)
    participant D as Discovery Context
    participant P as Planning Context
    participant C as Conductor Context
    participant I as Implementer Context

    Note over M: User's conversation history<br/>Could be 50K+ tokens

    M->>D: Task(model: opus)
    Note over D: Fresh context: ~2K<br/>(skill + project scan)

    loop Dialogue
        D->>D: +500 tokens per exchange
    end
    Note over D: Final: ~15K tokens

    D->>P: Task(model: opus)
    Note over D: Context discarded

    Note over P: Fresh context: ~10K<br/>(skill + specs + state)

    P->>C: Task(model: haiku)
    Note over P: Context discarded

    Note over C: Fresh context: ~5K<br/>(skill + state + tasks)

    par Parallel Spawns
        C->>I: Task(model: haiku, background)
        Note over I: Fresh: ~15K<br/>(skill + task + extracted specs)
    end

    Note over C: Context grows with<br/>completion tracking

    opt Refresh at 5 tasks
        C->>C: Spawn fresh conductor
        Note over C: Reset to ~5K
    end
```

## Context Accumulation Over Time

```mermaid
xychart-beta
    title "Context Usage Per Phase"
    x-axis ["Start", "Mid-Discovery", "End-Discovery", "Planning", "Conductor Start", "After 3 Tasks", "After 5 Tasks", "Refresh"]
    y-axis "Tokens (K)" 0 --> 50
    bar [2, 10, 18, 10, 5, 12, 18, 5]
    line [100, 100, 100, 100, 100, 100, 100, 100]
```

## Test Output Masking Example

```
BEFORE MASKING (5000+ tokens):
─────────────────────────────────────────────
PASS src/models/user.test.ts
  User Model
    ✓ should create user with valid email (3ms)
    ✓ should hash password on creation (15ms)
    ✓ should validate email format (2ms)
    ✓ should reject weak passwords (1ms)
    ... 50 more passing tests ...

FAIL src/services/auth.test.ts
  Auth Service
    ✓ should login with valid credentials (5ms)
    ✕ should reject invalid password (3ms)

      Expected: 401
      Received: 200

      at Object.<anonymous> (src/services/auth.test.ts:45:21)
      at processTicksAndRejections (node:internal/process/task_queues:95:5)

    ... stack trace continues for 30 lines ...

Test Suites: 1 failed, 5 passed, 6 total
Tests:       1 failed, 54 passed, 55 total
Time:        2.345s
─────────────────────────────────────────────

AFTER MASKING (~200 tokens):
─────────────────────────────────────────────
{
  "masked": true,
  "summary": "54 passed, 1 failed",
  "first_failure": {
    "test": "should reject invalid password",
    "file": "src/services/auth.test.ts:45",
    "expected": 401,
    "received": 200
  },
  "full_output_path": "/tmp/claude-scratch/test-1706195400.txt"
}
─────────────────────────────────────────────
```

## File Read Strategy

```mermaid
graph TB
    subgraph Need["What You Need"]
        N1[Understand code structure]
        N2[Find import patterns]
        N3[Check test patterns]
        N4[Modify specific file]
    end

    subgraph Strategy["Reading Strategy"]
        S1["grep -A 5 'function|class|export'<br/>~500 tokens"]
        S2["head -30 similar-file.ts<br/>~200 tokens"]
        S3["head -50 existing.test.ts<br/>~300 tokens"]
        S4["Read full file<br/>~1-2K tokens"]
    end

    subgraph Avoid["Avoid"]
        A1["Read entire directories"]
        A2["Read files you won't modify"]
        A3["Re-read files in context"]
    end

    N1 --> S1
    N2 --> S2
    N3 --> S3
    N4 --> S4

    style Avoid fill:#ffcdd2
```
