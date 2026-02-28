---
template_version: "1.1"
template_name: "TECHNICAL_DESIGN"
compatible_homerun: ">=5.0.0"
---

# Technical Design: {{FEATURE_NAME}}

<!--
INCLUDES: Architecture, components, data models, API contracts, dependencies, testing strategy,
          existing codebase analysis, integration points, change impact, agreement checklist
EXCLUDES: Business motivation, user stories, success metrics (→ PRD)
          Decision rationale, option comparisons (→ ADR)
          UI layouts, visual flows (→ WIREFRAMES)
-->

## Overview

{{1-2 paragraph summary of what this feature does and why}}

## Existing Codebase Analysis

_What already exists that this feature builds on or interacts with. Prevents duplication and ensures alignment._

### Related Functionality

| Existing Code | Relevance | Action |
|---------------|-----------|--------|
| {{file:line — description}} | Extends / Uses / Replaces | {{How this feature relates}} |

### Patterns to Follow

| Pattern | Source | Example |
|---------|--------|---------|
| {{Pattern name}} | {{file path}} | {{Brief description of the convention}} |

### Integration Point Map

_Where this feature connects to existing code. Each point needs verification after implementation._

| Integration Point | Existing Code | Impact Level | Verification |
|-------------------|--------------|--------------|--------------|
| {{description}} | {{file:function}} | High / Medium / Low | {{How to verify no breakage}} |

**Impact levels:**
- **High** — Changes data flow or control flow through existing code
- **Medium** — Changes data used by existing code (types, schemas)
- **Low** — Read-only interaction (imports types, calls existing functions without modification)

## Architecture

### System Context

```
{{ASCII diagram showing where this feature fits in the broader system}}
```

### Component Diagram

```
{{ASCII diagram showing internal components and their relationships}}
```

### Data Flow

```
{{Step-by-step data flow through the system, e.g.:
1. User Action
2. Frontend Processing
3. API Request
4. Backend Processing
5. Data Storage
6. Response}}
```

## Data Models

### {{Model Name}}

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | {{description}} |
| {{field}} | {{type}} | {{constraints}} | {{description}} |

### Relationships

```
{{Entity relationship diagram in ASCII}}
```

## API Contracts

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

**Response (Error):**
```json
{
  "error": {
    "code": "{{ERROR_CODE}}",
    "message": "{{Human readable message}}"
  }
}
```

**Status Codes:**
| Code | Meaning |
|------|---------|
| 200 | {{Success case}} |
| 400 | {{Validation error}} |
| 401 | {{Authentication required}} |
| 404 | {{Resource not found}} |

## Dependencies

### Internal

| Dependency | Purpose | Import Path |
|------------|---------|-------------|
| {{name}} | {{why needed}} | {{path}} |

### External

| Package | Version | Purpose |
|---------|---------|---------|
| {{name}} | {{version}} | {{why needed}} |

## Non-Functional Requirements (Implementation)

_Technical approach for meeting NFR targets from the PRD. Only include categories relevant to this feature._

### Performance

| Metric | Target | Implementation Approach |
|--------|--------|------------------------|
| {{e.g., API response time}} | {{e.g., < 200ms p95}} | {{e.g., Database index on email column, query caching}} |

### Security

| Concern | Approach | Verification |
|---------|----------|--------------|
| {{e.g., Password storage}} | {{e.g., bcrypt with cost factor 12}} | {{Unit test: hash is not plaintext}} |
| {{e.g., Input validation}} | {{e.g., Zod schema validation at API boundary}} | {{Test: malformed input returns 400}} |

### Reliability

| Failure Mode | Handling | Recovery |
|-------------|----------|----------|
| {{e.g., Database connection lost}} | {{e.g., Connection pool retry with backoff}} | {{e.g., Auto-reconnect, request queued}} |

## Error Handling

| Error Case | Response | Recovery |
|------------|----------|----------|
| {{case}} | {{what happens}} | {{how to recover}} |

## Testing Strategy

### Unit Tests

| Component | Test File | Coverage Focus |
|-----------|-----------|----------------|
| {{name}} | {{path}} | {{what to test}} |

### Integration Tests

| Scenario | Test File | Setup Required |
|----------|-----------|----------------|
| {{scenario}} | {{path}} | {{setup}} |

### Performance Tests

| Metric | Target | Test Method |
|--------|--------|-------------|
| {{metric}} | {{target}} | {{how to measure}} |

## Migration Plan

{{If this changes existing data/behavior, how to migrate}}

## Rollback Plan

{{How to revert if something goes wrong}}

## Observability

### Logging

| Event | Level | Data |
|-------|-------|------|
| {{event}} | {{INFO/WARN/ERROR}} | {{what to log}} |

### Metrics

| Metric | Type | Description |
|--------|------|-------------|
| {{name}} | {{counter/gauge/histogram}} | {{what it measures}} |

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

_Before implementation begins, confirm agreement on each item._

- [ ] **Scope**: {{What changes — list of components/files}}
- [ ] **Non-scope**: {{What explicitly does NOT change — preserve list}}
- [ ] **Constraints**: {{Backward compatibility, parallel operation, performance requirements}}
- [ ] **Testing**: {{Test strategy — unit, integration, e2e coverage expectations}}
- [ ] **Rollback**: {{How to revert if something goes wrong}}

## Open Questions

- [ ] {{Question that needs resolution}}
