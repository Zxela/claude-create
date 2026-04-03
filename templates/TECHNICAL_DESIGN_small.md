---
template_version: "1.1"
template_name: "TECHNICAL_DESIGN_small"
compatible_homerun: ">=5.0.0"
---

# Technical Design: {{FEATURE_NAME}}

<!--
SMALL-SCALE TEMPLATE (1-2 files)
Focused subset of the full TECHNICAL_DESIGN template for small features.
Omits: Architecture diagrams, Dependencies, NFRs, Migration/Rollback,
       Observability, Error Handling (overkill at this scale).
INCLUDES: Overview, what to change, data models, API contracts,
          testing strategy, change impact, agreement checklist
EXCLUDES: Business motivation, user stories (-> PRD)
          Decision rationale, option comparisons (-> ADR)
-->

## Overview

{{1-2 sentence summary of what this change does}}

## What to Change

| File | Lines | Change Description |
|------|-------|--------------------|
| {{file path}} | {{line range}} | {{what to modify}} |

### Patterns to Follow

| Pattern | Source |
|---------|--------|
| {{Pattern name}} | {{file path}} |

## Data Models

_Skip this section if no data model changes._

### {{Model Name}}

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| {{field}} | {{type}} | {{constraints}} | {{description}} |

## API Contracts

_Skip this section if no API changes._

### {{Endpoint Name}}

**Method:** `{{HTTP_METHOD}}`
**Path:** `{{/api/path}}`

**Request:**
```json
{
  "{{field}}": "{{type}} - {{description}}"
}
```

**Response (Success):**
```json
{
  "{{field}}": "{{type}} - {{description}}"
}
```

## Testing Strategy

| Component | Test File | Coverage Focus |
|-----------|-----------|----------------|
| {{name}} | {{path}} | {{what to test}} |

## Change Impact Map

### Direct Impact (files being modified)

| File/Module | Change Description |
|-------------|-------------------|
| {{path}} | {{what changes}} |

### Indirect Impact (files that import/use changed code)

| File/Module | Dependency | Verification |
|-------------|-----------|--------------|
| {{path}} | Imports {{symbol}} from {{changed file}} | {{How to verify no breakage}} |

### No Ripple Effect (explicitly unaffected)

- {{Feature/module confirmed unaffected and why}}

## Agreement Checklist

- [ ] **Scope**: {{What changes — list of files}}
- [ ] **Non-scope**: {{What explicitly does NOT change}}
- [ ] **Testing**: {{Test strategy — which tests to add/modify}}
