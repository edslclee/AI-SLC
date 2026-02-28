# ch01 — 에러 핸들링

> 키워드: `try`, `catch`, `exception`, `retry`, `fallback`

---

## Rules (MUST)

### R1. 에러를 절대 삼키지 않는다
모든 `catch` 블록은 반드시 에러를 로깅하거나, 재발생(rethrow)하거나, 명시적으로 처리해야 한다. 빈 `catch` 블록은 허용하지 않는다.

### R2. 커스텀 에러 클래스를 사용한다
비즈니스 로직 에러는 기본 `Error` 대신 도메인 특화 커스텀 에러 클래스를 정의하여 사용한다. 에러 코드, HTTP 상태 코드, 사용자 메시지를 포함한다.

### R3. 에러 전파 경계를 명확히 한다
에러는 처리할 수 있는 계층에서만 catch한다. 중간 계층에서 catch하려면 반드시 원본 에러를 cause로 포함하여 다시 던진다.

### R4. 재시도(retry)는 멱등한 작업에만 적용한다
네트워크 요청, 외부 API 호출 등 일시적 실패가 발생할 수 있는 멱등 작업에 대해 지수 백오프(exponential backoff) 전략으로 재시도한다. 최대 재시도 횟수를 반드시 설정한다.

### R5. 폴백(fallback) 메커니즘을 구현한다
핵심 기능에 장애가 발생할 때 대체 동작(캐시된 데이터 반환, 기본값 사용 등)을 제공한다. 폴백 실행 시 반드시 경고 로그를 남긴다.

### R6. 사용자에게는 친화적 메시지를, 개발자에게는 상세 정보를 제공한다
사용자 응답에는 내부 구현 상세나 스택 트레이스를 절대 포함하지 않는다. 내부 에러 상세는 로그에만 기록한다.

### R7. 에러 바운더리 패턴을 적용한다
UI 레이어에서는 에러 바운더리(Error Boundary)를 사용하여 컴포넌트 트리 전체가 언마운트되는 것을 방지한다. API 레이어에서는 글로벌 에러 핸들러를 설정한다.

### R8. 비동기 에러를 누락하지 않는다
모든 Promise에는 `.catch()` 또는 `try/catch`(async/await)를 적용한다. `unhandledRejection` 이벤트 핸들러를 프로세스 레벨에서 반드시 등록한다.

### R9. 에러 로그에는 컨텍스트를 포함한다
에러 로그에는 최소한 요청 ID, 사용자 ID(있는 경우), 타임스탬프, 에러 코드, 스택 트레이스를 포함한다.

### R10. 그레이스풀 디그레이데이션을 적용한다
부분 장애 시 시스템 전체가 중단되지 않도록 한다. 비핵심 기능의 실패가 핵심 기능에 영향을 주지 않도록 격리한다.

---

## Patterns (권장 패턴)

### 패턴 1: 커스텀 에러 클래스 계층 구조

```typescript
// 기본 애플리케이션 에러
class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500,
    public readonly isOperational: boolean = true,
    public readonly cause?: Error
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

// 도메인 특화 에러
class ValidationError extends AppError {
  constructor(message: string, public readonly fields: Record<string, string>) {
    super(message, 'VALIDATION_ERROR', 400);
  }
}

class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super(`${resource}(${id})을 찾을 수 없습니다`, 'NOT_FOUND', 404);
  }
}

class ExternalServiceError extends AppError {
  constructor(service: string, cause: Error) {
    super(
      `외부 서비스(${service}) 호출 실패`,
      'EXTERNAL_SERVICE_ERROR',
      502,
      true,
      cause
    );
  }
}
```

### 패턴 2: 지수 백오프 재시도

```typescript
interface RetryOptions {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
  retryableErrors?: string[];
}

async function withRetry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = { maxRetries: 3, baseDelayMs: 1000, maxDelayMs: 10000 }
): Promise<T> {
  let lastError: Error;

  for (let attempt = 0; attempt <= options.maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;

      if (attempt === options.maxRetries) break;

      // 재시도 가능한 에러인지 확인
      if (options.retryableErrors && !isRetryable(error, options.retryableErrors)) {
        throw error;
      }

      const delay = Math.min(
        options.baseDelayMs * Math.pow(2, attempt) + Math.random() * 1000,
        options.maxDelayMs
      );

      logger.warn(`재시도 ${attempt + 1}/${options.maxRetries}`, {
        error: lastError.message,
        nextRetryMs: delay,
      });

      await sleep(delay);
    }
  }

  throw lastError!;
}

// 사용 예시
const userData = await withRetry(
  () => externalApi.fetchUser(userId),
  { maxRetries: 3, baseDelayMs: 500, maxDelayMs: 5000 }
);
```

### 패턴 3: 폴백 메커니즘

```typescript
async function getUserProfile(userId: string): Promise<UserProfile> {
  try {
    // 1차: 주요 데이터 소스
    const profile = await userService.getProfile(userId);
    await cache.set(`user:${userId}`, profile, { ttl: 300 });
    return profile;
  } catch (error) {
    logger.warn('사용자 프로필 조회 실패, 캐시 폴백 시도', {
      userId,
      error: (error as Error).message,
    });

    try {
      // 2차: 캐시 폴백
      const cached = await cache.get<UserProfile>(`user:${userId}`);
      if (cached) {
        logger.info('캐시된 프로필 반환', { userId });
        return cached;
      }
    } catch (cacheError) {
      logger.error('캐시 조회도 실패', { userId, error: (cacheError as Error).message });
    }

    // 3차: 최소 기본값 반환
    logger.error('모든 폴백 실패, 기본 프로필 반환', { userId });
    return { userId, name: '알 수 없음', isPartial: true };
  }
}
```

