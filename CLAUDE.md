# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Swarm Workflow is an installable 4-phase parallel development workflow for Claude Code. It provides slash commands (`/spec`, `/swarm-plan`, `/swarm`, `/validate`) that use TDD with separated test and dev agents, dependency-aware task planning, and automated quality gates. It also provides optional executor variants (`/super-swarm`, `/swarm-tmux`, `/co-design`, `/swarm-spark`) for different execution strategies. Based on [am-will/swarms](https://github.com/am-will/swarms). Installed into target projects via `install.sh`, which copies the `workflow/` directory contents into a project's `.claude/` directory.

## Repository Structure

This repo is a **distribution package**, not a runtime application. There is no build step, no dependencies, and no tests to run.

- `install.sh` — Installer script. Copies workflow files into a target project. Supports `--with-design-review`, `--with-super-swarm`, `--with-tmux`, `--with-co-design`, `--with-spark`, `--with-cursor`, `--force` flags.
- `workflow/` — The installable payload:
  - `.claude/adapter.md` — Template for project-specific config (test commands, file patterns, conventions). Every skill reads this first.
  - `.claude/commands/` — Thin slash command routers (2-3 lines each). They load the adapter then delegate to the corresponding skill.
  - `.claude/skills/` — Full process logic for each phase (`spec/`, `swarm-plan/`, `swarm/`, `validate/`, `web-designer/`) and optional executor variants (`super-swarm/`, `swarm-tmux/`, `co-design/`, `swarm-spark/`).
  - `.claude/hooks/auto-lint.sh` — PostToolUse hook template for auto-linting after Write/Edit.
  - `.claude/hooks/tmux_spawn_worker.sh` — Helper script for tmux executor (optional).
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

## Executor Variants

The base `/swarm` executor uses wave-based execution with RED/GREEN agent separation. Four optional variants provide different execution strategies:

| Variant | Command | Install Flag | When to Use |
|---------|---------|-------------|-------------|
| **Super-Swarm** | `/super-swarm` | `--with-super-swarm` | Large plans with uneven task sizes — rolling pool fills slots as they free, no wave waiting |
| **Tmux** | `/swarm-tmux` | `--with-tmux` | When you want to watch agents work live in tmux panes |
| **Co-Design** | `/co-design` | `--with-co-design` | Plans mixing UI/design tasks with backend/logic — design tasks get full CLI + design-system awareness |
| **Spark** | `/swarm-spark` | `--with-spark` | When you need domain expertise, style enforcement, or security hardening injected into all agents |

All variants share the same plan format (from `/swarm-plan`), the same adapter, and the same Stop hook that chains into `/validate`.

### Spark Agent Profiles

The spark variant uses Claude Code's named subagent system. Users define agent profiles at `.claude/agents/<name>.md` with YAML frontmatter (model, tools, persona) and reference the profile name in the adapter config. See `workflow/.claude/skills/swarm-spark/SKILL.md` for the full profile format and examples.

Reference: [Claude Code subagent docs](https://docs.claude.com/en/docs/sub-agents)

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
