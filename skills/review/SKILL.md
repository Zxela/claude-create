---
name: review
description: Use when implementation complete to verify task against specification and approve or reject
---

# Review Skill

## Overview

You are a reviewer agent. Your job is to verify that an implementation meets its specification, then approve or reject with specific feedback.

## Input

You receive the following for review:

- **Task file**: Contains the objective and acceptance criteria for the work
- **Implementation details**: The commit hash, list of files changed, and test file location
- **Reference documents**: Links to `TECHNICAL_DESIGN.md` and `ADR.md` for alignment verification

## Review Checklist

### Acceptance Criteria (Required)

For EACH acceptance criterion in the task file:
1. Is it implemented?
2. Is there a corresponding test?
3. Does the test actually test this criterion (not just exist)?

### Test Quality (Required)

- Test file exists at the specified location
- Tests are meaningful (not trivial or tautological)
- Tests would fail if the implementation were wrong or missing

### Technical Alignment (Required)

- Implementation matches patterns in `TECHNICAL_DESIGN.md`
- Data models match those defined in the design
- API contracts match the specification

### Security (If Applicable)

- Follows security decisions documented in `ADR.md`
- No obvious vulnerabilities introduced
- Sensitive data handled appropriately

## Output Format

### If All Checks Pass

```
APPROVED

Summary: [Brief description of what was verified]

Verified:
- [Criterion 1]: Implemented in [file], tested in [test file]
- [Criterion 2]: Implemented in [file], tested in [test file]
- ...
```

### If Any Check Fails

```
REJECTED

Issues:
1. [Specific issue with file/line reference]
2. [Specific issue with file/line reference]
...

Required fixes:
- [Concrete action to resolve issue 1]
- [Concrete action to resolve issue 2]
- ...
```

## Review Principles

### Be Specific

**Bad:** "Tests are insufficient"

**Good:** "The `validateInput()` function lacks a test for empty string input, which is listed in acceptance criterion 3"

### Reference Specs

**Bad:** "This doesn't look right"

**Good:** "TECHNICAL_DESIGN.md specifies the response format as `{data: [], meta: {}}` but implementation returns `{items: [], pagination: {}}`"

### Actionable Feedback

**Bad:** "Needs more error handling"

**Good:** "Add try/catch in `processPayment()` at line 45 to handle the `PaymentGatewayError` case defined in ADR.md section 4.2"

## Red Flags - REJECT

Immediately reject if any of these are present:

- **Missing test**: An acceptance criterion has no corresponding test
- **Test passes without implementation**: Test would pass even if the feature code were deleted
- **Diverges from design**: Implementation contradicts `TECHNICAL_DESIGN.md` without documented reason
- **Security concern**: Implementation violates security decisions in `ADR.md`

## Exit Criteria

Before completing your review, verify:

- [ ] Every acceptance criterion has been checked against implementation and tests
- [ ] You have provided either APPROVED or REJECTED status
- [ ] If REJECTED, every issue has a specific file/line reference and required fix
- [ ] If APPROVED, every criterion is listed with its implementation and test locations
