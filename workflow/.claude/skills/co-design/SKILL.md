---
name: co-design
description: >
  Only to be triggered by explicit /co-design commands. Design-aware parallel
  executor that classifies tasks as "design" or "standard" and routes them
  differently — design tasks get full CLI access with design-system awareness,
  standard tasks get RED/GREEN TDD separation. Auto-invokes web-designer for
  post-wave design review. Automatic /validate chaining on completion.
hooks:
  Stop:
    - hooks:
        - type: prompt
          prompt: |
            You are checking whether a co-design execution phase is complete.

            Examine this assistant message. Does it indicate that ALL planned tasks
            are finished, integrated, and the regression gate has passed? Look for:
            - "all tasks complete", "all N tasks implemented"
            - "final regression green", "regression gate passed"
            - "ready for validation", "run /validate"
            - An execution summary with no remaining or blocked tasks

            If co-design execution IS complete, respond with:
            {"decision": "block", "reason": "Co-design execution complete. Read the project adapter at .claude/adapter.md, then read and execute the validate skill at .claude/skills/validate/SKILL.md to run broad validation and phase closure."}

            If execution is NOT complete (partial progress, asking a question, debugging, waiting for user input, retrying tasks), respond with:
            {}

            The message to examine:
            $ARGUMENTS
          timeout: 15
---

# Co-Design Executor — Design-Aware Parallel TDD

You are an Orchestrator. Parse plan files and execute tasks in parallel waves with **dual-track routing**: standard tasks use the RED/GREEN TDD flow via Task tool subagents, while design tasks (CSS, UI, components) route to `claude -p` with full CLI access and design-system awareness. After waves containing design tasks, the web-designer skill auto-reviews visual output.

## Prerequisites

- Read the project adapter at `.claude/adapter.md` for test commands, lint, conventions, regression gate commands, and design system doc paths.
- A plan file must exist (produced by `/swarm-plan`).
- For design review gates: the web-designer skill should be installed at `.claude/skills/web-designer/SKILL.md`. If not installed, design review is skipped with a warning.
- Read the **design identity doc** and **design system doc** (paths from adapter conventions) — these are injected into design agent prompts.

## Model Routing

| Agent Role | Model | Rationale |
|------------|-------|-----------|
| **Orchestrator** (you) | opus | Classification, validation, judgment calls |
| **Test Agent** (RED) | opus | Acceptance criteria, edge cases, test architecture |
| **Dev Agent** (GREEN) | sonnet | Fast, focused implementation |
| **Design Agent** | opus | Design-system-aware implementation via `claude -p` |
| **Design Gate** | opus | Post-wave visual review (web-designer skill) |

## Process

### Step 1: Parse Plan + Classify Tasks

Extract from user request:
1. **Plan file**: The markdown plan to read
2. **Task subset** (optional): Specific task IDs to run

Read and parse the plan:
1. Find task subsections (e.g., `### T1:` or `### Task 1.1:`)
2. For each task, extract:
   - Task ID, name, depends_on list
   - Files, test_files, test_type
   - Description, acceptance_criteria, validation command
3. Build task list and dependency graph
4. Calculate waves from the dependency DAG

**Classify each task as "design" or "standard":**

A task is **design** if ANY of these are true:
- Plan explicitly sets `task_type: design`
- Files list contains `.css`, `.scss`, `.sass`, `.less`, or `.styled.` files
- Files list contains component files (`.jsx`, `.tsx`, `.vue`, `.svelte`) where the description mentions styling, layout, UI, visual, or design
- Description contains design keywords: CSS, styling, layout, design tokens, animations, transitions, responsive, accessibility/a11y, visual, UI component, theme, palette

All other tasks are **standard**.

Read adapter config for overrides (if present under `## Executor Variants` → `### Co-Design`):
- **Design task keywords**: custom keyword list (or use defaults above)
- **Design tasks skip RED phase**: default false

Log the classification:
```
Task classification:
  T1: [Name] → standard
  T2: [Name] → design (matched: .css file, "layout" in description)
  T3: [Name] → standard
```

### Step 2: Execute Waves (Dual Track)

For each wave, launch all unblocked tasks in parallel. A task is unblocked when all IDs in its `depends_on` are complete AND the previous wave's regression gate passed.

#### Standard Track: RED/GREEN via Task Tool

