---
name: create
description: "Start orchestrated development workflow from idea to implementation. Use when building new features, adding functionality, or implementing complete development tasks from scratch."
argument-hint: "<prompt> [--auto] [--resume] [--retries N,M]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, MultiEdit, Skill
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

### Resume Mode (--resume flag)

When resuming an interrupted session:

1. Find the existing worktree:
   ```bash
   git worktree list | grep create/
   ```

2. Read the session state from `state.json` in the worktree root

3. Determine current phase from `state.json`:
   - If `phase` is "discovery" or discovery incomplete: invoke `homerun:discovery`
   - If `phase` is "planning" or planning incomplete: invoke `homerun:planning`
   - If `phase` is "execution" or execution incomplete: invoke `homerun:conductor`

4. Pass the stored configuration and any accumulated context to the skill

### New Session (no --resume)

When starting a new workflow:

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

3. **Invoke the discovery phase:**
   - Call `homerun:discovery` skill
   - Pass the user's prompt and configuration object
   - The discovery skill will gather requirements and context before proceeding

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
│  Planning   │  ← Create implementation plan
└─────────────┘
     │
     ▼
┌─────────────┐
│  Execution  │  ← Implement the plan in isolated worktree
└─────────────┘
     │
     ▼
   Complete
```

Each phase can be retried on failure according to the retry configuration. The workflow state is persisted to `state.json` in the worktree, allowing recovery from interruptions.
