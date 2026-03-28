#!/bin/bash
set -euo pipefail

# Claude Swarm Workflow Installer
# Usage: ./install.sh /path/to/your/project [OPTIONS]
#
# Options:
#   --with-design-review   Include web-designer skill + .mcp.json
#   --with-super-swarm     Include rolling pool executor (no wave batching)
#   --with-tmux            Include tmux executor (live pane visibility)
#   --with-co-design       Include design-aware executor (design/standard routing)
#   --with-spark           Include agent-profile executor (persona injection)
#   --with-cursor           Include .cursor/agents/ for Cursor IDE
#   --force                 Overwrite existing adapter.md
#   --help                  Show this help message

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$SCRIPT_DIR/workflow"

# Parse arguments
TARGET=""
WITH_DESIGN=false
WITH_SUPER_SWARM=false
WITH_TMUX=false
WITH_CODESIGN=false
WITH_SPARK=false
WITH_CURSOR=false
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --with-design-review) WITH_DESIGN=true ;;
    --with-super-swarm) WITH_SUPER_SWARM=true ;;
    --with-tmux) WITH_TMUX=true ;;
    --with-co-design) WITH_CODESIGN=true ;;
    --with-spark) WITH_SPARK=true ;;
    --with-cursor) WITH_CURSOR=true ;;
    --force) FORCE=true ;;
    --help)
      head -8 "$0" | tail -7 | sed 's/^# //'
      exit 0
      ;;
    *)
      if [ -z "$TARGET" ]; then
        TARGET="$arg"
      else
        echo "Error: unexpected argument '$arg'"
        exit 1
      fi
      ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "Usage: ./install.sh /path/to/your/project [OPTIONS]"
  echo "Run ./install.sh --help for all options."
  exit 1
fi

if [ ! -d "$TARGET" ]; then
  echo "Error: '$TARGET' is not a directory"
  exit 1
fi

echo "Installing Claude Swarm Workflow into: $TARGET"
echo ""

# Create directory structure
mkdir -p "$TARGET/.claude/commands"
mkdir -p "$TARGET/.claude/skills/spec"
mkdir -p "$TARGET/.claude/skills/swarm-plan"
mkdir -p "$TARGET/.claude/skills/swarm"
mkdir -p "$TARGET/.claude/skills/validate"
mkdir -p "$TARGET/.claude/hooks"

# Copy core skills
echo "  Installing core skills..."
cp "$WORKFLOW_DIR/.claude/skills/spec/SKILL.md" "$TARGET/.claude/skills/spec/SKILL.md"
cp "$WORKFLOW_DIR/.claude/skills/swarm-plan/SKILL.md" "$TARGET/.claude/skills/swarm-plan/SKILL.md"
cp "$WORKFLOW_DIR/.claude/skills/swarm/SKILL.md" "$TARGET/.claude/skills/swarm/SKILL.md"
cp "$WORKFLOW_DIR/.claude/skills/validate/SKILL.md" "$TARGET/.claude/skills/validate/SKILL.md"

# Copy commands
echo "  Installing slash commands..."
cp "$WORKFLOW_DIR/.claude/commands/spec.md" "$TARGET/.claude/commands/spec.md"
cp "$WORKFLOW_DIR/.claude/commands/swarm-plan.md" "$TARGET/.claude/commands/swarm-plan.md"
cp "$WORKFLOW_DIR/.claude/commands/swarm.md" "$TARGET/.claude/commands/swarm.md"
cp "$WORKFLOW_DIR/.claude/commands/validate.md" "$TARGET/.claude/commands/validate.md"

# Copy hooks
echo "  Installing auto-lint hook..."
cp "$WORKFLOW_DIR/.claude/hooks/auto-lint.sh" "$TARGET/.claude/hooks/auto-lint.sh"
chmod +x "$TARGET/.claude/hooks/auto-lint.sh"

# Adapter (don't overwrite without --force)
if [ -f "$TARGET/.claude/adapter.md" ] && [ "$FORCE" = false ]; then
  echo "  Skipping adapter.md (already exists — use --force to overwrite)"
else
  echo "  Installing adapter template..."
  cp "$WORKFLOW_DIR/.claude/adapter.md" "$TARGET/.claude/adapter.md"
fi

# Settings (merge carefully — don't overwrite existing)
if [ -f "$TARGET/.claude/settings.json" ]; then
  echo "  Skipping settings.json (already exists — merge manually from workflow/.claude/settings.json)"
else
  echo "  Installing settings.json..."
  cp "$WORKFLOW_DIR/.claude/settings.json" "$TARGET/.claude/settings.json"
fi

