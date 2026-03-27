# Swarm Workflow Briefing

A skimmable reference for how our AI-assisted development pipeline works. Each section is self-contained — read the ones relevant to you.

---

### What It Is

A four-phase workflow for turning ideas into shipped, validated code using Claude Code.

```
/spec  →  /swarm-plan  →  /swarm  →  /validate
```

Each phase is a Claude Code skill invoked with a slash command.

---

### The Core Idea: Parallel TDD at Scale

Work gets broken into **independent tasks** with explicit dependencies. Tasks with no dependencies on each other run **in parallel**. Each task is implemented using strict **test-first development** — one agent writes the failing tests, a separate agent writes the code to pass them.

---

### The Four Phases

**`/spec`** — Turn a vague idea into a structured specification.
Interactive discovery session. Outputs a spec with requirements, acceptance criteria, risks, and scope.

**`/swarm-plan`** — Break the spec into tasks and waves.
Each task owns specific files, declares dependencies, and has testable acceptance criteria. Tasks are grouped into waves for parallel execution.

**`/swarm <plan-file>`** — Execute tasks in parallel waves.
Per task: RED agent writes failing tests, GREEN agent makes them pass. Regression gate runs between waves.

**`/validate`** — Verify everything and close the phase.
Full test matrix, regression check, code quality review, documentation updates, phase closure.

---

### RED/GREEN Agent Separation

| | Test Agent (RED) | Dev Agent (GREEN) |
|---|---|---|
| **Job** | Write failing tests from acceptance criteria | Write code to make tests pass |
| **Model** | opus (deep reasoning) | sonnet (fast implementation) |
| **Can edit** | Test files only | Source files only |
| **Cannot** | Touch production code | Modify or weaken tests |

The test agent doesn't know how the code will be implemented. The dev agent can't change what "correct" means. This enforces real TDD.

---

### Waves and Regression Gates

```
Wave 1: [T1, T2, T3]  ──▶  Regression Gate  ──▶  Wave 2: [T4, T5]  ──▶  Gate  ──▶  Wave 3: [T6]
         (parallel)          (must pass)                  (parallel)                    (sequential)
```

- Tasks within a wave have no dependencies on each other — they run in parallel
- A regression gate runs the full test suite after each wave
- The next wave only starts if the gate passes
- A final integration pass handles any cross-task issues

---

### The Adapter: Single Source of Truth

`.claude/adapter.md` configures everything:
- **Test matrix** — which commands to run (lint, validate, format check)
- **Model routing** — which Claude model each agent role uses
- **File patterns** — where source, test, and config files live
- **Regression commands** — what gates run between waves

All four skills read the adapter first. Change the stack once, skills adapt automatically.

---

### Task Anatomy

Each task in a plan has:

| Field | Purpose |
|-------|---------|
| `depends_on` | Which tasks must complete first |
| `files` | Source files this task owns (exclusive) |
| `test_files` | Test files this task creates |
| `acceptance_criteria` | What the RED agent encodes as tests |
| `validation` | Command to verify this task |

No two tasks share a file — this eliminates merge conflicts during parallel execution.

---

### Key Design Choices

**File ownership** — Parallel agents can't conflict if they never touch the same file.

**Acceptance criteria as contract** — The test agent encodes them; the dev agent satisfies them. Neither can bend the rules.

**Adapter-first architecture** — One config file, four skills. Stack changes propagate automatically.

**Regression gates** — Catch problems between waves, not at the end when the blast radius is largest.

---

### File Structure

```
.claude/
├── adapter.md           ← Master config
├── commands/            ← /slash command entry points
│   ├── spec.md
│   ├── swarm-plan.md
│   ├── swarm.md
│   └── validate.md
└── skills/              ← Phase implementations
    ├── spec/SKILL.md
    ├── swarm-plan/SKILL.md
    ├── swarm/SKILL.md
    └── validate/SKILL.md
```
