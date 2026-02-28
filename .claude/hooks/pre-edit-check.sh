#!/bin/bash
# pre-edit-check.sh
# PreToolUse hook for Edit/Write operations
# Reads JSON from stdin, analyzes file_path pattern, returns manual chapter reminder

# Read JSON input from stdin
INPUT=$(cat)

# Extract file_path from the tool input
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Convert to lowercase for matching
FILE_LOWER=$(echo "$FILE_PATH" | tr '[:upper:]' '[:lower:]')

# Determine relevant manual chapters based on file path patterns
CHAPTERS=""

# Testing files
if echo "$FILE_LOWER" | grep -qE '\.(test|spec)\.' || echo "$FILE_LOWER" | grep -qE '(test|spec)'; then
  CHAPTERS="${CHAPTERS}ch05-testing "
fi

# Security/Auth files
if echo "$FILE_LOWER" | grep -qE '(auth|security|permission|role|access)'; then
  CHAPTERS="${CHAPTERS}ch02-security "
fi

# API/Route files
if echo "$FILE_LOWER" | grep -qE '(api|route|endpoint|controller|handler)'; then
  CHAPTERS="${CHAPTERS}ch03-api-design "
fi

# Database files
if echo "$FILE_LOWER" | grep -qE '(migration|schema|model|entity|repository|dao|seed)'; then
  CHAPTERS="${CHAPTERS}ch04-database "
fi

# Deployment files
if echo "$FILE_LOWER" | grep -qE '(docker|deploy|ci|cd|kubernetes|k8s|helm|terraform)'; then
  CHAPTERS="${CHAPTERS}ch10-deployment "
fi

# Error handling files
if echo "$FILE_LOWER" | grep -qE '(error|exception|handler|middleware)'; then
  CHAPTERS="${CHAPTERS}ch01-error-handling "
fi

# Logging files
if echo "$FILE_LOWER" | grep -qE '(log|monitor|metric|trace|alert)'; then
  CHAPTERS="${CHAPTERS}ch09-logging-monitoring "
fi

# Config/style files
if echo "$FILE_LOWER" | grep -qE '(lint|format|style|config|prettier|eslint)'; then
  CHAPTERS="${CHAPTERS}ch07-code-style "
fi

# If relevant chapters found, output reminder as additionalContext
if [ -n "$CHAPTERS" ]; then
  echo "[Manual Reminder] 편집 전 관련 매뉴얼을 확인하세요: ${CHAPTERS}"
  echo "매뉴얼 경로: manuals/ 디렉토리에서 해당 챕터를 읽으세요."
fi

exit 0
