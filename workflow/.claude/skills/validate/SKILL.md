---
name: validate
description: Broad validation and phase closure — full test matrix, regression check, cleanup, code review, documentation, and phase handoff. Triggers include "validate", "close phase", "final check", "/validate".
---

# validate — Broad Validation & Phase Closure

Pre-completion validation pass. Run the full test matrix, check for regressions, clean up artifacts, review code quality, update documentation, and prepare the phase for closure.

This skill merges per-change validation with the project's phase closure protocol. Use it after `/swarm` completes all tasks for a feature or phase.

## Prerequisites

- Read the project adapter at `.claude/adapter.md` for the full test matrix, conventions, and quality standards.
- Code should already be implemented and passing scoped tests (from `/swarm`).
- Know which phase/features are being validated (check feature tracker and roadmap — see adapter conventions).

## When to Use

- After `/swarm` completes all tasks for a feature or phase
- Before closing a phase
- When doing a final quality pass on a branch

## Checklist

Work through these steps in order. Each must pass before proceeding to the next.

### 1. Full Test Matrix

Run ALL test types from the adapter:

```bash
# Replace with your project's commands from adapter.md:
# [lint command]
# [unit test command(s)]
# [integration test command(s)]
# [E2E test command, if full stack available]
```

If any test fails:
- Determine if it's a regression you introduced or a pre-existing failure
- Fix regressions before proceeding
- Document pre-existing failures (not your responsibility, but note them)

### 2. Regression Check

Look beyond the files you directly changed:

- **Downstream consumers**: who imports or calls the modules you modified?
- **Keybind/shortcut conflicts**: did you add/change bindings that conflict with existing ones?
- **Design token usage**: any new hardcoded values that should use design system tokens?
- **Database**: any migration impacts or model changes?
- **API contracts**: any breaking changes to endpoints or data shapes?

Run targeted tests on adjacent areas if risk is identified.

### 3. Cleanup

Review all changes for artifacts that shouldn't ship:

- [ ] Remove `console.log()` / `print()` / debug statements
- [ ] Remove commented-out code
- [ ] Remove throwaway / exploratory tests (tests written to probe, not for coverage)
- [ ] Resolve TODO/FIXME comments (fix or convert to tracked issues)
- [ ] Verify no accidental file changes (editor config, unrelated files)
- [ ] No AI-generated comments that just narrate what code does

Run `git diff main` (or the base branch) and review every changed file.

### 4. Code Quality Review

Review the implementation against project standards (see adapter conventions):

- [ ] Pure functions extracted from component handlers (no inline decision trees)
- [ ] Test names mirror the function under test
- [ ] Specific assertions (`assert result.value == 'expected'` not `assert result is not None`)
- [ ] Design tokens used, not hardcoded values (if applicable)
- [ ] Project patterns followed (see adapter file patterns and conventions)
- [ ] Error handling gives user feedback (no silent catches)
- [ ] No versioned components (ProperX, SmoothX — fix the original)

### 5. Design Review (if frontend changes)

If this phase touched CSS, layout, or UI components, and the web-designer skill is installed:

1. Spawn a design review agent using the web-designer skill (`.claude/skills/web-designer/SKILL.md`)
2. The agent reads the design system docs (see adapter conventions)
3. It uses the Playwright MCP to screenshot all affected views
4. It produces a design review report with findings

If critical findings exist, fix them before proceeding.
If no frontend changes in this phase, or if the web-designer skill is not installed, skip this step.

### 6. Feature Completion Matrix

For each feature in scope, verify against the feature tracker (see adapter conventions):

```markdown
| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| [identifier]: [name] | COMPLETE | [test file(s)] | [any caveats] |
```

- Every acceptance criterion checked off
- Every test plan item has a corresponding test
- Update feature tracker status

### 7. Documentation Updates

- [ ] Feature tracker — feature statuses updated, acceptance criteria checked
- [ ] Design system doc — updated if UX patterns or tokens changed
- [ ] Roadmap — phase status updated if closing a phase
- [ ] ADRs written for significant architectural decisions
- [ ] Spec docs accurate and complete

### 8. Phase Closure Document (if closing a phase)

If this validation closes a roadmap phase, generate a closure document:

```markdown
# Phase [X]: [Name] — Closure Document

## Executive Summary
[What was built, why, key decisions made]

## Feature Completion Matrix
| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| [id] | COMPLETE | test file | notes |

## Technical Validation
- Test results: [summary of test runs]
- Quality gates: [lint, unit, integration, E2E status]
- Performance: [any benchmarks or observations]

## Handoff to Next Phase
- Next phase: [name from roadmap]
- Prerequisites: [what needs to be true before starting]
- Known limitations: [anything deferred]
- Recommended first steps: [concrete next actions]
```

Update project docs to point to the new phase.

### 9. Sign-off

All steps above must pass:

- [ ] Full test matrix: green (or pre-existing failures documented)
- [ ] Regression check: no new regressions
- [ ] Cleanup: no debug artifacts, no throwaway code
- [ ] Code quality: matches project standards
- [ ] Design review: alignment strong, no critical findings (if applicable)
- [ ] Feature completion: all acceptance criteria met
- [ ] Documentation: up to date
- [ ] Phase closure doc: written (if applicable)

If all pass: "Validation complete. Phase is ready for closure."

If any fail: list what needs fixing. After fixes, re-run the failed steps (not the entire checklist).

## Guidance

- **Don't rush**: This is the last gate before a phase is considered done. Thoroughness here prevents rework.
- **Pre-existing failures**: Not every red test is your fault. Compare against the base branch to distinguish regressions from pre-existing issues.
- **Greenfield check**: If this closes a phase, the next phase should start with a dependency audit and version alignment.
