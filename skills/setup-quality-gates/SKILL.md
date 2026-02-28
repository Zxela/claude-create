---
name: setup-quality-gates
description: "[haiku] Set up Claude Code hooks for automatic lint, typecheck, and auto-format enforcement"
model: haiku
color: orange
---

# Setup Quality Gates Skill

## Reference Materials

- Hook scripts: `scripts/homerun-pre-commit.sh`, `scripts/homerun-auto-lint.sh`
- Hooks configuration: `references/hooks-configuration.md`

## Overview

You are a **setup agent**. Your job: configure Claude Code hooks in the target project so that lint and typecheck are enforced automatically on every commit — without any agent needing to remember to run them.

This skill is **idempotent**. Safe to run multiple times. It detects existing configuration and only adds what's missing.

**Model Selection:** Haiku — this is mechanical detection and configuration, no reasoning needed.

**Announce at start:** "I'm setting up quality gate hooks for this project."

---

## Input Schema (JSON)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "project_path": {
      "type": "string",
      "description": "Path to the target project root. Defaults to cwd."
    }
  }
}
```

---

## Process

### Step 1: Detect Quality Tools

Identify what quality tools the project uses. Check in this order:

```bash
cd "$PROJECT_PATH"

echo "=== Detecting quality tools ==="

# Lint detection
LINT="none"
if [ -f package.json ] && jq -e '.scripts.lint' package.json >/dev/null 2>&1; then
  LINT="package-script"
  echo "Lint: package.json 'lint' script"
elif [ -f biome.json ] || [ -f biome.jsonc ]; then
  LINT="biome"
  echo "Lint: Biome"
elif [ -f eslint.config.js ] || [ -f eslint.config.mjs ] || [ -f .eslintrc.js ] || [ -f .eslintrc.json ]; then
  LINT="eslint"
  echo "Lint: ESLint"
elif [ -f pyproject.toml ] && grep -q 'ruff' pyproject.toml; then
  LINT="ruff"
  echo "Lint: Ruff"
fi

# Typecheck detection
TYPECHECK="none"
if [ -f package.json ] && jq -e '.scripts.typecheck // .scripts["type-check"] // .scripts["check-types"]' package.json >/dev/null 2>&1; then
  TYPECHECK="package-script"
  echo "Typecheck: package.json script"
elif [ -f tsconfig.json ]; then
  TYPECHECK="tsc"
  echo "Typecheck: TypeScript (tsc)"
elif command -v mypy &>/dev/null && [ -f pyproject.toml ]; then
  TYPECHECK="mypy"
  echo "Typecheck: mypy"
fi

# Formatter detection (for auto-lint hook)
FORMATTER="none"
if [ -f biome.json ] || [ -f biome.jsonc ]; then
  FORMATTER="biome"
elif [ -f .prettierrc ] || [ -f .prettierrc.js ] || [ -f .prettierrc.json ]; then
  FORMATTER="prettier"
fi
```

**If both LINT and TYPECHECK are "none":** Report that no quality tools were detected. Suggest the user install a linter/typechecker and re-run. Exit.

### Step 2: Check Existing Configuration

```bash
SETTINGS_FILE="$PROJECT_PATH/.claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
  echo "=== Existing .claude/settings.json found ==="
  # Check for existing hooks
  HAS_PRE_COMMIT=$(jq 'any(.hooks.PreToolUse[]?; .hooks[]?.command | test("pre-commit"))' "$SETTINGS_FILE" 2>/dev/null)
  HAS_AUTO_LINT=$(jq 'any(.hooks.PostToolUse[]?; .hooks[]?.command | test("auto-lint"))' "$SETTINGS_FILE" 2>/dev/null)
fi
```

### Step 3: Configure Hooks

Create or update `.claude/settings.json` to include the quality gate hooks.

**Required hooks to configure:**

1. **PreToolUse (Bash)** — Blocks `git commit`/`git push` if lint or typecheck fails:
```json
{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "$CLAUDE_PLUGIN_ROOT/scripts/homerun-pre-commit.sh"
  }]
}
```

2. **PostToolUse (Edit|Write)** — Auto-lints files after every edit:
```json
{
  "matcher": "Edit|Write",
  "hooks": [{
    "type": "command",
    "command": "$CLAUDE_PLUGIN_ROOT/scripts/homerun-auto-lint.sh"
  }]
}
```

**Merge rules:**
- If `.claude/settings.json` doesn't exist: create it with both hooks
- If it exists but hooks are missing: add them (preserve existing hooks)
- If hooks already present: skip (idempotent)
- Always ensure `.claude/` directory exists: `mkdir -p "$PROJECT_PATH/.claude"`

### Step 4: Verify Setup

```bash
echo "=== Verifying setup ==="

# Check settings file is valid JSON
jq . "$SETTINGS_FILE" >/dev/null 2>&1 || echo "ERROR: Invalid JSON in settings"

# Check hooks are present
jq '.hooks.PreToolUse' "$SETTINGS_FILE"
jq '.hooks.PostToolUse' "$SETTINGS_FILE"

# Dry-run the pre-commit script (should exit 0 when not intercepting a commit)
echo '{"tool_input":{"command":"git status"},"cwd":"'$PROJECT_PATH'"}' | \
  "$CLAUDE_PLUGIN_ROOT/scripts/homerun-pre-commit.sh"
echo "Pre-commit hook: OK (exit $?)"
```

### Step 5: Report

```
Quality gates configured:

✓ Pre-commit gate: lint + typecheck before every git commit/push
  - Lint: <detected tool>
  - Typecheck: <detected tool>
✓ Auto-lint: format files on every Edit/Write

Settings: <path to .claude/settings.json>
```

---

## Output Schema (JSON)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["signal", "status"],
  "properties": {
    "signal": { "const": "QUALITY_GATES_CONFIGURED" },
    "status": { "enum": ["configured", "already_configured", "no_tools_found"] },
    "tools_detected": {
      "type": "object",
      "properties": {
        "lint": { "type": "string" },
        "typecheck": { "type": "string" },
        "formatter": { "type": "string" }
      }
    },
    "hooks_added": {
      "type": "array",
      "items": { "type": "string" }
    },
    "settings_path": { "type": "string" }
  }
}
```

### Example Output

```json
{
  "signal": "QUALITY_GATES_CONFIGURED",
  "status": "configured",
  "tools_detected": {
    "lint": "biome",
    "typecheck": "tsc",
    "formatter": "biome"
  },
  "hooks_added": ["PreToolUse:Bash", "PostToolUse:Edit|Write"],
  "settings_path": "/home/user/myapp/.claude/settings.json"
}
```

---

## Exit Criteria

- [ ] Quality tools detected (or reported as missing)
- [ ] `.claude/settings.json` exists with correct hook configuration
- [ ] Hooks reference plugin scripts via `$CLAUDE_PLUGIN_ROOT`
- [ ] Existing configuration preserved (no destructive overwrites)
- [ ] Dry-run verification passed
- [ ] Signal emitted

---

## Integration

**Called by:**
- **using-git-worktrees** — After worktree setup, configure hooks
- **team-lead** — At start of orchestration, ensure gates are in place
- Manual invocation at any time

**Pairs with:**
- **quality-check** — Quality-check runs the full 5-phase pipeline; this skill ensures the deterministic phases (1 & 2) run automatically via hooks
- **finishing-a-development-branch** — Tests verified before merge; hooks ensure lint/types were checked at every commit along the way
