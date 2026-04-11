# Scale-Based Flow Determination

Determines which specification documents to generate based on estimated task scope. Used by the discovery skill to right-size documentation effort.

## Scale Classifications

### Trivial
**Estimated files:** 1
**Signals:** Prompt < 50 words, single-action keywords ("fix", "rename", "update", "change", "remove"), no architectural decisions needed, single file or clearly scoped change
**Examples:** "Fix the typo in README", "Rename getUserById to findUserById", "Add created_at field to User model"
**Pipeline:** Skip all phases. Direct single-implementer dispatch with haiku-tier quality check.
**State management:** No state.json, no tasks.json, no spec docs, no worktree.

### Small
**Estimated files:** 2-4
**Signals:** Prompt < 150 words, single-layer change ("add endpoint", "add page", "add validation"), no ADR triggers
**Examples:** "Add a /health endpoint", "Add email validation to signup form", "Create a 404 page"
**Pipeline:** Skip discovery, specs, spec review, scope analysis. Lightweight task decomposition (flat list, no DAG). Sequential dispatch.
**State management:** Minimal tasks.json (flat list). No spec docs. No worktree unless parallel.

### Medium
**Estimated files:** 5-8
**Documents to Generate:** PRD + TECHNICAL_DESIGN
**Dialogue Turns:** 10-15
**Planning:** Full task DAG
**Execution Pipeline:** Standard pipeline, max 2 concurrent implementers

### Large
**Estimated files:** 9+
**Documents to Generate:** PRD + ADR + TECHNICAL_DESIGN + WIREFRAMES
**Dialogue Turns:** 15-20
**Planning:** Full task DAG
**Execution Pipeline:** Full pipeline, up to 5 concurrent implementers

## Pipeline Short-Circuit Rules (Effort-Proportional Routing)

The team-lead uses the scale from `state.json` to determine the execution pipeline:

### Trivial Scale (1 file)
- **Skip:** All phases — discovery, specs, spec review, scope analysis, task decomposition
- **Skip:** Worktree creation, state.json, tasks.json
- **Use:** Direct single-implementer dispatch
- **Use:** Haiku-tier quality check (lint + types + tests only)
- **Model:** Haiku
- **Estimated cost:** ~2-5K tokens total

### Small Scale (2-4 files)
- **Skip:** Discovery, specs, spec review, scope analysis
- **Use:** Lightweight task decomposition (flat list, no DAG)
- **Use:** Sequential single-implementer dispatch
- **Use:** Haiku-tier quality check
- **Model:** Prefer haiku for implementation
- **Estimated cost:** ~5-15K tokens total

### Medium Scale (5-8 files)
- **Use:** Full spec review
- **Use:** Task DAG with max 2 concurrent implementers
- **Use:** 1 reviewer agent (background)
- **Use:** Quality check
- **Model:** Sonnet for implementation, skip opus escalation
- **Estimated cost:** ~30-60K tokens total

### Large Scale (9+ files)
- **Use:** Full pipeline (spec review → planning → Agent Teams → review → quality)
- **Use:** Up to 5 concurrent implementers (based on DAG width)
- **Use:** 1 reviewer agent (background)
- **Use:** Quality check with auto-fix
- **Model:** Full model routing (haiku/sonnet/opus per task type)
- **Estimated cost:** ~80-200K tokens total

## How to Estimate Scale

During the Scope & Boundaries dialogue category, assess:

```
1. How many existing files will be MODIFIED?
   → Check: grep for relevant functions, types, routes
   → Check: git log to see how many files a similar change touched

2. How many NEW files will be CREATED?
   → Check: task objective implies new model? new endpoint? new service?

3. Total = modified + created
   → 1 = Trivial, 2-4 = Small, 5-8 = Medium, 9+ = Large
```

**Quick heuristics:**
- "Fix typo in README" → Trivial (single file, single action)
- "Rename getUserById" → Trivial (single rename, mechanical)
- "Add created_at field to User model" → Trivial (single model file change)
- "Add a /health endpoint" → Small (route + handler + test)
- "Add user profile page with API" → Medium (route + handler + service + model + tests)
- "Build authentication system" → Large (models + service + middleware + routes + tests + config)

## Auto-Classification Heuristic

Classification runs as a single haiku call before any phase begins. This call pays for itself by avoiding unnecessary phases.

**Input to classifier:**
- User's prompt (verbatim)
- Codebase summary: primary language, file count, top-level directory structure
- Project type: new project (no existing code) vs existing codebase

**Structured output:**
```json
{
  "classification": "trivial|small|medium|large",
  "reasoning": "One sentence explaining why",
  "estimated_files": 3,
  "needs_adr": false
}
```

**Override rules:**
- `--full` flag → always "large"
- New project with no existing code → minimum "medium" (needs at least PRD + TD)
- Prompt mentions "migrate", "refactor across", "redesign" → minimum "medium"
- Prompt mentions multiple services/systems → minimum "large"

**Conservative default:** When uncertain between two tiers, choose the higher tier. Excess planning is cheaper than insufficient planning for complex tasks.

## ADR Trigger Conditions

Generate an ADR **regardless of scale** if ANY of these apply:

| Trigger | Description | Example |
|---------|-------------|---------|
| Type system change (3+ locations) | A type/interface change that propagates to 3+ files | Adding a field to User type used in auth, profile, admin |
| Data flow change | Storage location, processing order, or data passing method changes | Moving from localStorage to database, changing sync to async |
| Architecture change | New layer, responsibility shift, or structural reorganization | Adding a caching layer, splitting a monolith module |
| External dependency | Introducing or replacing an external library/service | Adding Redis, switching from REST to GraphQL |
| Complex logic | 3+ states or 5+ async processes | State machine for order processing, multi-step payment flow |

## Document Content by Scale

### Small (2-4 files)

**No spec documents.** Small tasks skip discovery and spec generation entirely — the task description and codebase provide sufficient context. Lightweight task decomposition produces a flat task list directly from the user prompt.

Skip: PRD, ADR, TECHNICAL_DESIGN, WIREFRAMES

### Medium (5-8 files)

**PRD** (focused):
- Problem statement (brief)
- User stories with acceptance criteria
- Non-goals (1-2 items)
- No detailed personas or market analysis

**TECHNICAL_DESIGN** (standard):
- Architecture overview (relevant subsystem only)
- Data models affected
- API contracts (if applicable)
- Testing strategy
- Dependencies

Skip: ADR (unless triggered), WIREFRAMES (unless UI change)

### Large (9+ files)

**Full document set:**
- PRD — Complete with goals, non-goals, user stories, success metrics
- ADR — Decision rationale with 2+ options compared
- TECHNICAL_DESIGN — Full architecture, data models, API contracts, security
- WIREFRAMES — If user-facing UI changes

## Storing Scale in State

```json
{
  "scale": {
    "estimated": "medium",
    "file_count": 4,
    "files_modified": ["src/models/user.ts", "src/routes/auth.ts"],
    "files_created": ["src/services/auth.ts", "tests/services/auth.test.ts"],
    "adr_triggers": [],
    "docs_generated": ["prd", "technical_design"]
  }
}
```

## Scale Override

The user can override the estimated scale:
- "This is bigger than it looks" → escalate to next scale
- "Keep it simple" → downgrade to smaller scale
- ADR trigger detected → always include ADR regardless of scale

---

## Document Segregation Rules

Each document has a strict content boundary. Mixing content across boundaries creates confusion during planning and implementation.

### PRD — Business Value Only

**Include:**
- Problem statement (who has this problem, why it matters)
- User stories with acceptance criteria
- Goals and non-goals
- Success metrics (measurable outcomes)
- MoSCoW prioritization (must/should/could/won't)

**Never include:**
- Implementation details (frameworks, libraries, file paths)
- Architecture decisions (that's ADR)
- Data schemas or API contracts (that's TECHNICAL_DESIGN)
- Timeline or schedule estimates

**Test:** Can a non-technical stakeholder read and understand this? If no, move the technical content out.

### ADR — Decision Rationale Only

**Include:**
- Context (what forces are driving this decision?)
- Options considered (minimum 2, ideally 3+)
- Decision made with explicit rationale ("because X, Y, Z")
- Consequences — positive AND negative
- Kill criteria (when would we reverse this decision?)

**Never include:**
- Implementation schedule or task breakdown
- Code examples or file paths (that's TECHNICAL_DESIGN)
- User stories or business requirements (that's PRD)
- How to implement the decision (that's TECHNICAL_DESIGN)

**Test:** Does every section answer "why?" not "how?"

### TECHNICAL_DESIGN — Implementation Only

**Include:**
- Architecture overview (components and their relationships)
- Data models with field types and constraints
- API contracts (endpoints, request/response schemas)
- Integration points with existing code
- Existing codebase analysis (what already exists, what to reuse)
- **Non-Scope declaration** — explicit list of what is NOT being changed
- **Change Impact Map:**
  - *Direct Impact* — files/modules being modified
  - *Indirect Impact* — files that import/use changed code (verify no breakage)
  - *No Ripple Effect* — features explicitly confirmed unaffected
- Security considerations
- Testing strategy

**Never include:**
- Business justification (that's PRD)
- Decision rationale or alternatives considered (that's ADR)
- User stories or success metrics (that's PRD)

**Test:** Can a developer implement from this without needing to ask "but why?" If they need "why," it should cross-reference the ADR. Can a developer know what NOT to touch? If unclear, add it to Non-Scope.

### WIREFRAMES — User Interface Only

**Include:**
- Screen layouts (ASCII/box diagrams)
- User flow between screens
- Component hierarchy
- Interactive states (hover, error, loading, empty)

**Never include:**
- API contracts (that's TECHNICAL_DESIGN)
- Business logic (that's PRD)

**Test:** Does this only show what the user sees and does?

### Cross-Reference Pattern

Documents should reference each other, not duplicate:

```markdown
<!-- In TECHNICAL_DESIGN.md -->
## Architecture
See ADR.md for why we chose this approach.
The user stories driving this design are in PRD.md (US-001, US-002).

## Data Model
### User
- email: string (required) — per AC-001 in PRD
- password_hash: string — per ADR-001 (bcrypt decision)
```
