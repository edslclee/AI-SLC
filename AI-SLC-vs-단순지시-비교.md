# AI-SLC 방식 vs 단순 지시 방식 — 개발 비교

> AI-SLC(AI 업무 최적화 시스템)을 통해 개발하는 경우와 Claude에게 단순히 "이것 만들어줘"라고 지시하는 경우의 차이를 실제 개발 흐름 기준으로 비교한 문서입니다.

---

## 1. 한눈에 보는 차이

| 항목 | 단순 지시 방식 | AI-SLC 방식 |
|------|----------------|-------------|
| 작업 시작 방식 | 즉시 코드 생성 | plan.md 확인 → 매뉴얼 참조 → 구현 |
| 매뉴얼/규칙 준수 | 없음 (Claude 재량) | 10개 챕터 기반 강제 준수 |
| 세션 간 맥락 유지 | 불가 (매 세션 초기화) | working-memory로 유지 |
| 변경 사항 추적 | 없음 | change-log.md 자동 기록 |
| 품질 검증 | 없음 | Pre/Post/Stop 훅 자동 실행 |
| 전문 검토 | 없음 | 5개 전문 에이전트 교차 검토 |
| 결과물 형식 | 자유 형식 | Findings/Modifications/Rationale 구조화 보고서 |
| 컨텍스트 포화 대응 | 없음 (결과 열화) | Hard Reset 절차로 복구 |

---

## 2. 개발 흐름 비교

### 단순 지시 방식

```
사용자: "로그인 API 만들어줘"
  ↓
Claude: 즉시 코드 생성
  ↓
사용자: "이 부분 수정해줘"
  ↓
Claude: 수정 (이전 맥락 일부 소실 가능)
  ↓
반복...
  ↓
결과: 코드 존재, but 일관성·품질 불확실
```

**문제점**
- 세션이 길어지면 초반 결정사항을 잊고 엇나간 코드 생성
- 보안, 에러 처리, 코딩 컨벤션은 Claude 당일 기분(?)에 의존
- 어디를 어떻게 바꿨는지 추적 불가
- 다음 세션에서 처음부터 다시 설명해야 함

---

### AI-SLC 방식

```
사용자: "로그인 API 만들어줘"
  ↓
System 2: working-memory/plan.md 확인 (기존 계획 파악)
  ↓
System 1: 키워드 감지 → ch02(보안), ch03(API 설계), ch01(에러 핸들링) 로딩
  ↓
PreToolUse 훅: 파일 편집 전 관련 매뉴얼 챕터 자동 알림
  ↓
Claude: 매뉴얼 규칙 준수하며 구현
  ↓
PostToolUse 훅: change-log.md에 변경 자동 기록
  ↓
System 4: security-auditor + reviewer 교차 검토
  ↓
Stop 훅 품질 게이트: 4개 항목 자동 검증
  ↓
결과: 구조화 보고서(Findings/Modifications/Rationale) 출력
```

---

## 3. 핵심 차이점 상세 비교

### 3-1. 매뉴얼 준수 — 보안 처리 예시

**단순 지시 방식**
```javascript
// Claude가 생성하는 코드 — 운이 좋으면 괜찮고, 아니면...
app.post('/login', async (req, res) => {
  const { username, password } = req.body;
  const user = await db.query(`SELECT * FROM users WHERE username='${username}'`);
  // SQL 인젝션 취약점 그대로
  if (user && user.password === password) {  // 평문 비교
    res.json({ token: generateToken(user) });
  }
});
```

**AI-SLC 방식** (ch02 보안 매뉴얼 적용)
```javascript
// ch02 MUST 규칙 적용:
// - 파라미터화된 쿼리 필수
// - bcrypt 해시 비교 필수
// - 에러 메시지에 내부 정보 노출 금지
app.post('/login', async (req, res) => {
  const { username, password } = req.body;
  const user = await db.query(
    'SELECT * FROM users WHERE username = $1', [username]  // 파라미터화
  );
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    return res.status(401).json({ error: 'Invalid credentials' }); // 정보 최소화
  }
  res.json({ token: generateToken(user) });
});
```

---

### 3-2. 세션 간 맥락 유지

**단순 지시 방식**

| 세션 | 상황 |
|------|------|
| 1일차 | "users 테이블에 soft delete 방식 쓰기로 함" |
| 2일차 | Claude가 기억 못함 → hard delete로 구현 → 버그 발생 |
| 3일차 | 다시 설명하고 수정 → 시간 낭비 |

**AI-SLC 방식**

```markdown
# working-memory/context-notes.md

## 기술적 결정사항
- [2024-01-15] users 테이블: soft delete 방식 채택 (deleted_at 컬럼)
  - 이유: 감사 로그 요구사항, 복구 가능성 확보
- [2024-01-15] 인증: JWT + Redis 세션 혼용 (보안 강화)
```

→ 다음 세션 시작 시 이 파일을 읽으면 즉시 이전 결정사항 파악 가능

---

### 3-3. 변경 사항 추적

**단순 지시 방식**
- 어떤 파일이 언제 바뀌었는지 알 수 없음
- 문제 발생 시 원인 추적 어려움