# Optional: web-designer skill + design-review command + MCP
if [ "$WITH_DESIGN" = true ]; then
  echo "  Installing web-designer skill..."
  mkdir -p "$TARGET/.claude/skills/web-designer"
  cp "$WORKFLOW_DIR/.claude/skills/web-designer/SKILL.md" "$TARGET/.claude/skills/web-designer/SKILL.md"
  cp "$WORKFLOW_DIR/.claude/commands/design-review.md" "$TARGET/.claude/commands/design-review.md"

  if [ ! -f "$TARGET/.mcp.json" ]; then
    echo "  Installing .mcp.json (Playwright MCP)..."
    cp "$WORKFLOW_DIR/.mcp.json" "$TARGET/.mcp.json"
  else
    echo "  Skipping .mcp.json (already exists — merge manually)"
  fi
fi

# Optional: super-swarm executor (rolling pool)
if [ "$WITH_SUPER_SWARM" = true ]; then
  echo "  Installing super-swarm executor..."
  mkdir -p "$TARGET/.claude/skills/super-swarm"
  cp "$WORKFLOW_DIR/.claude/skills/super-swarm/SKILL.md" "$TARGET/.claude/skills/super-swarm/SKILL.md"
  cp "$WORKFLOW_DIR/.claude/commands/super-swarm.md" "$TARGET/.claude/commands/super-swarm.md"
fi

# Optional: tmux executor (live pane visibility)
if [ "$WITH_TMUX" = true ]; then
  echo "  Installing swarm-tmux executor..."
  mkdir -p "$TARGET/.claude/skills/swarm-tmux"
  cp "$WORKFLOW_DIR/.claude/skills/swarm-tmux/SKILL.md" "$TARGET/.claude/skills/swarm-tmux/SKILL.md"
  cp "$WORKFLOW_DIR/.claude/commands/swarm-tmux.md" "$TARGET/.claude/commands/swarm-tmux.md"
  cp "$WORKFLOW_DIR/.claude/hooks/tmux_spawn_worker.sh" "$TARGET/.claude/hooks/tmux_spawn_worker.sh"
  chmod +x "$TARGET/.claude/hooks/tmux_spawn_worker.sh"
fi

# Optional: co-design executor (design/standard routing)
if [ "$WITH_CODESIGN" = true ]; then
  echo "  Installing co-design executor..."
  mkdir -p "$TARGET/.claude/skills/co-design"
  cp "$WORKFLOW_DIR/.claude/skills/co-design/SKILL.md" "$TARGET/.claude/skills/co-design/SKILL.md"
  cp "$WORKFLOW_DIR/.claude/commands/co-design.md" "$TARGET/.claude/commands/co-design.md"
  if [ ! -d "$TARGET/.claude/skills/web-designer" ]; then
    echo "    Note: co-design works best with --with-design-review for post-wave visual review"
  fi
fi

# Optional: spark executor (agent profile injection)
if [ "$WITH_SPARK" = true ]; then
  echo "  Installing swarm-spark executor..."
  mkdir -p "$TARGET/.claude/skills/swarm-spark"
  cp "$WORKFLOW_DIR/.claude/skills/swarm-spark/SKILL.md" "$TARGET/.claude/skills/swarm-spark/SKILL.md"
  cp "$WORKFLOW_DIR/.claude/commands/swarm-spark.md" "$TARGET/.claude/commands/swarm-spark.md"
fi

# Optional: Cursor agents
if [ "$WITH_CURSOR" = true ]; then
  echo "  Installing Cursor agents..."
  mkdir -p "$TARGET/.cursor/agents"
  cp "$WORKFLOW_DIR/.cursor/agents/planner.md" "$TARGET/.cursor/agents/planner.md"
  cp "$WORKFLOW_DIR/.cursor/agents/executor.md" "$TARGET/.cursor/agents/executor.md"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Edit .claude/adapter.md — fill in your project's test commands, file patterns, and conventions"
echo "  2. Edit .claude/hooks/auto-lint.sh — configure your linter commands"
echo "  3. Review .claude/settings.json — adjust permissions for your project"
echo "  4. Try it: run 'claude' and type '/spec' to start your first specification"
echo ""
echo "Slash commands installed:"
echo "  /spec         — Discover and specify features"
echo "  /swarm-plan   — Plan tasks with dependency DAG"
echo "  /swarm        — Execute tasks with parallel test/dev agents (wave-based)"
echo "  /validate     — Full validation and phase closure"
if [ "$WITH_SUPER_SWARM" = true ]; then
  echo "  /super-swarm  — Rolling pool executor (no wave batching, up to 12 concurrent)"
fi
if [ "$WITH_TMUX" = true ]; then
  echo "  /swarm-tmux   — Wave-based execution with live tmux pane visibility"
fi
if [ "$WITH_CODESIGN" = true ]; then
  echo "  /co-design    — Design-aware executor (design/standard task routing)"
fi
if [ "$WITH_SPARK" = true ]; then
  echo "  /swarm-spark  — Agent-profile executor (persona injection)"
fi
if [ "$WITH_DESIGN" = true ]; then
  echo "  /design-review — Visual design review (requires running app)"
fi
