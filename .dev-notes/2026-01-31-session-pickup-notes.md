# Session Pickup Notes - 2026-01-31

**Previous Session ID:** `6cfd3873-0761-4382-8c4b-b87916c71cf2`
**Directory:** `/home/zxela/claude-plugins/plugins/homerun` (was `create-workflow`)

---

## Context

Building the **homerun** plugin (renamed from `create-workflow`) - an orchestrated development workflow from idea to implementation with isolated agent contexts.

### Architecture Overview
```
/create <prompt>
    │
    ▼
PHASE 1: DISCOVERY → refine requirements, output PRD/ADR/Technical Design
    │
    ▼
PHASE 2: PLANNING → break specs into test-bounded tasks
    │
    ▼
PHASE 3: IMPLEMENTATION (conductor loop)
    │   ├─ spawn implementer agent
    │   ├─ spawn reviewer agent
    │   └─ retry/advance logic
    │
    ▼
PHASE 4: COMPLETION → merge, PR, or continue
```

### Current Skills Structure
```
plugins/homerun/
├── skills/
│   ├── conductor/     - orchestrates implementation loop
│   ├── discovery/     - requirements refinement
│   ├── planning/      - task breakdown
│   ├── implement/     - implements ONE task
│   ├── review/        - verifies implementation
│   └── superpowers/   - cloned methodology skills (TDD, debugging, etc.)
├── commands/
│   └── create.md      - /create command
└── templates/         - PRD, ADR, TECHNICAL_DESIGN, TASK, etc.
```

---

## Pending Tasks (from previous session)

### Task #4: Flatten superpowers directory structure
Move skills from `skills/superpowers/X/` to `skills/X/` (e.g., `skills/tdd/`)

### Task #5: Remove REQUIRED SUB-SKILL from implement
The implement skill currently says "REQUIRED SUB-SKILL: use homerun:tdd" - this couples things too tightly

### Task #6: Update conductor for explicit methodology
Conductor should explicitly tell implementer WHICH methodology to use (e.g., pass `"methodology": "tdd"` in JSON)

### Task #7: Update discovery to handle worktrees directly
Discovery should set up git worktrees itself, not depend on superpowers:using-git-worktrees

### Task #8: Update CLAUDE.md with new architecture
Document the flattened structure and explicit methodology passing

---

## Open Question: Skills vs Agents

**User's mental model:**
- **Agent** = the job/role (e.g., "implementer", "reviewer", "conductor")
- **Skill** = the ability/capability to complete tasks (e.g., "TDD", "code review")

**Question:** Does Anthropic's documentation support this distinction? We were researching this when the session ended.

**Key insight from Anthropic docs (partially fetched):**
- Skills are filesystem-based, loaded on-demand
- Three levels: metadata (always), instructions (when triggered), resources (when needed)
- Skills provide "progressive disclosure" - load info in stages

**TODO:** Finish reviewing Anthropic's agent skills documentation to clarify the skill/agent distinction and how to model it in homerun.

---

## Key Concern

> "I worry a bit that we've lost control by using the superpowers (implement triggers tdd) - can we decompose the superpowers into homerun skills and update the callers?"

The solution being explored: Make methodology explicit in conductor → implementer communication rather than having implement automatically trigger tdd.

---

## Git State

- Branch: `master`
- Modified: `plugins/homerun` submodule
- Untracked: `.gitignore`
- Recent commits show rename from `create-workflow` to `homerun`

---

## Next Steps

1. Clarify skills vs agents conceptual model
2. Execute Tasks #4-8 to flatten structure and make methodology explicit
3. Update CLAUDE.md with new architecture
