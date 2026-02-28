---
name: discovery
description: "[inherit] Refine ideas into PRD, ADR, Technical Design, and Wireframes through structured dialogue"
color: yellow
---

# Discovery Skill

## Reference Materials

- Question reference: `references/discovery-questions.md`
- Dialogue examples: `cookbooks/discovery-dialogue-examples.md`
- Document templates: `templates/*.template.md`
- Agent handoff patterns: `references/context-engineering.md`
- Scale determination & doc segregation: `references/scale-determination.md`

## Overview

Guide the user from a rough idea to complete specification documents through structured, one-question-at-a-time dialogue. This skill is the first phase of the `/create` workflow, transforming initial concepts into formal PRD, ADR, Technical Design, and Wireframe documents.

The discovery process is conversational and iterative. You ask focused questions, synthesize responses, and progressively build understanding until you have enough information to generate comprehensive specification documents.

---

## Input Schema (JSON)

The `/create` command provides input as a JSON object:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["prompt"],
  "properties": {
    "prompt": {
      "type": "string",
      "description": "User's description of what to build"
    },
    "config": {
      "type": "object",
      "properties": {
        "auto_mode": { "type": "boolean", "default": false },
        "max_dialogue_turns": { "type": "integer", "default": 20 },
        "dialogue_warning_at": { "type": "integer", "default": 15 },
        "retries": {
          "type": "object",
          "properties": {
            "same_agent": { "type": "integer", "default": 2 },
            "fresh_agent": { "type": "integer", "default": 1 }
          }
        }
      }
    },
    "project_root": { "type": "string" }
  }
}
```

### Example Input

```json
{
  "prompt": "Build a REST API for user authentication with JWT tokens",
  "config": {
    "auto_mode": false,
    "retries": { "same_agent": 2, "fresh_agent": 1 }
  },
  "project_root": "/path/to/project"
}
```

---

## Output Schema (JSON)

When discovery completes, output a JSON signal:

### Success: DISCOVERY_COMPLETE

See `references/signal-contracts.json` for the full envelope schema.

```json
{
  "signal": "DISCOVERY_COMPLETE",
  "timestamp": "2026-01-25T10:30:00Z",
  "source": { "skill": "homerun:discovery" },
  "payload": {
    "session_id": "user-auth-a1b2c3d4",
    "worktree_path": "../myapp-create-user-auth-a1b2c3d4",
    "branch": "create/user-auth-a1b2c3d4",
    "homerun_docs_dir": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4",
    "spec_paths": {
      "prd": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4/PRD.md",
      "adr": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4/ADR.md",
      "technical_design": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4/TECHNICAL_DESIGN.md",
      "wireframes": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4/WIREFRAMES.md"
    },
    "user_stories_count": 3,
    "acceptance_criteria_count": 12,
    "dialogue_stats": {
      "total_turns": 18,
      "categories_covered": ["purpose", "users", "scope", "constraints", "edge_cases"],
      "auto_completed": false
    }
  },
  "envelope_version": "1.0.0"
}
```

---

## Process

### 1. Context Gathering

Before engaging the user, gather project context silently:

```bash
# Read project configuration and conventions
cat CLAUDE.md 2>/dev/null || echo "No CLAUDE.md found"

# Scan project structure to understand codebase
find . -type f -name "*.md" | head -20
ls -la src/ lib/ app/ 2>/dev/null || ls -la

# Check recent development activity
git log --oneline -10 2>/dev/null || echo "Not a git repository"

