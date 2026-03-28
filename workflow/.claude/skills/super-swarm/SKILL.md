---
name: super-swarm
description: >
  Only to be triggered by explicit /super-swarm commands. Rolling pool executor
  with up to 12 concurrent RED/GREEN agent pairs, periodic regression gates,
  and automatic /validate chaining on completion.
hooks:
  Stop:
    - hooks:
        - type: prompt
          prompt: |
            You are checking whether a super-swarm execution phase is complete.

            Examine this assistant message. Does it indicate that ALL planned tasks
            are finished, integrated, and the regression gate has passed? Look for:
            - "all tasks complete", "all N tasks implemented"
            - "final regression green", "regression gate passed"
            - "ready for validation", "run /validate"
            - An execution summary with no remaining or blocked tasks

            If super-swarm execution IS complete, respond with:
            {"decision": "block", "reason": "Super-swarm execution complete. Read the project adapter at .claude/adapter.md, then read and execute the validate skill at .claude/skills/validate/SKILL.md to run broad validation and phase closure."}

            If execution is NOT complete (partial progress, asking a question, debugging, waiting for user input, retrying tasks), respond with:
            {}

            The message to examine:
            $ARGUMENTS
          timeout: 15
---

# Super-Swarm Executor — Rolling Pool TDD with Test/Dev Agent Separation

You are an Orchestrator. Parse plan files and execute tasks using a **rolling pool** of up to 12 concurrent RED/GREEN agent pairs. Unlike wave-based execution, tasks launch as soon as dependencies are satisfied and a pool slot is available — no waiting for an entire wave to complete. Regression gates run periodically rather than at wave boundaries.

## Prerequisites

- Read the project adapter at `.claude/adapter.md` for test commands, lint, conventions, and regression gate commands.
- A plan file must exist (produced by `/swarm-plan`).

## Model Routing

| Agent Role | Model | Rationale |
|------------|-------|-----------|
| **Orchestrator** (you) | opus | Judgment calls, validation, conflict resolution |
| **Test Agent** (RED) | opus | Deep reasoning about acceptance criteria, edge cases, test architecture |
| **Dev Agent** (GREEN) | sonnet | Fast, focused implementation — tests define the contract |
| **Design Gate** (optional) | opus | Visual review of CSS/layout changes (requires web-designer skill) |

## Process

### Step 1: Parse Plan

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
4. Build a **ready queue**: all tasks whose `depends_on` are empty or already complete

If no subset provided, run the full plan.

### Step 2: Initialize Rolling Pool

Read pool configuration from adapter (if present under `## Executor Variants` → `### Super-Swarm`):
- **Max concurrent agents**: default 12
- **Regression gate frequency**: default every 4 completed tasks

Initialize tracking:
- `active_slots`: currently executing RED/GREEN pairs (max = pool size)
- `completed_count`: total tasks completed
- `completed_since_last_gate`: counter, resets after each regression gate
- `ready_queue`: tasks whose dependencies are all satisfied but not yet launched

### Step 3: Rolling Pool Execution

**Loop until all tasks are complete or all remaining tasks are blocked:**

1. **Fill pool**: While `active_slots < max_concurrent` AND `ready_queue` is not empty:
   - Dequeue the next task from `ready_queue`
   - Launch its RED/GREEN pair (see agent prompts below)
   - Increment `active_slots`

2. **Wait for any completion**: When a RED/GREEN pair finishes:
   - Validate GREEN evidence (tests pass, lint clean)
   - If validation fails, retry the dev agent (up to 2 attempts) or escalate
   - Mark task complete, decrement `active_slots`
   - Increment `completed_count` and `completed_since_last_gate`
   - **Refresh ready queue**: check all pending tasks — any whose dependencies are now all complete get added to `ready_queue`

3. **Periodic regression gate**: If `completed_since_last_gate >= gate_frequency`:
   - Wait for all in-flight tasks to finish their current RED/GREEN cycle
   - Run the regression gate command from the adapter
   - If regression fails: identify breaking task(s), launch fix agent (sonnet), re-run until green
   - If regression passes and CSS/layout files were touched: run design gate (if web-designer skill installed)
   - Reset `completed_since_last_gate` to 0
   - Resume pool execution

4. **Natural drain gate**: If `active_slots == 0` AND there are still queued tasks:
   - Run regression gate before launching the next batch
   - This catches regressions at natural pause points

**For each task, execute two sequential agents:**

#### Phase A: Test Agent (RED)

Launch with `model: opus`:

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
   - For unit tests: no mocks, no rendering, pure input/output
   - For integration tests: real database/API client
   - For E2E tests: browser automation with mocking patterns from adapter
5. Run the tests to confirm they FAIL for the right reason:
   - Not import errors or typos
   - Genuine "not implemented yet" or "wrong behavior" failures
   - Run command: [validation command from plan]
6. ONLY edit test files. Do NOT touch production/source files.
7. Do NOT commit. Leave the failing tests for the dev agent.

