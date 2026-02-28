# AI 업무 최적화 시스템 (ai-slc) - Master Orchestrator

이 프로젝트는 4대 시스템을 통해 AI의 컨텍스트 윈도우 포화, 매뉴얼 미준수, 결과물 오류를 시스템적으로 방지한다.

---

## System 1: 자동 매뉴얼 시스템

### 프로토콜
1. 작업 시작 전 `manuals/TOC.md`를 확인한다
2. 관련 키워드가 감지되면 해당 챕터**만** 선택적으로 로딩한다 (전체 로딩 금지)
3. 매뉴얼 규칙(MUST)은 반드시 준수하고, Anti-Pattern(NEVER)은 절대 사용하지 않는다

### 활성화 조건 매핑 테이블

| 조건 유형 | 패턴 | 활성화 챕터 |
|-----------|------|-------------|
| 키워드 | try, catch, exception, retry, fallback | ch01 에러 핸들링 |
| 키워드 | auth, token, XSS, CSRF, encryption, secrets | ch02 보안 |
| 키워드 | REST, endpoint, HTTP, status code, API | ch03 API 설계 |
| 키워드 | SQL, ORM, migration, index, transaction | ch04 데이터베이스 |
| 키워드 | test, mock, coverage, fixture, assert | ch05 테스팅 |
| 키워드 | branch, commit, merge, PR | ch06 Git 워크플로우 |
| 키워드 | naming, format, lint, convention | ch07 코드 스타일 |
| 키워드 | cache, optimize, N+1, pagination | ch08 성능 |
| 키워드 | log, metric, alert, trace | ch09 로깅/모니터링 |
| 키워드 | Docker, CI/CD, env, K8s, deploy | ch10 배포 |
| 파일 위치 | `*.test.*`, `*spec.*` | ch05 테스팅 |
| 파일 위치 | `*auth*`, `*security*` | ch02 보안 |
| 파일 위치 | `*api*`, `*route*` | ch03 API 설계 |
| 파일 위치 | `*migration*`, `*schema*` | ch04 데이터베이스 |
| 파일 위치 | `*docker*`, `*deploy*` | ch10 배포 |
| 의도 | 에러/예외 처리 구현 | ch01 에러 핸들링 |
| 의도 | 인증/권한 구현 | ch02 보안 |
| 의도 | API 엔드포인트 생성 | ch03 API 설계 |
| 의도 | DB 스키마/쿼리 작업 | ch04 데이터베이스 |
| 의도 | 테스트 작성/수정 | ch05 테스팅 |

### 매뉴얼 퀵 레퍼런스

| 챕터 | 파일 | 주제 |
|------|------|------|
| ch01 | `manuals/ch01-error-handling.md` | 에러 핸들링 |
| ch02 | `manuals/ch02-security.md` | 보안 |
| ch03 | `manuals/ch03-api-design.md` | API 설계 |
| ch04 | `manuals/ch04-database.md` | 데이터베이스 |
| ch05 | `manuals/ch05-testing.md` | 테스팅 |
| ch06 | `manuals/ch06-git-workflow.md` | Git 워크플로우 |
| ch07 | `manuals/ch07-code-style.md` | 코드 스타일 |
| ch08 | `manuals/ch08-performance.md` | 성능 |
| ch09 | `manuals/ch09-logging-monitoring.md` | 로깅/모니터링 |
| ch10 | `manuals/ch10-deployment.md` | 배포 |

---

## System 2: 작업 기억 시스템

### 프로토콜
1. **세션 시작 시**: `working-memory/` 디렉토리의 모든 파일을 읽는다
2. **"Plan is King" 원칙**: `working-memory/plan.md`가 모든 구현의 기준이다. 계획에 없는 변경은 금지
3. **Hard Reset 절차**: 세션 종료 전 working-memory 파일을 최신 상태로 업데이트한다
4. **컨텍스트 노트**: 중요한 발견, 기술적 결정, 주의사항을 `context-notes.md`에 기록한다

### 작업 기억 파일

| 파일 | 역할 | 비유 |
|------|------|------|
| `plan.md` | 프로젝트 계획, 현재 Phase, 다음 액션 | 설계도 |
| `context-notes.md` | 배경 지식, 기술적 맥락, 주의사항 | 메모장 |
| `checklist.md` | 할 일 목록, 완료/차단/범위 밖 구분 | 공정표 |
| `change-log.md` | 모든 파일 수정 기록 (자동) | CCTV |

### Hard Reset 절차
세션 종료 또는 컨텍스트 압축 시:
1. `plan.md` - 현재 Phase, 완료 항목, 다음 액션 업데이트
2. `checklist.md` - 태스크 상태 업데이트
3. `context-notes.md` - 새로운 발견/결정 추가
4. `change-log.md` - 자동 기록 확인

---

## System 3: 자동 품질 검사 시스템

### 프로토콜
1. **수정 기록 의무화**: 모든 파일 변경은 `change-log.md`에 자동 기록된다 (PostToolUse 훅)
2. **매뉴얼 리마인더**: 파일 편집 전 관련 매뉴얼 챕터가 자동 표시된다 (PreToolUse 훅)
3. **완료 후 품질 체크리스트**: 작업 완료 시 아래 체크리스트를 실행한다

### 품질 체크리스트
코드 변경 완료 후 반드시 확인:
- [ ] 에러 처리가 누락되지 않았는가?
- [ ] 보안상 위험한 패턴은 없는가?
- [ ] 엣지 케이스가 커버되었는가?
- [ ] 테스트가 필요하거나 업데이트되었는가?
- [ ] 기존 기능이 보존되었는가?

### Stop 훅 품질 게이트
Claude 응답 완료 시 자동 검증:
1. 관련 매뉴얼 챕터를 참조했는가?
2. 모든 파일 변경이 change-log.md에 기록되었는가?
3. 완료 후 품질 체크리스트를 수행했는가?
4. 구조화 보고서(Findings/Modifications/Rationale)가 존재하는가?

> 코드 변경 없는 단순 대화/질문은 품질 게이트 통과.

---

## System 4: 전문 에이전트 협업 시스템

### 에이전트 라우팅 규칙

| 상황 | 에이전트 | 명령 |
|------|----------|------|
| 구현 전략 설계 필요 | planner | `/agents/planner.md` |
| 코드 리뷰/교차 검토 | reviewer | `/agents/reviewer.md` |
| 테스트 작성/실행 | tester | `/agents/tester.md` |
| 보안 감사 필요 | security-auditor | `/agents/security-auditor.md` |
| 최종 품질 확인 | qa-inspector | `/agents/qa-inspector.md` |

### 에이전트 공통 규칙
1. **구조화 보고서 필수**: 모든 에이전트는 아래 형식으로 보고한다
   - **Findings**: 발견 사항
   - **Modifications**: 수정 내용
   - **Rationale**: 판단 근거
2. **"완료했습니다" 단순 보고 금지**: 구체적 내용 기술 필수
3. **교차 리뷰**: 중요 변경은 최소 2개 에이전트 검토 (reviewer + security-auditor 또는 reviewer + qa-inspector)

---

## 워크플로우 요약

```
사용자 요청 → plan.md 확인 → TOC.md로 매뉴얼 선택 → 구현 → change-log 기록 → 품질 체크 → 보고서 작성
```

> 모든 작업은 이 흐름을 따른다. 예외 없음.