# Identify technology stack
cat package.json pyproject.toml Cargo.toml go.mod 2>/dev/null | head -50
```

Use this context to:
- Understand existing patterns and conventions
- Identify relevant technologies and dependencies
- Frame questions appropriately for the project

---

### 2. Refinement Dialogue

Engage the user with **ONE question at a time**. Prefer multiple-choice options when possible to reduce cognitive load and speed up the process.

**Question Reference:** See `references/discovery-questions.md` for the question catalog.

**Categories to cover:**
1. **Purpose & Goals** - What problem, who benefits, success criteria
2. **Users & Personas** - Who uses it, technical level, frequency
3. **Scope & Boundaries** - What's in/out of scope for v1 (include explicit **non-scope declaration**: what are you NOT changing?)
4. **Technical Constraints** - Performance, security, integrations
5. **Edge Cases & Error Handling** - Failure modes, validation

**Dialogue Guidelines:**
- Ask only ONE question per message
- Acknowledge the previous answer before asking the next question
- Build on previous answers - make connections visible
- If an answer is unclear, ask a clarifying follow-up
- Summarize understanding periodically (every 3-4 questions)

---

### Dialogue Turn Limits

Track dialogue turns to prevent infinite loops:

```javascript
function shouldContinueDialogue(state, config) {
  const turns = state.dialogue_state.turns_completed;
  const max = config.max_dialogue_turns || 20;
  const warning = config.dialogue_warning_at || 15;

  // Hard limit reached
  if (turns >= max) {
    return {
      continue: false,
      reason: 'max_turns_reached',
      action: 'auto_generate_specs'
    };
  }

  // Warning threshold
  if (turns >= warning && !state.dialogue_state.warnings_shown) {
    return {
      continue: true,
      showWarning: true,
      message: `We've gathered substantial detail (${turns} exchanges). Ready to generate specs, or continue refining?`
    };
  }

  // Check category coverage
  const remaining = state.dialogue_state.categories_remaining;
  if (remaining.length === 0) {
    return {
      continue: false,
      reason: 'all_categories_covered',
      action: 'generate_specs'
    };
  }

  return { continue: true };
}
```

**Progression behavior:**

At warning threshold (default: 15 turns):
```
"We've gathered substantial detail across N areas.
Would you like to:
1. Generate specs with current information
2. Continue refining (5 turns remaining)"
```

At max threshold (default: 20 turns):
```
"Reached dialogue limit. Generating specs with collected information.
You can refine the generated documents directly if needed."
```

**Category completion check:**

Mark category complete when:
- At least 2 substantive answers received for category
- User explicitly says "that's enough for [category]"
- No new information in 2 consecutive questions

```javascript
function markCategoryComplete(state, category) {
  state.dialogue_state.categories_covered.push(category);
  state.dialogue_state.categories_remaining =
    state.dialogue_state.categories_remaining.filter(c => c !== category);
}
```

After each user response, increment turn counter:
```javascript
state.dialogue_state.turns_completed++;
state.dialogue_state.last_question_category = currentCategory;
```

**Testability Guidance for Acceptance Criteria:**

When gathering acceptance criteria, guide users toward testable patterns. If a user provides vague criteria, help them refine it.

| User Says | Problem | Guide Toward |
|-----------|---------|--------------|
| "Should be user-friendly" | Adjective only, not testable | "What specific action should users complete easily? E.g., 'User can complete checkout in under 3 clicks'" |
| "Should work correctly" | No observable outcome | "What does 'correctly' look like? E.g., 'Returns HTTP 200 with user data'" |
| "Must be fast" | No threshold | "How fast? E.g., 'Response time < 200ms for 95th percentile'" |
| "Handle errors properly" | Vague handling | "What should happen on error? E.g., 'Display error message and preserve form input'" |

**EARS Format for Acceptance Criteria:**

Write every acceptance criterion using one of these four EARS patterns. Each maps directly to a test type:

| EARS Pattern | Template | Test Type | Example |
|-------------|----------|-----------|---------|
| **When** (trigger) | When \<trigger\>, the system shall \<response\> | Event-driven test | "When user clicks login with valid credentials, the system shall create a session and redirect to dashboard" |
| **While** (continuous) | While \<condition\>, the system shall \<behavior\> | State-based test | "While user is logged in, the system shall maintain the session for 60 minutes" |
| **If-Then** (conditional) | If \<condition\>, then the system shall \<response\> | Branch coverage test | "If credentials are invalid, then the system shall return 401 with message 'Invalid credentials'" |
| **None** (simple) | The system shall \<behavior\> | Basic functional test | "The system shall hash passwords using bcrypt with cost factor 12" |

**Guide vague criteria toward EARS:**

| User Says | Problem | Rewrite As |
|-----------|---------|------------|
| "Should be user-friendly" | Adjective, no observable outcome | **When** user opens the form, the system shall pre-fill known fields and focus the first empty field |
| "Should work correctly" | No measurable result | **When** user submits valid data, the system shall return HTTP 200 with the created resource |
| "Must be fast" | No threshold | **While** under normal load, the system shall respond in < 200ms for 95th percentile |
| "Handle errors properly" | Vague handling | **If** the database is unreachable, **then** the system shall return 503 and display "Service temporarily unavailable" |

When a user provides vague criteria, respond with:
```
That criterion might be hard to verify in tests. Could we rewrite it using EARS format?

