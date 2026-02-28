# Chapter 09: 로깅/모니터링

> 로깅과 모니터링은 프로덕션 시스템의 가시성(observability)을 확보하는 핵심이다. 구조화된 로그, 요청 추적, 메트릭 수집, 알림 전략을 체계적으로 구축하여 장애를 조기에 탐지하고 신속하게 대응한다.

---

## Rules (MUST)

### Rule 1: 구조화된 로그(JSON 형식)를 사용한다

- 모든 로그는 **JSON 형식**으로 출력한다
- 로그에 반드시 포함할 필드: `timestamp`, `level`, `message`, `service`, `traceId`
- 사람이 읽기 위한 로그(`console.log`)는 **프로덕션에서 사용하지 않는다**
- 로그 파서가 처리할 수 있도록 **일관된 스키마**를 유지한다

### Rule 2: 로그 레벨을 올바르게 사용한다

| 레벨 | 용도 | 예시 |
|------|------|------|
| `error` | 즉시 대응 필요한 오류 | DB 연결 실패, 결제 처리 실패 |
| `warn` | 잠재적 문제, 곧 실패할 수 있는 상황 | 디스크 90% 사용, 재시도 발생 |
| `info` | 정상 흐름의 주요 이벤트 | 서버 시작, 사용자 로그인, 주문 완료 |
| `debug` | 개발/디버깅용 상세 정보 | 쿼리 파라미터, 중간 계산값 |

- `error` 레벨은 **실제 에러 상황에만** 사용한다 (예상된 분기 처리에 사용 금지)
- 프로덕션에서는 `info` 이상만 출력한다 (`debug`는 개발 환경 전용)
- 로그 레벨은 **환경 변수로 동적 변경** 가능하게 설정한다

### Rule 3: 민감 데이터를 로그에 절대 기록하지 않는다

- **절대 기록 금지**: 비밀번호, 토큰, 신용카드 번호, 주민등록번호, API Key
- **마스킹 필수**: 이메일(`k**@example.com`), 전화번호(`010-****-5678`), IP 주소
- 요청/응답 본문을 로깅할 때 **민감 필드를 자동 필터링**한다
- 로그 마스킹 로직을 **중앙화**하여 누락을 방지한다

### Rule 4: 모든 요청에 Correlation ID(추적 ID)를 부여한다

- 클라이언트 요청 진입 시 고유한 **traceId**(또는 correlationId)를 생성한다
- traceId는 **모든 로그**, **서비스 간 호출**, **비동기 작업**에 전파한다
- 응답 헤더에 traceId를 포함하여 **클라이언트에서도 추적** 가능하게 한다
- 분산 시스템에서는 **OpenTelemetry** 기반 트레이싱을 사용한다

### Rule 5: 핵심 비즈니스 메트릭을 수집한다

수집해야 할 메트릭 유형:

| 유형 | 메트릭 예시 | 도구 |
|------|-------------|------|
| RED | Request Rate, Error Rate, Duration | Prometheus |
| USE | CPU Utilization, Memory Saturation, Disk Errors | Node Exporter |
| 비즈니스 | 주문 수, 결제 성공률, 회원가입 수 | Custom Metrics |

- **RED 메트릭**(Rate, Errors, Duration)을 모든 API에 적용한다
- 히스토그램으로 **응답 시간 분포**(p50, p95, p99)를 추적한다
- 카운터로 **에러 수와 요청 수**를 추적한다
- 게이지로 **현재 상태값**(커넥션 수, 큐 크기)을 추적한다

### Rule 6: 알림 전략을 증상 기반으로 설계한다

- **증상(Symptom)** 기반 알림: "응답 시간 p99 > 2초", "에러율 > 1%"
- **원인(Cause)** 기반 알림은 보조적으로만 사용: "CPU > 90%"
- 알림에 **심각도(Severity)** 를 분류한다: Critical / Warning / Info
- **알림 피로(Alert Fatigue)** 를 방지한다: 중복 알림 억제, 그룹화
- 모든 알림에 **Runbook 링크**를 포함한다

### Rule 7: 로그 보관 정책을 수립한다

| 레벨 | 보관 기간 | 이유 |
|------|-----------|------|
| error | 90일 이상 | 장애 분석, 감사 |
| warn | 30일 | 추세 분석 |
| info | 14일 | 운영 모니터링 |
| debug | 3일 | 디버깅 (프로덕션 비활성) |

