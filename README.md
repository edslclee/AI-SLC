# AI-SLC (AI 업무 최적화 시스템)

AI의 컨텍스트 윈도우 포화, 매뉴얼 미준수, 결과물 오류 문제를 시스템적으로 해결하는 Claude Code 프로젝트입니다.

## 4대 시스템

| 시스템 | 역할 | 핵심 기능 |
|--------|------|-----------|
| System 1 | 자동 매뉴얼 | TOC 기반 챕터 선택적 로딩 (10개 챕터) |
| System 2 | 작업 기억 | working-memory로 세션 간 맥락 유지 |
| System 3 | 자동 품질 검사 | 훅 기반 수정 기록 + 품질 게이트 |
| System 4 | 에이전트 협업 | 5개 전문 에이전트 (planner, reviewer, tester, security-auditor, qa-inspector) |

## 설치 방법

새 프로젝트에서 ai-slc를 적용하려면 한 줄이면 됩니다:

```bash
# 새 프로젝트 디렉토리에서
/path/to/ai-slc/setup.sh .

# 또는 경로를 지정해서
/path/to/ai-slc/setup.sh ~/my-new-project
```

### setup.sh가 하는 일

| 단계 | 동작 | 비고 |
|------|------|------|
| 1 | 디렉토리 구조 생성 | `.claude/`, `manuals/`, `working-memory/`, `templates/` |
| 2 | `CLAUDE.md` 복사 | 마스터 오케스트레이터 |
| 3 | 훅 & 에이전트 복사 | `settings.json`, 3개 훅 스크립트, 5개 에이전트 |
| 4 | 매뉴얼 10개 챕터 복사 | TOC 포함 |
| 5 | 템플릿 복사 | 4개 템플릿 |
| 6 | working-memory 초기화 | 템플릿에서 빈 상태로 생성 (이미 있으면 건너뜀) |

설치 후 `claude` 명령으로 Claude Code를 시작하면 `CLAUDE.md`와 `settings.json`의 훅이 자동으로 로딩되어 4대 시스템이 활성화됩니다.

## 프로젝트 구조

```
ai-slc/
├── CLAUDE.md                    # 마스터 오케스트레이터
├── .claude/
│   ├── settings.json            # 훅 설정
│   ├── hooks/                   # 자동 트리거 스크립트
│   └── agents/                  # 5개 전문 에이전트
├── manuals/                     # 매뉴얼 10개 챕터 + TOC
├── working-memory/              # 세션 간 맥락 유지
└── templates/                   # 작업 기억 템플릿
```
