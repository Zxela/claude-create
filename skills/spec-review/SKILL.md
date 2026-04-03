---
name: spec-review
description: "[sonnet] Review specification documents for consistency, completeness, and testability before planning"
model: sonnet
color: orange
---

# Spec Review Skill

## References

`references/signal-contracts.json` · `references/context-engineering.md` · `references/discovery-questions.md` · `references/scale-determination.md`

## Overview

Validate discovery output (PRD, ADR, TECHNICAL_DESIGN) for consistency, completeness, and testability. Quality gate between discovery and planning. **Model: sonnet. Budget: < 15K tokens.**

---

## Input Schema (JSON)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["worktree_path", "spec_paths"],
  "properties": {
    "worktree_path": { "type": "string" },
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

### Example Input

```json
{
  "worktree_path": "../myapp-create-user-auth-a1b2c3d4",
  "spec_paths": {
    "prd": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4/PRD.md",
    "adr": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4/ADR.md",
    "technical_design": "/home/user/.claude/homerun/a1b2c3d4/user-auth-a1b2c3d4/TECHNICAL_DESIGN.md",
    "wireframes": null
  },
  "config": { "auto_mode": false }
}
```

---

## Process

### 1. Cross-Document Consistency
Grep entity names across docs. Check: PRD entity not in TECHNICAL_DESIGN (high), ADR contradicts TECHNICAL_DESIGN (high), PRD references undefined API (medium), non-goals implemented (medium), unmeasurable metrics (low).

### 2. Completeness Check
**PRD:** problem statement, 1+ goals, 1+ non-goals, user stories with testable ACs. **ADR:** context/drivers, 2+ options, decision+rationale, consequences. **TECHNICAL_DESIGN:** architecture, data models, API contracts, deps, security, testing strategy.

### 3. Testability Audit
Every PRD AC must match behavioral (Given/When/Then), assertion, or quantitative patterns. Flag untestable ACs.

### 4. Design Sync
Flag explicit conflicts: type mismatches, numeric disagreements, integration point mismatches, missing entities. Only explicit conflicts — omissions handled in step 2.

### 4.5-4.6. Template Version & Scope Cohesion (Advisory)
Template version: informational only (low/style). Scope cohesion: components >8 (medium), user types >3 (medium), non-scope >5 (low). Advisory — does not block approval. Category: `scope_cohesion`.

### 5. Generate Review Report

Structured report: summary (docs reviewed, issue counts, verdict) → high severity (must fix) → medium (should fix) → low (optional). Each issue: category, description, file:line, fix.

---

## Output Schema (JSON)

### Pass: SPEC_REVIEW_COMPLETE

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["signal", "verdict", "issues"],
  "properties": {
    "signal": { "const": "SPEC_REVIEW_COMPLETE" },
    "verdict": { "enum": ["approved", "approved_with_scope_warning", "needs_revision"] },
    "issues": {
      "type": "object",
      "properties": {
        "high": { "type": "integer" },
        "medium": { "type": "integer" },
        "low": { "type": "integer" }
      }
    },
    "details": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["severity", "category", "description", "file", "fix"],
        "properties": {
          "severity": { "enum": ["high", "medium", "low"] },
          "category": { "enum": ["contradiction", "incomplete", "untestable", "missing_entity", "style", "scope_cohesion"] },
          "description": { "type": "string" },
          "file": { "type": "string" },
          "fix": { "type": "string" }
        }
      }
    }
  }
}
```

**Example (approved):**

```json
{
  "signal": "SPEC_REVIEW_COMPLETE",
  "verdict": "approved",
  "issues": { "high": 0, "medium": 1, "low": 2 },
  "details": [
    {
      "severity": "medium",
      "category": "incomplete",
      "description": "TECHNICAL_DESIGN missing error handling for /register endpoint",
      "file": "TECHNICAL_DESIGN.md",
      "fix": "Add error responses table"
    }
  ]
}
```

**Example (needs revision):**

```json
{
  "signal": "SPEC_REVIEW_COMPLETE",
  "verdict": "needs_revision",
  "issues": { "high": 2, "medium": 1, "low": 0 },
  "details": [
    {
      "severity": "high",
      "category": "contradiction",
      "description": "PRD requires password >= 12 chars but ADR specifies 8 char minimum",
      "file": "PRD.md:45, ADR.md:23",
      "fix": "Align on single password length requirement"
    }
  ]
}
```

### Validation Error: VALIDATION_ERROR

Return if input validation fails (see `references/signal-contracts.json`).

---

## Verdict Rules

| Condition | Verdict |
|-----------|---------|
| 0 high severity issues, no scope cohesion warnings | `approved` |
| 0 high severity issues, scope cohesion warnings present | `approved_with_scope_warning` |
| Any high severity issues | `needs_revision` |

**Medium and low issues are reported but do not block planning.**

When verdict is `needs_revision`:
- Present the high-severity issues to the user
- User must resolve them before planning proceeds
- After fixes, re-run spec review

When verdict is `approved_with_scope_warning`:
- Specs are complete and testable, but scope decomposition might be beneficial
- Present scope cohesion warnings alongside any other medium/low issues
- In auto_mode: proceed to planning (log warnings)
- In interactive mode: ask user whether to split scope or proceed as-is

When verdict is `approved` with medium/low issues:
- Present issues as advisory
- In auto_mode: proceed to planning
- In interactive mode: ask user whether to fix or proceed

---

## Exit Criteria

- [ ] All docs analyzed; consistency, completeness, testability checked; verdict determined; signal emitted

## Context Budget: ~15K
Spec docs ~6K | Analysis ~4K | Report ~2K | Buffer ~3K
