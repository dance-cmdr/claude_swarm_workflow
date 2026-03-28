---
name: swarm-tmux
description: >
  Only to be triggered by explicit /swarm-tmux commands. Wave-based parallel
  executor with live tmux pane visibility — each agent runs as `claude -p` in
  its own tmux pane. Automatic /validate chaining on completion.
hooks:
  Stop:
    - hooks:
        - type: prompt
          prompt: |
            You are checking whether a swarm-tmux execution phase is complete.

            Examine this assistant message. Does it indicate that ALL planned tasks
            are finished, integrated, and the regression gate has passed? Look for:
            - "all tasks complete", "all N tasks implemented"
            - "final regression green", "regression gate passed"
            - "ready for validation", "run /validate"
            - An execution summary with no remaining or blocked tasks

            If swarm-tmux execution IS complete, respond with:
            {"decision": "block", "reason": "Swarm-tmux execution complete. Read the project adapter at .claude/adapter.md, then read and execute the validate skill at .claude/skills/validate/SKILL.md to run broad validation and phase closure."}

            If execution is NOT complete (partial progress, asking a question, debugging, waiting for user input, retrying tasks), respond with:
            {}

            The message to examine:
            $ARGUMENTS
          timeout: 15
---

# Swarm-Tmux Executor — Wave-Based TDD with Live Tmux Visibility

You are an Orchestrator. Parse plan files and execute tasks in parallel waves where **each agent runs as `claude -p` in a live tmux pane**. Users can attach to the tmux session and watch agents work in real time. For each task: a test agent writes failing tests (RED), then a dev agent implements until green (GREEN). Between waves, run regression gates.

## Prerequisites

- Read the project adapter at `.claude/adapter.md` for test commands, lint, conventions, and regression gate commands.
- A plan file must exist (produced by `/swarm-plan`).
- **tmux must be installed**. Run `which tmux` to verify. If not found, tell the user to install it and stop.

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

### Step 2: Initialize Tmux Session

Use the helper script at `$CLAUDE_PROJECT_DIR/.claude/hooks/tmux_spawn_worker.sh`:

```bash
# Create the swarm session
"$CLAUDE_PROJECT_DIR/.claude/hooks/tmux_spawn_worker.sh" init "swarm-$(basename "$PLAN_FILE" .md)"
```

This creates a tmux session. Tell the user how to attach:

```
Tmux session created. To watch agents live:
  tmux attach -t swarm-<plan-name>
```

### Step 3: Execute Waves with Tmux Panes

For each wave, launch all unblocked tasks in parallel. A task is unblocked when all IDs in its `depends_on` are complete AND the previous wave's regression gate passed.

**For each task, run two sequential agents in tmux panes:**

#### Phase A: Test Agent (RED)

1. Write the test agent prompt to a temp file:

```bash
PROMPT_FILE=$(mktemp /tmp/swarm-red-TASKID-XXXX.md)
cat > "$PROMPT_FILE" << 'PROMPT_EOF'
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
PROMPT_EOF
```

2. Spawn the RED agent in a tmux pane:

```bash
"$CLAUDE_PROJECT_DIR/.claude/hooks/tmux_spawn_worker.sh" spawn "$SESSION" "T1-red" "$PROMPT_FILE" "--model opus"
```

3. Monitor until the pane's process exits:

```bash
while "$CLAUDE_PROJECT_DIR/.claude/hooks/tmux_spawn_worker.sh" status "$SESSION" "T1-red"; do
  sleep 5
done
```

4. Read the output log and validate RED evidence (tests fail for the right reason). If tests don't fail correctly, spawn a fix pane.

#### Phase B: Dev Agent (GREEN)

1. Write the dev agent prompt to a temp file (same pattern as RED but with dev instructions):

```bash
PROMPT_FILE=$(mktemp /tmp/swarm-green-TASKID-XXXX.md)
cat > "$PROMPT_FILE" << 'PROMPT_EOF'
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
PROMPT_EOF
```

