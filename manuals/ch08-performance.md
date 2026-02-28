# Chapter 08: 성능

> 성능은 사용자 경험과 운영 비용에 직접적으로 영향을 미친다. N+1 쿼리 방지, 캐싱 전략, 비동기 처리, 번들 최적화를 체계적으로 적용하여 응답 시간과 처리량을 최적화한다.

---

## Rules (MUST)

### Rule 1: N+1 쿼리를 반드시 방지한다

- 연관 데이터 조회 시 **Eager Loading** 또는 **DataLoader** 패턴을 사용한다
- ORM 사용 시 **생성되는 SQL 쿼리 수**를 항상 확인한다
- API 엔드포인트당 **쿼리 수 상한선**을 모니터링한다 (권장: 10개 이내)
- 개발 환경에서 **쿼리 로깅**을 활성화하여 N+1을 조기 탐지한다

### Rule 2: 캐싱 전략을 계층별로 설계한다

| 계층 | 도구 | 용도 | TTL 기준 |
|------|------|------|----------|
| L1 - 인메모리 | Map, LRU Cache | 동일 프로세스 내 반복 조회 | 초~분 단위 |
| L2 - 분산 캐시 | Redis, Memcached | 프로세스 간 공유 데이터 | 분~시간 단위 |
| L3 - CDN | CloudFront, Cloudflare | 정적 자산, 공개 API 응답 | 시간~일 단위 |
| L4 - 브라우저 | Cache-Control 헤더 | 클라이언트 측 자산 | 요청 특성에 따라 |

- Cache-Aside 패턴을 기본으로 사용한다
- TTL을 반드시 설정한다 (무기한 캐시 금지)
- 캐시 무효화(Invalidation) 전략을 반드시 함께 설계한다

### Rule 3: 대량 데이터 조회 시 반드시 페이지네이션을 적용한다

- 목록 API에는 **커서 기반 페이지네이션**을 권장한다
- 오프셋 기반은 **데이터가 적거나 정렬이 고정**인 경우에만 사용한다
- 페이지 크기에 **상한선**을 설정한다 (기본 20, 최대 100)
- `SELECT COUNT(*)`는 별도 캐싱하거나 근사값을 사용한다

### Rule 4: 데이터베이스 쿼리를 최적화한다

- 자주 조회되는 컬럼에 **인덱스**를 생성한다
- `SELECT *`를 사용하지 않고 **필요한 컬럼만** 조회한다
- 복합 조건에는 **복합 인덱스**를 활용한다
- `EXPLAIN ANALYZE`로 쿼리 실행 계획을 **정기적으로** 검토한다
- 대량 쓰기 작업은 **Batch Insert/Update**를 사용한다

### Rule 5: Lazy Loading을 적용하여 초기 로딩을 최소화한다

- 화면에 보이지 않는 컴포넌트는 **동적 import**로 분리한다
- 이미지는 **Lazy Loading** (`loading="lazy"`)을 적용한다
- 무거운 라이브러리는 **필요 시점에** 로딩한다
- 코드 스플리팅으로 **번들 크기**를 줄인다

### Rule 6: 번들 크기를 최적화한다

- **Tree Shaking**이 작동하도록 ES Module을 사용한다
- 번들 분석 도구(webpack-bundle-analyzer 등)로 **정기적으로** 크기를 확인한다
- 대형 라이브러리는 **필요한 함수만** import한다
- 번들 크기 예산(budget)을 설정하고 **CI에서 검증**한다

### Rule 7: 메모리 누수를 방지한다

- 이벤트 리스너, 타이머, 구독은 반드시 **정리(cleanup)** 한다
- 클로저에서 **불필요한 참조**를 유지하지 않는다
- 대용량 데이터를 **전역 변수**에 저장하지 않는다
- 주기적으로 **힙 스냅샷**을 분석한다

### Rule 8: 커넥션 풀링을 적용한다

