#!/bin/bash
# PostToolUse hook: auto-lint files after Write/Edit
# Receives JSON on stdin with tool_input.file_path
# Runs the appropriate linter based on file extension.
#
# CUSTOMIZE: Update the case patterns and commands below to match your project's
# linter setup. The examples show common patterns for Python (ruff) and
# TypeScript/JavaScript (ESLint).

FILE_PATH=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

cd "$CLAUDE_PROJECT_DIR" || exit 0

case "$FILE_PATH" in
  # Python files — using ruff (adjust path to your venv or global install)
  *.py)
    # ruff check --fix "$FILE_PATH" 2>/dev/null
    # ruff format "$FILE_PATH" 2>/dev/null
    echo "TODO: Configure Python linter" >/dev/null
    ;;
  # TypeScript/JavaScript files — using ESLint (adjust working directory)
  *.ts|*.tsx|*.js|*.jsx)
    # cd frontend && npx eslint --fix "../$FILE_PATH" 2>/dev/null
    echo "TODO: Configure JS/TS linter" >/dev/null
    ;;
  # Go files
  # *.go)
  #   gofmt -w "$FILE_PATH" 2>/dev/null
  #   ;;
  # Rust files
  # *.rs)
  #   rustfmt "$FILE_PATH" 2>/dev/null
  #   ;;
esac

# Always exit 0 — lint failures should not block the agent from proceeding
exit 0
