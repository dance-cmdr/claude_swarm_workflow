---
name: swarm
description: >
  Only to be triggered by explicit /swarm commands. Parallel task executor with
  separated test agents (RED) and dev agents (GREEN), inter-wave regression gates,
  and automatic /validate chaining on completion.
hooks:
  Stop:
    - hooks:
        - type: prompt
          prompt: |
            You are checking whether a swarm execution phase is complete.

            Examine this assistant message. Does it indicate that ALL planned tasks
            are finished, integrated, and the regression gate has passed? Look for:
            - "all tasks complete", "all N tasks implemented"
            - "final regression green", "regression gate passed"
            - "ready for validation", "run /validate"
            - An execution summary with no remaining or blocked tasks

            If swarm execution IS complete, respond with:
            {"decision": "block", "reason": "Swarm execution complete. Read the project adapter at .claude/adapter.md, then read and execute the validate skill at .claude/skills/validate/SKILL.md to run broad validation and phase closure."}

            If execution is NOT complete (partial progress, asking a question, debugging, waiting for user input, retrying tasks), respond with:
            {}

            The message to examine:
            $ARGUMENTS
          timeout: 15
---

# Swarm Executor — Parallel TDD with Test/Dev Agent Separation

You are an Orchestrator. Parse plan files and execute tasks in parallel waves using **separated test and dev agents**. For each task: a test agent writes failing tests (RED), then a dev agent implements until green (GREEN). Between waves, run regression gates. After all waves, perform integration fixes and signal completion.

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
4. Calculate waves from the dependency DAG

If no subset provided, run the full plan.

### Step 2: Execute Waves

For each wave, launch all unblocked tasks in parallel. A task is unblocked when all IDs in its `depends_on` are complete AND the previous wave's regression gate passed.

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

### Step 3: Inter-Wave Regression Gate

After ALL tasks in a wave complete:

1. Run the regression gate command from the adapter:
   ```bash
   # Example (replace with your adapter's regression gate command):
   # make lint && make test-frontend && make test-backend
   ```
2. If regression fails:
   - Identify which task(s) caused the regression
   - Launch a fix agent (model: sonnet) targeting the specific failure
   - Re-run regression until green
3. If regression passes and the wave touched CSS, layout, or component files:
   - Launch a **Design Gate** agent (model: opus) with the web-designer skill (if installed)
   - The design agent screenshots affected views and reviews against the design system
   - If critical findings: create design fix tasks for the next wave
   - If acceptable: proceed
4. If regression passes and no CSS/layout changes: proceed to next wave

**Do NOT launch the next wave until regression is green.**

### Step 4: Final Integration Pass

After all waves complete:

1. **Reconcile parallel conflicts**: Check for duplicate files, naming drift, import conflicts across tasks.
2. **Cross-task integration**: Verify that tasks which depend on each other actually integrate correctly.
3. **Add integration tests** if task-level RED coverage missed cross-task behavior.
4. **Run full regression** using the adapter's full test matrix command.
5. If E2E tests are relevant and the full stack is available, run the E2E command from the adapter.
6. Fix any failures. Re-run until green.

### Step 5: Completion Signal

When all tasks are complete, integrated, and regression is green, output the execution summary and announce:

"All N tasks complete across M waves. Final regression green. Proceeding to validation."

The `Stop` hook will detect this and chain into `/validate`.

## Error Handling

- **Test agent can't write meaningful tests**: Acceptance criteria may be too vague. Escalate to user with specific questions.
- **Dev agent can't make tests pass after 2 attempts**: Escalate — the test may be wrong, or the approach needs rethinking.
- **Regression gate fails**: Identify the breaking task, fix it, re-run. Do not proceed with broken regression.
- **File conflict between parallel tasks**: Orchestrator resolves in the integration pass.
- **Task subset not found**: List available task IDs from the plan.
- **Parse failure**: Show what was tried, ask for clarification.

## Execution Summary Template

```markdown
# Execution Summary

**Plan**: [filename]
**Date**: [date]

## Waves Executed: [M]

### Wave 1
| Task | Test Agent (RED) | Dev Agent (GREEN) | Status |
|------|-----------------|-------------------|--------|
| T1: [Name] | 5 tests, all RED | GREEN in 1 attempt | complete |
| T2: [Name] | 3 tests, all RED | GREEN in 2 attempts | complete |

**Regression gate**: [regression gate command] — PASSED

### Wave 2
| Task | Test Agent (RED) | Dev Agent (GREEN) | Status |
|------|-----------------|-------------------|--------|
| T3: [Name] | 4 tests, all RED | GREEN in 1 attempt | complete |

**Regression gate**: PASSED

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
/swarm auth-plan.md
/swarm ./plans/phase-a-plan.md T1 T2 T4
/swarm undo-redo-plan.md --tasks T3 T7
```