- 데이터베이스 커넥션은 **풀링**으로 관리한다
- HTTP 클라이언트는 **Keep-Alive**를 활성화한다
- Redis 등 외부 서비스도 **커넥션 풀**을 사용한다
- 풀 크기는 서버 리소스와 부하에 맞게 **튜닝**한다

### Rule 9: 독립적인 작업은 병렬 처리한다

- 서로 의존하지 않는 I/O 작업은 `Promise.all` 또는 `Promise.allSettled`로 **병렬 실행**한다
- CPU 집약적 작업은 **Worker Thread**로 오프로드한다
- 대량 작업은 **큐(Queue)** 기반 비동기 처리를 사용한다
- 병렬 처리 시 **동시성 제한(concurrency limit)** 을 설정한다

### Rule 10: 프로파일링과 벤치마크로 성능을 검증한다

- 성능 최적화는 **측정 후** 진행한다 (추측 기반 최적화 금지)
- 핵심 API의 응답 시간 **목표치(SLA)** 를 정의한다
- **부하 테스트**를 정기적으로 실행한다
- 성능 회귀를 **CI에서 자동 탐지**한다

---

## Patterns (권장 패턴)

### Pattern 1: N+1 방지 - DataLoader 패턴

```typescript
import DataLoader from 'dataloader';

// DataLoader를 사용하여 N+1 방지
// 개별 요청을 모아서 batch로 처리한다
function createUserLoader(): DataLoader<string, User> {
  return new DataLoader(async (userIds: readonly string[]) => {
    const users = await userRepository.find({
      where: { id: In([...userIds]) },
    });

    // userIds 순서에 맞게 정렬하여 반환
    const userMap = new Map(users.map((u) => [u.id, u]));
    return userIds.map((id) => userMap.get(id) ?? new Error(`User ${id} not found`));
  });
}

// 요청별 DataLoader 인스턴스 생성 (캐시 격리)
function createContext(): AppContext {
  return {
    loaders: {
      user: createUserLoader(),
      post: createPostLoader(),
    },
  };
}

// 사용: 개별 호출이지만 내부적으로 batch 처리됨
async function resolvePostAuthor(post: Post, ctx: AppContext): Promise<User> {
  return ctx.loaders.user.load(post.authorId);
}
```

### Pattern 2: 다계층 캐싱 (Cache-Aside)

```typescript
import { Redis } from 'ioredis';
import { LRUCache } from 'lru-cache';

interface CacheConfig {
  l1TtlMs: number;
  l2TtlSeconds: number;
}

class TieredCache<T> {
  private l1: LRUCache<string, T>;
  private l2: Redis;

  constructor(
    redis: Redis,
    private config: CacheConfig,
  ) {
    this.l1 = new LRUCache<string, T>({
      max: 1000,
      ttl: config.l1TtlMs,
    });
    this.l2 = redis;
  }

  async get(key: string, fetcher: () => Promise<T>): Promise<T> {
    // L1 (인메모리) 확인
    const l1Result = this.l1.get(key);
    if (l1Result !== undefined) {
      return l1Result;
    }

    // L2 (Redis) 확인
    const l2Result = await this.l2.get(key);
    if (l2Result !== null) {
      const parsed = JSON.parse(l2Result) as T;
      this.l1.set(key, parsed);
      return parsed;
    }

    // 캐시 미스: 원본 데이터 조회
    const freshData = await fetcher();

    // 양쪽 캐시에 저장
    this.l1.set(key, freshData);
    await this.l2.setex(key, this.config.l2TtlSeconds, JSON.stringify(freshData));

    return freshData;
  }

  async invalidate(key: string): Promise<void> {
    this.l1.delete(key);
    await this.l2.del(key);
  }

  async invalidatePattern(pattern: string): Promise<void> {
    // L1 전체 초기화 (패턴 매칭 미지원)
    this.l1.clear();

    // L2 패턴 매칭 삭제
    const keys = await this.l2.keys(pattern);
    if (keys.length > 0) {
      await this.l2.del(...keys);
    }
  }
}

// 사용 예시
const userCache = new TieredCache<User>(redis, {
  l1TtlMs: 30_000,       // 30초
  l2TtlSeconds: 300,     // 5분
});

async function getUserById(id: string): Promise<User> {
  return userCache.get(`user:${id}`, () => userRepository.findOneOrFail(id));
}
```

