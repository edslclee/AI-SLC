# Chapter 07: 코드 스타일

> 일관된 코드 스타일은 가독성을 높이고 팀 전체의 생산성을 향상시킨다. 네이밍, 포맷팅, 파일 구조, 린팅 규칙을 표준화하여 코드 리뷰 시간을 줄이고 유지보수성을 극대화한다.

---

## Rules (MUST)

### Rule 1: 네이밍 컨벤션을 일관되게 적용한다

| 대상 | 컨벤션 | 예시 |
|------|--------|------|
| 변수, 함수 | camelCase | `userName`, `getUserById` |
| 클래스, 인터페이스, 타입 | PascalCase | `UserService`, `AuthProvider` |
| 상수 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `API_BASE_URL` |
| 파일 (컴포넌트) | PascalCase | `UserProfile.tsx`, `AuthProvider.ts` |
| 파일 (유틸/모듈) | kebab-case | `date-utils.ts`, `api-client.ts` |
| 디렉토리 | kebab-case | `user-management/`, `auth-service/` |
| 환경 변수 | UPPER_SNAKE_CASE | `DATABASE_URL`, `JWT_SECRET` |
| Enum 멤버 | PascalCase | `UserRole.Admin`, `Status.Active` |
| Boolean 변수 | is/has/can/should 접두사 | `isActive`, `hasPermission`, `canEdit` |
| 이벤트 핸들러 | handle/on 접두사 | `handleSubmit`, `onClick` |

### Rule 2: 함수는 단일 책임 원칙을 따르며 30줄을 넘지 않는다

- 함수 하나는 **한 가지 일**만 수행한다
- 함수 본문은 **30줄 이내**를 유지한다 (빈 줄 제외)
- 매개변수는 **3개 이하**를 권장한다 (초과 시 객체로 묶는다)
- 함수명은 **동사 + 명사** 형태로 작성한다 (예: `createUser`, `validateEmail`)

### Rule 3: import 순서를 표준화한다

import 문은 아래 순서로 그룹화하고, 그룹 사이에 빈 줄을 넣는다:

```typescript
// 1. Node.js 내장 모듈
import path from 'node:path';
import fs from 'node:fs';

// 2. 외부 패키지 (node_modules)
import express from 'express';
import { z } from 'zod';

// 3. 내부 절대 경로 모듈 (@/ 또는 ~/ alias)
import { UserService } from '@/services/user-service';
import { logger } from '@/lib/logger';

// 4. 상대 경로 모듈
import { validateInput } from './validators';
import { UserDto } from './dto';

// 5. 타입 전용 import
import type { User, CreateUserRequest } from '@/types';
```

### Rule 4: 주석은 "왜(Why)"를 설명하고, "무엇(What)"은 코드가 말하게 한다

- **불필요한 주석**: 코드 자체로 의미가 명확한 경우 주석을 달지 않는다
- **필수 주석**: 비즈니스 규칙, 우회 처리(workaround), 성능 최적화 이유
- **TODO/FIXME**: 이슈 번호와 함께 작성한다 (`// TODO(PROJ-123): 리팩토링 필요`)
- **JSDoc**: 공개 API, 라이브러리 함수에는 JSDoc을 작성한다

### Rule 5: 파일 구조를 기능 단위(feature-based)로 구성한다

```
src/
├── features/
│   ├── auth/
│   │   ├── auth.controller.ts
│   │   ├── auth.service.ts
│   │   ├── auth.repository.ts
│   │   ├── auth.validator.ts
│   │   ├── auth.types.ts
│   │   └── __tests__/
│   │       ├── auth.service.test.ts
│   │       └── auth.controller.test.ts
│   └── user/
│       ├── user.controller.ts
│       ├── user.service.ts
│       └── ...
├── shared/
│   ├── lib/
│   ├── utils/
│   └── types/
├── config/
└── infrastructure/
```

### Rule 6: 포맷팅 규칙을 도구로 자동 적용한다

- **Prettier**로 코드 포맷팅을 자동화한다
- **ESLint**로 코드 품질 규칙을 강제한다
- 에디터 설정(`.editorconfig`)을 공유한다
- 포맷팅 논쟁은 **도구에 위임**하고 팀원 간 논쟁을 금지한다

### Rule 7: 코드 리뷰 시 스타일 지적은 린터에 위임한다

- 스타일 관련 리뷰 코멘트는 린터 규칙으로 대체한다
- 코드 리뷰는 **로직, 설계, 보안, 성능**에 집중한다
- 새로운 스타일 규칙은 **팀 합의 후 린터 설정에 추가**한다
- "내 취향"이 아닌 "팀 표준"을 따른다

### Rule 8: 죽은 코드(Dead Code)를 방치하지 않는다

- 사용되지 않는 코드는 **즉시 삭제**한다
- "나중에 쓸 수 있으니까" 주석 처리하지 않는다 (Git 이력에 남아있다)
- `no-unused-vars`, `no-unreachable` 린트 규칙을 **error**로 설정한다
- 주기적으로 **dead code 탐지 도구**를 실행한다

### Rule 9: 일관된 에러 핸들링 패턴을 사용한다

