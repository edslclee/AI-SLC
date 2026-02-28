# ch04 — 데이터베이스

> 키워드: `SQL`, `ORM`, `migration`, `index`, `transaction`

---

## Rules (MUST)

### R1. 마이그레이션으로만 스키마를 변경한다
데이터베이스 스키마 변경은 반드시 마이그레이션 파일을 통해 수행한다. 수동 SQL 실행으로 스키마를 변경하지 않는다. 모든 마이그레이션은 up/down(롤백)을 모두 구현한다.

### R2. 인덱스 전략을 수립한다
WHERE, JOIN, ORDER BY 절에 자주 사용되는 컬럼에 인덱스를 생성한다. 복합 인덱스는 카디널리티가 높은 컬럼을 앞에 배치한다. 불필요한 인덱스는 쓰기 성능을 저하시키므로 주기적으로 사용량을 점검한다.

### R3. N+1 쿼리를 반드시 방지한다
관계 데이터를 조회할 때 루프 안에서 쿼리를 실행하지 않는다. Eager Loading(`include`, `join`), 배치 로딩, DataLoader 패턴을 사용한다.

### R4. 트랜잭션을 적절히 사용한다
여러 테이블에 걸친 변경이나 데이터 일관성이 필요한 작업은 반드시 트랜잭션으로 감싼다. 트랜잭션 범위는 최소화하고, 트랜잭션 내에서 외부 API 호출을 하지 않는다.

### R5. 커넥션 풀을 관리한다
데이터베이스 커넥션 풀 크기를 환경에 맞게 설정한다. 커넥션 누수를 방지하기 위해 반드시 사용 후 반환(release)하거나 ORM의 자동 관리를 사용한다.

### R6. 쿼리 성능을 최적화한다
`SELECT *`를 사용하지 않고, 필요한 컬럼만 선택한다. 대량 데이터 처리 시 배치 처리 또는 스트리밍을 사용한다. 느린 쿼리를 모니터링하고 `EXPLAIN ANALYZE`로 실행 계획을 검토한다.

### R7. 스키마 설계 원칙을 따른다
모든 테이블에 `id`(Primary Key), `created_at`, `updated_at` 컬럼을 포함한다. 외래 키 제약 조건을 설정하여 데이터 무결성을 보장한다. 정규화 수준은 성능 요구사항에 따라 결정한다.

### R8. Soft Delete를 기본으로 사용한다
삭제 시 물리적 삭제(Hard Delete) 대신 `deleted_at` 타임스탬프를 사용한다. 모든 조회 쿼리에 soft delete 필터를 기본 적용한다. 규정(GDPR 등)이 요구하는 경우에만 물리적 삭제를 수행한다.

### R9. 백업 전략을 수립한다
일일 자동 백업을 설정한다. 백업 복원 테스트를 정기적으로 수행한다. Point-in-Time Recovery(PITR)가 가능하도록 WAL 또는 binlog를 보관한다.

### R10. ORM 사용 시 생성되는 쿼리를 이해한다
ORM이 생성하는 실제 SQL 쿼리를 반드시 확인한다. 개발 환경에서 쿼리 로깅을 활성화한다. 복잡한 쿼리는 ORM 대신 Raw Query를 사용하되, 반드시 파라미터화한다.

---

## Patterns (권장 패턴)

### 패턴 1: 마이그레이션 관리 (Prisma)

```typescript
// prisma/migrations/20260228_add_user_profile/migration.sql
// Prisma가 자동 생성하는 마이그레이션

// schema.prisma에서 모델 정의
// model User {
//   id         String    @id @default(cuid())
//   email      String    @unique
//   name       String
//   profile    Profile?
//   posts      Post[]
//   createdAt  DateTime  @default(now()) @map("created_at")
//   updatedAt  DateTime  @updatedAt @map("updated_at")
//   deletedAt  DateTime? @map("deleted_at")
//
//   @@map("users")
//   @@index([email])
//   @@index([deletedAt])
// }

// 마이그레이션 실행
// npx prisma migrate dev --name add_user_profile

// 프로덕션 배포
// npx prisma migrate deploy

// 마이그레이션 상태 확인
// npx prisma migrate status
```

### 패턴 2: N+1 쿼리 방지