### Pattern 3: 커서 기반 페이지네이션

```typescript
interface CursorPaginationParams {
  cursor?: string;  // base64 인코딩된 커서
  limit: number;
}

interface CursorPaginatedResult<T> {
  items: T[];
  nextCursor: string | null;
  hasMore: boolean;
}

async function getUsers(
  params: CursorPaginationParams,
): Promise<CursorPaginatedResult<User>> {
  const { cursor, limit } = params;
  const safeLimit = Math.min(limit, 100); // 최대 100개 제한

  const queryBuilder = userRepository
    .createQueryBuilder('user')
    .orderBy('user.createdAt', 'DESC')
    .addOrderBy('user.id', 'DESC')
    .take(safeLimit + 1); // +1로 hasMore 판단

  if (cursor) {
    const { createdAt, id } = decodeCursor(cursor);
    queryBuilder.where(
      '(user.createdAt, user.id) < (:createdAt, :id)',
      { createdAt, id },
    );
  }

  const items = await queryBuilder.getMany();
  const hasMore = items.length > safeLimit;

  if (hasMore) {
    items.pop(); // 초과분 제거
  }

  const lastItem = items[items.length - 1];
  const nextCursor = hasMore && lastItem
    ? encodeCursor({ createdAt: lastItem.createdAt, id: lastItem.id })
    : null;

  return { items, nextCursor, hasMore };
}

function encodeCursor(data: { createdAt: Date; id: string }): string {
  return Buffer.from(JSON.stringify(data)).toString('base64url');
}

function decodeCursor(cursor: string): { createdAt: Date; id: string } {
  return JSON.parse(Buffer.from(cursor, 'base64url').toString('utf-8'));
}
```

### Pattern 4: 병렬 처리와 동시성 제한

```typescript
// 독립적인 작업은 Promise.all로 병렬 실행
async function getUserDashboard(userId: string): Promise<Dashboard> {
  const [user, orders, notifications, recommendations] = await Promise.all([
    userService.findById(userId),
    orderService.getRecentOrders(userId),
    notificationService.getUnread(userId),
    recommendationService.getForUser(userId),
  ]);

  return { user, orders, notifications, recommendations };
}

// 대량 작업은 동시성 제한 적용
async function processInBatches<T, R>(
  items: T[],
  processor: (item: T) => Promise<R>,
  concurrency: number = 5,
): Promise<R[]> {
  const results: R[] = [];

  for (let i = 0; i < items.length; i += concurrency) {
    const batch = items.slice(i, i + concurrency);
    const batchResults = await Promise.allSettled(
      batch.map((item) => processor(item)),
    );

    for (const result of batchResults) {
      if (result.status === 'fulfilled') {
        results.push(result.value);
      } else {
        logger.error('Batch processing failed', { error: result.reason });
      }
    }
  }

  return results;
}

// 사용 예시: 1000개의 이메일을 5개씩 동시 발송
await processInBatches(emailRecipients, sendEmail, 5);
```

### Pattern 5: Lazy Loading과 코드 스플리팅

```typescript
// React - 동적 import로 코드 스플리팅
import { lazy, Suspense } from 'react';

// 무거운 컴포넌트를 lazy loading
const AdminDashboard = lazy(() => import('./features/admin/AdminDashboard'));
const ReportViewer = lazy(() => import('./features/reports/ReportViewer'));
const ChartLibrary = lazy(() =>
  import('./components/ChartLibrary').then((mod) => ({ default: mod.ChartLibrary })),
);

function App(): JSX.Element {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Routes>
        <Route path="/admin" element={<AdminDashboard />} />
        <Route path="/reports" element={<ReportViewer />} />
      </Routes>
    </Suspense>
  );
}

// Node.js - 무거운 라이브러리를 필요 시점에 로딩
async function generatePdf(data: ReportData): Promise<Buffer> {
  // puppeteer는 용량이 크므로 PDF 생성 시에만 로딩
  const puppeteer = await import('puppeteer');
  const browser = await puppeteer.launch();
  // ...
}
```

