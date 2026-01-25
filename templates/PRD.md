# Product Requirements Document: {{FEATURE_NAME}}

## Problem Statement

_Describe the problem this feature solves. What pain points exist today? Who is affected?_

## Goals

_What are we trying to achieve with this feature?_

- [ ] Goal 1
- [ ] Goal 2
- [ ] Goal 3

## Non-Goals

_What is explicitly out of scope for this feature?_

- Non-goal 1
- Non-goal 2

## User Stories

_Describe the feature from the user's perspective._

### Story 1: {{STORY_TITLE}}
**ID:** US-001
**As a** [type of user]
**I want** [some goal]
**So that** [some reason]

**Acceptance Criteria:**

_Each criterion MUST follow one of these testable patterns:_

| Pattern | Format | Example |
|---------|--------|---------|
| Behavioral | Given [context], when [action], then [outcome] | Given a logged-in user, when they click logout, then their session is destroyed |
| Assertion | [Subject] should/must/can [verb] [observable outcome] | User must see an error message when email is invalid |
| Quantitative | [Subject] [comparison] [threshold] | API response time must be < 500ms |

- [ ] AC-001: _Testable criterion using one of the patterns above_
- [ ] AC-002: _Testable criterion using one of the patterns above_

**Invalid criteria (do not use):**
- ❌ "Should be user-friendly" (no observable outcome)
- ❌ "Should work correctly" (vague)
- ❌ "Must be fast" (no threshold)

### Story 2: {{STORY_TITLE}}
**ID:** US-002
**As a** [type of user]
**I want** [some goal]
**So that** [some reason]

**Acceptance Criteria:**
- [ ] AC-003: _Testable criterion_
- [ ] AC-004: _Testable criterion_

## Success Metrics

_How will we measure if this feature is successful? Each metric MUST have a quantifiable target._

| ID | Metric | Current | Target | How to Measure |
|----|--------|---------|--------|----------------|
| SM-001 | _Metric name_ | _Baseline value or "N/A"_ | _Specific number (e.g., "> 95%", "< 200ms")_ | _Measurement method_ |
| SM-002 | _Metric name_ | _Baseline value_ | _Specific number_ | _Measurement method_ |

**Examples of good metrics:**
| ID | Metric | Current | Target | How to Measure |
|----|--------|---------|--------|----------------|
| SM-001 | User registration completion rate | N/A | > 80% | Analytics: registrations / registration starts |
| SM-002 | Login API response time (p95) | N/A | < 200ms | APM monitoring |
| SM-003 | Failed login attempts before lockout | N/A | 5 attempts | Auth service logs |

**Invalid metrics (avoid):**
- ❌ "Users are happy" (not measurable)
- ❌ "System performs well" (no threshold)
- ❌ "Fewer bugs" (no baseline or target)

## Open Questions

_List any unresolved questions that need answers before or during implementation._

- [ ] Question 1
- [ ] Question 2
- [ ] Question 3
