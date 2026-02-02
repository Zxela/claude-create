# Architecture Diagrams

## System Overview

```mermaid
graph TB
    subgraph User["User Layer"]
        CLI["/create command"]
    end

    subgraph Agents["Agent Layer"]
        D[Discovery Agent<br/>model: opus]
        P[Planning Agent<br/>model: opus]
        C[Conductor Agent<br/>model: haiku]
        I[Implementer Agents<br/>model: varies]
        R[Reviewer Agent<br/>model: sonnet]
    end

    subgraph Skills["Skill Layer"]
        SD[homerun:discovery]
        SP[homerun:planning]
        SC[homerun:conductor]
        SI[homerun:implement]
        SR[homerun:review]
        SF[homerun:finishing-a-development-branch]
    end

    subgraph Storage["Storage Layer"]
        subgraph Centralized["~/.claude/homerun/"]
            PRD[PRD.md]
            ADR[ADR.md]
            TD[TECHNICAL_DESIGN.md]
            WF[WIREFRAMES.md]
        end
        subgraph Worktree["../project-create-feature/"]
            State[state.json]
            Tasks[tasks.json]
            Code[Source Code]
            Tests[Test Files]
        end
    end

    CLI --> D
    D --> SD
    D --> P
    P --> SP
    P --> C
    C --> SC
    C --> I
    C --> R
    I --> SI
    R --> SR

    SD --> PRD
    SD --> ADR
    SD --> TD
    SD --> WF
    SD --> State

    SP --> State
    SP --> Tasks

    SC --> State
    SC --> Tasks

    SI --> Code
    SI --> Tests

    SR --> Code
    SR --> Tests
```

## Component Relationships

```mermaid
graph LR
    subgraph Commands
        Create[/create]
    end

    subgraph Core Skills
        Discovery
        Planning
        Conductor
        Implement
        Review
    end

    subgraph Reference Skills
        TDD[test-driven-development]
        Worktree[using-git-worktrees]
        Debug[systematic-debugging]
        Finish[finishing-a-development-branch]
    end

    subgraph Reference Docs
        CE[context-engineering.md]
        SM[state-machine.md]
        RP[retry-patterns.md]
        MR[model-routing.json]
        TE[token-estimation.md]
    end

    Create --> Discovery
    Discovery --> Planning
    Planning --> Conductor
    Conductor --> Implement
    Conductor --> Review
    Conductor --> Finish

    Implement -.-> TDD
    Discovery -.-> Worktree
    Implement -.-> Debug

    Conductor -.-> CE
    Conductor -.-> SM
    Conductor -.-> RP
    Planning -.-> MR
    Conductor -.-> TE
```

## Agent Spawning Architecture

```mermaid
graph TB
    subgraph Main["Main Session (User's Model)"]
        Entry["/create"]
    end

    subgraph Fresh1["Fresh Context #1"]
        D[Discovery Agent<br/>~10-20K tokens<br/>model: opus]
    end

    subgraph Fresh2["Fresh Context #2"]
        P[Planning Agent<br/>~10K tokens<br/>model: opus]
    end

    subgraph Fresh3["Fresh Context #3 (Refreshable)"]
        C[Conductor Agent<br/>~5K tokens<br/>model: haiku]
    end

    subgraph Parallel["Parallel Fresh Contexts"]
        I1[Implementer 1<br/>~15K tokens]
        I2[Implementer 2<br/>~15K tokens]
        I3[Implementer 3<br/>~15K tokens]
    end

    subgraph Sequential["Sequential Fresh Context"]
        R[Reviewer<br/>~10K tokens<br/>model: sonnet]
    end

    Entry -->|"Task(opus)"| D
    D -->|"Task(opus)"| P
    P -->|"Task(haiku)"| C
    C -->|"Task(varies, background)"| I1
    C -->|"Task(varies, background)"| I2
    C -->|"Task(varies, background)"| I3
    C -->|"Task(sonnet)"| R

    style Main fill:#e1f5fe
    style Fresh1 fill:#fff3e0
    style Fresh2 fill:#fff3e0
    style Fresh3 fill:#e8f5e9
    style Parallel fill:#fce4ec
    style Sequential fill:#f3e5f5
```

## File System Architecture

