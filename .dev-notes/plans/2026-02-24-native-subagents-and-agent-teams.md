# Plan: Native Subagents & Agent Teams Integration

**Date:** 2026-02-24
**Status:** Complete (Phases A-D implemented 2026-02-24)
**Scope:** Level 1 (native subagent wrappers) + Level 2 (Agent Teams conductor replacement)

## Context

Claude Code now offers native custom subagents and experimental Agent Teams. Homerun currently uses skills invoked via `Skill` tool within `Task()` wrappers, with a custom conductor for orchestration. This plan migrates to native platform features for enforced tool restrictions, persistent memory, declarative worktree isolation, and eventually replaces the conductor with Agent Teams.

## Level 1: Native Subagent Wrappers

### Goal
Add native Claude Code subagent definitions that wrap existing homerun skills. This is additive — skills remain the source of truth, subagents reference them.

### Files to Create

All in `agents/` directory (plugin subagents):

#### `agents/discovery-agent.md`
```yaml
name: discovery-agent
description: "Gather requirements through structured dialogue. Use when starting a new feature with /create."
tools: Read, Grep, Glob, Bash, Write, Edit
model: inherit
memory: project
skills:
  - discovery
```
- Body: Minimal — "You are the discovery agent. Follow the homerun:discovery skill."
- Memory: project-scoped — remembers user preferences, past feature patterns
- No worktree isolation — runs in main context during dialogue

#### `agents/spec-reviewer.md`
```yaml
name: spec-reviewer
description: "Review specification documents for consistency, completeness, and testability. Use after discovery, before planning."
tools: Read, Grep, Glob
model: sonnet
skills:
  - spec-review
```
- Body: "You are the spec review agent. Follow the homerun:spec-review skill."
- Read-only tools — reviewer should not modify specs
- No memory — stateless review

#### `agents/planner.md`
```yaml
name: planner
description: "Decompose specifications into test-bounded, commit-sized tasks. Use after spec review passes."
tools: Read, Grep, Glob, Bash, Write, Edit
model: opus
skills:
  - planning
```
- Body: "You are the planning agent. Follow the homerun:planning skill."
- Opus model — planning is high-leverage
- Write access needed to create tasks.json

#### `agents/implementer.md`
```yaml
name: implementer
description: "Implement a single task using TDD methodology. Use when conductor assigns a task."
tools: Read, Grep, Glob, Bash, Write, Edit
model: sonnet
isolation: worktree
skills:
  - implement
  - test-driven-development
```
- Body: "You are an implementer agent. Follow the homerun:implement skill."
- **isolation: worktree** — each implementer gets its own worktree automatically
- Preloads TDD skill so it's in context from start
- Model defaults to sonnet; conductor can override per-task

#### `agents/reviewer.md`
```yaml
name: reviewer
description: "Verify implementation against specification and approve or reject. Use after implementation completes."
tools: Read, Grep, Glob, Bash
model: sonnet
skills:
  - review
```
- Body: "You are the review agent. Follow the homerun:review skill."
- No Write/Edit — reviewer should not modify code
- Sonnet always for quality judgment

#### `agents/quality-checker.md`
```yaml
name: quality-checker
description: "Run 5-phase quality pipeline: lint, types, structure, tests, recheck. Use after review approval."
tools: Read, Grep, Glob, Bash, Write, Edit
model: sonnet
skills:
  - quality-check
```
- Body: "You are the quality check agent. Follow the homerun:quality-check skill."
- Write/Edit needed for auto-fixes

#### `agents/diagnostician.md`
```yaml
name: diagnostician
description: "Investigate bugs through 3-phase evidence pipeline: investigate, verify, solve. Use proactively when encountering bugs or test failures."
tools: Read, Grep, Glob, Bash
model: sonnet
memory: project
skills:
  - diagnose
  - systematic-debugging
```
- Body: "You are the diagnostic agent. Follow the homerun:diagnose skill."
- **memory: project** — remembers past bugs, common failure patterns
- Read-only + Bash for investigation (no code changes during diagnosis)

#### `agents/reverse-engineer.md`
```yaml
name: reverse-engineer
description: "Generate PRD, ADR, and TECHNICAL_DESIGN from an existing codebase. Use when documenting undocumented projects."
tools: Read, Grep, Glob, Bash, Write
model: opus
skills:
  - reverse-engineer
```
- Body: "You are the reverse engineering agent. Follow the homerun:reverse-engineer skill."
- Opus for deep codebase understanding
- Write access for generating spec documents