Instead of: "{{vague_criterion}}"
Consider: "{{ears_rewrite}}"

Would that work, or did you have something else in mind?
```

---

### 2.5. Scale Estimation

**After the Scope & Boundaries category,** estimate the task scale to determine which documents to generate. See `references/scale-determination.md` for the full matrix.

```bash
cd "$PROJECT_ROOT"

# Count files that would be modified
MODIFIED=$(grep -rn "${KEYWORDS}" src/ lib/ app/ --include="*.ts" --include="*.js" --include="*.py" -l 2>/dev/null | wc -l)

# Estimate new files from task description
# (new model = 1, new service = 1, new route = 1, new test = 1, etc.)
```

**Decision matrix:**

| Scale | Files | Documents | Dialogue Adjustment |
|-------|-------|-----------|-------------------|
| **Small** (1-2) | Config change, add field, simple fix | TECHNICAL_DESIGN only | Shorten remaining dialogue (5-8 turns total) |
| **Medium** (3-5) | New endpoint, new service | PRD + TECHNICAL_DESIGN | Standard dialogue (10-15 turns) |
| **Large** (6+) | New feature, architectural change | PRD + ADR + TECHNICAL_DESIGN + WIREFRAMES | Full dialogue (15-20 turns) |

**ADR trigger check** (always generate ADR if ANY apply, regardless of scale):
- Type/interface change used in 3+ locations
- Data flow change (storage, processing order, passing method)
- Architecture change (new layer, responsibility shift)
- External dependency introduction or replacement
- Complex logic with 3+ states or 5+ async processes

**Inform the user of the scale assessment:**
```
Based on the scope, this looks like a [small/medium/large] change (~N files).
I'll generate [list of documents]. Does that sound right, or is this bigger/smaller than it seems?
```

Store in state.json:
```json
{
  "scale": {
    "estimated": "medium",
    "file_count": 4,
    "adr_triggers": [],
    "docs_to_generate": ["prd", "technical_design"]
  }
}
```

---

### 2.6. Scale-Based Model and Phase Routing

Based on the scale estimation, adjust the downstream workflow:

| Scale | Discovery Model | Documents Generated | Skip Scope Analysis | Skip Spec Review |
|-------|----------------|--------------------|--------------------|-----------------|
| **Small** | haiku | TECHNICAL_DESIGN only | Yes | Yes |
| **Medium** | inherit (user default) | PRD + TECHNICAL_DESIGN | No | No |
| **Large** | inherit (user default) | All documents | No | No |

**For small-scale features (< 3 files):**
- Set `state.json` scale field: `"scale": "small"`
- Generate only TECHNICAL_DESIGN.md (simplified — skip architecture diagrams, focus on data model + implementation plan)
- Skip PRD, ADR, and WIREFRAMES
- The `/create` command will skip the `scope_analysis` phase entirely
- Task decomposition reads TECHNICAL_DESIGN directly (no scope-analysis.json intermediate)
- Shorten dialogue to 5-8 turns total (reduce question depth in each category)

**Store scale in state.json** (update the existing scale block):
```json
{
  "scale": "small",
  "scale_details": {
    "estimated_files": 2,
    "adr_triggers": [],
    "docs_to_generate": ["technical_design"],
    "skip_scope_analysis": true
  }
}
```

---

### 3. Document Generation

**Document segregation rules** (see `references/scale-determination.md` for details):

- **PRD** = business value ONLY (problem, user stories, goals — never implementation details)
- **ADR** = decision rationale ONLY (options, tradeoffs, consequences — never "how to implement")
- **TECHNICAL_DESIGN** = implementation ONLY (architecture, data models, API contracts — never "why")
- **WIREFRAMES** = user interface ONLY (layouts, flows, states)

Cross-reference between documents instead of duplicating content.

Once sufficient information is gathered, create the worktree and generate documents.

#### Create Worktree and Document Storage

Documents are stored in a centralized location to keep the project directory clean:

```
$HOME/.claude/homerun/<project-hash>/<feature-slug>/
  ├── PRD.md
  ├── ADR.md
  ├── TECHNICAL_DESIGN.md
  └── WIREFRAMES.md (if applicable)
