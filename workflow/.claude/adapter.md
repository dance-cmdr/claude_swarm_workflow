# Adapter: [Your Project Name]

<!--
  This is the project-specific configuration file for the swarm workflow.
  All skills (spec, swarm-plan, swarm, validate) read this file first.
  Fill in each section with your project's actual commands, paths, and conventions.
  Delete these HTML comments when you're done.
-->

Project-specific configuration for [your project]. Referenced by workflow skills (`spec`, `swarm-plan`, `swarm`, `validate`) for test commands, conventions, and file patterns.

## Stack

<!--
  List your languages, frameworks, and tools.
  Example:
  - **Backend**: Python FastAPI + JWT, PostgreSQL
  - **Frontend**: React + TypeScript (Vite)
  - **Testing**: Vitest (frontend), pytest (backend), Playwright (E2E)
-->

- **Backend**: [language/framework]
- **Frontend**: [language/framework]
- **Testing**: [test runners and tools]
- **Linting**: [linter tools]

## Test Matrix

<!--
  Define every test type your project uses.
  The swarm executor uses this to select the right runner per task.
-->

| Type | Layer | Runner | When |
|------|-------|--------|------|
| Unit (frontend) | Pure functions, component logic | `[command]` | Every change |
| Unit (backend) | Validation, utilities | `[command]` | Backend changes |
| Integration | API endpoints + DB | `[command]` | New endpoints |
| E2E | User journeys | `[command]` | Full stack or CI |

**Scoped validation** (per-task during `/swarm`): run the test type matching the task.

**Inter-wave regression gate** (between `/swarm` waves):
```bash
# This command runs between waves to catch regressions.
# It should cover lint + all fast test suites.
# Example: make lint && npm test && pytest
[your regression gate command]
```

**Broad validation** (during `/validate`): full test matrix + E2E if available.
```bash
# Full regression including E2E
[your full test matrix command]
```

## Lint

```bash
# Your lint command. Used by the auto-lint hook and regression gates.
# Example: make lint
[your lint command]
```

## Environment

```bash
# Commands to set up, start, and stop your development environment.
[setup command]    # Initial setup
[start command]    # Start services
[stop command]     # Stop services
```

- **Frontend**: [URL, e.g., http://localhost:3000]
- **Backend**: [URL, e.g., http://localhost:8000]
- **Database**: [connection info, if applicable]

## Conventions

<!--
  Project-specific paths and naming conventions.
  The skills reference these when creating specs, plans, and doing reviews.
-->

- **Specs**: `[path, e.g., docs/specs/YYYY-MM-DD-<name>.md]`
- **Feature tracker**: `[path or "none", e.g., FEATURE_DEFINITIONS.md]`
- **Design system doc**: `[path or "none", e.g., frontend/DESIGN.md]`
- **Design identity doc**: `[path or "none", e.g., frontend/DESIGN_SOUL.md]`
- **Roadmap**: `[path or "none", e.g., ROADMAP.md]`
- **ADRs**: `[path or "none", e.g., docs/architecture/ADR-NNN-<name>.md]`
- **Phase closure docs**: `[path pattern or "none", e.g., PHASE_<NAME>_COMPLETE.md]`
- **Import style**: [describe your import ordering convention]
- **Commit style**: [describe your commit message convention]
- **Comments**: [describe your commenting philosophy, e.g., "extreme minimalism — prefer descriptive names"]

## Test Architecture

<!--
  Map the concept-to-code relationship for tests in your project.
  This helps the test agent understand where to create test files and what patterns to follow.
-->

### Pure Functions
- **Frontend**: `[path pattern, e.g., src/utils/*.ts]`
- **Backend**: `[path pattern, e.g., backend/app/utils.py]`
- **Rule**: If a handler has an if/else tree, extract the decision into a pure function

### Unit Tests
- **Frontend**: `[path pattern, e.g., src/__tests__/*.test.ts]` — [runner], no mocks, no rendering
- **Backend**: `[path pattern, e.g., backend/tests/test_*.py]` — [runner], no DB, no HTTP

### Integration Tests
- **Backend**: `[path pattern]` — [runner] + real DB
- **Pattern**: [describe your integration test pattern]

### E2E Tests
- **Location**: `[path pattern, e.g., e2e/*.spec.ts]` — [runner]
- **Pattern**: [describe your E2E test pattern, e.g., "page.route() for mocking"]

## File Patterns

<!--
  Where things live in your codebase. Used by agents to find and create files.
-->

- **Components**: `[path pattern]`
- **Styles**: `[path pattern]`
- **Pure functions**: `[path pattern]`
- **Frontend tests**: `[path pattern]`
- **E2E tests**: `[path pattern]`
- **Backend models**: `[path]`
- **Backend routes**: `[path pattern]`
- **Backend tests**: `[path pattern]`

## Swarm Workflow

### Pipeline
```
/spec  -->  /swarm-plan  -->  /swarm  -->  /validate
```

### Model Routing
| Agent Role | Model | Rationale |
|------------|-------|-----------|
| Swarm Planner | opus | Deep reasoning, codebase exploration, dependency analysis |
| Test Agent (RED) | opus | Acceptance criteria reasoning, exhaustive edge cases |
| Dev Agent (GREEN) | sonnet | Fast focused implementation, tests define the contract |
| Orchestrator | opus | Validation, conflict resolution, judgment calls |
| Validate | opus | Broad analysis, regression, documentation |
| Web Designer | opus | Visual review against design system (optional) |

### Agent Separation
- **Test Agent**: Writes failing tests only. Does not touch production code. Proves RED evidence.
- **Dev Agent**: Implements production code only. Does not modify test files. Proves GREEN evidence.
- **Orchestrator**: Validates RED/GREEN evidence, runs regression gates between waves.

### Regression Gates
- **Per-task**: validation command from plan (scoped test runner)
- **Inter-wave**: [your regression gate command from above]
- **Final**: full test matrix including E2E if available

## Executor Variants (Optional)

<!--
  Configure optional executor variants. These sections are read by the variant
  skills if installed. If a section is missing, the variant uses sensible defaults.
-->

### Super-Swarm
<!--
  Rolling pool executor — launches tasks as slots free, no wave batching.
  Install with: ./install.sh --with-super-swarm
-->
- **Max concurrent agents**: 12
- **Regression gate frequency**: every 4 completed tasks

### Co-Design
<!--
  Design-aware executor — classifies tasks as "design" or "standard".
  Design tasks get full CLI access with design-system awareness.
  Install with: ./install.sh --with-co-design
-->
- **Design task keywords**: CSS, HTML, React components, styling, UI, layout, design tokens, animations, accessibility, responsive
- **Design tasks skip RED phase**: false

### Spark
<!--
  Agent-profile executor — injects a named agent profile into all subagents.
  Create your profile at .claude/agents/<name>.md, then reference it here.
  Install with: ./install.sh --with-spark
-->
- **Agent profile**: [your-profile-name]

## Browser MCP (Optional — for Design Review)

<!--
  Only needed if you use the web-designer skill for visual design review.
  Requires Playwright MCP configured in .mcp.json.
-->

Playwright MCP is configured in `.mcp.json` with vision mode enabled.

**Capabilities:**
- Navigate to any page (`browser_navigate`)
- Take screenshots for visual review (`browser_screenshot`)
- Click, type, interact with the UI
- Read the accessibility tree

**Prerequisites:** App must be running at the URLs specified above.
