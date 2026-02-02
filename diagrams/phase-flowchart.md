# Phase Flowcharts

## Overview: Complete Workflow

```mermaid
flowchart TB
    subgraph Phase1[Phase 1: Discovery]
        D1[Start /create] --> D2{Read CLAUDE.md?}
        D2 --> D3[Gather project context]
        D3 --> D4[Ask purpose questions]
        D4 --> D5[Ask user questions]
        D5 --> D6[Ask scope questions]
        D6 --> D7[Ask constraint questions]
        D7 --> D8[Ask edge case questions]
        D8 --> D9{All categories<br/>covered?}
        D9 -->|No| D4
        D9 -->|Yes| D10[Generate specs]
        D10 --> D11[Validate with user]
        D11 --> D12{Approved?}
        D12 -->|No| D10
        D12 -->|Yes| D13[Write to ~/.claude/homerun/]
        D13 --> D14[Commit state.json]
    end

    subgraph Phase2[Phase 2: Planning]
        P1[Read specs] --> P2[Analyze scope]
        P2 --> P3[Create dependency graph]
        P3 --> P4[Decompose into tasks]
        P4 --> P5{Task too big?}
        P5 -->|Yes| P6[Split into subtasks]
        P6 --> P4
        P5 -->|No| P7[Assign model per task]
        P7 --> P8[Validate DAG]
        P8 --> P9{Cycles?}
        P9 -->|Yes| P10[Fix ordering]
        P10 --> P8
        P9 -->|No| P11[Write tasks.json]
        P11 --> P12[Commit]
    end

    subgraph Phase3[Phase 3: Implementation]
        C1[Conductor starts] --> C2[Read state + tasks]
        C2 --> C3{All complete?}
        C3 -->|Yes| C10[WORKFLOW_COMPLETE]
        C3 -->|No| C4[Find ready tasks]
        C4 --> C5[Calculate slots]
        C5 --> C6[Spawn implementers]
        C6 --> C7[Poll for completions]
        C7 --> C8[Process reviews]
        C8 --> C9{Refresh needed?}
        C9 -->|Yes| C11[Spawn fresh conductor]
        C9 -->|No| C2
    end

    subgraph Phase4[Phase 4: Completion]
        F1[Present options] --> F2{User choice}
        F2 -->|Merge| F3[Merge to main]
        F2 -->|PR| F4[Create pull request]
        F2 -->|Continue| F5[Keep worktree]
    end

    Phase1 --> Phase2
    Phase2 --> Phase3
    Phase3 --> Phase4
```

## Discovery: Dialogue Flow

```mermaid
flowchart TB
    Start[User prompt] --> Init[Initialize dialogue_state]
    Init --> Cat{Next category?}

    Cat -->|purpose| Q1[Ask purpose question]
    Cat -->|users| Q2[Ask user question]
    Cat -->|scope| Q3[Ask scope question]
    Cat -->|constraints| Q4[Ask constraints question]
    Cat -->|edge_cases| Q5[Ask edge cases question]
    Cat -->|none| Gen[Generate specs]

    Q1 --> Ans[User answers]
    Q2 --> Ans
    Q3 --> Ans
    Q4 --> Ans
    Q5 --> Ans

    Ans --> Inc[Increment turn counter]
    Inc --> Check{Turn >= 15?}
    Check -->|Yes, first time| Warn[Show warning]
    Warn --> Cont{Continue?}
    Cont -->|Yes| Cat
    Cont -->|No| Gen
    Check -->|No| Mark{Category complete?}
    Check -->|>=20| Gen

    Mark -->|Yes| MarkDone[Mark category done]
    Mark -->|No| Cat
    MarkDone --> Cat

    Gen --> Val[Validate specs]
    Val --> Show[Show to user section by section]
    Show --> Conf{Confirmed?}
    Conf -->|Minor edits| Edit[Apply edits]
    Edit --> Show
    Conf -->|Major revision| Cat
    Conf -->|Yes| Write[Write files]
    Write --> Done[DISCOVERY_COMPLETE]
```

## Planning: Task Decomposition

```mermaid
flowchart TB
    Read[Read specs] --> Extract[Extract components]
    Extract --> Story[For each user story]

    Story --> AC[For each acceptance criterion]
    AC --> Create[Create task]

    Create --> Check{Decomposition<br/>needed?}

    Check -->|">3 AC"| Split[Split into subtasks]
    Check -->|">4 files"| Split
    Check -->|"Multiple layers"| Split
    Check -->|"Title has 'and'"| Split
    Check -->|No| Assign[Assign model]

    Split --> SubTask[Create subtask]
    SubTask --> SubModel[Assign haiku model]
    SubModel --> SubDep[Set dependencies]
    SubDep --> More{More subtasks?}
    More -->|Yes| SubTask
    More -->|No| Assign

    Assign --> Route{Task type?}
    Route -->|add_field, add_method| Haiku[model: haiku]
    Route -->|create_model, bug_fix| Sonnet[model: sonnet]
    Route -->|architectural| Opus[model: opus]

    Haiku --> Dep[Set dependencies]
    Sonnet --> Dep
    Opus --> Dep

    Dep --> Next{More stories?}
    Next -->|Yes| Story
    Next -->|No| DAG[Validate DAG]

    DAG --> Cycle{Cycles?}
    Cycle -->|Yes| Fix[Reorder tasks]
    Fix --> DAG
    Cycle -->|No| Write[Write tasks.json]
    Write --> Done[PLANNING_COMPLETE]
```

