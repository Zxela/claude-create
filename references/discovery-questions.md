# Discovery Question Reference

Quick reference for discovery phase dialogue. Ask ONE question at a time.

## Categories to Cover

### 1. Purpose & Goals
- What is the primary goal? (new feature / improvement / bug fix / refactor)
- What problem does this solve?
- What does success look like?

### 2. Users & Personas
- Who will use this? (end users / internal / API consumers / admins)
- What's their technical level?
- How frequently will they use it?

### 3. Scope & Boundaries
- What scope for v1? (minimal / standard / comprehensive)
- What's explicitly out of scope?

### 4. Technical Constraints
- Integration requirements?
- Performance requirements?
- Security/compliance needs?

### 5. Edge Cases & Error Handling
- How should errors be handled? (fail fast / degrade / retry / queue)
- What are the boundary conditions?

## Testable Acceptance Criteria

Guide users toward testable patterns:

| Vague | Testable |
|-------|----------|
| "Should be user-friendly" | "User can complete checkout in < 3 clicks" |
| "Should work correctly" | "Returns HTTP 200 with user data" |
| "Must be fast" | "Response time < 200ms for 95th percentile" |
| "Handle errors properly" | "Display error message and preserve form input" |

**Valid patterns:**
- Behavioral: "Given X, when Y, then Z"
- Assertion: "User must see X when Y"
- Quantitative: "X must be < N"

## Dialogue Limits

- Warning at 15 turns
- Hard limit at 20 turns
- Mark category complete after 2+ substantive answers
