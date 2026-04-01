# Review Feedback Examples

Reference examples for review skill approval/rejection patterns.

## Approved Examples

### Simple Approval

```json
{
  "s": "APPROVED",
  "ts": "2026-01-25T11:15:00Z",
  "src": { "skill": "review", "task_id": "001" },
  "p": {
    "summary": "User model created with proper validation and password hashing",
    "verified": [
      {
        "criterion": "AC-001",
        "description": "User model has email, password_hash, created_at fields",
        "implementation_file": "src/models/user.ts:15",
        "test_file": "tests/models/user.test.ts:8"
      },
      {
        "criterion": "AC-002",
        "description": "Email validation rejects invalid formats",
        "implementation_file": "src/models/user.ts:45",
        "test_file": "tests/models/user.test.ts:25"
      }
    ]
  }
}
```

### Approval with Notes

```json
{
  "s": "APPROVED",
  "ts": "2026-01-25T11:15:00Z",
  "src": { "skill": "review", "task_id": "003" },
  "p": {
    "summary": "Authentication middleware implemented correctly",
    "verified": [
      {
        "criterion": "AC-005",
        "description": "Protected routes return 401 without valid token",
        "implementation_file": "src/middleware/auth.ts:23",
        "test_file": "tests/middleware/auth.test.ts:45"
      }
    ],
    "notes": "Consider adding rate limiting in future iteration (not in scope)"
  }
}
```

---

## Rejected Examples

### Low Severity - Missing Test

```json
{
  "s": "REJECTED",
  "ts": "2026-01-25T11:15:00Z",
  "src": { "skill": "review", "task_id": "002" },
  "p": {
    "summary": "Implementation works but test coverage incomplete",
    "issues": [
      {
        "criterion": "AC-003",
        "description": "No test for empty email validation",
        "file": "tests/validators/email.test.ts",
        "severity": "low"
      }
    ],
    "required_fixes": [
      "Add test case: expect(validateEmail('')).toBe(false)"
    ]
  }
}
```

### Medium Severity - Logic Error

```json
{
  "s": "REJECTED",
  "ts": "2026-01-25T11:15:00Z",
  "src": { "skill": "review", "task_id": "004" },
  "p": {
    "summary": "Password comparison has subtle bug",
    "issues": [
      {
        "criterion": "AC-007",
        "description": "Using == instead of timing-safe comparison for password",
        "file": "src/services/auth.ts",
        "line": 67,
        "severity": "medium"
      }
    ],
    "required_fixes": [
      "Replace password === hash with crypto.timingSafeEqual()",
      "Import timingSafeEqual from 'crypto' module"
    ]
  }
}
```

### High Severity - Security Issue

```json
{
  "s": "REJECTED",
  "ts": "2026-01-25T11:15:00Z",
  "src": { "skill": "review", "task_id": "005" },
  "p": {
    "summary": "Critical: SQL injection vulnerability in query",
    "issues": [
      {
        "criterion": "AC-010",
        "description": "User input directly interpolated into SQL query",
        "file": "src/repositories/user.ts",
        "line": 34,
        "severity": "high"
      }
    ],
    "required_fixes": [
      "Use parameterized query: db.query('SELECT * FROM users WHERE id = $1', [userId])",
      "Never interpolate user input directly into SQL strings"
    ]
  }
}
```

---

## Edge Cases

### Partial Approval (Not Allowed)

Reviewers should NOT partially approve. If any criterion fails, REJECT:

```json
{
  "s": "REJECTED",
  "p": {
    "summary": "AC-001 and AC-002 pass, but AC-003 missing implementation",
    "issues": [
      {
        "criterion": "AC-003",
        "description": "Error handling not implemented",
        "severity": "medium"
      }
    ]
  }
}
```

### Multiple Issues, Mixed Severity

```json
{
  "s": "REJECTED",
  "p": {
    "summary": "Multiple issues found during review",
    "issues": [
      {
        "criterion": "AC-001",
        "description": "Test assertion too weak",
        "severity": "low"
      },
      {
        "criterion": "AC-002",
        "description": "Missing input validation",
        "severity": "medium"
      },
      {
        "criterion": "AC-003",
        "description": "Exposes sensitive data in error message",
        "severity": "high"
      }
    ],
    "required_fixes": [
      "Strengthen test: check specific error message content",
      "Add null/undefined check before accessing user.email",
      "URGENT: Remove stack trace from API error response"
    ]
  }
}
```

---

## Feedback Writing Guidelines

### Be Specific

| Bad | Good |
|-----|------|
| "Tests are insufficient" | "No test for `validateEmail('')` returning false" |
| "This doesn't look right" | "Line 45: Using `==` instead of `===` for comparison" |
| "Needs more error handling" | "Add try/catch in `processPayment()` for `PaymentGatewayError`" |

### Reference Specs

| Bad | Good |
|-----|------|
| "Doesn't match expected format" | "TECHNICAL_DESIGN.md specifies `{data: [], meta: {}}` but returns `{items: []}`" |
| "Security concern" | "ADR.md section 4.2 requires bcrypt, but using MD5" |

### Actionable Fixes

| Bad | Good |
|-----|------|
| "Fix the validation" | "Add `if (!email.includes('@')) return false;` at line 23" |
| "Add error handling" | "Wrap lines 45-50 in try/catch, return 500 on error" |
