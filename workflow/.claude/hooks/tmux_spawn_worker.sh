#!/bin/bash
set -euo pipefail

# tmux_spawn_worker.sh — Helper for swarm-tmux executor
#
# Usage:
#   tmux_spawn_worker.sh init <session-name>
#   tmux_spawn_worker.sh spawn <session> <task-id> <prompt-file> [claude-flags]
#   tmux_spawn_worker.sh status <session> <task-id>
#   tmux_spawn_worker.sh cleanup <session>

ACTION="${1:-}"
shift || true

case "$ACTION" in
  init)
    # Create a new tmux session for the swarm
    # Usage: init <session-name>
    SESSION_NAME="${1:?Usage: tmux_spawn_worker.sh init <session-name>}"

    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
      echo "Session '$SESSION_NAME' already exists, reusing."
    else
      tmux new-session -d -s "$SESSION_NAME" -n "orchestrator"
      tmux send-keys -t "$SESSION_NAME:orchestrator" \
        "echo '=== Swarm Orchestrator — $SESSION_NAME ===' && echo 'Waiting for tasks...'" Enter
    fi

    echo "$SESSION_NAME"
    ;;

  spawn)
    # Launch a claude -p agent in a new tmux window
    # Usage: spawn <session> <task-id> <prompt-file> [claude-flags]
    SESSION="${1:?Usage: tmux_spawn_worker.sh spawn <session> <task-id> <prompt-file> [flags]}"
    TASK_ID="${2:?Missing task-id}"
    PROMPT_FILE="${3:?Missing prompt-file}"
    CLAUDE_FLAGS="${4:-}"

    LOG_FILE="/tmp/swarm-${SESSION}-${TASK_ID}.log"
    WINDOW_NAME="$TASK_ID"

    # Create a new window for this task
    tmux new-window -t "$SESSION" -n "$WINDOW_NAME"

    # Read prompt from file and launch claude -p in the pane
    # The prompt is passed via file to avoid shell escaping issues
    tmux send-keys -t "$SESSION:$WINDOW_NAME" \
      "claude -p \"\$(cat '$PROMPT_FILE')\" $CLAUDE_FLAGS 2>&1 | tee '$LOG_FILE'; echo \"EXIT_CODE=\$?\" >> '$LOG_FILE'" Enter

    echo "Spawned $TASK_ID in session $SESSION (log: $LOG_FILE)"
    ;;

  status)
    # Check if a task's window still has a running process
    # Usage: status <session> <task-id>
    # Returns 0 if still running, 1 if done
    SESSION="${1:?Usage: tmux_spawn_worker.sh status <session> <task-id>}"
    TASK_ID="${2:?Missing task-id}"

    LOG_FILE="/tmp/swarm-${SESSION}-${TASK_ID}.log"

    # Check if the window still exists
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
      exit 1
    fi

    if ! tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -q "^${TASK_ID}$"; then
      exit 1
    fi

    # Check if the log file contains an EXIT_CODE line (indicates completion)
    if [ -f "$LOG_FILE" ] && grep -q "^EXIT_CODE=" "$LOG_FILE"; then
      exit 1  # Done
    fi

    exit 0  # Still running
    ;;

  cleanup)
    # Kill the tmux session and clean up logs
    # Usage: cleanup <session>
    SESSION="${1:?Usage: tmux_spawn_worker.sh cleanup <session>}"

    # Clean up log files
    rm -f /tmp/swarm-"${SESSION}"-*.log

    # Kill session if it exists
    if tmux has-session -t "$SESSION" 2>/dev/null; then
      tmux kill-session -t "$SESSION"
      echo "Session '$SESSION' killed."
    else
      echo "Session '$SESSION' not found."
    fi
    ;;

  *)
    echo "Usage: tmux_spawn_worker.sh {init|spawn|status|cleanup} [args]"
    echo ""
    echo "Actions:"
    echo "  init <session-name>                          Create tmux session"
    echo "  spawn <session> <task-id> <prompt-file> [flags]  Launch agent in pane"
    echo "  status <session> <task-id>                   Check if agent is running"
    echo "  cleanup <session>                            Kill session and logs"
    exit 1
    ;;
esac