## Conductor: Main Loop

```mermaid
flowchart TB
    Start[Start conductor] --> Read[Read state.json + tasks.json]
    Read --> Check{All tasks<br/>complete?}
    Check -->|Yes| Done[WORKFLOW_COMPLETE]

    Check -->|No| Blocked{Blocked by<br/>high-severity?}
    Blocked -->|Yes| Escalate[Present recovery options]
    Escalate --> Choice{User choice}
    Choice -->|Retry| Unblock[Clear blocked flag]
    Choice -->|Skip| Skip[Mark skipped]
    Choice -->|Replan| Replan[Return to planning]
    Unblock --> Poll
    Skip --> Poll

    Blocked -->|No| Poll[Poll running tasks]
    Poll --> Complete{Any completed?}
    Complete -->|Yes| Process[Process completions]
    Process --> Queue[Add to review queue]

    Complete -->|No| Review{Review queue<br/>empty?}
    Queue --> Review

    Review -->|No| DoReview[Process one review]
    DoReview --> Result{Result?}
    Result -->|APPROVED| MarkDone[Mark task complete]
    Result -->|REJECTED low/med| Retry[Add to retry queue]
    Result -->|REJECTED high| Block[Set blocked flag]
    MarkDone --> Review
    Retry --> Review
    Block --> Escalate

    Review -->|Yes| Ready[Find ready tasks]
    Ready --> Slots[Calculate available slots]
    Slots --> Spawn{Slots > 0 AND<br/>ready tasks?}
    Spawn -->|Yes| DoSpawn[Spawn implementers]
    DoSpawn --> Update[Update state]

    Spawn -->|No| Update
    Update --> Refresh{Refresh<br/>needed?}
    Refresh -->|Yes| NewConductor[Spawn fresh conductor]
    Refresh -->|No| Read
```

## Implementer: TDD Flow

```mermaid
flowchart TB
    Start[Receive task] --> Validate[Validate input]
    Validate --> Invalid{Valid?}
    Invalid -->|No| Error[VALIDATION_ERROR]

    Invalid -->|Yes| ReadSpec[Extract relevant spec section]
    ReadSpec --> Method{Methodology?}

    Method -->|tdd| Simple{Simple task?}
    Simple -->|Yes| BatchTest[Write ALL tests first]
    BatchTest --> BatchImpl[Implement all]
    BatchImpl --> Refactor[Single refactor pass]

    Simple -->|No| RedPhase[RED: Write failing test]
    RedPhase --> Run1[Run test]
    Run1 --> Fail{Fails?}
    Fail -->|No| FixTest[Fix test to fail]
    FixTest --> Run1
    Fail -->|Yes| GreenPhase[GREEN: Minimal implementation]
    GreenPhase --> Run2[Run test]
    Run2 --> Pass{Passes?}
    Pass -->|No| FixImpl[Fix implementation]
    FixImpl --> Run2
    Pass -->|Yes| RefactorPhase[REFACTOR: Clean up]
    RefactorPhase --> Run3[Run tests]
    Run3 --> Still{Still pass?}
    Still -->|No| Undo[Undo refactor]
    Undo --> RefactorPhase
    Still -->|Yes| More{More AC?}
    More -->|Yes| RedPhase
    More -->|No| Commit

    Refactor --> Commit[git commit]
    Method -->|direct| Direct[Implement directly]
    Direct --> Commit

    Commit --> Output[IMPLEMENTATION_COMPLETE]
```

## Reviewer: Verification Flow

```mermaid
flowchart TB
    Start[Receive implementation] --> Validate[Validate input]
    Validate --> Read[Read implementation files]
    Read --> Spec[Read spec sections]

    Spec --> AC[For each acceptance criterion]
    AC --> Impl{Implemented?}
    Impl -->|No| Issue1[Issue: not implemented]

    Impl -->|Yes| Test{Has test?}
    Test -->|No| Issue2[Issue: missing test]

    Test -->|Yes| Quality{Test meaningful?}
    Quality -->|No| Issue3[Issue: weak test]

    Quality -->|Yes| Pattern{Matches spec<br/>patterns?}
    Pattern -->|No| Issue4[Issue: diverges from design]

    Pattern -->|Yes| Security{Security OK?}
    Security -->|No| Issue5[Issue: security concern]

    Security -->|Yes| Next{More AC?}
    Issue1 --> Severity[Assign severity]
    Issue2 --> Severity
    Issue3 --> Severity
    Issue4 --> Severity
    Issue5 --> Severity
    Severity --> Next

    Next -->|Yes| AC
    Next -->|No| Decide{Any issues?}

    Decide -->|No| Approve[APPROVED]
    Decide -->|Yes| Reject[REJECTED]

    Approve --> Done[Return result]
    Reject --> Done
```
