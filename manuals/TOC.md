# AI-SLC 프로젝트 매뉴얼 목차

> Claude가 코드 생성/리뷰 시 참조하는 프로젝트 표준 매뉴얼입니다.
> 사용자의 질문이나 작업 컨텍스트에 포함된 **키워드**를 기반으로 해당 챕터를 로드합니다.

## 사용법

1. 사용자의 요청에서 키워드를 추출합니다.
2. 아래 테이블의 `keywords` 컬럼과 매칭합니다.
3. 매칭된 챕터 파일을 로드하여 규칙을 적용합니다.
4. 여러 챕터가 매칭되면 모두 로드합니다.

## 챕터 목록

| 챕터 | 파일 경로 | 주제 | 설명 | 키워드 |
|------|----------|------|------|--------|
| ch01 | `ch01-error-handling.md` | 에러 핸들링 | 에러 처리, 재시도, 폴백 전략에 대한 표준 규칙 | `try`, `catch`, `exception`, `retry`, `fallback` |
| ch02 | `ch02-security.md` | 보안 | 인증, 인가, 입력 검증, 시크릿 관리 등 보안 규칙 | `auth`, `token`, `XSS`, `CSRF`, `encryption`, `secrets` |
| ch03 | `ch03-api-design.md` | API 설계 | RESTful API 설계 원칙, HTTP 상태 코드, 버전 관리 규칙 | `REST`, `endpoint`, `HTTP`, `status code` |
| ch04 | `ch04-database.md` | 데이터베이스 | 마이그레이션, 인덱스, 트랜잭션, 쿼리 최적화 규칙 | `SQL`, `ORM`, `migration`, `index`, `transaction` |
| ch05 | `ch05-testing.md` | 테스팅 | 테스트 피라미드, 모킹 전략, 커버리지 기준 규칙 | `test`, `mock`, `coverage`, `fixture`, `assert` |
| ch06 | `ch06-git-workflow.md` | Git 워크플로우 | 브랜치 전략, 커밋 메시지, PR 규칙 | `branch`, `commit`, `merge`, `PR` |
| ch07 | `ch07-code-style.md` | 코드 스타일 | 네이밍, 포맷팅, 린트, 코딩 컨벤션 규칙 | `naming`, `format`, `lint`, `convention` |
| ch08 | `ch08-performance.md` | 성능 | 캐싱, 최적화, N+1 문제, 페이지네이션 규칙 | `cache`, `optimize`, `N+1`, `pagination` |
| ch09 | `ch09-logging-monitoring.md` | 로깅/모니터링 | 로그 레벨, 메트릭, 알림, 분산 추적 규칙 | `log`, `metric`, `alert`, `trace` |
| ch10 | `ch10-deployment.md` | 배포 | Docker, CI/CD 파이프라인, 환경 변수, K8s 규칙 | `Docker`, `CI/CD`, `env`, `K8s` |

## 각 챕터 구조

모든 챕터는 다음 통일된 구조를 따릅니다:

```
# chXX — 주제명

## Rules (MUST)
- 반드시 지켜야 하는 규칙 목록 (5~10개)

## Patterns (권장 패턴)
- 코드 예제와 함께 권장하는 구현 패턴

## Anti-Patterns (NEVER)
- 절대 하지 말아야 하는 패턴과 코드 예제

## Checklist
- PR/코드 리뷰 시 빠르게 확인할 수 있는 체크리스트 (5~8개)
```
