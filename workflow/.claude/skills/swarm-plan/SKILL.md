---
name: swarm-plan
description: >
  [EXPLICIT INVOCATION ONLY] Creates dependency-aware implementation plans optimized for
  parallel multi-agent execution with separated test and dev agents.
metadata:
  invocation: explicit-only
  model: opus
---

# Swarm-Ready Planner

Create implementation plans with explicit task dependencies optimized for parallel agent execution. Each task produces a dependency DAG with wave groupings, enabling the `/swarm` executor to launch test and dev agents in parallel.

## Prerequisites

- Read the project adapter at `.claude/adapter.md` for test matrix, conventions, file patterns, and regression gate commands.
- If a spec exists (see adapter for spec path), read it first. If not, the user's description is the input.
- Check the feature tracker for context on the feature(s) being planned (see adapter conventions).
- Read the design system doc if the work involves frontend (see adapter conventions).

## Core Principles

1. **Explore Codebase First**: Investigate architecture, patterns, existing implementations, dependencies, and frameworks in use.
2. **Ask Questions**: Clarify ambiguities and seek clarification on scope, constraints, or priorities. At any time.
3. **Explicit Dependencies**: Every task declares what it depends on, enabling maximum parallelization.
4. **Atomic Tasks**: Each task is independently executable by a single agent pair (test + dev).
5. **File Ownership**: No two tasks edit the same file (prevents parallel conflicts).
6. **Test Strategy Per Task**: Every task specifies what test type to write, using the adapter's test architecture.
7. **Review Before Yield**: A subagent reviews the plan for gaps before finalizing.

## Process

### Step 1: Research

**Codebase investigation:**
- Architecture, patterns, existing implementations
- Dependencies and frameworks in use
- Existing test patterns and coverage
- Design system tokens and conventions (if frontend — see adapter)

### Step 1a: Clarification Gate

If the architecture is unclear, requirements are ambiguous, or scope could reasonably go multiple ways:
- **STOP** and ask clarifying questions using AskUserQuestion
- Always offer recommendations with your questions
- Do not make assumptions about scope, constraints, or priorities

If scope is clear, proceed to Step 2.

### Step 2: Decompose into Dependency-Aware Tasks

Break the work into atomic tasks. Each task must include:

- **id**: Unique identifier (e.g., `T1`, `T2.1`)
- **depends_on**: Array of task IDs that must complete first (empty `[]` for root tasks)
- **description**: What the task accomplishes
- **files**: Exact file paths to create or modify (canonical — no two tasks share files)
- **test_type**: Which test layer applies (from adapter: unit/integration/E2E)
- **test_files**: Exact test file paths the test agent will create/modify
- **validation**: Commands to verify completion (from adapter test matrix)
- **acceptance_criteria**: Specific, testable criteria for the test agent to encode

Design tasks so that:
- Root tasks (no dependencies) maximize the first parallel wave
- Pure functions and utilities come before components that use them
- Backend before frontend when there's an API dependency
- Test files are owned by the same task as their source files (no cross-task test conflicts)

### Step 3: Build Wave Table

Calculate parallel execution waves from the dependency graph:

| Wave | Tasks | Can Start When | Regression Gate |
|------|-------|----------------|-----------------|
| 1 | T1, T2 | Immediately | After wave completes |
| 2 | T3, T4 | Wave 1 complete + regression green | After wave completes |
| 3 | T5 | T3, T4 complete + regression green | Final regression |

Each wave boundary includes a regression gate (see adapter for the regression gate command).

### Step 4: Save Plan

Save to `<topic>-plan.md` in the project root (CWD).

### Step 5: Subagent Review

Spawn a subagent to review the plan:

```
Review this implementation plan for:
1. Missing dependencies between tasks
2. File ownership conflicts (two tasks editing the same file)
3. Ordering issues that would cause failures
4. Missing test coverage — every task needs a test_type and test_files
5. Acceptance criteria gaps — are they specific enough for a test agent to encode?
6. Wave grouping correctness
7. Risks, edge cases, gotchas

Provide specific, actionable feedback. Do not ask questions.

Plan location: [file path]
Context: [brief context about the task]
```

If the subagent provides actionable feedback, revise the plan before yielding.

### Step 6: Handoff

After the plan is finalized:
- "Plan ready with N tasks across M waves. Review the plan, then run `/swarm <plan-file>` to execute."

## Plan Template

```markdown
# Plan: [Task Name]

**Generated**: [Date]
**Features**: [feature references, if applicable]

## Overview
[Summary of task and approach]

## Dependency Graph

T1 --+-- T3 --+
     |        |-- T5 -- T6
T2 --+-- T4 --+

## Tasks

### T1: [Name]
- **depends_on**: []
- **files**: [exact source file paths]
- **test_type**: [unit | integration | e2e]
- **test_files**: [exact test file paths]
- **description**: [what to implement]
- **acceptance_criteria**:
  - [specific, testable criterion 1]
  - [specific, testable criterion 2]
- **validation**: [test command from adapter]
- **status**: pending
- **log**: []
- **files_modified**: []

### T2: [Name]
- **depends_on**: []
- **files**: [exact source file paths]
- **test_type**: [unit | integration | e2e]
- **test_files**: [exact test file paths]
- **description**: [what to implement]
- **acceptance_criteria**:
  - [specific, testable criterion 1]
- **validation**: [test command from adapter]
- **status**: pending
- **log**: []
- **files_modified**: []

### T3: [Name]
- **depends_on**: [T1]
- **files**: [exact source file paths]
- **test_type**: [unit | integration | e2e]
- **test_files**: [exact test file paths]
- **description**: [what to implement]
- **acceptance_criteria**:
  - [specific, testable criterion 1]
- **validation**: [test command from adapter]
- **status**: pending
- **log**: []
- **files_modified**: []

[... continue for all tasks ...]

## Parallel Execution Waves

| Wave | Tasks | Can Start When | Regression Gate |
|------|-------|----------------|-----------------|
| 1 | T1, T2 | Immediately | [regression gate from adapter] |
| 2 | T3, T4 | Wave 1 green | [regression gate from adapter] |
| 3 | T5 | T3, T4 green | Full regression + E2E |

## Testing Strategy
- **Test agent model**: opus (writes failing tests from acceptance criteria)
- **Dev agent model**: sonnet (implements to make tests pass)
- **Inter-wave regression**: [regression gate from adapter]
- **Final regression**: [full test matrix from adapter]

## Risks & Mitigations
- [What could go wrong + how to handle]
```

## Guidance

- **Task granularity**: Target 3-10 tasks. More than 10 suggests splitting into multiple phases.
- **File ownership is critical**: Parallel agents editing the same file causes overwrites. Design tasks with clear file boundaries.
- **Acceptance criteria are the contract**: The test agent uses these to write tests. Vague criteria = weak tests. Be specific.
- **Gherkin first**: If the feature has a `.feature` file or BDD spec, read it — acceptance criteria are already defined.
- **Don't implement**: This skill only creates the plan. Execution is `/swarm`.
