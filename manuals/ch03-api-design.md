# ch03 — API 설계

> 키워드: `REST`, `endpoint`, `HTTP`, `status code`

---

## Rules (MUST)

### R1. RESTful 리소스 네이밍 규칙을 따른다
URL은 리소스를 나타내며 복수 명사를 사용한다. 동사를 URL에 포함하지 않는다. 계층 관계는 중첩 경로로 표현하되 2단계를 초과하지 않는다.

### R2. HTTP 메서드를 의미에 맞게 사용한다
- `GET`: 조회 (안전, 멱등)
- `POST`: 생성 (비멱등)
- `PUT`: 전체 교체 (멱등)
- `PATCH`: 부분 수정 (멱등)
- `DELETE`: 삭제 (멱등)

### R3. 적절한 HTTP 상태 코드를 반환한다
- `200`: 성공 (조회, 수정)
- `201`: 리소스 생성 성공
- `204`: 성공이지만 응답 본문 없음 (삭제)
- `400`: 클라이언트 요청 오류 (잘못된 입력)
- `401`: 인증 필요
- `403`: 인가 실패 (권한 부족)
- `404`: 리소스 없음
- `409`: 충돌 (중복 리소스)
- `422`: 검증 실패
- `429`: 요청 횟수 초과
- `500`: 서버 내부 오류

### R4. 일관된 에러 응답 형식을 사용한다
모든 에러 응답은 동일한 구조를 따른다. 에러 코드, 사용자 메시지, (개발 환경에서만) 상세 정보를 포함한다.

### R5. 페이지네이션을 필수 적용한다
목록 조회 API는 반드시 페이지네이션을 적용한다. 기본 페이지 크기와 최대 페이지 크기를 설정한다. 커서 기반 또는 오프셋 기반 방식 중 적합한 것을 선택한다.

### R6. API 버전 관리를 한다
URL 경로(`/api/v1/`)로 버전을 관리한다. 브레이킹 체인지 시 새 버전을 도입하고, 이전 버전은 일정 기간 유지(deprecation period)한다.

### R7. 요청 검증을 서버에서 수행한다
모든 API 요청의 본문, 쿼리 파라미터, 경로 파라미터를 서버에서 스키마 기반으로 검증한다. 검증 실패 시 어떤 필드가 왜 실패했는지 상세한 에러를 반환한다.

### R8. Rate Limiting을 적용한다
모든 공개 API에 요청 횟수 제한을 적용한다. 제한 정보를 응답 헤더(`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`)로 전달한다.

### R9. 멱등성(Idempotency)을 보장한다
`PUT`, `DELETE`는 여러 번 호출해도 동일한 결과를 보장한다. `POST`의 경우 `Idempotency-Key` 헤더를 지원하여 중복 생성을 방지한다.

### R10. API 문서를 자동 생성한다
OpenAPI(Swagger) 스펙을 코드와 동기화하여 유지한다. 모든 엔드포인트의 요청/응답 스키마, 에러 코드, 예제를 문서에 포함한다.

---

## Patterns (권장 패턴)

### 패턴 1: 일관된 응답 구조

```typescript
// 성공 응답 형식
interface SuccessResponse<T> {
  success: true;
  data: T;
  meta?: {
    pagination?: PaginationMeta;
    requestId: string;
  };
}

// 에러 응답 형식
interface ErrorResponse {
  success: false;
  error: {
    code: string;          // 머신이 읽을 수 있는 에러 코드
    message: string;       // 사용자 친화적 메시지
    details?: Array<{      // 검증 에러 상세
      field: string;
      message: string;
    }>;
  };
}

// 응답 헬퍼 함수
function sendSuccess<T>(res: Response, data: T, statusCode = 200): void {
  res.status(statusCode).json({
    success: true,
    data,
    meta: { requestId: res.locals.requestId },
  });
}

function sendCreated<T>(res: Response, data: T): void {
  sendSuccess(res, data, 201);
}

function sendNoContent(res: Response): void {
  res.status(204).send();
}

function sendError(res: Response, statusCode: number, code: string, message: string): void {
  res.status(statusCode).json({
    success: false,
    error: { code, message },
  });
}
```