```

```bash
# Generate session ID
SESSION_UUID=$(cat /proc/sys/kernel/random/uuid | cut -c1-8)
FEATURE_SLUG=$(echo "{{FEATURE_NAME}}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
BRANCH_NAME="create/${FEATURE_SLUG}-${SESSION_UUID}"

# Get repository info
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
WORKTREE_PATH="${REPO_ROOT}/../${REPO_NAME}-create-${FEATURE_SLUG}-${SESSION_UUID}"

# Create project hash for centralized storage (avoids path conflicts)
PROJECT_HASH=$(echo "$REPO_ROOT" | md5sum | cut -c1-8)
# IMPORTANT: Use $HOME, not ~ (tilde doesn't expand in all contexts)
HOMERUN_DOCS_DIR="${HOME}/.claude/homerun/${PROJECT_HASH}/${FEATURE_SLUG}-${SESSION_UUID}"

# Create branch and worktree
git branch "$BRANCH_NAME"
git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"

# Create centralized docs structure (NOT in project repo)
mkdir -p "$HOMERUN_DOCS_DIR"

# Create worktree task directory (tasks stay in worktree for git tracking)
mkdir -p "${WORKTREE_PATH}/docs"
```

**Why centralized storage:**
- Keeps ADRs, PRDs, design docs out of project repo
- Documents persist across sessions for reference
- No conflicts when running multiple features on same project
- Easy to find: `$HOME/.claude/homerun/` contains all homerun docs

**IMPORTANT:** When storing paths in `state.json`:
- Use the **fully expanded absolute path** from `$HOME`, not the variable itself
- Example: If `$HOME` is `/home/alice`, store `/home/alice/.claude/homerun/...`
- Never store `~` or `$HOME` literally - JSON doesn't expand shell variables
- The examples below use `/home/user/` as a placeholder for the actual home directory

#### Write Specification Documents

Generate documents to the centralized `~/.claude/homerun/` directory.

Use templates from `templates/` as starting points:
- `templates/PRD.template.md`
- `templates/ADR.template.md`
- `templates/TECHNICAL_DESIGN.template.md`

**Documents to generate (based on scale from Step 2.5):**

**All acceptance criteria MUST use EARS format** (When/While/If-Then/None).

#### Always generated (all scales):

1. **TECHNICAL_DESIGN.md** - Technical Design Document
   - Architecture overview (simplified for small scale)
   - Data models and schemas
   - API contracts if applicable
   - Integration points with existing code
   - Dependencies (internal and external)
   - **Non-Scope declaration** — explicitly list what is NOT being changed
   - **Change Impact Map** — classify affected areas as:
     - *Direct Impact*: files/modules being modified
     - *Indirect Impact*: files that import/use changed code (verify no breakage)
     - *No Ripple Effect*: explicitly list features confirmed unaffected
   - Security considerations
   - Testing strategy outline

#### Generated for medium and large scale:

2. **PRD.md** - Product Requirements Document (business value only)
   - Problem statement from gathered context
   - Goals derived from user responses
   - User stories with acceptance criteria (EARS format)
   - Non-goals explicitly stated
   - Success metrics where applicable
   - Never include: implementation details, file paths, frameworks

#### Generated for large scale (or when ADR triggers apply):

3. **ADR.md** - Architecture Decision Record (decision rationale only)
   - Context explaining the decision drivers
   - Options considered (at least 2-3)
   - Decision with rationale ("because X, Y, Z")
   - Consequences (positive AND negative)
   - Kill criteria (when would we reverse this decision?)
   - Never include: implementation schedule, code examples

4. **WIREFRAMES.md** - UI Wireframes (if applicable, UI changes only)
   - Skip for CLI, API, or library projects
   - ASCII/box diagrams for screen layouts
   - User flow diagrams
   - Component hierarchy
   - Interactive states (hover, error, loading, empty)

**Write documents:**
```bash
# Write to centralized location
cat > "$HOMERUN_DOCS_DIR/PRD.md" << 'EOF'
{{Generated PRD content}}
EOF

cat > "$HOMERUN_DOCS_DIR/ADR.md" << 'EOF'
{{Generated ADR content}}
EOF

cat > "$HOMERUN_DOCS_DIR/TECHNICAL_DESIGN.md" << 'EOF'
{{Generated TECHNICAL_DESIGN content}}
EOF

# WIREFRAMES.md only if UI feature
```

#### Initialize State

Create `state.json` in the worktree root with traceability structure and token tracking:

```json
{
  "session_id": "user-auth-a1b2c3d4",
  "branch": "create/user-auth-a1b2c3d4",
  "worktree": "../myapp-create-user-auth-a1b2c3d4",
  "feature": "user-auth",
  "created_at": "2026-01-25T10:00:00Z",
  "phase": "discovery",
  "homerun_docs_dir": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4",
  "spec_paths": {
    "prd": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4/PRD.md",
    "adr": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4/ADR.md",
    "technical_design": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4/TECHNICAL_DESIGN.md",
    "wireframes": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4/WIREFRAMES.md"
  },
  "tasks_file": "docs/tasks.json",
  "traceability": {
    "user_stories": {
      "US-001": {
        "title": "User can register with email and password",
        "acceptance_criteria": ["AC-001", "AC-002", "AC-003"],
        "tasks": []
      },
      "US-002": {
        "title": "User can log in with credentials",
        "acceptance_criteria": ["AC-004", "AC-005"],
        "tasks": []
      }
    },
    "acceptance_criteria": {
      "AC-001": {
        "description": "User must provide valid email format",
        "story": "US-001",
        "pattern": "assertion",
        "tasks": []
      },
      "AC-002": {
        "description": "Password must be at least 8 characters",
        "story": "US-001",
        "pattern": "quantitative",
        "tasks": []
      }
    },
    "adr_decisions": {
      "ADR-001": {
        "title": "Use bcrypt for password hashing",
        "rationale": "Industry standard, configurable work factor",
        "tasks_affected": []
      }
    },
    "non_goals": [
      "NG-001: Social login (OAuth) is out of scope",
      "NG-002: Two-factor authentication is out of scope"
    ]
  },
  "tasks": {},
  "current_task": null,
  "config": {
    "auto_mode": false,
    "timeout_minutes": 30,
    "max_identical_rejections": 3,
    "max_iterations_without_progress": 3,
    "retries": {
      "same_agent": 2,
      "fresh_agent": 1
    }
  },
  "token_tracking": {
    "enabled": true,
    "config": {
      "window_size": 200000,
      "target_usage_percent": 50,
      "refresh_threshold_percent": 40,
      "warning_threshold_percent": 60
    },
    "phases": {
      "discovery": {
        "started_at": "2026-01-25T10:00:00Z",
        "dialogue_turns": 0
      }
    },
    "refresh_log": []
  },
  "dialogue_state": {
    "turns_completed": 0,
    "categories_covered": [],
    "categories_remaining": ["purpose", "users", "scope", "constraints", "edge_cases"],
    "last_question_category": null,
    "warnings_shown": false
  },
  "progress": {
    "iteration": 0,
    "tasks_completed_this_iteration": 0,
    "last_completion_iteration": 0
  },
  "skill_log": []
}
```

**Traceability Fields:**
| Field | Purpose |
|-------|---------|
| `traceability.user_stories` | Maps story IDs to titles, criteria, and implementing tasks |
| `traceability.acceptance_criteria` | Maps criteria IDs to descriptions, source story, and tasks |
| `traceability.adr_decisions` | Maps ADR decision IDs to affected tasks |
| `traceability.non_goals` | List of explicitly out-of-scope items for boundary checking |

---

### 4. Validation

Present each document section-by-section for user confirmation.

**Validation Guidelines:**
- Present sections in 200-300 word chunks
- After each section, ask: "Does this accurately capture your intent?"
- Accept one of:
  - **Confirmed** - Move to next section
  - **Minor edits** - Apply changes, re-present
  - **Major revision** - Return to dialogue for that topic
- Track which sections are confirmed

**Validation Flow:**

```
1. Present PRD Problem Statement (200-300 words)
   → Ask for confirmation

2. Present PRD Goals and Non-Goals
   → Ask for confirmation

3. Present PRD User Stories
   → Ask for confirmation

4. Present ADR Context and Decision
   → Ask for confirmation

5. Present Technical Design Architecture
   → Ask for confirmation

6. Present Technical Design Data Models
   → Ask for confirmation

7. Present Wireframes (if applicable)
   → Ask for confirmation
```

After all sections confirmed:
- Documents are already in centralized storage (not committed to repo)
- Commit state.json to track the feature

```bash
cd "$WORKTREE_PATH"
git add state.json
git commit -m "chore: initialize ${FEATURE_SLUG} workflow

Session ID: ${SESSION_UUID}
Docs location: ${HOMERUN_DOCS_DIR}

Generated by /create workflow discovery phase"
```

**Note:** Spec documents are stored in `~/.claude/homerun/` and NOT committed to the project repo. This keeps the project clean while preserving design history for reference.

---

### 5. Transition

After validation is complete:

1. Update state.json:
   ```json
   {
     "phase": "spec_review",
     ...
   }
   ```

2. Commit the state update:
   ```bash
   git add state.json
   git commit -m "chore: transition to spec review phase"
   ```

3. **Output signal and return:**

   ```json
   {
     "signal": "DISCOVERY_COMPLETE",
     "timestamp": "<ISO8601>",
     "source": { "skill": "homerun:discovery" },
     "payload": {
       "worktree_path": "...",
       "spec_paths": { "prd": "...", "adr": "...", "technical_design": "..." }
     },
     "envelope_version": "1.0.0"
   }
   ```

   **Do NOT spawn the next phase.** Return after emitting this signal.

---

## State Initialization Example

When starting a new discovery session, initialize state with this structure:

```json
{
  "session_id": "feature-name-a1b2c3d4",
  "branch": "create/feature-name-a1b2c3d4",
  "worktree": "../repo-create-feature-name-a1b2c3d4",
  "feature": "feature-name",
  "created_at": "2026-01-25T10:00:00Z",
  "phase": "discovery",
  "homerun_docs_dir": "/home/user/.claude/homerun/b1c2d3e4/feature-name-a1b2c3d4",
  "spec_paths": {
    "prd": "/home/user/.claude/homerun/b1c2d3e4/feature-name-a1b2c3d4/PRD.md",
    "adr": "/home/user/.claude/homerun/b1c2d3e4/feature-name-a1b2c3d4/ADR.md",
    "technical_design": "/home/user/.claude/homerun/b1c2d3e4/feature-name-a1b2c3d4/TECHNICAL_DESIGN.md",
    "wireframes": "/home/user/.claude/homerun/b1c2d3e4/feature-name-a1b2c3d4/WIREFRAMES.md"
  },
  "tasks_file": "docs/tasks.json",
  "traceability": {
    "user_stories": {},
    "acceptance_criteria": {},
    "adr_decisions": {},
    "non_goals": []
  },
  "tasks": {},
  "current_task": null,
  "config": {
    "auto_mode": false,
    "timeout_minutes": 30,
    "max_identical_rejections": 3,
    "max_iterations_without_progress": 3,
    "retries": {
      "same_agent": 2,
      "fresh_agent": 1
    }
  },
  "progress": {
    "iteration": 0,
    "tasks_completed_this_iteration": 0,
    "last_completion_iteration": 0
  },
  "skill_log": []
}
```

**Field Descriptions:**
| Field | Description |
|-------|-------------|
| session_id | Unique identifier combining feature slug and UUID |
| branch | Git branch name for this workflow |
| worktree | Path to the git worktree directory |
| feature | Slugified feature name |
| created_at | ISO 8601 timestamp of session creation |
| phase | Current workflow phase (discovery, planning, implementing, etc.) |
| spec_paths | Explicit paths to spec documents (PRD, ADR, technical_design, wireframes) |
| tasks_file | Path to JSON file with all tasks (e.g., "docs/tasks.json") |
| traceability | Links between user stories, acceptance criteria, ADR decisions, and tasks |
| tasks | Map of task IDs to status objects (populated in planning) |
| current_task | ID of task currently being worked on (null in discovery) |
| config | Configuration including timeouts and retry limits |
| progress | Iteration tracking for deadlock detection |
| skill_log | Array of skill invocations for visibility and debugging |

---

## Exit Criteria

Before transitioning to the planning phase, verify all criteria are met:

- [ ] CLAUDE.md and project structure reviewed for context
- [ ] All five question categories addressed (Purpose, Users, Scope, Constraints, Edge Cases)
- [ ] PRD.md created with problem statement, goals, non-goals, and user stories
- [ ] ADR.md created with context, options, decision, and consequences
- [ ] TECHNICAL_DESIGN.md created with architecture, data models, and API contracts
- [ ] WIREFRAMES.md created (or explicitly skipped for non-UI features)
- [ ] All document sections validated by user (200-300 word chunks confirmed)
- [ ] Git worktree created with proper branch naming
- [ ] state.json initialized with session configuration
- [ ] All documents committed to the feature branch
- [ ] User confirmed ready to proceed to planning phase (or auto_mode enabled)

---

## Phase Transition Validation Gate

**REQUIRED:** Before transitioning to planning phase, run these automated validations:

### PRD Validation

Verify the PRD meets quality standards:

```bash
# Check for measurable success metrics (must have at least one with target value)
grep -E "Target.*[0-9]|[0-9]+%|< ?[0-9]|> ?[0-9]" "$HOMERUN_DOCS_DIR/PRD.md" || echo "VALIDATION_FAILED: No measurable success metrics found"

# Check for explicit non-goals section with content
grep -A 5 "## Non-Goals" "$HOMERUN_DOCS_DIR/PRD.md" | grep -E "^- " || echo "VALIDATION_FAILED: Non-goals section empty"
```

### User Story Testability Validation

Every user story acceptance criterion MUST match one of these testable patterns:

| Pattern | Example | Regex |
|---------|---------|-------|
| Behavioral (Given/When/Then) | "Given a logged-in user, when they click logout, then session is destroyed" | `(Given|When|Then)` |
| Assertion (should/must/can) | "User should see an error message" | `(should|must|can|will) [a-z]+ [a-z]+` |
| Quantitative | "Response time < 2s" | `[<>=≤≥] ?[0-9]` |

**Reject these vague patterns:**
- Adjective-only: "should be user-friendly" (no observable outcome)
- No outcome: "should work correctly" (what does "correctly" mean?)
- Passive/vague: "is handled properly" (what does "properly" mean?)

Run validation:
```bash
# Extract acceptance criteria and check for testable patterns
grep -E "^\s*-\s*\[" "$HOMERUN_DOCS_DIR/PRD.md" | while read -r criterion; do
  if ! echo "$criterion" | grep -qE "(Given|When|Then|should|must|can|will) [a-z]+|[<>=≤≥] ?[0-9]"; then
    echo "VALIDATION_WARNING: Potentially untestable criterion: $criterion"
  fi
done
```

### ADR Validation

Verify the ADR has required sections:

```bash
# Check for explicit non-goals or constraints in ADR
grep -E "## (Non-Goals|Constraints|Out of Scope)" "$HOMERUN_DOCS_DIR/ADR.md" || echo "VALIDATION_WARNING: ADR missing non-goals/constraints section"

# Check decision has rationale
grep -A 10 "## Decision" "$HOMERUN_DOCS_DIR/ADR.md" | grep -E "(because|due to|since|rationale)" || echo "VALIDATION_WARNING: Decision lacks explicit rationale"
```

### Validation Response

If any `VALIDATION_FAILED` errors occur:
1. **Do not transition** to the planning phase
2. Present the specific validation failures to the user
3. Return to the relevant dialogue section to address the issues
4. Re-run validation after corrections

If only `VALIDATION_WARNING` items occur:
1. Present warnings to the user
2. Ask: "These items may cause issues during implementation. Would you like to address them now or proceed with caution?"
3. On "proceed", continue to planning phase
4. On "address", return to dialogue to refine the content