Standard tasks use the same separated test/dev agent flow as `/swarm`:

**Phase A: Test Agent (RED)** — Launch with `model: opus`:

```
You are a specialized TEST AGENT. Your only job is to write failing tests that
encode the acceptance criteria for a task. You do NOT implement production code.

## Context
- Plan: [filename]
- Project adapter: .claude/adapter.md (READ THIS FIRST for test patterns and conventions)
- Task: [ID]: [Name]
- Test type: [unit | integration | e2e]
- Test files to create/modify: [exact paths from plan]
- Acceptance criteria:
  [list from plan]

## Related Context
- Source files this task will modify: [paths — read these to understand the interface]
- Dependencies completed: [list of completed task IDs and their summaries]
- Existing test patterns: [relevant test file paths to read for style reference]

## Instructions

1. Read the project adapter at `.claude/adapter.md` to understand test conventions, file patterns, and runner commands.
2. Read the source files listed above to understand the current interface and types.
3. Read existing test files for the same layer to match patterns and style.
4. Write failing tests that encode EVERY acceptance criterion:
   - One or more test cases per criterion
   - Include edge cases and error paths
   - Use specific assertions (assert result.value == 'expected', not assert result is not None)
   - Follow project naming conventions (test names mirror function under test)
5. Run the tests to confirm they FAIL for the right reason.
6. ONLY edit test files. Do NOT touch production/source files.
7. Do NOT commit. Leave the failing tests for the dev agent.
```

**Phase B: Dev Agent (GREEN)** — Launch with `model: sonnet`:

```
You are a specialized DEV AGENT. Your job is to implement production code that
makes the failing tests pass. You do NOT modify test files.

## Context
- Plan: [filename]
- Project adapter: .claude/adapter.md (READ THIS FIRST for conventions)
- Task: [ID]: [Name]
- Source files to modify: [exact paths from plan]
- Test files (your contract — DO NOT MODIFY): [paths written by test agent]
- RED evidence: [summary of what's failing and why]

## Instructions

1. Read the project adapter for conventions.
2. Read the failing test files — these are your implementation contract.
3. Implement the minimal production code to make ALL tests pass.
4. Run the tests until GREEN.
5. Run lint and fix any issues.
6. ONLY edit source/production files.
7. Commit (never push). Update plan file task entry with status/log/files_modified.
```

#### Design Track: Design Agent via `claude -p`

Design tasks launch via `claude -p` in a background shell with full CLI access and design-system awareness.

**If design tasks should include RED phase** (adapter config `Design tasks skip RED phase: false`):
1. First launch a RED agent (same as standard track) to write tests for any testable behavior (responsive breakpoints, animation timing, accessibility attributes, state changes)
2. Then launch the design agent to implement

**If purely visual** (adapter config `Design tasks skip RED phase: true`):
1. Skip RED phase
2. Launch design agent directly

**Design Agent prompt** — Launch via `claude -p` with `--model opus`:

```bash
claude -p "$(cat <<'PROMPT_EOF'
You are a DESIGN IMPLEMENTATION AGENT with full CLI access and deep knowledge
of the project's design system.

## Read These First (in order)
1. Design identity doc: [path from adapter conventions]
2. Design system doc: [path from adapter conventions]
3. Project adapter: .claude/adapter.md

## Task
- Task: [ID]: [Name]
- Files to modify: [exact paths from plan]
- Description: [description from plan]
- Acceptance criteria:
  [list from plan]

## Design Constraints
- Use design tokens from the design system doc — NEVER hardcode colors, spacing, typography, or breakpoints
- Follow the design identity's aesthetic principles and visual language
- Follow component patterns and composition rules from the design system
- Ensure WCAG AA accessibility (contrast ratios, focus indicators, aria attributes)
- Match existing component patterns in the codebase

## Instructions

1. Read the design docs listed above to understand tokens, patterns, and identity.
2. Read the source files you'll modify and related components for pattern consistency.
3. Implement the design task:
   - Use design tokens for all values (colors, spacing, font sizes, breakpoints)
   - Follow component composition patterns from the design system
   - Include hover, focus, active, disabled, error states as appropriate
   - Add aria attributes and keyboard navigation where needed
4. Run lint and fix any issues.
5. If test files exist for this task (from a RED phase), run tests until GREEN.
6. Commit your work (never push). Descriptive commit message.
7. Update the plan file task entry with status: complete, log, files_modified.
PROMPT_EOF
)" --model opus 2>&1 | tee "/tmp/co-design-[TASK_ID]-output.log"
```

