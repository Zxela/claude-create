# Discovery Dialogue Examples

Reference examples for the discovery phase dialogue patterns.

## Question Patterns by Category

### Purpose & Goals

```
What is the primary goal of this feature?

A) Add new functionality that doesn't exist yet
B) Improve or extend existing functionality
C) Fix a bug or address a limitation
D) Refactor for maintainability or performance
E) Something else (please describe)
```

### Users & Personas

```
Who will primarily use this feature?

A) End users (customers/public)
B) Internal team members
C) API consumers / developers
D) Administrators / operators
E) Multiple user types (please specify)
```

### Scope & Boundaries

```
Which scope level fits best for the initial implementation?

A) Minimal - Core functionality only, bare essentials
B) Standard - Core plus common use cases
C) Comprehensive - Full feature set with edge cases
D) Let me describe the specific scope...
```

### Technical Constraints

```
Are there specific technical constraints to consider?

A) Must integrate with existing [system/API]
B) Has performance requirements (latency, throughput)
C) Security/compliance requirements (auth, encryption, audit)
D) Must support specific platforms/browsers
E) No special constraints
F) Multiple constraints (please list)
```

### Edge Cases & Error Handling

```
How should the feature handle errors?

A) Fail fast with clear error messages
B) Gracefully degrade with fallback behavior
C) Retry automatically with backoff
D) Queue for manual review
E) Depends on the error type (let's discuss)
```

---

## Testable Acceptance Criteria

### Valid Patterns

| Pattern | Example |
|---------|---------|
| Behavioral (Given/When/Then) | "Given a logged-in user, when they click logout, then their session is destroyed" |
| Assertion (should/must/can) | "User must see an error message when submitting an empty form" |
| Quantitative | "API response time must be < 500ms for 99% of requests" |

### Invalid Patterns to Transform

| User Says | Problem | Guide Toward |
|-----------|---------|--------------|
| "Should be user-friendly" | Adjective only | "What specific action should users complete easily?" |
| "Should work correctly" | No observable outcome | "What does 'correctly' look like?" |
| "Must be fast" | No threshold | "How fast? E.g., 'Response time < 200ms'" |
| "Handle errors properly" | Vague handling | "What should happen on error?" |

### Transformation Examples

| Vague Criterion | Testable Version |
|-----------------|------------------|
| "Login should be secure" | "Failed login attempts are rate-limited to 5 per minute" |
| "Page loads quickly" | "Initial page render completes in < 2 seconds on 3G" |
| "Errors are handled" | "On API error, show error toast and preserve form input" |
| "Works on mobile" | "UI is usable on viewport width >= 320px" |

---

## Validation Dialogue Flow

### Section-by-Section Confirmation

After presenting each section (200-300 words):

```
Does this accurately capture your intent?

Options:
- [Confirmed] - Move to next section
- [Minor edits] - I'll describe what to change
- [Major revision] - Let's discuss this further
```

### Handling Revisions

For minor edits:
```
User: "Change 'users can' to 'administrators can'"
Assistant: Updated. Here's the revised section: [...]
Does this look correct now?
```

For major revisions:
```
User: "Actually, we need OAuth instead of username/password"
Assistant: That's a significant change to the authentication approach.
Let me ask a few follow-up questions to update the design...
```

---

## Complete Dialogue Example

```
User: "I want to add a dark mode toggle to the app"