```mermaid
graph TB
    subgraph Home["~/.claude/"]
        subgraph Homerun["homerun/"]
            subgraph Project1["<project-hash-1>/"]
                subgraph Feature1["<feature-slug-uuid>/"]
                    PRD1[PRD.md]
                    ADR1[ADR.md]
                    TD1[TECHNICAL_DESIGN.md]
                    WF1[WIREFRAMES.md]
                end
                subgraph Feature2["<feature-slug-uuid>/"]
                    PRD2[PRD.md]
                    ADR2[ADR.md]
                    TD2[TECHNICAL_DESIGN.md]
                end
            end
            subgraph Project2["<project-hash-2>/"]
                subgraph Feature3["<feature-slug-uuid>/"]
                    PRD3[PRD.md]
                    ADR3[ADR.md]
                end
            end
        end
    end

    subgraph Worktrees["Git Worktrees (Adjacent to Project)"]
        subgraph WT1["../project-create-feature-uuid/"]
            State1[state.json]
            Tasks1[docs/tasks.json]
            Src1[src/]
            Test1[tests/]
        end
    end

    subgraph MainRepo["Main Project Repository"]
        Main[Original codebase]
    end

    MainRepo -.->|"git worktree add"| WT1
    Feature1 -.->|"spec_paths"| State1
```

## Model Routing Architecture

```mermaid
graph TB
    subgraph TaskTypes["Task Types"]
        Simple[Simple Tasks<br/>add_field, add_method,<br/>add_validation, rename_refactor,<br/>add_test, add_config]
        Medium[Medium Tasks<br/>create_model, create_service,<br/>add_endpoint_complex,<br/>create_middleware, bug_fix]
        Complex[Complex Tasks<br/>architectural]
    end

    subgraph Models["Model Selection"]
        Haiku[Haiku<br/>Fast, Cost-effective<br/>5 concurrent max]
        Sonnet[Sonnet<br/>Balanced<br/>3 concurrent max]
        Opus[Opus<br/>Most Capable<br/>1 concurrent max]
    end

    subgraph Roles["Agent Roles"]
        Cond[Conductor]
        Impl[Implementer]
        Rev[Reviewer]
        Plan[Planner]
    end

    Simple --> Haiku
    Medium --> Sonnet
    Complex --> Opus

    Cond --> Haiku
    Plan --> Opus
    Rev --> Sonnet

    Impl --> Simple
    Impl --> Medium
    Impl --> Complex

    subgraph Escalation["Escalation Path"]
        E1[Haiku fails 3x] --> E2[Retry with Sonnet]
        E2 --> E3[Fails again] --> E4[Escalate to User]
    end
```

## State Management Architecture

```mermaid
graph LR
    subgraph StateJSON["state.json"]
        Session[session_id]
        Branch[branch]
        WT[worktree]
        Phase[phase]
        DocDir[homerun_docs_dir]
        SpecPaths[spec_paths]
        TasksFile[tasks_file]
        Trace[traceability]
        Config[config]
        ParState[parallel_state]
        TokenTrack[token_tracking]
    end

    subgraph TasksJSON["tasks.json"]
        TaskList[tasks array]
        subgraph Task["Each Task"]
            TID[id]
            Title[title]
            Type[task_type]
            AC[acceptance_criteria]
            Deps[depends_on]
            Status[status]
            Model[model]
            TracesTo[traces_to]
        end
    end

    subgraph Phases["Phase Transitions"]
        Discovery --> Planning
        Planning --> Implementing
        Implementing --> Completing
        Completing --> Done
    end

    Phase --> Phases
    TasksFile --> TasksJSON
    ParState --> TaskList
```

## Concurrency Model

```mermaid
graph TB
    subgraph Limits["Concurrency Limits"]
        Global[Global: max_parallel_tasks = 3]
        PerModel[Per-Model Limits]
        HaikuL[Haiku: 5 max]
        SonnetL[Sonnet: 3 max]
        OpusL[Opus: 1 max]
    end

    subgraph Slots["Slot Calculation"]
        Available[Available Slots = min<br/>global_limit - running,<br/>model_limit - running_by_model]
    end

    subgraph Queue["Task Queues"]
        Ready[Ready Queue<br/>Dependencies resolved]
        Retry[Retry Queue<br/>Previously failed]
        Running[Running Set<br/>In progress]
        Review[Review Queue<br/>Awaiting review]
    end

    Global --> Available
    PerModel --> Available
    HaikuL --> PerModel
    SonnetL --> PerModel
    OpusL --> PerModel

    Available --> Ready
    Ready -->|Spawn| Running
    Running -->|Complete| Review
    Review -->|Rejected| Retry
    Retry -->|Available slot| Ready
```
