---
name: scope-analysis
description: "[sonnet] Extract scope, validate ACs, and create JIT context refs from spec documents"
model: sonnet
color: cyan
---

# Scope Analysis Skill

## References

`references/model-routing.json` · `references/signal-contracts.json` · `references/context-engineering.md`

## Overview

Mechanical spec reading → structured scope analysis for task-decomposer. Extracts components, validates ACs, creates JIT context refs, maps dependencies. Output: `docs/scope-analysis.json`. **Model: sonnet** (mechanical extraction, no judgment).

---

## Input Schema (JSON)

The scope-analyzer agent receives input from the `/create` or `/plan` command:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["worktree_path", "spec_paths"],
  "properties": {
    "worktree_path": { "type": "string" },
    "session_id": { "type": "string" },
    "branch": { "type": "string" },
    "spec_paths": {
      "type": "object",
      "required": ["prd", "adr", "technical_design"],
      "properties": {
        "prd": { "type": "string" },
        "adr": { "type": "string" },
        "technical_design": { "type": "string" },
        "wireframes": { "type": ["string", "null"] }
      }
    },
    "config": {
      "type": "object",
      "properties": {
        "auto_mode": { "type": "boolean" }
      }
    }
  }
}
```

---

## Output Schema

### Success: SCOPE_ANALYSIS_COMPLETE

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["signal", "scope_file", "components_count", "acceptance_criteria_count", "all_criteria_testable"],
  "properties": {
    "signal": { "const": "SCOPE_ANALYSIS_COMPLETE" },
    "scope_file": { "type": "string" },
    "components_count": { "type": "integer" },
    "acceptance_criteria_count": { "type": "integer" },
    "all_criteria_testable": { "type": "boolean" },
    "untestable_criteria": {
      "type": "array",
      "items": { "type": "string" }
    }
  }
}
```

**Example:**

```json
{
  "signal": "SCOPE_ANALYSIS_COMPLETE",
  "timestamp": "2026-02-27T10:30:00Z",
  "source": { "skill": "homerun:scope-analysis" },
  "payload": {
    "scope_file": "docs/scope-analysis.json",
    "components_count": 5,
    "acceptance_criteria_count": 12,
    "all_criteria_testable": true,
    "untestable_criteria": []
  },
  "envelope_version": "1.0.0"
}
```

---

## scope-analysis.json Schema

The output artifact written to `docs/scope-analysis.json`:

```json
{
  "components": [
    {
      "name": "UserService",
      "responsibility": "Handle user CRUD operations",
      "layer": "service",
      "files": ["src/services/user.ts"]
    }
  ],
  "data_models": [
    {
      "name": "User",
      "fields": ["id", "email", "password_hash", "created_at"],
      "relationships": ["has_many: sessions"]
    }
  ],
  "api_contracts": [
    {
      "method": "POST",
      "path": "/api/users",
      "request": { "body": { "email": "string", "password": "string" } },
      "response": { "status": 201, "body": { "id": "string", "email": "string" } }
    }
  ],
  "external_dependencies": [
    { "name": "bcrypt", "purpose": "Password hashing" }
  ],
  "acceptance_criteria": [
    {
      "id": "AC-001",
      "criterion": "User must be able to register with email and password",
      "testable": true,
      "pattern": "assertion",
      "test_assertion_template": "expect(response.status).toBe(201)",
      "source_story": "US-001"
    }
  ],
  "jit_context_refs": {
    "by_component": {
      "UserService": {
        "interface_locations": ["TECHNICAL_DESIGN.md:## UserService"],
        "pattern_files": ["src/services/base.ts"],
        "grep_patterns": ["export class.*Service"],
        "constraints_section": "ADR.md:## Decision 1"
      }
    }
  },
  "non_scope": ["Payment processing", "Email verification"],
  "change_impact_map": {
    "direct": ["src/services/", "src/models/"],
    "indirect": ["src/middleware/auth.ts"]
  },
  "testing_strategy": "Unit tests for models/services, integration tests for API endpoints",
  "traceability": {
    "user_stories": {},
    "acceptance_criteria": {},
    "adr_decisions": {}
  }
}
```

---

## Process

