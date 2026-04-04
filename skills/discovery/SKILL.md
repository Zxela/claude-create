---
name: discovery
description: "[inherit] Refine ideas into PRD, ADR, Technical Design, and Wireframes through structured dialogue"
color: yellow
---

# Discovery Skill

## References

`references/state-schema.md` · `references/validation-gates.md` · `references/scale-determination.md` · `templates/*.md` · `cookbooks/discovery-dialogue-examples.md` · `references/signal-contracts.json` · `references/context-engineering.md`

## Overview

Guide user from rough idea → spec documents through codebase-informed dialogue. Deeply understand the codebase first, then fill gaps through conversation — never ask what the code already answers. Auto mode (`config.auto_mode: true`): skip dialogue, generate specs from prompt + codebase analysis.

## Input/Output

**Input:** `prompt`, `config` (auto_mode, max_dialogue_turns:20, dialogue_warning_at:15, retries), `project_root`
**Output:** `DISCOVERY_COMPLETE` signal with `spec_paths`, `session_id`, `worktree_path`, `dialogue_stats` (see `references/signal-contracts.json`)

---

## Process

### 1. Codebase Analysis (Silent)

Analyze before engaging user: CLAUDE.md, package.json/pyproject.toml, directory structure (layers), existing patterns for similar features, related functionality, test conventions, `git log --oneline -10`.

