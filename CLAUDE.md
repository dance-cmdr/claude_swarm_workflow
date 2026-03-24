# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Swarm Workflow is an installable 4-phase parallel development workflow for Claude Code. It provides slash commands (`/spec`, `/swarm-plan`, `/swarm`, `/validate`) that use TDD with separated test and dev agents, dependency-aware task planning, and automated quality gates. It is installed into target projects via `install.sh`, which copies the `workflow/` directory contents into a project's `.claude/` directory.

## Repository Structure

This repo is a **distribution package**, not a runtime application. There is no build step, no dependencies, and no tests to run.

- `install.sh` — Installer script. Copies workflow files into a target project. Supports `--with-design-review`, `--with-cursor`, `--force` flags.
- `workflow/` — The installable payload:
  - `.claude/adapter.md` — Template for project-specific config (test commands, file patterns, conventions). Every skill reads this first.
  - `.claude/commands/` — Thin slash command routers (2-3 lines each). They load the adapter then delegate to the corresponding skill.
  - `.claude/skills/` — Full process logic for each phase (`spec/`, `swarm-plan/`, `swarm/`, `validate/`, `web-designer/`).
  - `.claude/hooks/auto-lint.sh` — PostToolUse hook template for auto-linting after Write/Edit.
  - `.claude/settings.json` — Permissions config + hook wiring.
- `examples/hexmap-cartographer/` — Real-world adapter and auto-lint examples.

## Architecture: Command -> Adapter -> Skill

Commands are thin routers. Skills contain full workflow logic. The adapter is the single project-specific config file.

```
User types /swarm plan.md
  -> .claude/commands/swarm.md (router: "read adapter, then read skill")
  -> .claude/adapter.md (project config: test commands, file patterns)
  -> .claude/skills/swarm/SKILL.md (full orchestration logic)
```

All four skills follow this same pattern. The adapter is what makes the workflow portable across projects.

## Key Design Decisions

- **Agent separation**: Test Agent (Opus, writes failing tests only) and Dev Agent (Sonnet, implements production code only) cannot edit each other's files. This ensures tests are a genuine contract.
- **File ownership**: No two parallel tasks edit the same file. This is the core constraint enabling safe parallel execution.
- **Wave-based execution**: Tasks are grouped into waves from a dependency DAG. Regression gates run between waves.
- **Stop hook chaining**: The swarm skill's YAML frontmatter defines a Stop hook that detects completion and auto-chains into `/validate`.
- **Skills use YAML frontmatter** for metadata (name, description, hooks). Commands use `$ARGUMENTS` for user input passthrough.

## Working on This Repo

Since this is a template/installer project, changes are made by editing the workflow files directly:

- To modify a phase's behavior, edit `workflow/.claude/skills/<phase>/SKILL.md`
- To modify a command's routing, edit `workflow/.claude/commands/<phase>.md`
- To modify the adapter template, edit `workflow/.claude/adapter.md`
- To modify installation logic, edit `install.sh`
- To add a new skill: create `workflow/.claude/skills/<name>/SKILL.md` + `workflow/.claude/commands/<name>.md`, then add the copy step to `install.sh`

There are no automated tests, linters, or build commands for this repository itself.