```typescript
// BAD: N+1 쿼리 발생
async function getUsersWithPosts_BAD(): Promise<UserWithPosts[]> {
  const users = await prisma.user.findMany(); // 쿼리 1회
  for (const user of users) {
    user.posts = await prisma.post.findMany({  // 유저 수 N만큼 추가 쿼리
      where: { authorId: user.id },
    });
  }
  return users;
}

// GOOD: Eager Loading으로 1~2회 쿼리
async function getUsersWithPosts(): Promise<UserWithPosts[]> {
  return prisma.user.findMany({
    include: {
      posts: {
        where: { deletedAt: null },
        orderBy: { createdAt: 'desc' },
        take: 10, // 최신 10개만
      },
    },
    where: { deletedAt: null },
  });
}

// GOOD: DataLoader 패턴 (GraphQL 등)
import DataLoader from 'dataloader';

const postLoader = new DataLoader<string, Post[]>(async (userIds) => {
  const posts = await prisma.post.findMany({
    where: { authorId: { in: [...userIds] }, deletedAt: null },
  });

  const postsByUser = new Map<string, Post[]>();
  for (const post of posts) {
    const existing = postsByUser.get(post.authorId) ?? [];
    existing.push(post);
    postsByUser.set(post.authorId, existing);
  }

  return userIds.map((id) => postsByUser.get(id) ?? []);
});
```

### 패턴 3: 트랜잭션 처리

```typescript
// 올바른 트랜잭션 사용
async function transferCredits(
  fromUserId: string,
  toUserId: string,
  amount: number
): Promise<void> {
  await prisma.$transaction(async (tx) => {
    // 잔액 확인 (FOR UPDATE로 행 잠금)
    const fromUser = await tx.$queryRaw<[{ credits: number }]>`
      SELECT credits FROM users WHERE id = ${fromUserId} FOR UPDATE
    `;

    if (!fromUser[0] || fromUser[0].credits < amount) {
      throw new ValidationError('잔액이 부족합니다', {
        credits: `현재 잔액: ${fromUser[0]?.credits ?? 0}, 필요: ${amount}`,
      });
    }

    // 차감 및 증가
    await tx.user.update({
      where: { id: fromUserId },
      data: { credits: { decrement: amount } },
    });

    await tx.user.update({
      where: { id: toUserId },
      data: { credits: { increment: amount } },
    });

    // 이력 기록
    await tx.creditTransaction.create({
      data: {
        fromUserId,
        toUserId,
        amount,
        type: 'TRANSFER',
      },
    });
  });

  // 외부 API 호출은 트랜잭션 밖에서
  await notificationService.sendTransferNotification(fromUserId, toUserId, amount);
}
```

### 패턴 4: Soft Delete 구현

```typescript
// Prisma 미들웨어로 글로벌 Soft Delete 적용
prisma.$use(async (params, next) => {
  // Delete를 Soft Delete로 변환
  if (params.action === 'delete') {
    params.action = 'update';
    params.args.data = { deletedAt: new Date() };
  }

  if (params.action === 'deleteMany') {
    params.action = 'updateMany';
    if (params.args.data !== undefined) {
      params.args.data.deletedAt = new Date();
    } else {
      params.args.data = { deletedAt: new Date() };
    }
  }

  // 조회 시 삭제된 레코드 자동 필터링
  if (params.action === 'findUnique' || params.action === 'findFirst') {
    params.action = 'findFirst';
    params.args.where = { ...params.args.where, deletedAt: null };
  }

  if (params.action === 'findMany') {
    if (params.args.where) {
      if (params.args.where.deletedAt === undefined) {
        params.args.where.deletedAt = null;
      }
    } else {
      params.args.where = { deletedAt: null };
    }
  }

  return next(params);
});

// GDPR 등 규정에 의한 물리적 삭제가 필요한 경우
async function hardDeleteUser(userId: string): Promise<void> {
  await prisma.$executeRaw`DELETE FROM users WHERE id = ${userId}`;
  logger.info('GDPR 요청에 의한 사용자 물리적 삭제 완료', { userId });
}
```

### 패턴 5: 쿼리 성능 최적화