**AI-SLC 방식** (PostToolUse 훅 자동 기록)

```markdown
# working-memory/change-log.md

| 시각 | 작업 | 파일 |
|---------------------|------|--------------------|
| 2024-01-15 14:22:31 | Edit | src/routes/auth.js |
| 2024-01-15 14:23:05 | Edit | src/middleware/validate.js |
| 2024-01-15 14:25:18 | Write | tests/auth.test.js |
```

→ 문제 발생 시 "언제 뭘 바꿨는지" 즉시 파악 가능

---

### 3-4. 품질 게이트

**단순 지시 방식**
- Claude가 코드 작성 → 그냥 끝
- 품질 검증은 사용자 몫

**AI-SLC 방식** — Stop 훅이 완료 시 자동 점검

```
✓ 관련 매뉴얼 챕터를 참조했는가?          → ch02, ch03 참조 확인
✓ 모든 파일 변경이 change-log에 기록됐는가? → 3개 파일 기록 확인
✓ 품질 체크리스트를 수행했는가?            → 에러 처리, 보안, 엣지 케이스 확인
✓ 구조화 보고서가 존재하는가?              → Findings/Modifications/Rationale 확인
```

---

### 3-5. 에이전트 교차 검토

**단순 지시 방식**
- Claude 혼자 작성하고 혼자 검토 → 사각지대 발생

**AI-SLC 방식**

| 에이전트 | 역할 | 보안 API 예시 |
|------------------|----------------|--------------------------------------|
| planner | 구현 전략 설계 | "JWT vs 세션 방식 ADR 작성" |
| reviewer | 코드 품질 검토 | "에러 처리 누락 3곳 발견" |
| security-auditor | 보안 취약점 감사 | "CSRF 토큰 누락, rate limiting 없음" |
| tester | 테스트 작성 | "엣지 케이스 5개 테스트 추가" |
| qa-inspector | 최종 품질 확인 | "기존 기능 회귀 없음 확인" |

중요 변경 시 최소 2개 에이전트가 독립적으로 검토 → 단일 관점의 맹점 제거

---

## 4. 컨텍스트 포화 문제 비교

긴 작업에서 Claude의 컨텍스트 윈도우가 가득 차는 상황:

**단순 지시 방식**
- 초반 요구사항, 설계 결정, 제약조건 등이 점차 밀려남
- 이후 생성 코드가 초반 결정과 충돌하기 시작
- 사용자가 다시 설명해야 하는 악순환

**AI-SLC 방식** — Hard Reset 절차

```
컨텍스트 압박 감지
  ↓
세션 종료 전:
  1. plan.md → 현재 Phase, 완료 항목, 다음 액션 업데이트
  2. checklist.md → 태스크 상태 업데이트
  3. context-notes.md → 새 발견/결정 추가
  4. change-log.md → 자동 기록 확인
  ↓
다음 세션 시작:
  working-memory/ 전체 읽기 → 즉시 맥락 복원
```

→ 세션이 끊겨도 **3분 이내 맥락 완전 복원** 가능

---

## 5. 결과물 품질 비교

| 관점 | 단순 지시 | AI-SLC |
|------------|------------------------|--------------------------|
| **보안** | Claude 판단에 의존 | ch02 MUST 규칙 강제 적용 |
| **에러 처리** | 누락 빈번 | ch01 패턴 필수 적용 |
| **테스트** | 요청 시만 작성 | ch05 기준 자동 확인 |
| **코드 일관성** | 세션마다 달라질 수 있음 | ch07 컨벤션 고정 |
| **API 설계** | 임의 설계 | ch03 RESTful 규칙 준수 |
| **추적 가능성** | 없음 | change-log 100% 기록 |
| **재현 가능성** | 낮음 | working-memory로 높음 |

---

## 6. 언제 어떤 방식을 쓸까?

| 상황 | 권장 방식 | 이유 |
|----------------------------------|-----------|--------------------------|
| 빠른 프로토타입, 1회성 스크립트 | 단순 지시 | 오버헤드 불필요 |
| 1일 이상 이어지는 프로젝트 | AI-SLC | 맥락 유지 가치 있음 |
| 팀 협업, 코드 리뷰 있는 프로젝트 | AI-SLC | 일관성·추적성 필수 |
| 보안이 중요한 서비스 (금융, 인증 등) | AI-SLC | 매뉴얼 강제 준수 필수 |
| 장기 유지보수 프로젝트 | AI-SLC | 변경 추적·맥락 복원 가치 큼 |
| 간단한 질문/답변, 개념 설명 | 단순 지시 | 시스템 필요 없음 |

---

## 7. 요약

> **단순 지시 방식**은 빠르지만 일관성·품질·추적성이 없다.
> **AI-SLC 방식**은 약간의 초기 설정 비용이 있지만, 프로젝트가 길어질수록 누적 품질 이득이 압도적이다.

핵심 가치 3가지:

1. **기억** — working-memory로 세션이 끊겨도 맥락 보존
2. **규칙** — 매뉴얼 10개 챕터로 품질 기준 강제화
3. **추적** — 훅 자동화로 모든 변경사항 100% 기록