Form hypotheses: files to change (scale estimate), patterns to follow, codebase constraints (state, don't ask), user's likely intent. **Saturation check:** 3 consecutive sources yield no new info → stop exploring.

---

### 1.5. Early Scope Assessment

Before clarifying questions, scan for 3+ independent subsystems (distinct user types, integration points, architectural layers, keywords like "and also"/"additionally"). If detected → propose phasing before detailed dialogue. Focused requests (<3 areas) → skip to dialogue.

---

### 2. Adaptive Dialogue

**Auto mode:** Skip dialogue. Infer all answers from codebase + prompt. Set `auto_completed: true`, jump to Step 3.

**Interactive mode:**

#### Opening
Present codebase findings (tech stack, patterns, related functionality) + your understanding of the request. Immediately use `AskUserQuestion` for clarifications.

#### AskUserQuestion Guidelines
- Batch 1-4 related questions per call. 2-4 options each (system auto-adds "Other"). Short headers (max 12 chars). Use `multiSelect: true` for non-exclusive choices.
- **Ask** what code can't answer: business motivation, scope boundaries, behavior preferences, edge case priorities.
- **State** what code reveals: "I see you use PostgreSQL with Prisma — I'll follow existing patterns."

#### Progression
Acknowledge previous answers → build connections → summarize every 2-3 exchanges. Topic complete when: enough info for that spec section, user signals done, or no new info. Turn limits: warn at 15, hard limit at 20.

#### Scale Estimation

| Scale | Files | Documents | Dialogue |
|-------|-------|-----------|----------|
| **Small** (1-2) | TECHNICAL_DESIGN_small.md only | 5-8 turns |
| **Medium** (3-5) | PRD + TECHNICAL_DESIGN | 10-15 turns |
| **Large** (6+) | PRD + ADR + TECHNICAL_DESIGN + WIREFRAMES | 15-20 turns |

Always generate ADR if triggers detected (type change 3+ locations, data flow change, architecture change, external dep, complex logic 3+ states). See `references/scale-determination.md`.

#### Acceptance Criteria (EARS Format)

Every AC must be an observable, testable outcome. Litmus test: "Can I verify pass/fail without follow-up?"

EARS templates: **When** [trigger] → Event-driven | **While** [state] → State-driven | **If** [condition] → Conditional | The system **shall** → Unconditional.

Vague ACs ("user-friendly", "fast", "handle errors") → rewrite into EARS format with specific observable outcomes.

---

### 3. Document Generation

#### Create Worktree and Storage

```bash
# Generate session ID
SESSION_UUID=$(cat /proc/sys/kernel/random/uuid | cut -c1-8)
FEATURE_SLUG=$(echo "{{FEATURE_NAME}}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
BRANCH_NAME="create/${FEATURE_SLUG}-${SESSION_UUID}"

# Paths
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
WORKTREE_PATH="${REPO_ROOT}/../${REPO_NAME}-create-${FEATURE_SLUG}-${SESSION_UUID}"
PROJECT_HASH=$(echo "$REPO_ROOT" | md5sum | cut -c1-8)
# IMPORTANT: Use $HOME, not ~ (tilde doesn't expand in all contexts)
HOMERUN_DOCS_DIR="${HOME}/.claude/homerun/${PROJECT_HASH}/${FEATURE_SLUG}-${SESSION_UUID}"

# Create worktree and docs directory
git branch "$BRANCH_NAME"
git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
mkdir -p "$HOMERUN_DOCS_DIR"
mkdir -p "${WORKTREE_PATH}/docs"
```

#### Write Specification Documents

Templates: `templates/*.md`. Generate only scale-appropriate documents.

**Template selection by scale:**
- **Small (1-2 files):** Use `templates/TECHNICAL_DESIGN_small.md` — focused template with: Overview, What to Change, Data Models, API Contracts, Testing Strategy, Change Impact Map, Agreement Checklist.
- **Medium/Large (3+ files):** Use `templates/TECHNICAL_DESIGN.md` — full template with all sections.

**Strict boundaries:** PRD = business value only | ADR = decision rationale only | TECHNICAL_DESIGN = implementation only | WIREFRAMES = UI only (skip for CLI/API/library). Cross-reference, don't duplicate.

**Requirements:** FRs in PRD (MoSCoW priority, EARS-format ACs). NFRs: quantified targets in PRD, implementation in TECHNICAL_DESIGN. Omit categories without measurable targets.

**Quality:** Ground in codebase (real files/patterns). ACs must be testable. Non-scope explicit in TECHNICAL_DESIGN with Change Impact Map (direct/indirect/unaffected). Small features use `TECHNICAL_DESIGN_small.md`; large features get full document set. No boilerplate. Omit inapplicable sections entirely.

Write documents to `$HOMERUN_DOCS_DIR/`.

#### Initialize State

See `references/state-schema.md` for the complete schema, field descriptions, and scale-based initialization examples.

Key fields to populate:
- `session_id`, `branch`, `worktree`, `feature`
- `homerun_docs_dir` and `spec_paths` — fully expanded absolute paths, never `~` or `$HOME`
- `scale` and `scale_details`
- `traceability` — user stories, acceptance criteria, ADR decisions, non-goals
- `config` — auto_mode, retries from input
- `dialogue_state` — turns completed, topics covered

---

### 4. Validation & Transition

**Auto mode:** Run validation gates, log warnings, proceed.
**Interactive:** Present generated docs with 1-sentence summaries. Use `AskUserQuestion` with options: Looks good / Minor edits / Major revision. Run validation gates from `references/validation-gates.md`. VALIDATION_FAILED → return to dialogue. VALIDATION_WARNING → ask (interactive) or log (auto).

#### Commit and Transition

```bash
cd "$WORKTREE_PATH"
git add state.json
git commit -m "chore: initialize ${FEATURE_SLUG} workflow

Session ID: ${SESSION_UUID}
Docs location: ${HOMERUN_DOCS_DIR}

Generated by /create workflow discovery phase"
```

Update phase to `"spec_review"` and commit:

```bash
jq '.phase = "spec_review"' state.json > tmp.json && mv tmp.json state.json
git add state.json
git commit -m "chore: transition to spec review phase"
```

Emit `DISCOVERY_COMPLETE` signal with session_id, worktree_path, branch, homerun_docs_dir, spec_paths, dialogue_stats. **Do NOT spawn the next phase.**

## Exit Criteria

- [ ] Codebase analyzed; knowledge gaps addressed (dialogue or auto)
- [ ] Scale-appropriate documents generated with testable ACs and explicit non-scope
- [ ] Worktree created, state.json initialized, validation gates passed, phase → `spec_review`