- 파일 전체에서 **동일한 에러 처리 패턴**을 사용한다
- async 함수에서 try-catch 또는 Result 패턴을 **일관되게** 적용한다
- 에러 변수명은 `error` 또는 `err`로 통일한다 (프로젝트 내 하나만 선택)

---

## Patterns (권장 패턴)

### Pattern 1: Prettier + ESLint 설정

```json
// .prettierrc
{
  "semi": true,
  "trailingComma": "all",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2,
  "endOfLine": "lf",
  "arrowParens": "always",
  "bracketSpacing": true
}
```

```typescript
// eslint.config.ts (Flat Config)
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';
import prettier from 'eslint-config-prettier';

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  prettier,
  {
    rules: {
      // 네이밍 컨벤션
      '@typescript-eslint/naming-convention': [
        'error',
        { selector: 'variable', format: ['camelCase', 'UPPER_CASE', 'PascalCase'] },
        { selector: 'function', format: ['camelCase'] },
        { selector: 'typeLike', format: ['PascalCase'] },
        { selector: 'enumMember', format: ['PascalCase'] },
        {
          selector: 'variable',
          types: ['boolean'],
          format: ['PascalCase'],
          prefix: ['is', 'has', 'can', 'should', 'will', 'did'],
        },
      ],

      // Dead code 방지
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      'no-unreachable': 'error',

      // 함수 복잡도 제한
      'max-lines-per-function': ['warn', { max: 30, skipBlankLines: true, skipComments: true }],
      'max-params': ['warn', 3],
      complexity: ['warn', 10],
    },
  },
);
```

### Pattern 2: EditorConfig 설정

```ini
# .editorconfig
root = true

[*]
charset = utf-8
end_of_line = lf
indent_style = space
indent_size = 2
insert_final_newline = true
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
```

### Pattern 3: 좋은 네이밍 예시

```typescript
// -- 변수 네이밍 --
// 구체적이고 의미를 전달하는 이름
const maxRetryCount = 3;
const isEmailVerified = true;
const hasAdminPermission = user.role === UserRole.Admin;
const activeUserIds = users.filter((u) => u.isActive).map((u) => u.id);

// -- 함수 네이밍 --
// 동사 + 명사로 행위를 명확하게 표현
async function findUserByEmail(email: string): Promise<User | null> {
  return userRepository.findOne({ where: { email } });
}

function calculateTotalPrice(items: CartItem[]): number {
  return items.reduce((total, item) => total + item.price * item.quantity, 0);
}

function formatCurrency(amount: number, locale: string = 'ko-KR'): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency: 'KRW',
  }).format(amount);
}

// -- 클래스/인터페이스 네이밍 --
interface CreateUserRequest {
  email: string;
  name: string;
  password: string;
}

interface UserResponse {
  id: string;
  email: string;
  name: string;
  createdAt: Date;
}

class UserService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly emailService: EmailService,
  ) {}
}
```

### Pattern 4: 매개변수 객체 패턴

```typescript
// 매개변수가 3개를 초과하면 객체로 묶는다
interface SearchUsersParams {
  query: string;
  page: number;
  limit: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
  filters?: UserFilter;
}

async function searchUsers(params: SearchUsersParams): Promise<PaginatedResult<User>> {
  const { query, page, limit, sortBy = 'createdAt', sortOrder = 'desc', filters } = params;

  const queryBuilder = userRepository
    .createQueryBuilder('user')
    .where('user.name ILIKE :query', { query: `%${query}%` })
    .skip((page - 1) * limit)
    .take(limit)
    .orderBy(`user.${sortBy}`, sortOrder.toUpperCase() as 'ASC' | 'DESC');

  if (filters?.role) {
    queryBuilder.andWhere('user.role = :role', { role: filters.role });
  }

  const [items, total] = await queryBuilder.getManyAndCount();
  return { items, total, page, limit };
}
```

### Pattern 5: JSDoc 활용

```typescript
/**
 * 사용자의 구독 상태를 갱신한다.
 *
 * 결제 검증 후 구독 만료일을 연장하고, 변경 이력을 기록한다.
 * 이미 활성 구독이 있는 경우 만료일을 기존 날짜에서 연장한다.
 *
 * @param userId - 대상 사용자 ID
 * @param plan - 구독 플랜 정보
 * @returns 갱신된 구독 정보
 * @throws {PaymentVerificationError} 결제 검증 실패 시
 * @throws {UserNotFoundError} 사용자를 찾을 수 없는 경우
 *
 * @example
 * ```typescript
 * const subscription = await renewSubscription('user-123', {
 *   planId: 'premium-monthly',
 *   paymentId: 'pay-456',
 * });
 * ```
 */
async function renewSubscription(
  userId: string,
  plan: SubscriptionPlan,
): Promise<Subscription> {
  // 구현
}
```

---

## Anti-Patterns (NEVER)

### Anti-Pattern 1: 의미 없는 변수/함수명

