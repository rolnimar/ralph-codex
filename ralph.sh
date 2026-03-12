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
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

TARGET_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
BASE_BRANCH=$(jq -r '.baseBranch // empty' "$PRD_FILE" 2>/dev/null || echo "")

if [ -z "$TARGET_BRANCH" ]; then
  echo "Error: prd.json must define branchName."
  exit 1
fi

if [ -z "$BASE_BRANCH" ]; then
  echo "Error: prd.json must define baseBranch."
  exit 1
fi

if ! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
  echo "Error: baseBranch '$BASE_BRANCH' does not exist locally."
  exit 1
fi

WORKTREE_ROOT="$REPO_ROOT/.ralph-worktrees"
WORKTREE_NAME="${TARGET_BRANCH//\//-}"
WORKTREE_DIR="$WORKTREE_ROOT/$WORKTREE_NAME"

mkdir -p "$WORKTREE_ROOT"

BRANCH_CHECKED_OUT_ELSEWHERE=""
while IFS= read -r line; do
  case "$line" in
    branch\ refs/heads/$TARGET_BRANCH)
      BRANCH_CHECKED_OUT_ELSEWHERE="1"
      ;;
  esac
done < <(git -C "$REPO_ROOT" worktree list --porcelain)

if [ ! -d "$WORKTREE_DIR/.git" ]; then
  if [ -n "$BRANCH_CHECKED_OUT_ELSEWHERE" ] && git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    echo "Error: target branch '$TARGET_BRANCH' is already checked out in another worktree."
    echo "Clean up or remove that worktree before rerunning Ralph."
    exit 1
  fi

  if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    git -C "$REPO_ROOT" worktree add "$WORKTREE_DIR" "$TARGET_BRANCH"
  else
    git -C "$REPO_ROOT" worktree add -b "$TARGET_BRANCH" "$WORKTREE_DIR" "$BASE_BRANCH"
  fi
fi

SCRIPT_DIR="$WORKTREE_DIR"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

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
echo "Worktree: $WORKTREE_DIR"
echo "Base branch: $BASE_BRANCH"
echo "Target branch: $TARGET_BRANCH"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  # Run the selected tool with the ralph prompt
  if [[ "$TOOL" == "amp" ]]; then
    OUTPUT=$(cat "$SCRIPT_DIR/prompt.md" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  elif [[ "$TOOL" == "codex" ]]; then
    OUTPUT=$(codex exec --dangerously-bypass-approvals-and-sandbox -C "$SCRIPT_DIR" - < "$SCRIPT_DIR/CODEX.md" 2>&1 | tee /dev/stderr) || true
  else
    # Claude Code: use --dangerously-skip-permissions for autonomous operation, --print for output
    OUTPUT=$(claude --dangerously-skip-permissions --print < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee /dev/stderr) || true
  fi

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
