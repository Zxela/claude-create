---
name: create
description: "Start orchestrated development workflow from idea to implementation. Use when building new features, adding functionality, or implementing complete development tasks from scratch."
argument-hint: "<prompt> [--auto] [--resume] [--retries N,M]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, MultiEdit, Skill, Task
---

# /create Command

Start an orchestrated development workflow that takes you from idea to implementation through structured phases: discovery, planning, and execution.

## Usage

```
/create "description of what to build" [options]
```

## Arguments

- `prompt`: Description of what to build (required). Can be provided as:
  - First positional argument: `/create build a REST API for user management`
  - Quoted string: `/create "build a REST API with authentication"`

## Options

- `--auto`: Enable fully automated mode. Skips confirmation prompts between phases and proceeds automatically through discovery, planning, and execution.
- `--resume`: Resume an interrupted session. Finds the existing worktree and continues from where you left off.
- `--retries N,M`: Configure retry limits for phase failures.
  - `N`: Maximum retries using the same agent (default: 2)
  - `M`: Maximum retries spawning a fresh agent (default: 1)
  - Example: `--retries 3,2` allows 3 same-agent retries, then 2 fresh-agent retries

## Workflow

### Architecture: Flat State Machine

**Every phase runs at depth 1** — spawned directly by this command, never chained. This guarantees all agents have full tool access (including Task for spawning subagents). After each phase returns, read `state.json` and spawn the next phase.

```
/create (main session — loop controller)
  ├─ spawn discovery-agent      (depth 1) → returns
  ├─ spawn spec-reviewer        (depth 1) → returns
  ├─ spawn planner              (depth 1) → returns
  ├─ invoke team-lead skill     (depth 0, dispatches implementers at depth 1)
  └─ invoke finishing skill     (depth 0) → done
```

**Agents do NOT chain to the next phase.** Each agent updates `state.json` with the next phase and returns. This command reads the phase and spawns the next agent. The team-lead runs inline as a skill (not a spawned agent) for reliable orchestration.

### Resume Mode (--resume flag)

When resuming an interrupted session:

1. Find the existing worktree:
   ```bash
   git worktree list | grep create/
   ```

2. Read `state.json` from the worktree root

3. Jump into the **Phase Loop** below at the current phase

### New Session (no --resume)

1. **Announce the workflow:**
   ```
   Starting /create workflow for: [brief summary of the prompt]
   ```

2. **Parse and store configuration:**
   ```json
   {
     "auto_mode": false,
     "retries": {
       "same_agent": 2,
       "fresh_agent": 1
     }
   }
   ```
   - Set `auto_mode: true` if `--auto` flag is present
   - Parse `--retries N,M` to override default retry values

3. **Start the Phase Loop** beginning at "discovery"

### Phase Loop

Read the current phase from `state.json` (or start at "discovery" for new sessions). Spawn the appropriate agent, wait for it to return, then read `state.json` again and continue to the next phase. Repeat until complete.

```bash
PHASE=$(jq -r '.phase // "discovery"' "$WORKTREE_PATH/state.json" 2>/dev/null || echo "discovery")
```

#### Phase: discovery

```javascript
Task({
  description: "Gather requirements",
  subagent_type: "discovery-agent",
  prompt: `Start discovery for: ${userPrompt}

  Configuration: ${JSON.stringify(config)}
  Project root: ${projectRoot}`
});
```

After discovery returns, re-read `state.json`. Discovery sets `phase: "spec_review"`.

#### Phase: spec_review

```javascript
Task({
  description: "Review specification documents",
  subagent_type: "spec-reviewer",
  prompt: `Review specs for consistency, completeness, and testability.

  Worktree: ${worktree}
  Spec paths: ${JSON.stringify(state.spec_paths)}
  Auto mode: ${state.config.auto_mode}

  Emit SPEC_REVIEW_COMPLETE signal with verdict.`
});
```

**After spec-review returns**, check the verdict:
- If `verdict: "approved"`: update `state.json` phase to `"planning"` and continue
- If `verdict: "needs_revision"`: report issues to user and **stop** (user fixes specs, then runs `/create --resume`)

**Note:** The spec-reviewer is read-only (no Write tool), so this command handles the phase transition.

#### Phase: planning

```javascript
Task({
  description: "Plan implementation tasks",
  subagent_type: "planner",
  prompt: `Decompose specs into implementation tasks.

  Worktree: ${worktree}
  State file: ${worktree}/state.json

  Read state.json and spec documents, then create tasks.json with DAG.`
});
```

After planning returns, re-read `state.json`. Planning sets `phase: "implementing"`.

#### Phase: implementing

```javascript
Skill({ skill: "homerun:team-lead" });
```

The team-lead skill runs inline — it reads tasks.json, dispatches implementers via Task(), tracks progress, and runs the quality gate. After completing, it sets `state.json` phase to `"completing"`.

#### Phase: completing

```javascript
Skill({ skill: "homerun:finishing-a-development-branch" });
```

Invoke the finishing skill in the current context to present merge/PR/continue options.

## Examples

### Basic usage
```
/create "build a CLI tool that converts markdown to HTML"
```

### Automated mode
```
/create "add user authentication to the API" --auto
```

### Custom retry configuration
```
/create "refactor the database layer" --retries 3,2
```

### Resume interrupted session
```
/create --resume
```

## Phase Flow

```
/create command
     │
     ▼
┌─────────────┐
│  Discovery  │  ← Gather requirements, explore codebase
└─────────────┘
     │
     ▼
┌─────────────┐
│ Spec Review │  ← Validate specs for consistency, completeness, testability
└─────────────┘
     │
     ▼
┌─────────────┐
│  Planning   │  ← Create implementation plan
└─────────────┘
     │
     ▼
┌──────────────────┐
│ Test Skeletons   │  ← (optional) Generate ROI-prioritized test scaffolding
└──────────────────┘
     │
     ▼
┌─────────────┐
│  Execution  │  ← Team lead orchestrates parallel implementation (Agent Teams)
└─────────────┘
     │
     ▼
┌───────────────┐
│ Quality Check │  ← Lint, types, structure, tests, recheck
└───────────────┘
     │
     ▼
┌─────────────┐
│  Complete   │  ← Merge, PR, keep, or discard
└─────────────┘
```

Each phase can be retried on failure according to the retry configuration. The workflow state is persisted to `state.json` in the worktree, allowing recovery from interruptions.

## Related Commands

These commands allow jumping directly into specific phases:

- `/plan` — Skip to planning with existing specs
- `/build` — Skip to execution with existing tasks
- `/review` — Run spec review and/or quality checks
- `/diagnose` — Investigate a bug with the 3-phase evidence pipeline
- `/reverse-engineer` — Generate specs from an existing codebase
