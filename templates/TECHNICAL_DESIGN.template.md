# Technical Design: {{FEATURE_NAME}}

## Overview

{{1-2 paragraph summary of what this feature does and why}}

## Architecture

### System Context

```
{{ASCII diagram showing where this feature fits in the broader system}}
```

### Component Diagram

```
{{ASCII diagram showing internal components and their relationships}}
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

## Security Considerations

### Authentication

{{How users are authenticated for this feature}}

### Authorization

{{What permissions are required, how they're checked}}

### Data Protection

{{How sensitive data is handled, encryption, etc.}}

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

## Open Questions

- [ ] {{Question that needs resolution}}
