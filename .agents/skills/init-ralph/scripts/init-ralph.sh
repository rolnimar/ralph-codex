#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS_DIR="$SKILL_DIR/assets"
TARGET_DIR="${1:-$PWD}"
TARGET_RALPH_DIR="$TARGET_DIR/scripts/ralph"
TARGET_GITIGNORE="$TARGET_DIR/.gitignore"
TARGET_PROGRESS="$TARGET_RALPH_DIR/progress.txt"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_RALPH_DIR"

copy_if_missing() {
  local source_file="$1"
  local target_file="$2"

  if [[ -e "$target_file" ]]; then
    echo "Skipped existing file: $target_file"
    return
  fi

  cp "$source_file" "$target_file"
  echo "Created: $target_file"
}

copy_if_missing "$ASSETS_DIR/ralph.sh" "$TARGET_RALPH_DIR/ralph.sh"
copy_if_missing "$ASSETS_DIR/CODEX.md" "$TARGET_RALPH_DIR/CODEX.md"
copy_if_missing "$ASSETS_DIR/prd.json.example" "$TARGET_RALPH_DIR/prd.json.example"

if [[ ! -e "$TARGET_PROGRESS" ]]; then
  {
    echo "# Ralph Progress Log"
    echo "Started: $(date)"
    echo "---"
  } > "$TARGET_PROGRESS"
  echo "Created: $TARGET_PROGRESS"
else
  echo "Skipped existing file: $TARGET_PROGRESS"
fi

chmod +x "$TARGET_RALPH_DIR/ralph.sh"

R_START="# Ralph working files (generated during runs)"
R_BLOCK="$(cat <<'EOF'
# Ralph working files (generated during runs)
scripts/ralph/prd.json
scripts/ralph/progress.txt
scripts/ralph/.last-branch
EOF
)"

if [[ -f "$TARGET_GITIGNORE" ]]; then
  if grep -Fq "$R_START" "$TARGET_GITIGNORE"; then
    echo "Skipped existing Ralph .gitignore block: $TARGET_GITIGNORE"
  else
    {
      echo
      echo "$R_BLOCK"
    } >> "$TARGET_GITIGNORE"
    echo "Updated: $TARGET_GITIGNORE"
  fi
else
  printf "%s\n" "$R_BLOCK" > "$TARGET_GITIGNORE"
  echo "Created: $TARGET_GITIGNORE"
fi

echo
echo "Ralph initialized in: $TARGET_DIR"
echo "Next steps:"
echo "1. Use \$prd to create a PRD markdown file."
echo "2. Use \$ralph to convert that PRD to scripts/ralph/prd.json."
echo "3. Run ./scripts/ralph/ralph.sh"
