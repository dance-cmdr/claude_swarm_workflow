#!/bin/bash
# PostToolUse hook: auto-lint files after Write/Edit
# Receives JSON on stdin with tool_input.file_path
# Runs the appropriate linter based on file extension

FILE_PATH=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

cd "$CLAUDE_PROJECT_DIR" || exit 0

case "$FILE_PATH" in
  backend/*.py|*.py)
    backend/.venv/bin/ruff check --fix "$FILE_PATH" 2>/dev/null
    backend/.venv/bin/ruff format "$FILE_PATH" 2>/dev/null
    ;;
  frontend/*.ts|frontend/*.tsx|frontend/*.js|frontend/*.jsx)
    cd frontend && npx eslint --fix "../$FILE_PATH" 2>/dev/null
    ;;
esac

exit 0
