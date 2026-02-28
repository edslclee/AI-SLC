# ch05 — 테스팅

> 키워드: `test`, `mock`, `coverage`, `fixture`, `assert`

---

## Rules (MUST)

### R1. 테스트 피라미드를 준수한다
단위 테스트를 가장 많이, 통합 테스트를 적절히, E2E 테스트를 핵심 플로우에만 작성한다. 비율 가이드: 단위 70%, 통합 20%, E2E 10%.

### R2. 테스트 격리를 보장한다
각 테스트는 독립적으로 실행 가능해야 한다. 테스트 간 상태 공유를 금지한다. 데이터베이스를 사용하는 테스트는 트랜잭션 롤백 또는 테스트별 정리(cleanup)를 수행한다.

### R3. 의미 있는 어설션을 작성한다
하나의 테스트에 하나의 논리적 검증을 수행한다. `toBeTruthy()` 같은 모호한 어설션 대신, 구체적인 값이나 상태를 검증한다. 경계 조건, 에러 케이스를 반드시 포함한다.

### R4. Mock/Stub은 외부 의존성에만 사용한다
데이터베이스, 외부 API, 파일 시스템 등 외부 의존성만 모킹한다. 테스트 대상 모듈의 내부 구현을 모킹하지 않는다. 과도한 모킹은 테스트의 가치를 떨어뜨린다.

### R5. 테스트 이름은 행동을 설명한다
`describe`-`it` 구조를 사용하여 "무엇이 어떤 조건에서 어떻게 동작하는가"를 명확히 기술한다. 테스트 이름만으로 무엇을 검증하는지 파악할 수 있어야 한다.

### R6. 픽스처를 체계적으로 관리한다
테스트 데이터는 팩토리 패턴 또는 빌더 패턴으로 생성한다. 하드코딩된 매직 넘버나 문자열을 피한다. 공유 픽스처는 변경 불가능(immutable)하게 관리한다.

### R7. 커버리지 기준을 설정한다
라인 커버리지 80% 이상을 목표로 한다. 커버리지 숫자보다 핵심 비즈니스 로직의 분기 커버리지가 더 중요하다. CI에서 커버리지 감소를 차단한다.

### R8. TDD 워크플로우를 권장한다
새로운 기능 개발 시 Red-Green-Refactor 사이클을 따른다. 먼저 실패하는 테스트를 작성하고, 최소한의 코드로 통과시킨 후, 리팩토링한다.

### R9. 엣지 케이스를 반드시 테스트한다
빈 입력, null/undefined, 경계값, 대량 데이터, 동시성, 타임아웃 등 예외 상황에 대한 테스트를 포함한다. "해피 패스"만 테스트하는 것은 불충분하다.

### R10. CI에서 모든 테스트를 자동 실행한다
PR 생성 시 전체 테스트 스위트가 자동 실행된다. 테스트 실패 시 머지를 차단한다. 느린 테스트는 태깅하여 별도 파이프라인에서 실행할 수 있도록 한다.

---

## Patterns (권장 패턴)

### 패턴 1: 테스트 네이밍과 구조

```typescript
// describe-it 구조로 행동 기술
describe('UserService', () => {
  describe('createUser', () => {
    it('유효한 입력이 주어지면 새 사용자를 생성하고 반환한다', async () => {
      const input = createUserInput({ email: 'test@example.com' });

      const result = await userService.createUser(input);

      expect(result.id).toBeDefined();
      expect(result.email).toBe('test@example.com');
      expect(result.createdAt).toBeInstanceOf(Date);
    });

    it('이미 존재하는 이메일이면 ConflictError를 던진다', async () => {
      const input = createUserInput({ email: 'existing@example.com' });
      await userService.createUser(input); // 첫 번째 생성

      await expect(userService.createUser(input)).rejects.toThrow(ConflictError);
    });

    it('이메일 형식이 잘못되면 ValidationError를 던진다', async () => {
      const input = createUserInput({ email: 'invalid-email' });

      await expect(userService.createUser(input)).rejects.toThrow(ValidationError);
    });

    it('이름이 빈 문자열이면 ValidationError를 던진다', async () => {
      const input = createUserInput({ name: '' });

      await expect(userService.createUser(input)).rejects.toThrow(ValidationError);
    });
  });
});
```

### 패턴 2: 테스트 팩토리 (빌더 패턴)

