---
template_version: "1.1"
template_name: "PRD"
compatible_homerun: ">=5.0.0"
---

# PRD: {{FEATURE_NAME}}

<!--
INCLUDES: Business value, user stories, acceptance criteria, success metrics, constraints, risks
EXCLUDES: Implementation details, technical architecture, code-level decisions (→ TECHNICAL_DESIGN)
          Decision rationale, option comparisons (→ ADR)
          UI layouts, visual flows (→ WIREFRAMES)
-->

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

## Functional Requirements

_What the system must DO. Prioritized using MoSCoW._

### Must Have (MVP)

| ID | Requirement | Acceptance Criteria |
|----|-------------|---------------------|
| FR-001 | {{Core requirement}} | {{EARS-format AC}} |
| FR-002 | {{Core requirement}} | {{EARS-format AC}} |

### Should Have

| ID | Requirement | Acceptance Criteria |
|----|-------------|---------------------|
| FR-003 | {{Important but not blocking}} | {{EARS-format AC}} |

### Could Have

| ID | Requirement | Notes |
|----|-------------|-------|
| FR-004 | {{Nice-to-have enhancement}} | {{Deferrable to later iteration}} |

### Won't Have (this iteration)

- {{Explicitly excluded functional requirement — with reason}}

## Non-Functional Requirements

_How well the system must PERFORM those functions. Each MUST have a quantified target._

| Category | Requirement | Target | How Measured |
|----------|-------------|--------|--------------|
| **Performance** | {{Response time, throughput}} | {{e.g., < 200ms p95}} | {{APM / load test}} |
| **Reliability** | {{Availability, error rate}} | {{e.g., 99.9% uptime}} | {{Monitoring}} |
| **Security** | {{Auth, encryption, audit}} | {{e.g., OWASP Top 10 compliant}} | {{Security review}} |
| **Scalability** | {{Growth handling}} | {{e.g., 10K concurrent users}} | {{Load test}} |

_Omit categories that don't apply. Do NOT pad with generic "should be secure" — either quantify or omit._

## User Stories

### US-001: {{User Story Title}}

**As a** {{user type}}
**I want** {{action/capability}}
**So that** {{benefit/value}}

**Acceptance Criteria:**

_Each criterion MUST use EARS format (Easy Approach to Requirements Syntax):_

| EARS Pattern | Format | Example |
|--------------|--------|---------|
| **Event-driven** | **When** [trigger], the system **shall** [response] | When user submits invalid email, the system shall display "Please enter a valid email" below the field |
| **State-driven** | **While** [state], the system **shall** [behavior] | While user is unauthenticated, the system shall redirect all /dashboard requests to /login |
| **Conditional** | **If** [condition], **then** the system **shall** [response] | If the session token is expired, then the system shall return 401 and clear the refresh token |
| **Unconditional** | The system **shall** [behavior] | The system shall hash passwords using bcrypt with cost factor 12 before storage |
| **Quantitative** | [Subject] **shall** [verb] within/under [threshold] | The API shall respond to login requests within 200ms at p95 |

- [ ] AC-001: {{EARS-format criterion with observable outcome}}
- [ ] AC-002: {{EARS-format criterion}}
- [ ] AC-003: {{EARS-format criterion}}

**Invalid criteria (do not use):**
- "Should be user-friendly" (no observable outcome — ask: what specific action should be easy?)
- "Should work correctly" (vague — ask: what does correct behavior look like?)
- "Must be fast" (no threshold — ask: what response time is acceptable?)
- "Errors are handled" (passive/vague — ask: what should the user see when X fails?)

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