### Pattern 6: 커넥션 풀링 설정

```typescript
// TypeORM 커넥션 풀 설정
import { DataSource } from 'typeorm';

const dataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  database: process.env.DB_NAME,
  username: process.env.DB_USER,
  password: process.env.DB_PASSWORD,

  // 커넥션 풀 설정
  extra: {
    max: 20,                   // 최대 커넥션 수
    min: 5,                    // 최소 유휴 커넥션 수
    idleTimeoutMillis: 30_000, // 유휴 커넥션 타임아웃
    connectionTimeoutMillis: 5_000, // 커넥션 획득 타임아웃
  },

  logging: process.env.NODE_ENV === 'development' ? ['query', 'error'] : ['error'],
});

// Redis 커넥션 풀
import { Redis } from 'ioredis';

const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: Number(process.env.REDIS_PORT),
  maxRetriesPerRequest: 3,
  retryStrategy(times: number): number | null {
    if (times > 3) return null;
    return Math.min(times * 200, 2000);
  },
  lazyConnect: true,
});
```

---

## Anti-Patterns (NEVER)

### Anti-Pattern 1: N+1 쿼리

```typescript
// NEVER - 루프 안에서 개별 쿼리 실행 (N+1 문제)
async function getPostsWithAuthors(posts: Post[]): Promise<PostWithAuthor[]> {
  const result: PostWithAuthor[] = [];

  for (const post of posts) {
    // 게시물 100개 → 쿼리 100회 추가 실행!
    const author = await userRepository.findOne({ where: { id: post.authorId } });
    result.push({ ...post, author });
  }

  return result;
}

// MUST - 한 번의 쿼리로 모든 데이터 조회
async function getPostsWithAuthors(posts: Post[]): Promise<PostWithAuthor[]> {
  const authorIds = [...new Set(posts.map((p) => p.authorId))];
  const authors = await userRepository.find({
    where: { id: In(authorIds) },
  });
  const authorMap = new Map(authors.map((a) => [a.id, a]));

  return posts.map((post) => ({
    ...post,
    author: authorMap.get(post.authorId)!,
  }));
}
```

### Anti-Pattern 2: 캐시 무효화 없는 캐싱

```typescript
// NEVER - TTL도 없고 무효화 전략도 없는 캐시
const cache = new Map<string, User>();

async function getUser(id: string): Promise<User> {
  if (cache.has(id)) {
    return cache.get(id)!; // 영원히 오래된 데이터 반환
  }
  const user = await userRepository.findOne(id);
  cache.set(id, user); // 무기한 저장
  return user;
}

// MUST - TTL과 무효화를 함께 설정
const userCache = new LRUCache<string, User>({
  max: 500,
  ttl: 60_000, // 1분 후 만료
});

async function getUser(id: string): Promise<User> {
  const cached = userCache.get(id);
  if (cached) return cached;

  const user = await userRepository.findOneOrFail(id);
  userCache.set(id, user);
  return user;
}

async function updateUser(id: string, data: UpdateUserDto): Promise<User> {
  const user = await userRepository.update(id, data);
  userCache.delete(id); // 변경 시 캐시 무효화
  return user;
}
```

### Anti-Pattern 3: 페이지네이션 없는 목록 조회