### 패턴 2: RESTful 라우터 설계

```typescript
import { Router } from 'express';

const router = Router();

// 리소스: 사용자
// GET    /api/v1/users          - 사용자 목록 조회 (페이지네이션)
// POST   /api/v1/users          - 사용자 생성
// GET    /api/v1/users/:id      - 사용자 상세 조회
// PUT    /api/v1/users/:id      - 사용자 전체 수정
// PATCH  /api/v1/users/:id      - 사용자 부분 수정
// DELETE /api/v1/users/:id      - 사용자 삭제

router.get('/api/v1/users', authenticate, validate(ListUsersQuery), userController.list);
router.post('/api/v1/users', authenticate, authorize('admin'), validate(CreateUserBody), userController.create);
router.get('/api/v1/users/:id', authenticate, validate(UserIdParam), userController.getById);
router.put('/api/v1/users/:id', authenticate, validate(UpdateUserBody), userController.update);
router.patch('/api/v1/users/:id', authenticate, validate(PatchUserBody), userController.patch);
router.delete('/api/v1/users/:id', authenticate, authorize('admin'), userController.delete);

// 중첩 리소스 (최대 2단계)
// GET    /api/v1/users/:userId/posts       - 특정 사용자의 게시글 목록
// POST   /api/v1/users/:userId/posts       - 특정 사용자의 게시글 생성
router.get('/api/v1/users/:userId/posts', authenticate, postController.listByUser);
router.post('/api/v1/users/:userId/posts', authenticate, postController.create);

// 3단계 이상 중첩 금지 — 아래처럼 분리
// BAD:  /api/v1/users/:userId/posts/:postId/comments
// GOOD: /api/v1/posts/:postId/comments
router.get('/api/v1/posts/:postId/comments', authenticate, commentController.listByPost);
```

### 패턴 3: 커서 기반 페이지네이션

```typescript
interface PaginationMeta {
  hasMore: boolean;
  nextCursor: string | null;
  totalCount?: number;
}

// 컨트롤러
async function listUsers(req: Request, res: Response): Promise<void> {
  const { cursor, limit = 20 } = req.query;
  const maxLimit = Math.min(Number(limit), 100); // 최대 100개 제한

  const users = await userRepository.findMany({
    cursor: cursor ? String(cursor) : undefined,
    take: maxLimit + 1, // 다음 페이지 존재 여부 확인을 위해 1개 더 조회
  });

  const hasMore = users.length > maxLimit;
  const items = hasMore ? users.slice(0, maxLimit) : users;
  const nextCursor = hasMore ? items[items.length - 1].id : null;

  sendSuccess(res, items, 200);
  // meta에 pagination 정보 포함
  res.json({
    success: true,
    data: items,
    meta: {
      requestId: res.locals.requestId,
      pagination: { hasMore, nextCursor },
    },
  });
}
```

### 패턴 4: Rate Limiting

```typescript
import rateLimit from 'express-rate-limit';

// 글로벌 Rate Limit
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15분
  max: 100,                  // 최대 100회
  standardHeaders: true,     // RateLimit-* 헤더 포함
  legacyHeaders: false,
  message: {
    success: false,
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: '요청 횟수를 초과했습니다. 잠시 후 다시 시도해 주세요.',
    },
  },
});

// 로그인 엔드포인트 전용 (브루트포스 방지)
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5, // 15분에 5회
  skipSuccessfulRequests: true,
  message: {
    success: false,
    error: {
      code: 'TOO_MANY_LOGIN_ATTEMPTS',
      message: '로그인 시도 횟수를 초과했습니다. 15분 후 다시 시도해 주세요.',
    },
  },
});

app.use('/api/', globalLimiter);
app.use('/api/v1/auth/login', loginLimiter);
```

### 패턴 5: 멱등성 키 (POST 요청)

