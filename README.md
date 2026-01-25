# Create Workflow Plugin

Orchestrated development workflow from idea to implementation with isolated agent contexts.

## Usage

```bash
/create "Build a user authentication system"
/create --auto "Add dark mode toggle"
/create --resume
```

## Phases

1. **Discovery** - Refine idea into PRD, ADR, Tech Design, Wireframes
2. **Planning** - Break specs into test-bounded tasks
3. **Implementation** - Execute tasks with TDD, verify with reviewer
4. **Completion** - Merge, PR, or continue development

## Configuration

- `--auto`: Skip confirmations between phases
- `--resume`: Resume interrupted session
- `--retries N,M`: Retry limits (default: 2,1)

## Skills

| Skill | Phase | Purpose |
|-------|-------|---------|
| discovery | 1 | Requirements gathering and doc generation |
| planning | 2 | Task decomposition |
| conductor | 3 | Implementation loop orchestration |
| implement | 3 | Task execution (TDD) |
| review | 3 | Task verification |

## Dependencies

- superpowers:test-driven-development
- superpowers:using-git-worktrees
- superpowers:finishing-a-development-branch
