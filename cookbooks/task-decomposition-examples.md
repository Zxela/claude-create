# Task Decomposition Examples

Reference examples for decomposing tasks according to the rules in `skills/planning/SKILL.md`.

## Example 1: User Authentication Feature

### Original Task (Too Large)

```json
{
  "id": "001",
  "title": "Implement user authentication",
  "acceptance_criteria": [
    "AC-001: User can register with email/password",
    "AC-002: User can login and receive JWT",
    "AC-003: Protected routes require valid JWT",
    "AC-004: User can logout (invalidate token)",
    "AC-005: Password reset via email"
  ]
}
```

**Why decompose:** 5 acceptance criteria (> 3 threshold), crosses multiple layers (model, service, middleware, endpoints).

### Decomposed (Correct)

```json
[
  {
    "id": "001a",
    "title": "Create User model",
    "task_type": "add_field",
    "acceptance_criteria": [{ "id": "AC-001a", "criterion": "User model exists with id, email, password_hash fields" }],
    "model": "haiku",
    "blocked_by": []
  },
  {
    "id": "001b",
    "title": "Add password hashing to User",
    "task_type": "add_method",
    "acceptance_criteria": [{ "id": "AC-001b", "criterion": "Password is hashed with bcrypt on creation" }],
    "model": "haiku",
    "blocked_by": ["001a"]
  },
  {
    "id": "001c",
    "title": "Create AuthService.register()",
    "task_type": "create_service",
    "acceptance_criteria": [{ "id": "AC-001", "criterion": "User can register with email/password" }],
    "model": "sonnet",
    "blocked_by": ["001b"]
  },
  {
    "id": "001d",
    "title": "Create AuthService.login()",
    "task_type": "add_method",
    "acceptance_criteria": [{ "id": "AC-002", "criterion": "User can login and receive JWT" }],
    "model": "sonnet",
    "blocked_by": ["001c"]
  },
  {
    "id": "001e",
    "title": "Add JWT middleware",
    "task_type": "create_middleware",
    "acceptance_criteria": [{ "id": "AC-003", "criterion": "Protected routes require valid JWT" }],
    "model": "sonnet",
    "blocked_by": ["001d"]
  },
  {
    "id": "001f",
    "title": "Add logout endpoint",
    "task_type": "add_endpoint",
    "acceptance_criteria": [{ "id": "AC-004", "criterion": "User can logout (invalidate token)" }],
    "model": "haiku",
    "blocked_by": ["001e"]
  },
  {
    "id": "001g",
    "title": "Implement password reset",
    "task_type": "add_endpoint_complex",
    "acceptance_criteria": [{ "id": "AC-005", "criterion": "Password reset via email" }],
    "model": "sonnet",
    "blocked_by": ["001c"]
  }
]
```

---

## Example 2: Simple API Endpoint (No Decomposition)

### Original Task

```json
{
  "id": "002",
  "title": "Add GET /users endpoint",
  "task_type": "add_endpoint",
  "acceptance_criteria": [
    { "id": "AC-002", "criterion": "Returns list of users with pagination" }
  ],
  "model": "haiku"
}
```

**Decision:** Do NOT decompose.
- Single acceptance criterion
- Haiku task type (not decomposable)
- Single endpoint, single concern

---

## Example 3: Service with Multiple Methods

### Original Task

```json
{
  "id": "003",
  "title": "Create NotificationService",
  "task_type": "create_service",
  "acceptance_criteria": [
    "AC-001: Can send email notifications",
    "AC-002: Can send push notifications",
    "AC-003: Can queue notifications for batch sending",
    "AC-004: Tracks notification delivery status"
  ]
}
```

**Why decompose:** 4 acceptance criteria, `create_service` is marked as decomposable in model-routing.json.

### Decomposed

```json
[
  {
    "id": "003a",
    "title": "Create NotificationService interface",
    "task_type": "add_field",
    "acceptance_criteria": [{ "id": "AC-003a", "criterion": "NotificationService class exists with interface" }],
    "model": "haiku",
    "blocked_by": []
  },
  {
    "id": "003b",
    "title": "Implement email notification sending",
    "task_type": "add_method",
    "acceptance_criteria": [{ "id": "AC-001", "criterion": "Can send email notifications" }],
    "model": "haiku",
    "blocked_by": ["003a"]
  },
  {
    "id": "003c",
    "title": "Implement push notification sending",
    "task_type": "add_method",
    "acceptance_criteria": [{ "id": "AC-002", "criterion": "Can send push notifications" }],
    "model": "haiku",
    "blocked_by": ["003a"]
  },
  {
    "id": "003d",
    "title": "Add notification queue for batching",
    "task_type": "add_method",
    "acceptance_criteria": [{ "id": "AC-003", "criterion": "Can queue notifications for batch sending" }],
    "model": "sonnet",
    "blocked_by": ["003b", "003c"]
  },
  {
    "id": "003e",
    "title": "Add delivery status tracking",
    "task_type": "add_method",
    "acceptance_criteria": [{ "id": "AC-004", "criterion": "Tracks notification delivery status" }],
    "model": "haiku",
    "blocked_by": ["003d"]
  }
]
```

---

## Example 4: Compound Title Detection

### Original Task

```json
{
  "id": "004",
  "title": "Create order AND send confirmation email",
  "task_type": "create_service",
  "acceptance_criteria": [
    "AC-001: Order is created with items",
    "AC-002: Confirmation email is sent after order creation"
  ]
}
```

**Why decompose:** Title contains "AND" connecting distinct operations.

### Decomposed

```json
[
  {
    "id": "004a",
    "title": "Create order with items",
    "task_type": "create_service",
    "acceptance_criteria": [{ "id": "AC-001", "criterion": "Order is created with items" }],
    "model": "sonnet",
    "blocked_by": []
  },
  {
    "id": "004b",
    "title": "Send order confirmation email",
    "task_type": "add_method",
    "acceptance_criteria": [{ "id": "AC-002", "criterion": "Confirmation email is sent after order creation" }],
    "model": "haiku",
    "blocked_by": ["004a"]
  }
]
```

---

## Decision Matrix

| Original Task | AC Count | Decomposable Type | Contains "AND" | Action |
|---------------|----------|-------------------|----------------|--------|
| Add user email field | 1 | no | no | Keep as-is |
| Create User model | 3 | yes | no | Consider decomposing |
| Implement auth system | 5 | yes | no | MUST decompose |
| Create order AND notify | 2 | yes | yes | MUST decompose |
| Fix login bug | 1 | no | no | Keep as-is |