- 로그 로테이션을 설정하여 **디스크 부족**을 방지한다
- 오래된 로그는 **비용이 낮은 스토리지**로 아카이빙한다
- 규정 준수를 위해 **감사 로그는 별도로 장기 보관**한다

### Rule 8: 에러 트래킹 서비스를 연동한다

- Sentry, Bugsnag 등 에러 트래킹 도구를 **프로덕션에 반드시** 연동한다
- 에러 발생 시 **스택 트레이스**, **요청 컨텍스트**, **사용자 정보**를 수집한다
- 동일 에러를 **그룹화(fingerprinting)** 하여 중복 알림을 방지한다
- 에러 알림을 **Slack/Teams 등 커뮤니케이션 도구**에 연동한다

### Rule 9: 헬스 체크 엔드포인트를 구현한다

- **Liveness**: 프로세스가 살아있는지 확인 (`/health/live`)
- **Readiness**: 트래픽을 처리할 준비가 되었는지 확인 (`/health/ready`)
- Readiness 체크에 **외부 의존성 상태**(DB, Redis, 외부 API)를 포함한다
- 헬스 체크는 **인증 없이** 접근 가능해야 한다 (로드밸런서용)

### Rule 10: 대시보드를 목적에 맞게 설계한다

| 대시보드 유형 | 대상 | 포함 내용 |
|--------------|------|-----------|
| 운영 대시보드 | SRE/DevOps | 에러율, 응답시간, 리소스 사용량 |
| 비즈니스 대시보드 | PM/경영진 | 주문 수, 매출, 전환율 |
| 서비스 상세 | 개발팀 | 개별 서비스 메트릭, DB 쿼리 분석 |
| 온콜 대시보드 | 당번 엔지니어 | 활성 알림, 최근 배포, 에러 트렌드 |

---

## Patterns (권장 패턴)

### Pattern 1: 구조화된 로거 설정 (winston)

```typescript
import winston from 'winston';

interface LogMeta {
  traceId?: string;
  userId?: string;
  action?: string;
  duration?: number;
  [key: string]: unknown;
}

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL ?? 'info',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'ISO' }),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: {
    service: process.env.SERVICE_NAME ?? 'api-server',
    environment: process.env.NODE_ENV ?? 'development',
    version: process.env.APP_VERSION ?? 'unknown',
  },
  transports: [
    new winston.transports.Console(),
  ],
});

// 개발 환경에서는 읽기 쉬운 형식 추가
if (process.env.NODE_ENV === 'development') {
  logger.add(
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple(),
      ),
    }),
  );
}

export { logger };
export type { LogMeta };
```

출력 예시:
```json
{
  "timestamp": "2026-02-28T09:15:30.123Z",
  "level": "info",
  "message": "User login successful",
  "service": "api-server",
  "environment": "production",
  "version": "1.2.3",
  "traceId": "abc-123-def-456",
  "userId": "user-789",
  "duration": 42
}
```

### Pattern 2: 민감 데이터 마스킹

```typescript
type MaskableValue = string | number | null | undefined;

const SENSITIVE_FIELDS = new Set([
  'password', 'token', 'accessToken', 'refreshToken',
  'authorization', 'cookie', 'creditCard', 'cardNumber',
  'cvv', 'ssn', 'secret', 'apiKey', 'privateKey',
]);

const MASKABLE_PATTERNS: Array<{ pattern: RegExp; replacement: string }> = [
  // 이메일: 앞 한글자만 보여주고 나머지 마스킹
  { pattern: /([a-zA-Z0-9])[a-zA-Z0-9.]*@/g, replacement: '$1**@' },
  // 전화번호: 가운데 자리 마스킹
  { pattern: /(\d{2,3})-(\d{3,4})-(\d{4})/g, replacement: '$1-****-$3' },
  // 카드번호: 첫 4자리와 마지막 4자리만 표시
  { pattern: /(\d{4})\d{4,8}(\d{4})/g, replacement: '$1-****-$2' },
];

function maskSensitiveData(obj: unknown): unknown {
  if (obj === null || obj === undefined) return obj;
  if (typeof obj === 'string') return applyPatternMasking(obj);
  if (typeof obj !== 'object') return obj;

  if (Array.isArray(obj)) {
    return obj.map((item) => maskSensitiveData(item));
  }

  const masked: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
    if (SENSITIVE_FIELDS.has(key.toLowerCase())) {
      masked[key] = '[REDACTED]';
    } else if (typeof value === 'string') {
      masked[key] = applyPatternMasking(value);
    } else if (typeof value === 'object') {
      masked[key] = maskSensitiveData(value);
    } else {
      masked[key] = value;
    }
  }
  return masked;
}

function applyPatternMasking(value: string): string {
  let result = value;
  for (const { pattern, replacement } of MASKABLE_PATTERNS) {
    result = result.replace(pattern, replacement);
  }
  return result;
}

// 로거에 마스킹 적용
function logSafe(level: string, message: string, meta?: Record<string, unknown>): void {
  const safeMeta = meta ? maskSensitiveData(meta) : undefined;
  logger.log(level, message, safeMeta as Record<string, unknown>);
}
```

