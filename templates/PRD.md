---
template_version: "1.0"
template_name: "PRD"
compatible_homerun: ">=5.0.0"
---

# PRD: {{FEATURE_NAME}}

## Problem Statement

{{2-3 sentences describing the problem this feature solves. Who has this problem? Why does it matter?}}

## Goals

1. {{Primary goal - what success looks like}}
2. {{Secondary goal}}
3. {{Tertiary goal}}

## Non-Goals

- {{What we are explicitly NOT doing}}
- {{Out of scope item}}
- {{Future consideration, not now}}

## Success Metrics

_Each metric MUST have a quantifiable target._

| Metric | Current | Target | How Measured |
|--------|---------|--------|--------------|
| {{metric}} | {{baseline}} | {{goal}} | {{measurement method}} |

**Examples of good metrics:**
| Metric | Current | Target | How Measured |
|--------|---------|--------|--------------|
| User registration completion rate | N/A | > 80% | Analytics: registrations / registration starts |
| Login API response time (p95) | N/A | < 200ms | APM monitoring |

**Invalid metrics (avoid):**
- "Users are happy" (not measurable)
- "System performs well" (no threshold)
- "Fewer bugs" (no baseline or target)

## User Stories

### US-001: {{User Story Title}}

**As a** {{user type}}
**I want** {{action/capability}}
**So that** {{benefit/value}}

**Acceptance Criteria:**

_Each criterion MUST follow one of these testable patterns:_

| Pattern | Format | Example |
|---------|--------|---------|
| Behavioral | Given [context], when [action], then [outcome] | Given a logged-in user, when they click logout, then their session is destroyed |
| Assertion | [Subject] should/must/can [verb] [observable outcome] | User must see an error message when email is invalid |
| Quantitative | [Subject] [comparison] [threshold] | API response time must be < 500ms |

- [ ] AC-001: {{Testable criterion with observable outcome}}
- [ ] AC-002: {{Testable criterion}}
- [ ] AC-003: {{Testable criterion}}

**Invalid criteria (do not use):**
- "Should be user-friendly" (no observable outcome)
- "Should work correctly" (vague)
- "Must be fast" (no threshold)

### US-002: {{User Story Title}}

**As a** {{user type}}
**I want** {{action/capability}}
**So that** {{benefit/value}}

**Acceptance Criteria:**
- [ ] AC-004: {{Testable criterion}}
- [ ] AC-005: {{Testable criterion}}

## User Flows

### Flow 1: {{Flow Name}}

```
1. User {{action}}
2. System {{response}}
3. User {{action}}
4. System {{response}}
5. Done: {{end state}}
```

## Constraints

### Technical
- {{Technical constraint}}

### Business
- {{Business constraint}}

### Timeline
- {{Timeline constraint}}

## Dependencies

| Dependency | Type | Status | Notes |
|------------|------|--------|-------|
| {{name}} | Internal/External | Ready/Pending | {{notes}} |

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| {{risk}} | High/Medium/Low | High/Medium/Low | {{mitigation}} |

## Open Questions

- [ ] {{Question needing answer}}

## Appendix

### Glossary

| Term | Definition |
|------|------------|
| {{term}} | {{definition}} |

### References

- {{Link to related documentation}}
