#!/bin/bash
# post-edit-track.sh
# PostToolUse hook for Edit/Write operations
# Records file modifications to working-memory/change-log.md

# Read JSON input from stdin
INPUT=$(cat)

# Extract file_path from the tool input
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Determine the project root (where CLAUDE.md is)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CHANGE_LOG="$PROJECT_ROOT/working-memory/change-log.md"

# Get timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Determine action type
ACTION="${TOOL_NAME:-Edit}"

# Make path relative to project root if possible
REL_PATH="${FILE_PATH#$PROJECT_ROOT/}"

# Append to change log
echo "| ${TIMESTAMP} | ${ACTION} | ${REL_PATH} |" >> "$CHANGE_LOG"

exit 0
