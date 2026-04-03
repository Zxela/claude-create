# Pre-Implementation Analysis (Step 0)

**For sonnet/opus tasks only.** Haiku tasks skip this entirely. Budget: ~2.5K tokens.

## 0a. Strategy Selection

Pick one strategy and document rationale in 2-3 sentences:

| Strategy | When to Use |
|----------|-------------|
| **Vertical slice** | Greenfield — prove e2e path works |
| **Horizontal layer** | Extending existing patterns |
| **Outside-in** | Start from API surface, work inward |
| **Inside-out** | Start from data, work outward |
| **Risk-first** | Uncertain — validate the riskiest part early |

## 0b. Metacognitive Questions

Generate 3-5 self-interrogation questions by task type. Answer briefly. "I don't know" → investigate via targeted grep before coding.

- **create_model/add_field:** existing references? migrations? serialization breaks?
- **create_service/add_method:** call chain? consumers? error states?
- **add_endpoint:** middleware? auth? response contract?
- **bug_fix:** reproducible? root cause vs symptom? regression test?
- **create_middleware:** execution order? downstream data? failure modes?
- **architectural:** blast radius? what breaks if wrong? reversible?

## 0c. Impact Analysis (3-Stage)

1. **Discovery** — grep for related functions/classes/constants in src/ and tests/
   ```bash
   grep -rn "function.*${KEYWORD}\|class.*${KEYWORD}" src/ --include="*.ts" --include="*.js" | head -20
   grep -rn "${KEYWORD}" tests/ --include="*.test.*" | head -10
   ```

2. **Understanding** — classify each match:
   - **Calls** this code → verify caller expectations hold
   - **Called by** this code → ensure dependency contract stable
   - **Shares state** → check for race conditions
   - **Tests** this code → note which tests to update

3. **Identification** — label files:
   - **Direct** (must modify) → include in plan
   - **Indirect** (imports changed code) → verify after
   - **Unaffected** (keyword match, no dependency) → ignore

## 0d. Duplication Check (Rule of Three)

1st occurrence → implement inline. 2nd → note similarity (`// NOTE: similar to <path>:<line>`). 3rd+ → must consolidate (extract shared logic).

**When NOT to consolidate** (even at 3+): different bounded contexts, coupling risk, superficial similarity.

**If 3+ real matches with same semantics:**
```json
{
  "signal": "IMPLEMENTATION_BLOCKED",
  "blocker_type": "duplication_detected",
  "reason": "Similar function already exists",
  "details": ["Existing: <path>:<line> — <function>"],
  "suggested_resolution": "Import and reuse existing implementation"
}
```
