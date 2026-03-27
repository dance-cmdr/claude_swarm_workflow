# Swarm Workflow Overview

## TL;DR

We use a four-phase AI-assisted development workflow — **Spec, Plan, Execute, Validate** — powered by Claude Code skills. Work is broken into independent tasks with explicit dependencies, executed in parallel waves by separated test and implementation agents, with automated regression gates between each wave.

---

## The Pipeline at a Glance

```
 /spec              /swarm-plan           /swarm               /validate
┌──────────┐      ┌──────────────┐      ┌──────────────┐      ┌─────────────┐
│ Discovery │ ──▶  │  Break down  │ ──▶  │   Execute    │ ──▶  │   Verify    │
│ & specify │      │  into tasks  │      │   in waves   │      │   & close   │
└──────────┘      └──────────────┘      └──────────────┘      └─────────────┘
     │                   │                     │                      │
 Structured spec    Task DAG with         RED/GREEN agents      Full test matrix
 in docs/specs/     dependency waves      per task, gates       + phase closure
                    in *-plan.md          between waves         document
```

| Phase | Command | Input | Output |
|-------|---------|-------|--------|
| **Spec** | `/spec` | Idea, ticket, or bug report | `docs/specs/YYYY-MM-DD-<name>.md` |
| **Plan** | `/swarm-plan` | Spec document | `<topic>-plan.md` with tasks and wave table |
| **Execute** | `/swarm <plan>` | Plan file | Committed code, execution summary |
| **Validate** | `/validate` | Completed work | Test results, phase closure document |

---

## How Each Phase Works

### 1. Spec — Discovery & Specification

An interactive conversation that transforms a vague idea into a structured, implementable specification. The skill asks focused questions across seven steps: orient, explore codebase, deep dive, resolve conflicts, completeness check, generate spec, and hand off.

**What comes out**: A spec document with problem statement, affected areas, prioritized requirements (P0/P1), acceptance criteria, test plan, technical approach, risks, and explicit scope boundaries.

### 2. Plan — Dependency-Aware Task Decomposition

Reads the spec and decomposes work into atomic tasks. Each task declares:
- Which files it owns (no two tasks share a file)
- What it depends on (building a directed acyclic graph)
- Testable acceptance criteria
- The validation command to run

Tasks are grouped into **waves** — sets of tasks that can run in parallel because they have no mutual dependencies.

**What comes out**: A plan file with task definitions and a wave table showing execution order.

### 3. Execute — Parallel RED/GREEN Waves

For each task in a wave, two agents run sequentially:

| Agent | Role | Model | Touches |
|-------|------|-------|---------|
| **Test (RED)** | Write failing tests encoding acceptance criteria | opus | Test files only |
| **Dev (GREEN)** | Write minimal code to make tests pass | sonnet | Source files only |

After each wave completes, a **regression gate** runs the full test matrix. Only when it passes does the next wave begin. A final integration pass resolves any cross-task issues.

**What comes out**: Committed code with passing tests and an execution summary.

### 4. Validate — Verification & Phase Closure

Runs the complete test matrix, checks for regressions, cleans up artifacts, reviews code quality, verifies all acceptance criteria, and produces a phase closure document summarizing what was built, decisions made, and handoff notes for the next phase.

**What comes out**: Validation report and phase closure document.

---

## Architecture Decisions

### Why separate RED and GREEN agents?

The test agent writes tests without knowing the implementation, so tests encode *requirements*, not *implementation details*. The dev agent treats tests as a contract — it can't weaken them. This mirrors proper TDD discipline.

### Why waves and regression gates?

Tasks within a wave run in parallel for speed. Gates between waves catch breakage early — a failing gate blocks downstream work before it compounds the problem.

### Why an adapter file?

`.claude/adapter.md` is the single source of truth for test commands, file patterns, model routing, and conventions. Every skill reads it first. When the project's stack changes, you update one file — not four skills.

### Why file ownership per task?

If two parallel agents edit the same file, merge conflicts are inevitable. Exclusive file ownership eliminates this class of failure entirely.

---

## Appendix: File Map

```
.claude/
├── adapter.md              ← Central config (test matrix, model routing, file patterns)
├── settings.json           ← Permissions and hooks
├── hooks/
│   └── auto-lint.sh        ← Post-edit auto-linting hook
├── commands/               ← Thin wrappers (entry points for /slash commands)
│   ├── spec.md
│   ├── swarm-plan.md
│   ├── swarm.md
│   └── validate.md
└── skills/                 ← Full skill implementations
    ├── spec/SKILL.md           (discovery phase logic)
    ├── swarm-plan/SKILL.md     (planning phase logic)
    ├── swarm/SKILL.md          (execution phase logic)
    └── validate/SKILL.md       (validation phase logic)
```

### Model Routing

| Role | Model | Why |
|------|-------|-----|
| Swarm Planner | opus | Deep reasoning for dependency analysis |
| Test Agent (RED) | opus | Edge case reasoning, acceptance criteria |
| Dev Agent (GREEN) | sonnet | Fast, focused implementation |
| Orchestrator | opus | Judgment calls, conflict resolution |
| Validate | opus | Broad analysis, regression checking |