### 패턴 4: 글로벌 에러 핸들러 (Express)

```typescript
// 글로벌 에러 핸들링 미들웨어
function globalErrorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  const requestId = req.headers['x-request-id'] as string;

  if (err instanceof AppError) {
    // 운영 에러: 예상된 에러
    logger.error('운영 에러 발생', {
      requestId,
      code: err.code,
      message: err.message,
      statusCode: err.statusCode,
      stack: err.stack,
      cause: err.cause?.message,
    });

    res.status(err.statusCode).json({
      success: false,
      error: {
        code: err.code,
        message: err.message, // 사용자 친화적 메시지
      },
    });
  } else {
    // 프로그래밍 에러: 예상치 못한 에러
    logger.error('예상치 못한 에러 발생', {
      requestId,
      message: err.message,
      stack: err.stack,
    });

    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: '서버 내부 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
      },
    });
  }
}

// 처리되지 않은 Promise 거부 핸들러
process.on('unhandledRejection', (reason: unknown) => {
  logger.fatal('처리되지 않은 Promise 거부', { reason });
  // 그레이스풀 셧다운 진행
  gracefulShutdown(1);
});

process.on('uncaughtException', (error: Error) => {
  logger.fatal('처리되지 않은 예외', { error: error.message, stack: error.stack });
  gracefulShutdown(1);
});
```

### 패턴 5: 에러 전파 시 원본 보존

```typescript
// 서비스 계층에서 에러 전파
async function processOrder(orderId: string): Promise<Order> {
  try {
    const order = await orderRepository.findById(orderId);
    if (!order) {
      throw new NotFoundError('Order', orderId);
    }

    const payment = await paymentService.charge(order);
    return await orderRepository.update(orderId, { status: 'paid', paymentId: payment.id });
  } catch (error) {
    if (error instanceof AppError) {
      throw error; // 이미 도메인 에러이면 그대로 전파
    }

    // 외부 에러는 감싸서 전파 (원본 cause 보존)
    throw new ExternalServiceError('PaymentService', error as Error);
  }
}
```

---

## Anti-Patterns (NEVER)

### 안티패턴 1: 빈 catch 블록 (에러 삼키기)

```typescript
// NEVER: 에러를 삼키면 디버깅이 불가능하다
try {
  await saveUserData(data);
} catch (error) {
  // 아무 것도 안 함 - 절대 금지!
}
```

### 안티패턴 2: 모든 곳에서 catch하기

```typescript
// NEVER: 불필요한 catch로 에러 정보 손실
async function getUser(id: string) {
  try {
    return await db.users.findById(id);
  } catch (error) {
    return null; // 에러 원인을 완전히 숨김. DB 장애인지 코드 버그인지 알 수 없음
  }
}
```

### 안티패턴 3: 내부 정보 사용자 노출

```typescript
// NEVER: 스택 트레이스나 내부 구현을 사용자에게 노출
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  res.status(500).json({
    error: err.message,         // "Cannot read property 'id' of undefined"
    stack: err.stack,           // 파일 경로, 라인 넘버 전부 노출
    query: req.query,           // 요청 정보 노출
    dbConnectionString: config.db.url,  // 치명적 보안 사고
  });
});
```

### 안티패턴 4: 재시도 횟수 무제한

```typescript
// NEVER: 무한 재시도는 시스템 리소스를 고갈시킨다
async function fetchWithRetry(url: string): Promise<Response> {
  while (true) {  // 무한 루프 - 절대 금지!
    try {
      return await fetch(url);
    } catch {
      await sleep(100); // 백오프도 없이 빠르게 반복
    }
  }
}
```

### 안티패턴 5: 제네릭 에러만 사용

```typescript
// NEVER: 구분할 수 없는 에러를 던지면 호출자가 적절히 처리할 수 없다
throw new Error('실패했습니다');          // 무엇이 왜 실패했는지 알 수 없음
throw new Error('invalid input');        // 어떤 입력이 왜 잘못되었는지 불명
throw new Error(JSON.stringify(errors)); // 에러 메시지에 JSON을 넣지 말 것
```

### 안티패턴 6: 비동기 에러 무시

```typescript
// NEVER: catch 없는 Promise는 unhandledRejection을 일으킨다
function fireAndForget() {
  someAsyncOperation(); // .catch() 없음 - 절대 금지!

  promises.map(async (p) => {
    await doSomething(p); // map 내부의 async는 에러가 전파되지 않음
  });
}
```

---

## Checklist

코드 리뷰 또는 PR 작성 시 아래 항목을 확인합니다:

- [ ] 모든 `catch` 블록이 에러를 로깅하거나 재발생시키는가? (빈 catch 없음)
- [ ] 비즈니스 에러에 커스텀 에러 클래스를 사용하고 있는가?
- [ ] 사용자 응답에 내부 에러 상세(스택 트레이스, DB 쿼리 등)가 포함되지 않는가?
- [ ] 모든 비동기 작업에 에러 처리가 있는가? (`.catch()` 또는 `try/catch`)
- [ ] 외부 서비스 호출에 재시도 로직이 있고, 최대 횟수가 설정되어 있는가?
- [ ] 에러 로그에 충분한 컨텍스트(요청 ID, 사용자 ID 등)가 포함되는가?
- [ ] 핵심 기능에 폴백 메커니즘이 구현되어 있는가?
- [ ] `unhandledRejection`, `uncaughtException` 핸들러가 등록되어 있는가?
