#!/bin/bash
set -euo pipefail

# Claude Swarm Workflow Installer
# Usage: ./install.sh /path/to/your/project [OPTIONS]
#
# Options:
#   --with-design-review   Include web-designer skill + .mcp.json
#   --with-cursor           Include .cursor/agents/ for Cursor IDE
#   --force                 Overwrite existing adapter.md
#   --help                  Show this help message

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$SCRIPT_DIR/workflow"

# Parse arguments
TARGET=""
WITH_DESIGN=false
WITH_CURSOR=false
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --with-design-review) WITH_DESIGN=true ;;
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
  echo "Usage: ./install.sh /path/to/your/project [--with-design-review] [--with-cursor] [--force]"
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
echo "  /swarm        — Execute tasks with parallel test/dev agents"
echo "  /validate     — Full validation and phase closure"
if [ "$WITH_DESIGN" = true ]; then
  echo "  /design-review — Visual design review (requires running app)"
fi