#### `agents/test-skeleton-generator.md`
```yaml
name: test-skeleton-generator
description: "Generate ROI-prioritized test skeletons from specs. Use optionally between planning and implementation."
tools: Read, Grep, Glob, Bash, Write
model: sonnet
skills:
  - generate-test-skeletons
```

#### `agents/walkthrough-generator.md`
```yaml
name: walkthrough-generator
description: "Generate Playwright or curl walkthrough scripts from user journeys. Use after feature implementation for demos."
tools: Read, Grep, Glob, Bash, Write
model: sonnet
skills:
  - walkthrough
```

### Changes to Existing Files

#### `commands/create.md`
- Update workflow to use `Task(discovery-agent)` instead of `Task() + homerun:discovery`
- Each phase transition spawns the native subagent by name
- Remove manual model/skill wiring from the command

#### `commands/diagnose.md`
- Update to use `Task(diagnostician)`
- Claude may also auto-delegate based on description

#### `commands/review.md`
- Update to use `Task(spec-reviewer)` and `Task(quality-checker)`

#### `commands/reverse-engineer.md`
- Update to use `Task(reverse-engineer)`

#### `references/model-routing.json`
- Add note that model routing is now declared in agent frontmatter
- Keep as reference/documentation

### Hooks to Add

#### `WorktreeCreate` hook
```json
{
  "hooks": {
    "WorktreeCreate": [{
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-worktree-setup.sh"
      }]
    }]
  }
}
```
Script: Copy state.json template, install dependencies, verify clean baseline.

#### `SubagentStop` hook (for implementer)
```json
{
  "hooks": {
    "SubagentStop": [{
      "matcher": "implementer",
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-post-implement.sh"
      }]
    }]
  }
}
```
Script: Update task status in tasks.json after implementation completes.

### Migration Notes
- Skills remain unchanged — they ARE the system prompts
- Subagent files reference skills via `skills:` field
- Commands updated to spawn subagents by name
- Signal contracts unchanged — agents still emit JSON signals
- state.json / tasks.json format unchanged

---

## Level 2: Agent Teams Conductor Replacement

### Goal
Replace the custom conductor skill with Claude Code's Agent Teams feature. The `/create` command's execution phase becomes a team lead that coordinates implementer and reviewer teammates.

### Prerequisites
- Level 1 complete (native subagents working)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` enabled
- Agent Teams stable enough for production use

### Architecture Change

**Current (conductor skill):**
```
/create → discovery → spec-review → planning → conductor skill
  conductor reads state.json
  conductor finds ready tasks (jq queries)
  conductor spawns Task(implementer) in background
  conductor polls for completion (TaskOutput)
  conductor spawns Task(reviewer) sequentially
  conductor handles retry/escalation
  conductor refreshes every 5 tasks
```

**Proposed (Agent Teams):**
```
/create → discovery → spec-review → planning → team lead
  lead creates Agent Team
  lead creates native Tasks (TaskCreate) with DAG from tasks.json
  lead spawns implementer teammates (self-claim from task list)
  lead spawns reviewer teammate (reviews completions)
  lead spawns quality-checker teammate (runs at end)
  teammates communicate directly
  teammates self-claim next task when done
  lead synthesizes results and runs completion
```

### Implementation Plan

#### Step 1: Convert tasks.json to Native Tasks
After planning produces `docs/tasks.json`, convert to native Claude Code tasks:

```javascript
// For each task in tasks.json:
TaskCreate({
  title: task.title,
  description: task.objective,
  status: "pending",
  // Convert depends_on to addBlockedBy
  addBlockedBy: task.depends_on.map(id => nativeTaskIdMap[id])
});
```

This gives us:
- DAG enforcement by the platform
- Cross-session visibility
- Automatic unblocking when dependencies complete

#### Step 2: Create Team Lead Skill
New skill: `skills/team-lead/SKILL.md`

The team lead:
1. Reads tasks.json and creates native Tasks
2. Spawns implementer teammates (3-5 based on task count)
3. Spawns 1 reviewer teammate
4. Monitors progress via shared task list
5. Handles escalations
6. Runs quality-checker when all tasks complete
7. Transitions to completion phase

#### Step 3: Create Team Lead Agent
```yaml
name: team-lead
description: "Orchestrate parallel implementation using Agent Teams. Use during /create execution phase."
tools: Task(implementer, reviewer, quality-checker), Read, Grep, Glob, Bash, Write, Edit
model: sonnet
skills:
  - team-lead
