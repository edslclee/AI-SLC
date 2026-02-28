#!/bin/bash
# pre-bash-validate.sh
# PreToolUse hook for Bash operations
# Blocks dangerous commands

# Read JSON input from stdin
INPUT=$(cat)

# Extract the command from the tool input
COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Define dangerous command patterns
DANGEROUS_PATTERNS=(
  "rm -rf /"
  "rm -rf /*"
  "rm -rf ~"
  "rm -rf \$HOME"
  "mkfs\."
  "dd if=.* of=/dev/"
  ":(){:|:&};:"
  "chmod -R 777 /"
  "chown -R .* /"
  "git push.*--force.*main"
  "git push.*--force.*master"
  "git push.*-f.*main"
  "git push.*-f.*master"
  "git reset --hard.*origin"
  "drop database"
  "drop table"
  "truncate table"
  "DELETE FROM.*WHERE 1"
  "shutdown"
  "reboot"
  "init 0"
  "init 6"
  "curl.*|.*sh"
  "wget.*|.*sh"
  "curl.*|.*bash"
  "wget.*|.*bash"
)

# Check command against dangerous patterns
CMD_LOWER=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]')

for PATTERN in "${DANGEROUS_PATTERNS[@]}"; do
  PATTERN_LOWER=$(echo "$PATTERN" | tr '[:upper:]' '[:lower:]')
  if echo "$CMD_LOWER" | grep -qiE "$PATTERN_LOWER"; then
    echo "[BLOCKED] 위험 명령어가 감지되었습니다: $COMMAND"
    echo "패턴: $PATTERN"
    echo "이 명령은 시스템에 심각한 영향을 줄 수 있어 차단되었습니다."
    exit 2
  fi
done

exit 0