### Pattern 3: Correlation ID 미들웨어

```typescript
import { randomUUID } from 'node:crypto';
import { AsyncLocalStorage } from 'node:async_hooks';
import type { Request, Response, NextFunction } from 'express';

interface RequestContext {
  traceId: string;
  userId?: string;
  startTime: number;
}

const asyncLocalStorage = new AsyncLocalStorage<RequestContext>();

// 현재 컨텍스트 조회 유틸리티
export function getRequestContext(): RequestContext | undefined {
  return asyncLocalStorage.getStore();
}

export function getTraceId(): string {
  return asyncLocalStorage.getStore()?.traceId ?? 'no-trace';
}

// Express 미들웨어
export function correlationIdMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const traceId = (req.headers['x-trace-id'] as string) ?? randomUUID();

  const context: RequestContext = {
    traceId,
    startTime: Date.now(),
  };

  // 응답 헤더에 traceId 포함
  res.setHeader('x-trace-id', traceId);

  // 응답 완료 시 요청 로그 기록
  res.on('finish', () => {
    const duration = Date.now() - context.startTime;
    logger.info('Request completed', {
      traceId,
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration,
      userId: context.userId,
    });
  });

  asyncLocalStorage.run(context, () => next());
}

// 로거에 traceId 자동 포함
function createContextLogger() {
  return {
    info(message: string, meta?: Record<string, unknown>): void {
      logger.info(message, { ...meta, traceId: getTraceId() });
    },
    warn(message: string, meta?: Record<string, unknown>): void {
      logger.warn(message, { ...meta, traceId: getTraceId() });
    },
    error(message: string, meta?: Record<string, unknown>): void {
      logger.error(message, { ...meta, traceId: getTraceId() });
    },
    debug(message: string, meta?: Record<string, unknown>): void {
      logger.debug(message, { ...meta, traceId: getTraceId() });
    },
  };
}

export const contextLogger = createContextLogger();
```

### Pattern 4: Prometheus 메트릭 수집

```typescript
import promClient from 'prom-client';
import type { Request, Response, NextFunction } from 'express';

// 기본 메트릭 수집 (CPU, 메모리, 이벤트 루프 등)
promClient.collectDefaultMetrics({ prefix: 'app_' });

// HTTP 요청 메트릭
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP 요청 처리 시간 (초)',
  labelNames: ['method', 'route', 'status_code'] as const,
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
});

const httpRequestTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'HTTP 요청 총 수',
  labelNames: ['method', 'route', 'status_code'] as const,
});

const httpRequestErrors = new promClient.Counter({
  name: 'http_request_errors_total',
  help: 'HTTP 에러 요청 수',
  labelNames: ['method', 'route', 'error_type'] as const,
});

// 비즈니스 메트릭
const orderTotal = new promClient.Counter({
  name: 'business_orders_total',
  help: '주문 총 수',
  labelNames: ['status', 'payment_method'] as const,
});

const activeConnections = new promClient.Gauge({
  name: 'app_active_connections',
  help: '현재 활성 커넥션 수',
});

// 미들웨어: 모든 HTTP 요청에 대한 메트릭 수집
export function metricsMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const end = httpRequestDuration.startTimer();

  res.on('finish', () => {
    const route = req.route?.path ?? req.path;
    const labels = {
      method: req.method,
      route,
      status_code: String(res.statusCode),
    };

    end(labels);
    httpRequestTotal.inc(labels);

    if (res.statusCode >= 400) {
      httpRequestErrors.inc({
        method: req.method,
        route,
        error_type: res.statusCode >= 500 ? 'server' : 'client',
      });
    }
  });

  next();
}

// 메트릭 엔드포인트
export async function metricsHandler(req: Request, res: Response): Promise<void> {
  res.set('Content-Type', promClient.register.contentType);
  res.end(await promClient.register.metrics());
}
```

### Pattern 5: 헬스 체크 엔드포인트