2. Spawn the GREEN agent in the same pane (or a new one):

```bash
"$CLAUDE_PROJECT_DIR/.claude/hooks/tmux_spawn_worker.sh" spawn "$SESSION" "T1-green" "$PROMPT_FILE" "--model sonnet"
```

3. Monitor until complete. Validate GREEN evidence.

**Launch all tasks in a wave in parallel** — each task's RED/GREEN sequence runs independently in its own pane(s).

### Step 4: Inter-Wave Regression Gate

After ALL tasks in a wave complete:

1. Run the regression gate command from the adapter.
2. If regression fails:
   - Identify which task(s) caused the regression
   - Launch a fix agent in a new tmux pane targeting the specific failure
   - Re-run regression until green
3. If regression passes and the wave touched CSS, layout, or component files:
   - Launch a **Design Gate** agent (model: opus) with the web-designer skill (if installed)
   - If critical findings: create design fix tasks for the next wave
   - If acceptable: proceed
4. If regression passes and no CSS/layout changes: proceed to next wave

**Do NOT launch the next wave until regression is green.**

### Step 5: Final Integration Pass

After all waves complete:

1. **Reconcile parallel conflicts**: Check for duplicate files, naming drift, import conflicts across tasks.
2. **Cross-task integration**: Verify that tasks which depend on each other actually integrate correctly.
3. **Add integration tests** if task-level RED coverage missed cross-task behavior.
4. **Run full regression** using the adapter's full test matrix command.
5. If E2E tests are relevant and the full stack is available, run the E2E command from the adapter.
6. Fix any failures. Re-run until green.

### Step 6: Cleanup & Completion Signal

1. Clean up temp prompt files: `rm -f /tmp/swarm-red-* /tmp/swarm-green-*`
2. Optionally kill the tmux session (or leave alive for audit):

```bash
"$CLAUDE_PROJECT_DIR/.claude/hooks/tmux_spawn_worker.sh" cleanup "$SESSION"
```

3. Output the execution summary and announce:

"All N tasks complete across M waves. Final regression green. Proceeding to validation."

The `Stop` hook will detect this and chain into `/validate`.

## Error Handling

- **tmux not installed**: Stop immediately with install instructions.
- **Test agent can't write meaningful tests**: Acceptance criteria may be too vague. Escalate to user with specific questions.
- **Dev agent can't make tests pass after 2 attempts**: Escalate — the test may be wrong, or the approach needs rethinking.
- **Regression gate fails**: Identify the breaking task, fix it in a new tmux pane, re-run. Do not proceed with broken regression.
- **File conflict between parallel tasks**: Orchestrator resolves in the integration pass.
- **Pane exits with error**: Check the output log, diagnose, and retry or escalate.
- **Task subset not found**: List available task IDs from the plan.

## Execution Summary Template

```markdown
# Execution Summary

**Plan**: [filename]
**Date**: [date]
**Executor**: swarm-tmux
**Session**: tmux attach -t [session-name]

## Waves Executed: [M]

### Wave 1
| Task | Pane (RED) | Pane (GREEN) | Status |
|------|-----------|-------------|--------|
| T1: [Name] | T1-red: 5 tests | T1-green: GREEN in 1 attempt | complete |
| T2: [Name] | T2-red: 3 tests | T2-green: GREEN in 2 attempts | complete |

**Regression gate**: [command] — PASSED

### Wave 2
| Task | Pane (RED) | Pane (GREEN) | Status |
|------|-----------|-------------|--------|
| T3: [Name] | T3-red: 4 tests | T3-green: GREEN in 1 attempt | complete |

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
All [N] tasks complete across [M] waves. Final regression green. Ready for /validate.
```

## Example Usage

```
/swarm-tmux auth-plan.md
/swarm-tmux ./plans/phase-a-plan.md T1 T2 T4
```
