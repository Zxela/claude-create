# Context Engineering Patterns in Homerun

> **Updated (v3.0.0):** Phases now use named native subagents (e.g., `Task(discovery-agent)` instead of `Task(general-purpose) + skill`).
> The execution phase uses the `team-lead` agent with Agent Teams for native task DAG management.

## Core Principles Applied

### 1. Context Isolation via Agent Spawning

Each phase runs in a **fresh agent context** at **depth 1** (flat state machine). The `/create` command spawns each phase directly — agents do NOT chain to the next phase:

```
/create loop (main session)
   │
   ├─> Task(discovery-agent)   → Discovery     [dialogue with user]       → returns
   ├─> Task(spec-reviewer)     → Spec Review   [validation gate]          → returns
   ├─> Task(planner)           → Planning      [decomposition into tasks] → returns
   └─> Task(team-lead)         → Team Lead     [orchestration]            → returns
                                     │
                                     ├─> Task(implementer) × 1-5  (depth 2)
                                     ├─> Task(reviewer) × 1       (depth 2)
                                     └─> Task(quality-checker)     (depth 2)
```

**Why this works:**
- Each agent starts with ~5-10K tokens (just state.json + task)
- Previous phase deliberation doesn't bloat next phase
- Model selection optimizes cost/quality per role
- No "telephone game" — agents read state.json directly
- **Flat spawning guarantees Task tool availability** — team-lead at depth 1 can always spawn conductor/implementers via Task at depth 2

### 2. Filesystem-as-Memory Pattern

Instead of passing data through messages, agents communicate via filesystem:

| File | Purpose | Updated By |
|------|---------|------------|
| `state.json` | Workflow state, phase, progress | All phases |
| `docs/tasks.json` | Task status, attempts, feedback | Team lead / Conductor |
| `~/.claude/homerun/<hash>/<feature>/` | Spec documents | Discovery |

**Benefits:**
- Sub-agents read files directly (no summarization loss)
- Output offloading - large tool results go to files
- Plan persistence - tasks.json survives agent restarts

### 3. Observation Masking

Tool outputs consume ~84% of context in typical agent workflows. Homerun applies masking:

| What | Mask Strategy |
|------|---------------|
| Git diffs | Write to temp file, return summary |
| Test output | Extract pass/fail + first failure, discard rest |
| Build logs | Return exit code + last 20 lines |
| Large file reads | Read in chunks, summarize findings |

**Implementation in conductor:**
```javascript
function maskObservation(toolOutput, type) {
  if (toolOutput.length < 2000) return toolOutput; // Keep small outputs

  // Write full output to scratch file
  const scratchPath = writeScratchFile(toolOutput, type);

  // Return compact reference
  return {
    summary: extractKeySummary(toolOutput, type),
    full_output: scratchPath,
    token_savings: estimateTokens(toolOutput) - 100
  };
}
```

### 4. Progressive Disclosure

Skills load minimal context, with references to detailed docs:

**Before (bloated):**
```markdown
# Conductor Skill

## Full Algorithm (500 lines of pseudocode inline)
...
```

**After (progressive):**
```markdown
# Conductor Skill

## Reference Documents
- `references/state-machine.md` - Full algorithms
- `references/retry-patterns.md` - Retry logic details

## Summary
Key steps: poll → review → handle failures → spawn
```

### 5. Compaction and Auto-Compaction

**Team-lead and conductor agents should proactively compact** to prevent context degradation during long monitoring loops.

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Monitoring iterations | every 10 | `/compact Focus on task status, DAG progress, unresolved blockers` |
| Auto-compaction | 50% capacity | Set `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50` for orchestrator agents |
| Stalled iterations | 3 without progress | Escalate to user |
| High-severity failure | any | Block and escalate |

**Native auto-compaction (recommended over manual refresh):**
Claude Code supports `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` — set to `50` for team-lead/conductor agents to trigger compaction at 50% capacity instead of the default 95%. This is cheaper than spawning a fresh conductor and preserves more context.

**Tracked in state.json:**
```json
{
  "token_tracking": {
    "config": {
      "autocompact_pct": 50,
      "compact_focus": "task status, DAG progress, unresolved blockers"
    },
    "refresh_log": [
      {"reason": "auto_compaction", "at": "...", "pre_tokens": 80000}
    ]
  }
}
```

### 6. Forward Message Bypass

When work is complete, skip the orchestrator chain:

**Problem:** Conductor summarizing reviewer responses loses fidelity.

**Solution:** Final signals go directly to user:

```javascript
// In conductor, when all tasks complete
if (allTasksComplete(state)) {
  // Don't summarize - output directly for user
  return {
    signal: "WORKFLOW_COMPLETE",
    summary: "All tasks implemented and reviewed",
    next_action: "Use homerun:finishing-a-development-branch"
  };
}
```

## Model Selection Guidelines

Based on research: **model choice drives 80% of performance variance**.

| Role | Model | Rationale |
|------|-------|-----------|
| Discovery | inherit | User controls quality of requirements |
| Spec Review | sonnet | Quality judgment on spec consistency |
| Planning | opus | High-leverage - bad decomposition cascades |
| Team Lead | sonnet | Coordination decisions, teammate scaling |
| Conductor (fallback) | haiku | Mechanical scheduling, no reasoning needed |
| Implementer (simple) | haiku | Pattern-following tasks |
| Implementer (complex) | sonnet | Design decisions, security implications |
| Reviewer | sonnet | Quality judgment requires reasoning |

**Escalation path:**
```
haiku task fails 3x → retry with sonnet
sonnet task fails 3x → escalate to user
```

### 7. JIT Context Loading (v4.0)

Instead of embedding full spec excerpts in tasks at planning time, provide lightweight references:

```
BEFORE (embedded — stale, bloated):
  task.embedded_context.relevant_interfaces = "interface User { ... }" // 500 tokens

AFTER (JIT references — current, lightweight):
  task.context_refs.interface_locations = ["src/models/user.ts:User interface"] // 20 tokens
```

**Benefits:** Implementers read current code (not stale planner snapshots), tasks.json is smaller, and the team-lead monitoring loop is cheaper.

### 8. Effort-Proportional Routing (v4.0)

Scale the pipeline complexity to the task size:

| Scale | Pipeline |
|-------|----------|
| Small (1-2 files) | Single implementer, no DAG, no reviewer agent |
| Medium (3-5 files) | Standard pipeline, max 2 concurrent |
| Large (6+ files) | Full pipeline with independence gate |

### 9. Deterministic Gates (v4.0)

Use deterministic CLI checks (exit codes) instead of LLM judgment for:
- Lint/format (Phase 1) → run linter, check exit code
- Type checking (Phase 2) → run tsc, check exit code
- Tests (Phase 4) → run test suite, check exit code

Reserve LLM for structural review (Phase 3) where judgment is genuinely needed.

### 10. Fresh-Context-First Retries (v4.0)

Invert naive retry order. First retry = fresh agent with structured failure summary:

```
BEFORE: same_agent(2x) → fresh_agent(1x) → escalate
AFTER:  fresh_agent(1x) → same_agent(1x) → escalate
```

Accumulated context from failed attempts degrades performance. A clean context with a concise failure summary succeeds more often.

## Anti-Patterns to Avoid

### 1. Telephone Game
❌ Agent A summarizes to B, B summarizes to C, C summarizes to user
✅ Agents write to files, others read directly

### 2. Context Hoarding
❌ Load all specs, all tasks, full git history at start
✅ Load state.json, read specific files on demand

### 3. Uniform Model Distribution
❌ Use opus everywhere "for quality"
✅ Match model capability to task complexity

### 4. Ignoring Token Budgets
❌ Keep growing context until errors
✅ Auto-compact at 50% for orchestrators, monitor usage

### 5. Embedded Context Snapshots (NEW)
❌ Embed full interface definitions and code patterns in tasks.json at planning time
✅ Provide JIT references (file paths, section names, grep patterns) — implementers load current code

### 6. LLM Judgment for Deterministic Checks (NEW)
❌ Use Sonnet to decide if lint/type/test checks pass
✅ Run CLI tools, check exit codes — zero-cost, deterministic, reproducible

### 7. Retrying with Accumulated Context (NEW)
❌ Retry failed implementation with all previous attempt context accumulated
✅ Fresh agent with structured failure summary — higher success rate, lower token cost

## Measuring Effectiveness

Track these metrics:

| Metric | Target | Measurement |
|--------|--------|-------------|
| Phase context size | < 50K tokens | Token estimation at phase start |
| Agent spawn success | > 95% | Successful handoffs / total |
| Observation masking ratio | > 60% reduction | Masked tokens / raw tokens |
| Task completion rate | > 90% | Completed / total tasks |