```typescript
// test/factories/user.factory.ts
interface UserInput {
  email: string;
  name: string;
  role: 'user' | 'editor' | 'admin';
  password: string;
}

function createUserInput(overrides: Partial<UserInput> = {}): UserInput {
  return {
    email: `user-${Date.now()}@example.com`,
    name: '테스트 사용자',
    role: 'user',
    password: 'SecureP@ss1',
    ...overrides,
  };
}

// DB에 실제 레코드를 생성하는 팩토리 (통합 테스트용)
async function createTestUser(overrides: Partial<UserInput> = {}): Promise<User> {
  const input = createUserInput(overrides);
  return prisma.user.create({
    data: {
      email: input.email,
      name: input.name,
      role: input.role,
      passwordHash: await hashPassword(input.password),
    },
  });
}

// 게시글 팩토리 (관계 데이터 포함)
async function createTestPost(
  authorOverrides: Partial<UserInput> = {},
  postOverrides: Partial<{ title: string; content: string }> = {}
): Promise<{ author: User; post: Post }> {
  const author = await createTestUser(authorOverrides);
  const post = await prisma.post.create({
    data: {
      title: postOverrides.title ?? '테스트 게시글',
      content: postOverrides.content ?? '테스트 본문 내용입니다.',
      authorId: author.id,
    },
  });
  return { author, post };
}
```

### 패턴 3: 외부 의존성 모킹

```typescript
// 외부 API 모킹
import { jest } from '@jest/globals';

// 모듈 레벨 모킹
jest.mock('../services/payment.service');
const mockPaymentService = jest.mocked(paymentService);

describe('OrderService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('결제 성공 시 주문 상태를 paid로 변경한다', async () => {
    // Arrange
    const order = await createTestOrder({ status: 'pending' });
    mockPaymentService.charge.mockResolvedValueOnce({
      transactionId: 'txn_123',
      status: 'succeeded',
    });

    // Act
    const result = await orderService.processPayment(order.id);

    // Assert
    expect(result.status).toBe('paid');
    expect(mockPaymentService.charge).toHaveBeenCalledWith({
      amount: order.totalAmount,
      currency: 'KRW',
      orderId: order.id,
    });
    expect(mockPaymentService.charge).toHaveBeenCalledTimes(1);
  });

  it('결제 실패 시 주문 상태를 payment_failed로 변경하고 에러를 던진다', async () => {
    // Arrange
    const order = await createTestOrder({ status: 'pending' });
    mockPaymentService.charge.mockRejectedValueOnce(
      new ExternalServiceError('PaymentGateway', new Error('Card declined'))
    );

    // Act & Assert
    await expect(orderService.processPayment(order.id))
      .rejects.toThrow(ExternalServiceError);

    const updatedOrder = await prisma.order.findUnique({ where: { id: order.id } });
    expect(updatedOrder?.status).toBe('payment_failed');
  });
});
```

### 패턴 4: 통합 테스트 (API 레벨)

```typescript
import request from 'supertest';
import { app } from '../app';

describe('POST /api/v1/users', () => {
  // 테스트 격리: 각 테스트 전후 정리
  afterEach(async () => {
    await prisma.user.deleteMany({
      where: { email: { contains: '@test.example.com' } },
    });
  });

  it('유효한 요청이면 201과 생성된 사용자를 반환한다', async () => {
    const response = await request(app)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        email: 'new@test.example.com',
        name: '새 사용자',
        password: 'SecureP@ss1',
      });

    expect(response.status).toBe(201);
    expect(response.body).toMatchObject({
      success: true,
      data: {
        email: 'new@test.example.com',
        name: '새 사용자',
      },
    });
    expect(response.body.data.id).toBeDefined();
    // 비밀번호가 응답에 포함되지 않는지 확인
    expect(response.body.data).not.toHaveProperty('password');
    expect(response.body.data).not.toHaveProperty('passwordHash');
  });

  it('이메일이 누락되면 400과 검증 에러를 반환한다', async () => {
    const response = await request(app)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: '새 사용자',
        password: 'SecureP@ss1',
      });

    expect(response.status).toBe(400);
    expect(response.body).toMatchObject({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
      },
    });
  });

  it('인증 토큰이 없으면 401을 반환한다', async () => {
    const response = await request(app)
      .post('/api/v1/users')
      .send({
        email: 'new@test.example.com',
        name: '새 사용자',
        password: 'SecureP@ss1',
      });

    expect(response.status).toBe(401);
  });
});
```

### 패턴 5: 엣지 케이스 테스트

```typescript
describe('calculateDiscount', () => {
  // 경계값 테스트
  it('최소 주문 금액(10000원)이면 할인율 0%를 반환한다', () => {
    expect(calculateDiscount(10000)).toBe(0);
  });

  it('최소 주문 금액 미만이면 할인 대상이 아니다', () => {
    expect(calculateDiscount(9999)).toBe(0);
  });

  it('골드 등급 기준(50000원) 이상이면 5% 할인을 반환한다', () => {
    expect(calculateDiscount(50000)).toBe(0.05);
    expect(calculateDiscount(50001)).toBe(0.05);
  });

  // 엣지 케이스
  it('0원이면 할인율 0%를 반환한다', () => {
    expect(calculateDiscount(0)).toBe(0);
  });

  it('음수 금액이면 ValidationError를 던진다', () => {
    expect(() => calculateDiscount(-1)).toThrow(ValidationError);
  });

  it('NaN이면 ValidationError를 던진다', () => {
    expect(() => calculateDiscount(NaN)).toThrow(ValidationError);
  });

  it('Infinity이면 ValidationError를 던진다', () => {
    expect(() => calculateDiscount(Infinity)).toThrow(ValidationError);
  });

  // 정밀도 테스트
  it('소수점 금액에 대해 올바르게 계산한다', () => {
    expect(calculateDiscount(50000.5)).toBe(0.05);
  });
});
```