```typescript
import type { Request, Response } from 'express';
import type { DataSource } from 'typeorm';
import type { Redis } from 'ioredis';

interface HealthCheckResult {
  status: 'healthy' | 'unhealthy';
  timestamp: string;
  version: string;
  uptime: number;
  checks: Record<string, ComponentHealth>;
}

interface ComponentHealth {
  status: 'up' | 'down';
  responseTime?: number;
  message?: string;
}

async function checkDatabase(dataSource: DataSource): Promise<ComponentHealth> {
  const start = Date.now();
  try {
    await dataSource.query('SELECT 1');
    return { status: 'up', responseTime: Date.now() - start };
  } catch (error) {
    return {
      status: 'down',
      responseTime: Date.now() - start,
      message: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

async function checkRedis(redis: Redis): Promise<ComponentHealth> {
  const start = Date.now();
  try {
    await redis.ping();
    return { status: 'up', responseTime: Date.now() - start };
  } catch (error) {
    return {
      status: 'down',
      responseTime: Date.now() - start,
      message: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

// Liveness: 프로세스가 살아있는지만 확인
export function livenessHandler(req: Request, res: Response): void {
  res.status(200).json({ status: 'alive' });
}

// Readiness: 외부 의존성 포함 전체 상태 확인
export async function readinessHandler(
  req: Request,
  res: Response,
  deps: { dataSource: DataSource; redis: Redis },
): Promise<void> {
  const checks: Record<string, ComponentHealth> = {};

  const [dbHealth, redisHealth] = await Promise.allSettled([
    checkDatabase(deps.dataSource),
    checkRedis(deps.redis),
  ]);

  checks.database = dbHealth.status === 'fulfilled'
    ? dbHealth.value
    : { status: 'down', message: 'Health check failed' };

  checks.redis = redisHealth.status === 'fulfilled'
    ? redisHealth.value
    : { status: 'down', message: 'Health check failed' };

  const isHealthy = Object.values(checks).every((c) => c.status === 'up');

  const result: HealthCheckResult = {
    status: isHealthy ? 'healthy' : 'unhealthy',
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION ?? 'unknown',
    uptime: process.uptime(),
    checks,
  };

  res.status(isHealthy ? 200 : 503).json(result);
}
```

### Pattern 6: Sentry 에러 트래킹 연동

```typescript
import * as Sentry from '@sentry/node';
import type { Request } from 'express';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: process.env.APP_VERSION,

  // 에러 샘플링: 프로덕션에서 100%
  sampleRate: 1.0,

  // 성능 트레이싱 샘플링: 10%
  tracesSampleRate: 0.1,

  // 민감 데이터 제거
  beforeSend(event) {
    if (event.request?.headers) {
      delete event.request.headers.authorization;
      delete event.request.headers.cookie;
    }
    if (event.request?.data) {
      event.request.data = maskSensitiveData(event.request.data);
    }
    return event;
  },

  // 무시할 에러 타입
  ignoreErrors: [
    'AbortError',
    'Request aborted',
    /^Network request failed$/,
  ],
});

// Express 에러 핸들러에서 Sentry 전송
export function errorHandler(
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  // Sentry에 컨텍스트와 함께 전송
  Sentry.withScope((scope) => {
    scope.setTag('path', req.path);
    scope.setTag('method', req.method);
    scope.setUser({ id: req.user?.id });
    scope.setContext('request', {
      query: req.query,
      params: req.params,
      traceId: getTraceId(),
    });
    Sentry.captureException(error);
  });

  // 클라이언트 응답
  const statusCode = error instanceof AppError ? error.statusCode : 500;
  res.status(statusCode).json({
    error: {
      message: statusCode === 500 ? 'Internal Server Error' : error.message,
      traceId: getTraceId(),
    },
  });
}
```

---

## Anti-Patterns (NEVER)

### Anti-Pattern 1: console.log를 프로덕션에서 사용

```typescript
// NEVER - 비구조화, 레벨 없음, 추적 불가
console.log('User logged in');
console.log('Error:', error);
console.log('Request body:', JSON.stringify(req.body));

// MUST - 구조화된 로거 사용
logger.info('User logged in', {
  userId: user.id,
  traceId: getTraceId(),
  loginMethod: 'email',
});

logger.error('Payment processing failed', {
  error: error.message,
  stack: error.stack,
  orderId: order.id,
  traceId: getTraceId(),
});
```

### Anti-Pattern 2: 민감 데이터를 로그에 기록

