# Adapter: Hexmap Cartographer

Project-specific configuration for the Hexmap Cartographer codebase. Referenced by workflow skills (`spec`, `swarm-plan`, `swarm`, `validate`) for test commands, conventions, and file patterns.

## Stack

- **Backend**: Python FastAPI + JWT, PostgreSQL + PostGIS
- **Frontend**: React + TypeScript (Vite)
- **Testing**: Vitest/RTL/msw v2 (frontend unit), pytest (backend), Playwright (E2E)
- **Linting**: ruff (backend), ESLint (frontend)
- **Infrastructure**: Docker Compose for database, npm for frontend dev

## Test Matrix

| Type | Layer | Runner | When |
|------|-------|--------|------|
| Frontend unit | Pure functions, component logic | `make test-frontend` (Vitest) | Every change |
| Backend unit | Validation, utilities | `make test-backend` (pytest, needs DB) | Backend changes |
| Backend integration | API endpoints + DB | `make test-backend` (pytest + TestClient) | New endpoints |
| E2E | User journeys | `cd frontend && npx playwright test --project=chromium` | Full stack or CI |

**Scoped validation** (per-task during `/swarm`): run the test type matching the task. Frontend component? `make test-frontend`. Backend endpoint? `make test-backend`. New user flow? Playwright for that spec file.

**Inter-wave regression gate** (between `/swarm` waves):
```bash
make lint && make test-frontend && make test-backend
```

**Broad validation** (during `/validate`): full test matrix + E2E if full stack available.
```bash
make lint && make test-frontend && make test-backend
cd frontend && npx playwright test --project=chromium  # if full stack running
```

## Lint

```bash
make lint    # ruff check/format (backend) + eslint (frontend)
```

## Environment

```bash
make setup   # Initial setup
make up      # Start database (Docker)
make down    # Stop services
```

- **Frontend**: http://localhost:3000 (no Docker needed for dev)
- **Backend**: http://localhost:8000
- **Database**: localhost:5432 (main), localhost:5433 (test)

## Conventions

- **Specs**: `docs/specs/YYYY-MM-DD-<name>.md` (individual), consolidated into `FEATURE_DEFINITIONS.md`
- **ADRs**: `docs/architecture/ADR-NNN-<name>.md`
- **Design system**: `frontend/DESIGN.md` (tokens, keybinds, component patterns, a11y)
- **Design soul**: `frontend/DESIGN_SOUL.md` (aesthetic identity, palette, commandments, anti-patterns)
- **Cursor rules**: `.cursor/rules/*.mdc` (point to DESIGN.md for details)
- **Phase closure docs**: `PHASE_<NAME>_COMPLETE.md` at project root
- **Feature numbering**: F001-F999 in FEATURE_DEFINITIONS.md
- **Roadmap**: `ROADMAP.md` (Phases A-H)
- **Import style**: ruff-first (backend), ESLint-first (frontend); all imports at top, grouped and alphabetical
- **Commit style**: descriptive messages focused on "why", single logical change per commit
- **Comments**: extreme minimalism — prefer descriptive names over comments

## Test Architecture

### Pure Functions
- **Frontend**: `frontend/src/components/hex/*.ts` (non-React), e.g. `hexClickActions.ts`, `HexMath.ts`
- **Backend**: `backend/app/terrain_validation.py`, standalone utility modules
- **Rule**: If a handler has an if/else tree, extract the decision into a pure function

### Unit Tests
- **Frontend**: `frontend/src/__tests__/<function-group>.test.ts` — Vitest, no React, no mocks
- **Backend**: `backend/tests/test_<function-group>.py` — pytest, no DB, no HTTP

### Integration Tests
- **Backend**: `backend/tests/test_<feature>.py` — pytest + `TestClient(app)` with real DB
- **Pattern**: Register → login → token → API call → assert response + DB state

### E2E Tests
- **Location**: `frontend/e2e/*.spec.ts` — Playwright with chromium
- **Pattern**: `page.route()` for mocking, `page.addInitScript()` for auth
- **Helpers**: `frontend/e2e/helpers/auth.helper.ts`
- **Gherkin specs**: `frontend/e2e/features/*.feature` (human-readable acceptance criteria)

## File Patterns

- **React components**: `frontend/src/components/**/*.tsx`
- **CSS Modules**: `frontend/src/components/**/*.module.css`
- **Pure functions**: `frontend/src/components/hex/*.ts`
- **Frontend tests**: `frontend/src/__tests__/*.test.ts`
- **E2E tests**: `frontend/e2e/*.spec.ts`
- **E2E features**: `frontend/e2e/features/*.feature`
- **Backend models**: `backend/app/models.py`
- **Backend routers**: `backend/app/routers/*.py`
- **Backend tests**: `backend/tests/test_*.py`
- **Design tokens**: `frontend/src/index.css` (CSS variables)
- **Keybind registry**: `frontend/src/components/hex/keybinds.ts`

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
| Web Designer | opus | Visual review against DESIGN_SOUL.md via Playwright MCP |

### Agent Separation
- **Test Agent**: Writes failing tests only. Does not touch production code. Proves RED evidence.
- **Dev Agent**: Implements production code only. Does not modify test files. Proves GREEN evidence.
- **Orchestrator**: Validates RED/GREEN evidence, runs regression gates between waves.

### Regression Gates
- **Per-task**: validation command from plan (scoped test runner)
- **Inter-wave**: `make lint && make test-frontend && make test-backend`
- **Final**: full test matrix including E2E if available

## Browser MCP (Live Visual Inspection)

Playwright MCP is configured in `.mcp.json` with vision mode enabled. It gives agents a real browser for design planning sessions and visual testing.

**Capabilities:**
- Navigate to any page (`browser_navigate`)
- Take screenshots for visual review (`browser_screenshot`)
- Click, type, interact with the UI
- Read the accessibility tree (structured DOM)
- Evaluate JavaScript in the page

**Auth:** The init script (`frontend/e2e/helpers/browser-mcp-init.js`) pre-loads a mock JWT token so the browser starts authenticated.

**When to use:**
- Design planning sessions (compare UI against `frontend/DESIGN.md`)
- Visual regression review after CSS/layout changes
- Debugging rendering issues the test runner can't capture
- Verifying component appearance matches design tokens

**Prerequisites:** Frontend must be running at http://localhost:3000 (and backend at http://localhost:8000 if testing authenticated routes with real data).

**Note:** For mocked data design sessions, the init script handles auth but API calls will need the backend running or network interception configured.

## Architecture Invariants

- **Cube coordinates**: (x, y, z) as source of truth, x + y + z = 0
- **Entity separation**: `Map → Hex → {HexTile, HexRoad[], HexBuilding[], HexAnnotation[]}`
- **Terrain borders**: 6-character strings (NESW edges), validated by backend
- **Canvas-centric UX**: hex canvas fills viewport, all chrome floats or docks at edges
- **Keybind mantra**: Cmd=commands, Shift=constrain, Alt=alternate, Space=pan, Tab=toggle, Escape=cancel
