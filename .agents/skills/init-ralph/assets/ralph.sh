#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--tool amp|codex|claude] [max_iterations]

set -e

# Parse arguments
TOOL="codex"  # Default to Codex CLI
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "codex" && "$TOOL" != "claude" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp', 'codex', or 'claude'."
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

if [ -z "$PROJECT_ROOT" ]; then
  if [ -d "$SCRIPT_DIR/../.." ]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
  else
    PROJECT_ROOT="$SCRIPT_DIR"
  fi
fi

all_stories_complete() {
  if [ ! -f "$PRD_FILE" ]; then
    return 1
  fi

  jq -e '(.userStories // []) | length > 0 and all(.[]; .passes == true)' "$PRD_FILE" >/dev/null 2>&1
}

run_with_ralph_context() {
  local prompt_file="$1"
  local runtime_cmd="$2"
  local temp_prompt

  temp_prompt="$(mktemp)"
  {
    echo "## Ralph Runtime Context"
    echo "- Repository root: $PROJECT_ROOT"
    echo "- Ralph directory: $SCRIPT_DIR"
    echo "- PRD path: $PRD_FILE"
    echo "- Progress log path: $PROGRESS_FILE"
    echo "- Start all code/file operations from the repository root unless a task explicitly requires the Ralph directory."
    echo
    cat "$prompt_file"
  } > "$temp_prompt"

  OUTPUT=$(eval "$runtime_cmd" < "$temp_prompt" 2>&1 | tee /dev/stderr) || true
  rm -f "$temp_prompt"
}

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

if all_stories_complete; then
  echo "All stories in $PRD_FILE are already marked complete."
  exit 0
fi

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  # Run the selected tool with the ralph prompt
  if [[ "$TOOL" == "amp" ]]; then
    run_with_ralph_context "$SCRIPT_DIR/prompt.md" "cd \"$PROJECT_ROOT\" && amp --dangerously-allow-all"
  elif [[ "$TOOL" == "codex" ]]; then
    run_with_ralph_context "$SCRIPT_DIR/CODEX.md" "codex exec --dangerously-bypass-approvals-and-sandbox -C \"$PROJECT_ROOT\" -"
  else
    # Claude Code: use --dangerously-skip-permissions for autonomous operation, --print for output
    run_with_ralph_context "$SCRIPT_DIR/CLAUDE.md" "cd \"$PROJECT_ROOT\" && claude --dangerously-skip-permissions --print"
  fi

  # Only stop when the PRD confirms all stories are complete.
  if all_stories_complete; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  # Warn if the agent claimed completion but the PRD still has pending work.
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Warning: agent reported completion, but pending stories remain in $PRD_FILE."
    echo "Continuing to next iteration."
  fi
  
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
