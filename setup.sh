#!/bin/bash
# ai-slc 설치 스크립트
# 사용법: /path/to/ai-slc/setup.sh [대상 프로젝트 경로]

set -e

# ai-slc 소스 경로 (이 스크립트가 있는 디렉토리)
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

# 대상 프로젝트 경로
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

if [ "$SOURCE_DIR" = "$TARGET_DIR" ]; then
  echo "오류: 대상 경로가 ai-slc 소스 디렉토리와 같습니다."
  exit 1
fi

echo "=== ai-slc 설치 ==="
echo "소스: $SOURCE_DIR"
echo "대상: $TARGET_DIR"
echo ""

# 1. 디렉토리 생성
echo "[1/6] 디렉토리 생성..."
mkdir -p "$TARGET_DIR/.claude/hooks"
mkdir -p "$TARGET_DIR/.claude/agents"
mkdir -p "$TARGET_DIR/manuals"
mkdir -p "$TARGET_DIR/working-memory"
mkdir -p "$TARGET_DIR/templates"

# 2. CLAUDE.md 복사
echo "[2/6] CLAUDE.md 복사..."
cp "$SOURCE_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"

# 3. .claude/ 복사 (settings, hooks, agents)
echo "[3/6] 훅 & 에이전트 복사..."
cp "$SOURCE_DIR/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"
cp "$SOURCE_DIR/.claude/hooks/"*.sh "$TARGET_DIR/.claude/hooks/"
chmod +x "$TARGET_DIR/.claude/hooks/"*.sh
cp "$SOURCE_DIR/.claude/agents/"*.md "$TARGET_DIR/.claude/agents/"

# 4. 매뉴얼 복사
echo "[4/6] 매뉴얼 복사..."
cp "$SOURCE_DIR/manuals/"*.md "$TARGET_DIR/manuals/"

# 5. 템플릿 복사
echo "[5/6] 템플릿 복사..."
cp "$SOURCE_DIR/templates/"*.md "$TARGET_DIR/templates/"

# 6. working-memory 초기화 (템플릿에서 생성)
echo "[6/6] working-memory 초기화..."
if [ ! -f "$TARGET_DIR/working-memory/plan.md" ]; then
  cp "$SOURCE_DIR/templates/plan-template.md" "$TARGET_DIR/working-memory/plan.md"
fi
if [ ! -f "$TARGET_DIR/working-memory/context-notes.md" ]; then
  cp "$SOURCE_DIR/templates/context-notes-template.md" "$TARGET_DIR/working-memory/context-notes.md"
fi
if [ ! -f "$TARGET_DIR/working-memory/checklist.md" ]; then
  cp "$SOURCE_DIR/templates/checklist-template.md" "$TARGET_DIR/working-memory/checklist.md"
fi
if [ ! -f "$TARGET_DIR/working-memory/change-log.md" ]; then
  cat > "$TARGET_DIR/working-memory/change-log.md" << 'CHANGELOG'
# Change Log (CCTV)

> 이 파일은 모든 파일 수정 사항을 자동으로 기록합니다.

| 시간 | 액션 | 파일 |
|------|------|------|
CHANGELOG
fi

echo ""
echo "=== 설치 완료 ==="
echo ""
echo "사용법:"
echo "  cd $TARGET_DIR"
echo "  claude  # Claude Code 시작 → 4대 시스템 자동 활성화"