```typescript
// NEVER - 비밀번호, 토큰이 로그에 노출
logger.info('Login attempt', {
  email: user.email,
  password: user.password,      // 절대 금지!
  token: session.accessToken,   // 절대 금지!
});

logger.debug('API response', {
  body: response.data,  // 카드번호, 개인정보 포함 가능
});

// MUST - 민감 정보 제거 또는 마스킹
logger.info('Login attempt', {
  email: maskEmail(user.email),  // k**@example.com
  hasPassword: Boolean(user.password),
});

logger.debug('API response', {
  body: maskSensitiveData(response.data),
  statusCode: response.status,
});
```

### Anti-Pattern 3: 로그 레벨을 잘못 사용

```typescript
// NEVER - 정상 흐름인데 error 레벨 사용
logger.error('User not found'); // 404는 에러가 아니라 정상 분기

// NEVER - 심각한 에러인데 info 레벨 사용
logger.info('Database connection failed', { error }); // 즉시 대응 필요!

// NEVER - 과도한 debug 로그를 프로덕션에서 활성화
logger.debug('Processing item', { item }); // 수백만 건이면 디스크 부족

// MUST - 적절한 레벨 사용
logger.info('User not found, returning 404', { userId }); // 정상 흐름
logger.error('Database connection failed', {              // 긴급 대응
  error: error.message,
  host: dbConfig.host,
  retryCount: 3,
});
```

### Anti-Pattern 4: 추적 ID 없는 로그

```typescript
// NEVER - traceId 없이 로그만 남김
logger.info('Order created');
logger.info('Payment processed');
logger.error('Notification failed');
// → 이 세 로그가 같은 요청인지 추적 불가

// MUST - 모든 로그에 traceId 포함
const traceId = getTraceId();
logger.info('Order created', { traceId, orderId: 'ord-123' });
logger.info('Payment processed', { traceId, orderId: 'ord-123', amount: 50000 });
logger.error('Notification failed', { traceId, orderId: 'ord-123', channel: 'email' });
// → traceId로 전체 요청 흐름 추적 가능
```

### Anti-Pattern 5: 알림 없는 모니터링

```typescript
// NEVER - 메트릭만 수집하고 알림 없음
const errorRate = new promClient.Counter({
  name: 'http_errors_total',
  help: 'Total HTTP errors',
});
// 에러가 폭증해도 아무도 모름

// NEVER - 너무 민감한 알림 (알림 피로 유발)
// alert: CPU > 50% for 1 minute → 하루에 수십 건 알림

// MUST - 증상 기반 알림 + Runbook
// alerting rule (Prometheus):
// alert: HighErrorRate
//   expr: rate(http_errors_total[5m]) / rate(http_requests_total[5m]) > 0.01
//   for: 5m
//   labels:
//     severity: critical
//   annotations:
//     summary: "에러율 1% 초과"
//     runbook: "https://wiki.example.com/runbooks/high-error-rate"
```

### Anti-Pattern 6: 헬스 체크에서 항상 200 반환

```typescript
// NEVER - DB가 죽어도 200 반환
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' }); // DB 다운이어도 ok!
});

// MUST - 실제 의존성 상태를 확인
app.get('/health/ready', async (req, res) => {
  const dbHealthy = await checkDatabase();
  const redisHealthy = await checkRedis();

  const isReady = dbHealthy && redisHealthy;
  res.status(isReady ? 200 : 503).json({
    status: isReady ? 'ready' : 'not_ready',
    checks: { database: dbHealthy, redis: redisHealthy },
  });
});
```

---

## Checklist

로깅/모니터링 구현 및 리뷰 시 아래 항목을 확인한다:

- [ ] 모든 로그가 JSON 형식으로 출력되며 `timestamp`, `level`, `message`, `traceId`가 포함되는가?
- [ ] 로그 레벨이 올바르게 사용되고 있는가? (`error`는 실제 에러에만 사용)
- [ ] 비밀번호, 토큰, 카드번호 등 민감 데이터가 로그에 노출되지 않는가?
- [ ] 모든 요청에 Correlation ID(traceId)가 부여되고 전파되는가?
- [ ] 핵심 API에 RED 메트릭(Rate, Errors, Duration)이 수집되고 있는가?
- [ ] 에러율, 응답시간 등 핵심 지표에 대한 알림이 설정되어 있는가?
- [ ] 헬스 체크 엔드포인트가 외부 의존성 상태를 정확히 반영하는가?
- [ ] Sentry 등 에러 트래킹 서비스가 프로덕션에 연동되어 있는가?