---

## Anti-Patterns (NEVER)

### 안티패턴 1: 테스트 간 상태 공유

```typescript
// NEVER: 테스트 순서에 의존하는 공유 상태
let createdUserId: string;

it('사용자를 생성한다', async () => {
  const user = await userService.createUser(input);
  createdUserId = user.id; // 다음 테스트에서 사용하려고 저장
});

it('생성된 사용자를 조회한다', async () => {
  const user = await userService.getUser(createdUserId); // 위 테스트가 실패하면 이것도 실패
  expect(user).toBeDefined();
});
// 테스트 실행 순서가 바뀌거나 첫 테스트가 실패하면 전부 무너짐
```

### 안티패턴 2: 내부 구현 모킹

```typescript
// NEVER: 테스트 대상의 내부 함수를 모킹
describe('UserService.createUser', () => {
  it('사용자를 생성한다', async () => {
    // 내부 private 메서드를 모킹하면 리팩토링 시 테스트가 깨짐
    jest.spyOn(userService as any, 'validateEmail').mockReturnValue(true);
    jest.spyOn(userService as any, 'hashPassword').mockResolvedValue('hashed');
    jest.spyOn(userService as any, 'sendWelcomeEmail').mockResolvedValue(undefined);

    const result = await userService.createUser(input);

    // 이 테스트는 내부 구현을 전부 모킹했으므로 실질적으로 아무것도 검증하지 않음
    expect(result).toBeDefined();
  });
});
```

### 안티패턴 3: 모호한 어설션

```typescript
// NEVER: 무엇이 참인지 명확하지 않은 어설션
it('사용자를 반환한다', async () => {
  const result = await userService.getUser(userId);
  expect(result).toBeTruthy();     // null이 아닌 건 맞지만, 올바른 데이터인지 알 수 없음
  expect(result).toBeDefined();    // 마찬가지로 불충분
  expect(result).not.toBeNull();   // 어떤 사용자든 반환하면 통과
});

// NEVER: 어설션이 없는 테스트
it('에러 없이 실행된다', async () => {
  await userService.createUser(input);
  // expect가 없으면 테스트가 항상 통과 - 의미 없음
});
```

### 안티패턴 4: 하드코딩된 테스트 데이터

```typescript
// NEVER: 매직 넘버, 하드코딩된 ID에 의존
it('사용자를 조회한다', async () => {
  const user = await userService.getUser('507f1f77bcf86cd799439011'); // 이 ID가 항상 존재?
  expect(user.name).toBe('홍길동'); // 이 값이 변경되면 테스트 실패
  expect(user.age).toBe(30);        // 매직 넘버
});
```

### 안티패턴 5: 느리고 불안정한 테스트

```typescript
// NEVER: 실제 시간 대기
it('캐시가 만료된 후 재조회한다', async () => {
  await cache.set('key', 'value', { ttl: 5 });
  await new Promise((resolve) => setTimeout(resolve, 6000)); // 6초 대기!
  expect(await cache.get('key')).toBeNull();
});

// NEVER: 외부 서비스에 실제 요청
it('결제를 처리한다', async () => {
  const result = await realPaymentGateway.charge(1000); // 실제 결제 API 호출!
  expect(result.status).toBe('succeeded');
});
```

---

## Checklist

코드 리뷰 또는 PR 작성 시 아래 항목을 확인합니다:

- [ ] 새로운 기능/버그 수정에 대한 테스트가 포함되어 있는가?
- [ ] 각 테스트가 독립적으로 실행 가능한가? (다른 테스트에 의존하지 않음)
- [ ] 해피 패스뿐 아니라 에러 케이스, 엣지 케이스가 테스트되었는가?
- [ ] 외부 의존성만 모킹되고, 내부 구현은 모킹하지 않았는가?
- [ ] 테스트 이름이 "무엇이 어떤 조건에서 어떻게 동작하는가"를 설명하는가?
- [ ] 테스트 데이터가 팩토리/빌더로 생성되고 하드코딩되지 않았는가?
- [ ] CI에서 전체 테스트가 자동 실행되고, 실패 시 머지가 차단되는가?
- [ ] 커버리지가 기준(80%) 이상이고, 핵심 로직의 분기 커버리지가 확보되었는가?