```typescript
// 필요한 컬럼만 선택
const users = await prisma.user.findMany({
  select: {
    id: true,
    email: true,
    name: true,
    // password, internalNotes 등 불필요한 컬럼 제외
  },
  where: { deletedAt: null },
});

// 대량 데이터 배치 처리
async function processAllUsers(batchSize = 1000): Promise<void> {
  let cursor: string | undefined;

  while (true) {
    const users = await prisma.user.findMany({
      take: batchSize,
      ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
      orderBy: { id: 'asc' },
      where: { deletedAt: null },
    });

    if (users.length === 0) break;

    await Promise.all(
      users.map((user) => processUser(user))
    );

    cursor = users[users.length - 1].id;
    logger.info(`배치 처리 완료: ${users.length}건, cursor: ${cursor}`);
  }
}

// 개발 환경에서 쿼리 로깅 활성화
const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development'
    ? ['query', 'info', 'warn', 'error']
    : ['error'],
});
```

---

## Anti-Patterns (NEVER)

### 안티패턴 1: 수동 스키마 변경

```typescript
// NEVER: 운영 DB에 직접 SQL 실행
// psql> ALTER TABLE users ADD COLUMN phone VARCHAR(20);
// 마이그레이션 히스토리에 기록되지 않아 환경 간 불일치 발생

// NEVER: 마이그레이션 파일을 수동 수정 후 재실행
// 이미 적용된 마이그레이션을 수정하면 다른 환경에서 실패
```

### 안티패턴 2: 루프 안에서 쿼리 실행 (N+1)

```typescript
// NEVER: 유저 100명이면 101개의 쿼리 실행
const users = await prisma.user.findMany();
const result = [];
for (const user of users) {
  const postCount = await prisma.post.count({
    where: { authorId: user.id },
  });
  result.push({ ...user, postCount });
}
```

### 안티패턴 3: 트랜잭션 내 외부 호출

```typescript
// NEVER: 트랜잭션 내에서 외부 API 호출
await prisma.$transaction(async (tx) => {
  await tx.order.update({ where: { id: orderId }, data: { status: 'paid' } });

  // 외부 API 호출이 5초 걸리면 트랜잭션 락도 5초 유지
  // 네트워크 실패 시 트랜잭션 롤백되지만 외부 결제는 이미 처리됨
  await paymentGateway.charge(amount); // 절대 금지!

  await tx.payment.create({ data: { orderId, amount } });
});
```

### 안티패턴 4: SELECT * 사용

```typescript
// NEVER: 불필요한 데이터 전송 및 민감 정보 노출 위험
const users = await prisma.$queryRaw`SELECT * FROM users`;
// password_hash, internal_notes, admin_flags 등 모두 포함

// NEVER: ORM에서도 전체 필드 조회 시 주의
const users = await prisma.user.findMany(); // 모든 컬럼 포함
res.json(users); // password_hash 등 민감 정보 응답에 포함 위험
```

### 안티패턴 5: 인덱스 없는 대용량 테이블 조회

```typescript
// NEVER: 인덱스 없이 대용량 테이블에서 필터링
// users 테이블에 100만 건, status 컬럼에 인덱스 없음
const active = await prisma.user.findMany({
  where: { status: 'active' }, // Full Table Scan 발생
  orderBy: { name: 'asc' },   // filesort 발생
});
```

### 안티패턴 6: 커넥션 풀 미설정

```typescript
// NEVER: 매 요청마다 새 커넥션 생성
app.get('/users', async (req, res) => {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();    // 매번 새 커넥션
  const result = await client.query('SELECT * FROM users');
  await client.end();        // 매번 해제 — 커넥션 풀이 아님
  res.json(result.rows);
});
```

---

## Checklist

코드 리뷰 또는 PR 작성 시 아래 항목을 확인합니다:

- [ ] 스키마 변경이 마이그레이션 파일로 관리되고 있는가? (up/down 모두 구현)
- [ ] 자주 조회되는 컬럼에 적절한 인덱스가 있는가?
- [ ] N+1 쿼리가 발생하지 않는가? (Eager Loading 또는 DataLoader 사용)
- [ ] 여러 테이블 변경 시 트랜잭션으로 감싸져 있는가?
- [ ] 트랜잭션 내에서 외부 API 호출이 없는가?
- [ ] `SELECT *` 대신 필요한 컬럼만 선택하고 있는가?
- [ ] Soft Delete가 적용되고, 조회 시 삭제된 레코드가 필터링되는가?
- [ ] 개발 환경에서 쿼리 로깅이 활성화되어 있는가?