```typescript
// 멱등성 미들웨어
async function idempotency(req: Request, res: Response, next: NextFunction): Promise<void> {
  if (req.method !== 'POST') return next();

  const idempotencyKey = req.headers['idempotency-key'] as string;
  if (!idempotencyKey) return next();

  // 이전 결과 조회
  const cached = await redis.get(`idempotency:${idempotencyKey}`);
  if (cached) {
    const { statusCode, body } = JSON.parse(cached);
    res.status(statusCode).json(body);
    return;
  }

  // 원본 json() 함수를 래핑하여 결과 캐싱
  const originalJson = res.json.bind(res);
  res.json = (body: any) => {
    redis.set(
      `idempotency:${idempotencyKey}`,
      JSON.stringify({ statusCode: res.statusCode, body }),
      'EX',
      86400 // 24시간 유지
    );
    return originalJson(body);
  };

  next();
}

// 사용
router.post('/api/v1/payments', authenticate, idempotency, paymentController.create);

// 클라이언트 사용 예시
// POST /api/v1/payments
// Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

---

## Anti-Patterns (NEVER)

### 안티패턴 1: URL에 동사 사용

```typescript
// NEVER: URL에 동작(동사)을 포함하지 않는다
router.post('/api/v1/createUser', handler);        // 동사 사용
router.get('/api/v1/getUserById/:id', handler);     // 동사 사용
router.post('/api/v1/deleteUser/:id', handler);     // POST로 삭제
router.get('/api/v1/getAllUsers', handler);          // 동사 사용

// 올바른 방법: HTTP 메서드가 동작을 나타낸다
// POST   /api/v1/users
// GET    /api/v1/users/:id
// DELETE /api/v1/users/:id
// GET    /api/v1/users
```

### 안티패턴 2: 모든 응답에 200 반환

```typescript
// NEVER: 에러 상황에서도 200을 반환하면 클라이언트가 에러를 감지할 수 없다
app.post('/api/v1/users', async (req, res) => {
  try {
    const user = await createUser(req.body);
    res.status(200).json({ result: 'success', user }); // 201이어야 함
  } catch (error) {
    res.status(200).json({ result: 'error', message: error.message }); // 4xx/5xx여야 함
  }
});
```

### 안티패턴 3: 일관성 없는 응답 형식

```typescript
// NEVER: 엔드포인트마다 응답 형식이 다르면 클라이언트 구현이 어렵다
// 엔드포인트 A
res.json({ data: users, total: 100 });
// 엔드포인트 B
res.json({ items: posts, count: 50, page: 1 });
// 엔드포인트 C
res.json({ result: comments, hasNext: true });
// 에러 응답도 제각각
res.json({ error: '실패' });
res.json({ message: '오류 발생', code: 500 });
res.json({ errors: ['잘못된 입력'] });
```

### 안티패턴 4: 페이지네이션 없는 목록 조회

```typescript
// NEVER: 전체 데이터를 한번에 반환하면 메모리/네트워크 과부하 발생
app.get('/api/v1/logs', async (req, res) => {
  const allLogs = await db.logs.findMany(); // 수백만 건이 될 수 있음
  res.json(allLogs); // 서버 OOM 크래시 가능
});
```

### 안티패턴 5: HTTP 메서드 오용

```typescript
// NEVER: GET으로 상태 변경, POST로 조회
router.get('/api/v1/users/:id/delete', userController.delete);  // GET으로 삭제
router.post('/api/v1/users/search', userController.search);      // 단순 조회에 POST
// 검색은 쿼리 파라미터로: GET /api/v1/users?name=Kim&role=admin
```

---

## Checklist

코드 리뷰 또는 PR 작성 시 아래 항목을 확인합니다:

- [ ] URL이 복수 명사로 구성되고 동사가 포함되지 않았는가?
- [ ] HTTP 메서드가 의미에 맞게 사용되었는가? (GET=조회, POST=생성 등)
- [ ] 상태 코드가 적절한가? (201=생성, 204=삭제, 400=잘못된 요청 등)
- [ ] 성공/에러 응답이 프로젝트 표준 형식을 따르는가?
- [ ] 목록 조회 API에 페이지네이션이 적용되어 있는가? (기본/최대 크기 설정)
- [ ] API 버전이 URL 경로에 포함되어 있는가? (`/api/v1/`)
- [ ] 모든 요청 파라미터가 서버에서 검증되는가?
- [ ] Rate Limiting이 적용되어 있는가?