```

Key: `tools: Task(implementer, reviewer, quality-checker)` — restricts which subagents the lead can spawn.

#### Step 4: Add Quality Gate Hooks

```json
{
  "hooks": {
    "TaskCompleted": [{
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-task-completed.sh"
      }]
    }],
    "TeammateIdle": [{
      "matcher": "implementer",
      "hooks": [{
        "type": "command",
        "command": "./scripts/homerun-teammate-idle.sh"
      }]
    }]
  }
}
```

- `TaskCompleted`: Validate implementation before marking complete (exit 2 to block)
- `TeammateIdle`: Assign next task or shut down teammate

#### Step 5: Update /create Command
Replace conductor invocation with team lead:

```javascript
// OLD
Task({
  model: "haiku",
  prompt: "Use homerun:conductor skill..."
});

// NEW
Task({
  subagent_type: "team-lead",
  prompt: "Orchestrate implementation for feature..."
});
```

#### Step 6: Deprecate Conductor Skill
- Mark `skills/conductor/SKILL.md` as deprecated
- Keep for reference / fallback if Agent Teams disabled
- Add note in SKILL.md: "Deprecated in v3.0.0 — use Agent Teams via team-lead agent"

### Teammate Configuration

| Teammate | Count | Model | Isolation | Claims Tasks |
|----------|-------|-------|-----------|-------------|
| implementer | 3-5 (based on task count) | haiku/sonnet (per task type) | worktree | Yes — self-claim from shared list |
| reviewer | 1 | sonnet | none | No — lead assigns after implementation |
| quality-checker | 1 | sonnet | none | No — lead assigns at end |

### Communication Flow
```
Lead creates tasks with DAG
  │
  ├─► Implementer A claims task 001, works in worktree
  ├─► Implementer B claims task 002, works in worktree
  ├─► Implementer C claims task 003, works in worktree
  │
  │   Implementer A completes → messages Reviewer
  │   Reviewer reviews → APPROVED → Lead sees task complete
  │   Reviewer reviews → REJECTED → messages Implementer A with feedback
  │
  │   Task 004 unblocks (depended on 001) → Implementer A self-claims
  │
  └─► All tasks complete → Lead spawns Quality Checker
      Quality Checker runs 5-phase pipeline
      Lead transitions to completion phase
```

### Fallback Strategy
If Agent Teams is disabled or unavailable:
- Detect `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var
- If not set: fall back to conductor skill (current behavior)
- If set: use Agent Teams
- Log which mode is active in state.json

### Risk Mitigation
- Agent Teams is experimental — may have bugs
- Keep conductor as fallback
- Start with 2-3 teammates, scale up as confidence grows
- Monitor token usage (Agent Teams uses more tokens)

---

## Implementation Order

### Phase A: Level 1 (Native Subagents)
1. Create `agents/` directory with all 10 subagent definitions
2. Update commands to reference subagents by name
3. Add WorktreeCreate/SubagentStop hooks
4. Test: run `/create` end-to-end with native subagents
5. Commit as v2.1.0

### Phase B: Level 2 Prep
1. Create `skills/team-lead/SKILL.md`
2. Create `agents/team-lead.md`
3. Add TaskCompleted/TeammateIdle hooks
4. Add fallback detection logic
5. Test: run Agent Teams manually first

### Phase C: Level 2 Integration
1. Update `/create` to use team-lead in execution phase
2. Convert tasks.json → native Tasks bridge
3. Deprecate conductor skill
4. Test: full `/create` with Agent Teams
5. Commit as v3.0.0

### Phase D: Polish
1. Update README with new architecture diagrams
2. Add evals for Agent Teams mode
3. Document fallback behavior
4. Update CHANGELOG

---

## Token Cost Comparison

| Mode | Discovery | Spec Review | Planning | Execution (8 tasks) | Total |
|------|-----------|-------------|----------|---------------------|-------|
| **Current (skills + conductor)** | ~20K | ~15K | ~10K | ~160K (8 × 20K) | ~205K |
| **Level 1 (native subagents)** | ~20K | ~15K | ~10K | ~160K (same) | ~205K |
| **Level 2 (Agent Teams, 3 teammates)** | ~20K | ~15K | ~10K | ~120K (parallel, less idle) | ~165K |

Agent Teams may reduce total tokens because teammates self-claim and don't need conductor polling overhead. But each teammate has its own context, so monitoring costs increase. Net effect: roughly similar, but faster wall-clock time due to true parallelism.
