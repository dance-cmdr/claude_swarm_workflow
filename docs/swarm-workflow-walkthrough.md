# Swarm Workflow: Guided Walkthrough

A practical guide to using the workflow end-to-end — from a rough idea to validated, committed code.

---

## Before You Start

You need Claude Code running in a project that has the swarm skills installed (`.claude/skills/` and `.claude/adapter.md`). The adapter should be configured for your project's test commands and file patterns.

---

## Phase 1: Start with /spec

### When to use it

You have an idea, a ticket, a bug report, or a "we should really..." thought that needs to become concrete before anyone writes code.

### How to kick it off

```
/spec
```

Then describe what you're thinking in plain language. Don't worry about structure — the spec skill will guide you through it.

### Example prompts to start with

**New feature:**
> We need to load our IOC config from S3 instead of bundling it in the deploy. The housekeeping servers should pull fresh config on each scan run.

**Bug report:**
> Users on the allowlist are still getting flagged. I think the case-sensitivity handling is wrong — usernames come in mixed case from GitHub but we're doing exact match.

**Refactor / tech debt:**
> The validation script has grown into a mess. It checks JSON syntax, allowlist format, and IOC pattern validity all in one bash function. We should break it apart so CI failures are easier to diagnose.

**Exploratory / uncertain:**
> I'm not sure if we need this, but what would it look like to add a "confidence score" to each IOC rule so we can prioritize scanning?

### What happens next

The spec skill will:
1. Ask 2-3 clarifying questions to orient on the problem
2. Explore the codebase to understand what exists
3. Walk through affected areas, acceptance criteria, risks, and scope
4. Surface any conflicts or tradeoffs for your decision
5. Write a spec to `docs/specs/YYYY-MM-DD-<name>.md`

### Tips

- **Be honest about uncertainty.** "I'm not sure if X or Y is the right approach" gives the spec skill something to investigate rather than assume.
- **Push back on scope.** When it lists affected areas, say "that's out of scope" for anything that shouldn't be in this round.
- **Acceptance criteria matter most.** These become the literal test cases later. Make sure they're specific and testable.

---

## Phase 2: Plan with /swarm-plan

### When to use it

You have a spec (or a clear enough picture in your head) and want to break the work into implementable tasks.

### How to kick it off

```
/swarm-plan
```

Then point it at the spec:

> Plan the implementation for docs/specs/2026-03-24-config-as-code-pipeline.md

Or describe the work directly if you skipped the spec phase:

> Plan the work to add S3 config loading. We need Terraform for the bucket, a GitHub Actions workflow to deploy, and a validation script for CI.

### What happens next

The planner will:
1. Research the codebase — existing patterns, file structure, dependencies
2. Ask clarifying questions if anything is ambiguous
3. Decompose work into atomic tasks with explicit dependencies
4. Build a wave table showing parallel execution order
5. Write the plan to `<topic>-plan.md`
6. Self-review the plan for gaps

### What to look for in the plan

- **File ownership**: Each task should own specific files. Flag it if two tasks list the same file.
- **Dependency accuracy**: Does task T4 actually need T1 and T2 to be done first? Or could it start earlier?
- **Wave sizing**: Too many waves means unnecessary serialization. Too few means hidden dependencies.
- **Acceptance criteria**: Each task's criteria should be concrete enough to write a test from.

### Example follow-up prompts

> T3 and T5 don't actually depend on each other — can you move T5 to Wave 1?

> The acceptance criteria for T2 are too vague. What specifically should the validation script check?

> Can you split T4 into two tasks? The PR workflow and the deploy workflow touch different files.

---

## Phase 3: Execute with /swarm

### When to use it

You have a reviewed plan and you're ready to implement.

### How to kick it off

```
/swarm config-as-code-pipeline-plan.md
```

To run specific tasks only:

```
/swarm config-as-code-pipeline-plan.md T1 T2
```

### What happens

For each wave, the orchestrator launches tasks in parallel. Each task runs two agents back-to-back:

1. **RED (Test Agent)** — Reads the acceptance criteria, writes failing tests, confirms they fail for the right reasons.
2. **GREEN (Dev Agent)** — Reads the failing tests as a contract, writes the minimal code to make them pass, commits.

After each wave, a regression gate runs the full test suite. If it passes, the next wave begins.

### When to intervene

- **RED agent can't write meaningful tests** — The acceptance criteria may be too vague. Refine them in the plan.
- **GREEN agent can't pass tests after 2 attempts** — The task may be too complex or the tests may encode a contradictory requirement. The orchestrator will escalate.
- **Regression gate fails** — Something in this wave broke a previous wave's work. The orchestrator will attempt a fix; it may ask for your input.

### What comes out

Each task gets a commit. The plan file is updated with status, logs, and files modified. An execution summary shows what happened across all waves.

---

## Phase 4: Validate with /validate

### When to use it

After `/swarm` completes (it auto-chains to validate), or whenever you want a thorough check of current state.

### How to kick it off

```
/validate
```

### What it checks

1. Full test matrix (every command from the adapter)
2. Regressions — did anything break that was working before?
3. Cleanup — debug statements, commented-out code, stale TODOs
4. Code quality — naming, structure, test coverage
5. Acceptance criteria — are all of them satisfied?
6. Documentation — anything that needs updating?

### What comes out

A validation report. If you're closing a phase, a phase closure document with executive summary, completion matrix, and handoff notes.

---

## Putting It All Together: A Real Example

Here's how the config-as-code pipeline feature went through the workflow:

**1. Spec** — Started with "we need to load IOC config from S3." The spec session identified seven areas of work, flagged a cross-repo dependency on server_build_tools, and explicitly scoped out multi-region replication.

**2. Plan** — Decomposed into 7 tasks across 3 waves:

```
Wave 1 (parallel):  T1 Terraform bootstrap
                    T2 Validation script
                    T3 Terraform main config

Wave 2 (parallel):  T4 PR validation workflow    (needs T2, T3)
                    T5 Deploy workflow            (needs T2, T3)
                    T6 server_build_tools plumbing (needs T3)

Wave 3:            T7 Instance profile attribute  (needs T6)
```

**3. Execute** — Wave 1 tasks ran in parallel. RED agents wrote test harnesses for the validation script while Terraform bootstrap had no RED phase (validated by `tofu validate` only). After Wave 1's regression gate passed, Wave 2 kicked off.

**4. Validate** — Full test matrix, cross-repo consistency check, phase closure document.

---

## Quick Reference

| I want to... | Command | What to say |
|---|---|---|
| Explore an idea | `/spec` | Describe the idea in plain language |
| Break work into tasks | `/swarm-plan` | Point at a spec or describe the work |
| Implement the plan | `/swarm <plan-file>` | Optionally specify task IDs |
| Run specific tasks | `/swarm <plan-file> T1 T3` | List the task IDs to run |
| Check everything | `/validate` | Runs automatically after swarm, or invoke manually |

---

## Common Patterns

**Skip spec for small changes**: If you already know exactly what needs to happen, go straight to `/swarm-plan`.

**Iterate on the plan**: The plan is a markdown file. Edit it directly, adjust dependencies, refine acceptance criteria, then run `/swarm`.

**Partial execution**: Use `/swarm <plan> T1 T2` to run just the tasks you want — useful for testing Wave 1 before committing to the full plan.

**Re-validate after manual changes**: If you hand-edit code after swarm finishes, run `/validate` again to make sure nothing broke.
