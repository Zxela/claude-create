# Context Engineering Patterns in Homerun

## Core Principles Applied

### 1. Context Isolation via Agent Spawning

Each phase runs in a **fresh agent context** with explicit model selection:

```
/create (Opus - user's default)
   │
   └─> Task(model: "opus")  → Discovery  [dialogue with user]
           │
           └─> Task(model: "opus")  → Planning   [high-leverage decomposition]
                   │
                   └─> Task(model: "haiku") → Conductor [mechanical scheduling]
                           │
                           ├─> Task(model: task.model) → Implementer [varies by complexity]
                           │
                           └─> Task(model: "sonnet")   → Reviewer    [quality judgment]
```

**Why this works:**
- Each agent starts with ~5-10K tokens (just state.json + task)
- Previous phase deliberation doesn't bloat next phase
- Model selection optimizes cost/quality per role
- No "telephone game" - agents read state.json directly

### 2. Filesystem-as-Memory Pattern

Instead of passing data through messages, agents communicate via filesystem:

| File | Purpose | Updated By |
|------|---------|------------|
| `state.json` | Workflow state, phase, progress | All phases |
| `docs/tasks.json` | Task status, attempts, feedback | Conductor |
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

### 5. Compaction Triggers

Monitor context usage and trigger refresh:

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Token usage | > 70% | Spawn fresh conductor |
| Tasks completed | every 5 | Spawn fresh conductor |
| Stalled iterations | 3 without progress | Escalate to user |
| High-severity failure | any | Block and escalate |

**Tracked in state.json:**
```json
{
  "token_tracking": {
    "config": {
      "refresh_threshold_percent": 40,
      "warning_threshold_percent": 60
    },
    "refresh_log": [
      {"reason": "task_count", "at": "...", "tasks_completed": 5}
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
| Planning | opus | High-leverage - bad decomposition cascades |
| Conductor | haiku | Mechanical scheduling, no reasoning needed |
| Implementer (simple) | haiku | Pattern-following tasks |
| Implementer (complex) | sonnet | Design decisions, security implications |
| Reviewer | sonnet | Quality judgment requires reasoning |

**Escalation path:**
```
haiku task fails 3x → retry with sonnet
sonnet task fails 3x → escalate to user
```

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
✅ Monitor usage, compact at 70%, refresh at 80%

## Measuring Effectiveness

Track these metrics:

| Metric | Target | Measurement |
|--------|--------|-------------|
| Phase context size | < 50K tokens | Token estimation at phase start |
| Agent spawn success | > 95% | Successful handoffs / total |
| Observation masking ratio | > 60% reduction | Masked tokens / raw tokens |
| Task completion rate | > 90% | Completed / total tasks |