```typescript
// NEVER - 축약어, 의미 불명확한 이름
const d = new Date();
const u = await getUser();
const res = await fetch(url);
function proc(d: any): any { /* ... */ }
const arr = users.filter((x) => x.a > 0);
const temp = calculateSomething();

// MUST - 의미가 명확한 이름
const currentDate = new Date();
const currentUser = await getUserById(userId);
const apiResponse = await fetch(userApiUrl);
function processPayment(order: Order): PaymentResult { /* ... */ }
const activeUsers = users.filter((user) => user.loginCount > 0);
const totalRevenue = calculateMonthlyRevenue();
```

### Anti-Pattern 2: 불필요한 주석 / 주석 처리된 코드

```typescript
// NEVER - 코드가 이미 설명하는 것을 주석으로 반복
// 사용자를 가져온다
const user = await getUserById(id);

// 이름을 설정한다
user.name = newName;

// 저장한다
await user.save();

// NEVER - 주석 처리된 코드 방치
// function oldFunction() {
//   const result = doSomething();
//   return result;
// }

// MUST - "왜"를 설명하는 주석만 작성
// 한국 시간 기준으로 자정에 만료 처리하기 위해 UTC+9 보정
const expirationDate = addHours(baseDate, 9);

// PG사 응답이 간헐적으로 3초 이상 걸리는 이슈 (PROJ-567)로 타임아웃 연장
const PAYMENT_TIMEOUT_MS = 10_000;
```

### Anti-Pattern 3: 일관성 없는 코드 스타일

```typescript
// NEVER - 같은 파일 내에서 스타일이 혼재
const user_name = 'Kim';       // snake_case
const userEmail = 'a@b.com';   // camelCase
const UserAge = 25;            // PascalCase (변수인데)

function getUser() { /* ... */ }      // 중괄호 같은 줄
function deleteUser()
{                                     // 중괄호 다음 줄
  /* ... */
}

// 어떤 곳에서는 세미콜론 있고, 어떤 곳에서는 없음
const a = 1;
const b = 2
```

### Anti-Pattern 4: 거대한 함수

```typescript
// NEVER - 100줄이 넘는 함수
async function processOrder(orderId: string): Promise<void> {
  // 1. 주문 조회 (10줄)
  // 2. 재고 확인 (15줄)
  // 3. 결제 처리 (20줄)
  // 4. 재고 차감 (10줄)
  // 5. 알림 발송 (15줄)
  // 6. 로그 기록 (10줄)
  // 7. 통계 업데이트 (10줄)
  // ... 총 90줄 이상
}

// MUST - 단일 책임 함수로 분리
async function processOrder(orderId: string): Promise<void> {
  const order = await findOrderOrThrow(orderId);
  await validateStock(order.items);
  const payment = await processPayment(order);
  await deductStock(order.items);
  await sendOrderConfirmation(order, payment);
  await recordOrderMetrics(order);
}
```

### Anti-Pattern 5: import 순서 무시

```typescript
// NEVER - import 순서가 뒤죽박죽
import { validateInput } from './validators';
import express from 'express';
import { UserService } from '@/services/user-service';
import path from 'node:path';
import type { User } from '@/types';
import { z } from 'zod';
import { logger } from '@/lib/logger';
import fs from 'node:fs';

// MUST - 그룹별 정렬, 그룹 사이 빈 줄
import fs from 'node:fs';
import path from 'node:path';

import express from 'express';
import { z } from 'zod';

import { logger } from '@/lib/logger';
import { UserService } from '@/services/user-service';

import { validateInput } from './validators';

import type { User } from '@/types';
```

### Anti-Pattern 6: 매직 넘버 / 매직 스트링

```typescript
// NEVER - 의미를 알 수 없는 리터럴 값
if (user.role === 'admin') { /* ... */ }
if (retryCount > 3) { /* ... */ }
if (file.size > 5242880) { /* ... */ }
setTimeout(callback, 86400000);

// MUST - 상수로 정의하여 의미 부여
const UserRole = {
  Admin: 'admin',
  Member: 'member',
  Guest: 'guest',
} as const;

const MAX_RETRY_COUNT = 3;
const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5MB
const ONE_DAY_MS = 24 * 60 * 60 * 1000;

if (user.role === UserRole.Admin) { /* ... */ }
if (retryCount > MAX_RETRY_COUNT) { /* ... */ }
if (file.size > MAX_FILE_SIZE_BYTES) { /* ... */ }
setTimeout(callback, ONE_DAY_MS);
```

---

## Checklist

코드 작성 및 리뷰 시 아래 항목을 확인한다:

- [ ] 네이밍 컨벤션(camelCase, PascalCase, UPPER_SNAKE_CASE)이 일관되게 적용되었는가?
- [ ] 함수가 30줄 이내이고, 매개변수가 3개 이하인가?
- [ ] import 순서가 표준(내장 -> 외부 -> 내부 -> 상대 -> 타입)을 따르는가?
- [ ] 매직 넘버/스트링 없이 명명된 상수를 사용했는가?
- [ ] 주석 처리된 코드나 사용되지 않는 변수가 남아있지 않은가?
- [ ] Prettier/ESLint 경고 및 에러가 0건인가?
- [ ] Boolean 변수에 `is/has/can/should` 접두사가 있는가?
- [ ] 공개 API 함수에 JSDoc이 작성되었는가?