**Monitor design agent completion**: Check the log file for the `claude -p` process exit.

### Step 3: Inter-Wave Regression + Design Gate

After ALL tasks in a wave complete:

1. **Regression gate**: Run the regression gate command from the adapter.
   - If regression fails: identify which task(s) caused it, launch fix agent, re-run until green.

2. **Design review gate** (if this wave contained design tasks):
   - Check if the web-designer skill is installed at `.claude/skills/web-designer/SKILL.md`
   - If installed: spawn a design review subagent:
     ```
     Read the design identity doc, design system doc, and project adapter.
     Then follow the web-designer skill at .claude/skills/web-designer/SKILL.md.
     Review the following components/views that were modified in this wave:
     [list of design task files and descriptions]
     ```
   - If the review finds **critical findings**: create fix tasks and execute them before the next wave.
   - If **acceptable** or **minor findings**: log them and proceed.
   - If web-designer skill not installed: log a warning and skip design review.

3. If no design tasks in this wave: skip design review, proceed to next wave.

**Do NOT launch the next wave until regression is green.**

### Step 4: Final Integration Pass

After all waves complete:

1. **Reconcile parallel conflicts**: Check for duplicate files, naming drift, import conflicts across tasks.
2. **Cross-task integration**: Verify design + standard tasks integrate correctly (e.g., components use the styles that were implemented).
3. **Run full regression** using the adapter's full test matrix command.
4. Fix any failures. Re-run until green.

### Step 5: Completion Signal

When all tasks are complete, integrated, and regression is green, output the execution summary and announce:

"All N tasks complete across M waves (D design + S standard). Final regression green. Proceeding to validation."

The `Stop` hook will detect this and chain into `/validate`.

## Error Handling

- **Misclassification**: If a design task clearly needs tests (has behavioral acceptance criteria), the orchestrator should add a RED phase even if it was classified as design-only. Use judgment.
- **Design agent produces hardcoded values**: The design review gate should catch this. If it does, create a fix task.
- **Web-designer skill not installed**: Log warning, skip design review gates. Co-design still works — you just lose the automated visual review.
- **`claude -p` fails or hangs**: Check the output log. Kill the process and retry or escalate.
- **Test agent can't write meaningful tests**: Escalate to user.
- **Dev agent can't make tests pass after 2 attempts**: Escalate.
- **File conflict between parallel tasks**: Resolve in integration pass.

## Execution Summary Template

```markdown
# Execution Summary

**Plan**: [filename]
**Date**: [date]
**Executor**: co-design

## Task Classification
| Task | Type | Reason |
|------|------|--------|
| T1: [Name] | standard | No design keywords |
| T2: [Name] | design | .css file + "layout" in description |
| T3: [Name] | standard | Backend logic |

## Waves Executed: [M]

### Wave 1
| Task | Type | RED | GREEN/Design | Design Review | Status |
|------|------|-----|-------------|---------------|--------|
| T1 | standard | 5 tests | GREEN in 1 attempt | — | complete |
| T2 | design | skipped | Design agent: done | — | complete |

**Regression gate**: PASSED
**Design review**: [findings summary or "no design tasks"]

### Wave 2
| Task | Type | RED | GREEN/Design | Design Review | Status |
|------|------|-----|-------------|---------------|--------|
| T3 | standard | 4 tests | GREEN in 1 attempt | — | complete |

**Regression gate**: PASSED

## Design Review Summary
- Wave 1: [N] findings ([critical/major/minor]), [resolution]
- Wave 2: No design tasks

## Integration Pass
- [Conflict or fix]: [Resolution]

## Final Regression
- Lint: PASSED
- Unit tests: PASSED (N tests)
- Integration tests: PASSED (N tests)
- E2E (if run): PASSED (N tests)

## Files Modified
[List of all changed files across all tasks]

## Overall Status
All [N] tasks complete across [M] waves ([D] design + [S] standard). Final regression green. Ready for /validate.
```

## Example Usage

```
/co-design ui-redesign-plan.md
/co-design ./plans/dashboard-plan.md T2 T5 T6
```