## Output
Return:
- Test files created/modified (exact paths)
- Number of test cases written
- RED evidence: command output showing tests fail for the expected reason
- Any blockers or ambiguities discovered
```

**Validate RED evidence** before proceeding. If tests don't fail for the right reason, have the test agent fix them.

#### Phase B: Dev Agent (GREEN)

Launch with `model: sonnet`:

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

## Related Context
- Dependencies completed: [list of completed task IDs and their summaries]
- Design system doc: [path from adapter, if frontend work]
- Constraints: [risks from plan]

## Instructions

1. Read the project adapter at `.claude/adapter.md` for conventions.
2. Read the failing test files — these are your implementation contract.
3. Read the source files you'll modify, plus related modules.
4. Read the design system doc if this is frontend work (see adapter conventions).
5. Implement the minimal production code to make ALL tests pass:
   - Follow project conventions (adapter.md)
   - Use design tokens, not hardcoded values
   - Extract pure functions from handlers when there's decision logic
   - Extreme comment minimalism — prefer descriptive names
6. Run the tests until GREEN:
   - Run command: [validation command from plan]
   - If tests fail, fix your implementation (not the tests)
   - If stuck after 2 attempts, report the blocker
7. Run lint: [lint command from adapter] — fix any issues you introduced.
8. ONLY edit source/production files. Do NOT modify test files.
9. Commit your work:
   - Stage only files for this task (source + test files)
   - NEVER PUSH. ONLY COMMIT.
   - Descriptive commit message focused on "why"
10. Update the plan file task entry with:
    - status: complete
    - log: [concise work summary]
    - files_modified: [exact paths]

## Output
Return:
- Files modified/created (exact paths)
- GREEN evidence: command output showing all tests pass
- Lint status: clean or issues fixed
- How acceptance criteria are satisfied
- Any gotchas encountered
```

**Validate GREEN evidence** before marking the task complete. If tests aren't green, have the dev agent retry or escalate.

### Step 4: Final Integration Pass

After all tasks complete:

1. **Reconcile parallel conflicts**: Check for duplicate files, naming drift, import conflicts across tasks.
2. **Cross-task integration**: Verify that tasks which depend on each other actually integrate correctly.
3. **Add integration tests** if task-level RED coverage missed cross-task behavior.
4. **Run full regression** using the adapter's full test matrix command.
5. If E2E tests are relevant and the full stack is available, run the E2E command from the adapter.
6. Fix any failures. Re-run until green.

### Step 5: Completion Signal

When all tasks are complete, integrated, and regression is green, output the execution summary and announce:

"All N tasks complete. Final regression green. Proceeding to validation."

The `Stop` hook will detect this and chain into `/validate`.

## Error Handling

- **Test agent can't write meaningful tests**: Acceptance criteria may be too vague. Escalate to user with specific questions.
- **Dev agent can't make tests pass after 2 attempts**: Escalate — the test may be wrong, or the approach needs rethinking.
- **Regression gate fails**: Identify the breaking task, fix it, re-run. Do not proceed with broken regression.
- **File conflict between parallel tasks**: Orchestrator resolves in the integration pass.
- **Pool stall**: If all active slots are occupied by blocked/stuck tasks, escalate to user rather than waiting indefinitely.
- **Task subset not found**: List available task IDs from the plan.
- **Parse failure**: Show what was tried, ask for clarification.

## Execution Summary Template

```markdown
# Execution Summary

**Plan**: [filename]
**Date**: [date]
**Executor**: super-swarm (rolling pool, max [N] concurrent)

## Task Completion Timeline

| Order | Task | Started | Completed | RED | GREEN | Regression Gate |
|-------|------|---------|-----------|-----|-------|-----------------|
| 1 | T1: [Name] | 0:00 | 0:05 | 5 tests | GREEN in 1 attempt | — |
| 2 | T2: [Name] | 0:00 | 0:07 | 3 tests | GREEN in 2 attempts | — |
| 3 | T3: [Name] | 0:01 | 0:08 | 4 tests | GREEN in 1 attempt | — |
| 4 | T4: [Name] | 0:05 | 0:12 | 2 tests | GREEN in 1 attempt | Gate @ task 4: PASSED |

## Regression Gates
| After Task # | Command | Result |
|-------------|---------|--------|
| 4 | [regression command] | PASSED |
| 8 | [regression command] | PASSED |
| Final | [full test matrix] | PASSED |

## Integration Pass
- [Conflict or fix]: [Resolution]
- Tests added: [any integration tests]

## Final Regression
- Lint: PASSED
- Unit tests: PASSED (N tests)
- Integration tests: PASSED (N tests)
- E2E (if run): PASSED (N tests)

## Files Modified
[List of all changed files across all tasks]

## Issues Encountered
- [Task ID]: [Issue and resolution]

## Overall Status
All [N] tasks complete. Final regression green. Ready for /validate.
```

## Example Usage

```
/super-swarm auth-plan.md
/super-swarm ./plans/phase-a-plan.md T1 T2 T4
```