```typescript
// NEVER - 전체 데이터를 한 번에 조회
app.get('/api/users', async (req, res) => {
  const users = await userRepository.find(); // 100만 건 전체 로딩!
  res.json(users);
});

// NEVER - 위험한 OFFSET 페이지네이션 (대용량 데이터)
const users = await userRepository.find({
  skip: 999_000, // 999,000건을 스캔 후 버림
  take: 20,
});

// MUST - 커서 기반 페이지네이션
app.get('/api/users', async (req, res) => {
  const { cursor, limit = 20 } = req.query;
  const result = await getUsers({ cursor, limit: Math.min(Number(limit), 100) });
  res.json(result);
});
```

### Anti-Pattern 4: 순차적 I/O 처리

```typescript
// NEVER - 독립적인 작업을 순차 실행
async function getUserProfile(userId: string): Promise<UserProfile> {
  const user = await userService.findById(userId);         // 100ms
  const orders = await orderService.getRecent(userId);      // 150ms
  const reviews = await reviewService.getByUser(userId);    // 120ms
  const wishlist = await wishlistService.getByUser(userId); // 80ms
  // 총 450ms (순차)

  return { user, orders, reviews, wishlist };
}

// MUST - 독립 작업은 병렬 실행
async function getUserProfile(userId: string): Promise<UserProfile> {
  const [user, orders, reviews, wishlist] = await Promise.all([
    userService.findById(userId),
    orderService.getRecent(userId),
    reviewService.getByUser(userId),
    wishlistService.getByUser(userId),
  ]);
  // 총 ~150ms (가장 느린 작업 기준)

  return { user, orders, reviews, wishlist };
}
```

### Anti-Pattern 5: SELECT * 사용

```typescript
// NEVER - 불필요한 컬럼까지 전부 조회
const users = await userRepository.find();
// SELECT * FROM users → 프로필 이미지(BLOB), 개인정보 등 불필요한 데이터까지 포함

// MUST - 필요한 컬럼만 선택
const users = await userRepository.find({
  select: ['id', 'name', 'email', 'role', 'createdAt'],
});
// SELECT id, name, email, role, created_at FROM users
```

### Anti-Pattern 6: 메모리 누수 방치

```typescript
// NEVER - 이벤트 리스너 정리 없음
class WebSocketManager {
  connect(): void {
    const ws = new WebSocket(this.url);
    // 연결할 때마다 리스너가 누적됨!
    ws.on('message', this.handleMessage);
    ws.on('error', this.handleError);
  }
}

// NEVER - setInterval 정리 없음
function startPolling(): void {
  setInterval(async () => {
    await fetchLatestData();
  }, 5000);
  // 서버 종료 시에도 계속 실행됨
}

// MUST - 정리 함수 반환
function startPolling(): () => void {
  const intervalId = setInterval(async () => {
    await fetchLatestData();
  }, 5000);

  return () => clearInterval(intervalId); // cleanup 함수 반환
}

// MUST - AbortController 활용
class ApiClient {
  private controller: AbortController | null = null;

  async fetch(url: string): Promise<Response> {
    this.controller?.abort(); // 이전 요청 취소
    this.controller = new AbortController();

    return fetch(url, { signal: this.controller.signal });
  }

  destroy(): void {
    this.controller?.abort();
    this.controller = null;
  }
}
```

---

## Checklist

성능 관련 코드 작성 및 리뷰 시 아래 항목을 확인한다:

- [ ] 루프 내에서 개별 DB 쿼리를 실행하고 있지 않은가? (N+1 확인)
- [ ] 캐시에 TTL이 설정되어 있고, 데이터 변경 시 무효화 로직이 있는가?
- [ ] 목록 API에 페이지네이션이 적용되어 있는가? (최대 크기 제한 포함)
- [ ] 독립적인 I/O 작업이 `Promise.all`로 병렬 처리되고 있는가?
- [ ] `SELECT *` 대신 필요한 컬럼만 조회하고 있는가?
- [ ] 이벤트 리스너, 타이머, 구독에 대한 정리(cleanup) 코드가 있는가?
- [ ] 번들 크기를 최근에 분석했으며 예산(budget) 이내인가?
- [ ] DB 커넥션 풀 크기가 적절하게 설정되어 있는가?
