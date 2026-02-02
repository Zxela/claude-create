# Homerun System Diagrams

Visual documentation of the homerun workflow system.

## Diagrams

| Diagram | Purpose | Key Visualizations |
|---------|---------|-------------------|
| [sequence-diagram.md](sequence-diagram.md) | Message flow between agents | Full workflow, retry flow, parallel execution |
| [phase-flowchart.md](phase-flowchart.md) | Decision logic within each phase | Discovery dialogue, planning decomposition, conductor loop, TDD flow, reviewer verification |
| [architecture.md](architecture.md) | Component and service relationships | System overview, agent spawning, file system, model routing, concurrency |
| [context-flow.md](context-flow.md) | Token budgets and agent spawning | Per-phase budgets, observation masking, spec extraction, file read strategy |
| [state-machine.md](state-machine.md) | Phase and task state transitions | Workflow phases, task status, retry logic, circuit breaker, conductor loop, dialogue states |

## Quick Reference

### Agent Model Assignment
```
Discovery  → opus (user dialogue, requirements)
Planning   → opus (high-leverage decomposition)
Conductor  → haiku (mechanical scheduling)
Implementer → haiku/sonnet (based on task_type)
Reviewer   → sonnet (quality judgment)
```

### Context Budgets
```
Discovery:   10-20K tokens (grows during dialogue)
Planning:    ~10K tokens (specs + state)
Conductor:   ~5K tokens (refreshes every 5 tasks)
Implementer: <20K tokens target (with masking)
Reviewer:    ~10K tokens
```

### Key State Transitions
```
Phases: discovery → planning → implementing → completing → done
Tasks:  pending → in_progress → pending_review → completed/failed
Retry:  attempt_1 → attempt_2 (same agent) → attempt_3 (fresh) → escalate
```

## Rendering

These diagrams use [Mermaid](https://mermaid.js.org/) syntax.

**View options:**
- GitHub renders Mermaid automatically in markdown
- VS Code with Mermaid extension
- [Mermaid Live Editor](https://mermaid.live/)
- Any Mermaid-compatible markdown viewer