### 1. Read All Spec Documents

Read spec documents from paths in `state.json`:

```bash
cd "$WORKTREE_PATH"

# Read state.json to get spec paths
jq -r '.spec_paths | to_entries[] | "\(.key): \(.value)"' state.json
```

Read each document:
- **PRD.md** — User stories, acceptance criteria, success metrics
- **ADR.md** — Architecture decisions and rationale
- **TECHNICAL_DESIGN.md** — Components, data models, API contracts, dependencies
- **WIREFRAMES.md** — UI layouts and user flows (if applicable)

Also read:
- `CLAUDE.md` — Project conventions and patterns

**Important:** Always use absolute paths from `state.json.spec_paths`.

### 2. Extract Components, Data Models, API Contracts, Dependencies

From TECHNICAL_DESIGN.md, extract:

```bash
# Extract component headers
grep -E "^#{1,3} " "$TECH_DESIGN_PATH"

# Extract data models
grep -A 30 "## Data Model" "$TECH_DESIGN_PATH"

# Extract API contracts
grep -A 30 "## API" "$TECH_DESIGN_PATH"

# Extract external dependencies
grep -A 20 "## Dependencies\|## External" "$TECH_DESIGN_PATH"
```

Classify each component by layer:
- `data` — Models, schemas, migrations
- `service` — Business logic, services
- `api` — Routes, endpoints, controllers
- `ui` — Components, pages, layouts

### 3. Validate AC Testability

Check each AC against EARS patterns: When/While/If/The system shall, quantitative thresholds, legacy Given/When/Then. Reject: adjective-only, vague outcomes, no thresholds, passive voice, missing "shall". Mark untestable ACs.

### 4. Generate Test Assertion Templates
Map each valid AC → test assertion template (e.g., "API returns X" → `expect(response.body).toEqual(X)`).

### 5. Create JIT Context Refs
Per component: interface_locations (file:section), pattern_files (discover via grep in src/), grep_patterns, constraints_section (ADR/TECHNICAL_DESIGN reference).

### 6. Extract Non-Scope & Change Impact Map
From TECHNICAL_DESIGN: non-scope/exclusions section + impact/affected sections. Extract traceability from state.json.

### 8. Write scope-analysis.json

Assemble all extracted data into `docs/scope-analysis.json`:

```bash
cd "$WORKTREE_PATH"
mkdir -p docs

# Write the scope analysis file
cat > docs/scope-analysis.json << 'SCOPE_EOF'
{
  "components": [...],
  "data_models": [...],
  "api_contracts": [...],
  "external_dependencies": [...],
  "acceptance_criteria": [...],
  "jit_context_refs": { "by_component": {...} },
  "non_scope": [...],
  "change_impact_map": { "direct": [...], "indirect": [...] },
  "testing_strategy": "...",
  "traceability": {...}
}
SCOPE_EOF
```

### 9. Update State and Commit

```bash
cd "$WORKTREE_PATH"

# Update state.json phase
jq '.phase = "task_decomposition"' state.json > tmp.json && mv tmp.json state.json

# Commit scope analysis
git add docs/scope-analysis.json state.json
git commit -m "scope: extract scope analysis from specifications

Components: N, Acceptance Criteria: N
All criteria testable: yes/no"
```

### 10. Emit Signal

Return the `SCOPE_ANALYSIS_COMPLETE` signal:

```json
{
  "signal": "SCOPE_ANALYSIS_COMPLETE",
  "timestamp": "<ISO8601>",
  "source": { "skill": "homerun:scope-analysis" },
  "payload": {
    "scope_file": "docs/scope-analysis.json",
    "components_count": N,
    "acceptance_criteria_count": N,
    "all_criteria_testable": true,
    "untestable_criteria": []
  },
  "envelope_version": "1.0.0"
}
```

**Do NOT spawn the next phase.** Return after emitting this signal.

---

## Exit Criteria

- [ ] Specs read; components/models/contracts/deps extracted; ACs validated with test templates
- [ ] JIT context refs created; non-scope + impact map extracted; traceability preserved
- [ ] `docs/scope-analysis.json` committed; phase → `task_decomposition`; signal emitted
