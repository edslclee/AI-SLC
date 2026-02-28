# Chapter 10: 배포

> 배포는 코드를 프로덕션 환경에 안전하게 전달하는 과정이다. Docker 최적화, CI/CD 파이프라인, 무중단 배포, 롤백 전략을 체계적으로 구축하여 배포 위험을 최소화하고 릴리스 속도를 높인다.

---

## Rules (MUST)

### Rule 1: Dockerfile은 멀티 스테이지 빌드와 non-root 사용자를 적용한다

- **멀티 스테이지 빌드**로 최종 이미지 크기를 최소화한다
- **non-root 사용자**로 컨테이너를 실행한다
- 베이스 이미지는 **특정 버전 태그**를 사용한다 (`latest` 금지)
- `.dockerignore`로 불필요한 파일을 제외한다
- 레이어 캐싱을 최적화하기 위해 **변경 빈도 순**으로 명령어를 배치한다

### Rule 2: 환경 변수를 안전하게 관리한다

- 환경별 설정은 **환경 변수**로 주입한다 (하드코딩 금지)
- `.env` 파일은 **버전 관리에 포함하지 않는다**
- `.env.example` 파일로 필요한 환경 변수 **목록과 형식**을 문서화한다
- 환경 변수는 애플리케이션 시작 시 **스키마 검증**한다
- 기본값은 **개발 환경에만** 설정하고, 프로덕션은 반드시 명시적으로 설정한다

### Rule 3: CI/CD 파이프라인을 자동화한다

파이프라인 단계:

```
코드 푸시 → 린트/포맷 검사 → 빌드 → 단위 테스트 → 통합 테스트
→ 보안 스캔 → Docker 이미지 빌드 → 스테이징 배포 → E2E 테스트
→ 승인 → 프로덕션 배포
```

- 모든 PR에 대해 **자동으로** 린트, 테스트, 빌드를 실행한다
- main 브랜치 머지 시 **자동으로** 스테이징에 배포한다
- 프로덕션 배포는 **수동 승인 게이트**를 추가한다
- 파이프라인 실패 시 **슬랙/이메일 알림**을 발송한다

### Rule 4: 무중단 배포(Zero-Downtime Deployment)를 구현한다

- **Rolling Update** 또는 **Blue-Green** 전략을 사용한다
- 새 버전은 **헬스 체크 통과 후** 트래픽을 받는다
- DB 마이그레이션은 **backward compatible**하게 작성한다
- 배포 중 **이전 버전과 새 버전이 공존**할 수 있음을 고려한다

### Rule 5: 헬스 체크를 배포 프로세스에 통합한다

- 컨테이너 오케스트레이터의 **liveness/readiness probe**를 설정한다
- 새 버전 배포 시 readiness 체크를 **통과해야만** 트래픽을 라우팅한다
- 헬스 체크 실패 시 **자동으로 롤백**되도록 설정한다
- startup probe로 **초기화 시간이 긴 애플리케이션**을 지원한다

### Rule 6: 롤백 전략을 사전에 준비한다

- 모든 배포에 대해 **즉시 롤백**이 가능해야 한다
- 이전 버전 이미지를 **항상 보관**한다 (최소 5개 버전)
- 롤백 절차를 **문서화하고 정기적으로 훈련**한다
- DB 마이그레이션 롤백 스크립트를 **함께 작성**한다
- 롤백 기준(에러율, 응답시간 임계치)을 **사전에 정의**한다

### Rule 7: Infrastructure as Code(IaC)를 사용한다

- 인프라 설정을 **코드로 관리**한다 (Terraform, Pulumi, AWS CDK 등)
- 인프라 변경도 **PR 리뷰**를 거친다
- 환경(dev/staging/production)간 **동일한 코드**를 사용하되 변수만 다르게 한다
- 인프라 상태는 **원격 백엔드**(S3, GCS)에 저장한다

### Rule 8: 시크릿을 안전하게 관리한다

- 시크릿은 **전용 시크릿 매니저**(AWS Secrets Manager, Vault, 1Password)를 사용한다
- 시크릿을 **환경 변수로 직접 하드코딩**하지 않는다
- CI/CD에서 시크릿은 **암호화된 변수**로 관리한다
- 시크릿 접근 로그를 **감사(audit)** 한다
- 시크릿은 **정기적으로 로테이션**한다

### Rule 9: 컨테이너 오케스트레이션 기본 원칙을 따른다

- Pod/컨테이너에 **리소스 제한(limits)과 요청(requests)** 을 설정한다
- **수평 자동 확장(HPA)** 을 설정하여 트래픽에 대응한다
- 서비스 디스커버리와 **내부 DNS**를 활용한다
- PodDisruptionBudget으로 **최소 가용 인스턴스**를 보장한다

### Rule 10: 프로덕션 배포 후 모니터링을 강화한다

- 배포 직후 **15-30분간 집중 모니터링**한다
- 에러율, 응답시간, CPU/메모리 사용량을 **배포 전후 비교**한다
- 배포 이벤트를 **모니터링 도구에 마커**로 표시한다
- 이상 감지 시 **자동 또는 수동 롤백**을 즉시 실행한다

---

## Patterns (권장 패턴)

### Pattern 1: 최적화된 Dockerfile (멀티 스테이지)

```dockerfile
# ===== Stage 1: 의존성 설치 =====
FROM node:20.11-alpine AS deps

WORKDIR /app

# 패키지 파일만 먼저 복사 (레이어 캐싱 최적화)
COPY package.json package-lock.json ./
RUN npm ci --only=production && \
    cp -R node_modules /production_modules && \
    npm ci

# ===== Stage 2: 빌드 =====
FROM node:20.11-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build && \
    npm prune --production

# ===== Stage 3: 프로덕션 실행 =====
FROM node:20.11-alpine AS runner

# 보안: non-root 사용자 생성
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 appuser

WORKDIR /app

# 프로덕션 의존성만 복사
COPY --from=deps /production_modules ./node_modules
# 빌드 결과물만 복사
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./

# non-root 사용자로 전환
USER appuser

# 헬스 체크
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health/live || exit 1

EXPOSE 3000

CMD ["node", "dist/main.js"]
```

```gitignore
# .dockerignore
node_modules
npm-debug.log
.git
.gitignore
.env
.env.*
*.md
docs/
tests/
coverage/
.nyc_output/
.vscode/
.idea/
```

### Pattern 2: 환경 변수 스키마 검증

```typescript
import { z } from 'zod';

const envSchema = z.object({
  // 서버 설정
  NODE_ENV: z.enum(['development', 'staging', 'production']),
  PORT: z.coerce.number().default(3000),

  // 데이터베이스
  DATABASE_URL: z.string().url(),
  DB_POOL_SIZE: z.coerce.number().min(1).max(50).default(10),

  // Redis
  REDIS_URL: z.string().url(),

  // 인증
  JWT_SECRET: z.string().min(32),
  JWT_EXPIRES_IN: z.string().default('15m'),

  // 외부 서비스
  SENTRY_DSN: z.string().url().optional(),
  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.coerce.number().optional(),

  // 기능 플래그
  ENABLE_NEW_CHECKOUT: z.coerce.boolean().default(false),
});

export type Env = z.infer<typeof envSchema>;

// 애플리케이션 시작 시 검증
function validateEnv(): Env {
  const result = envSchema.safeParse(process.env);

  if (!result.success) {
    const missing = result.error.issues
      .map((issue) => `  - ${issue.path.join('.')}: ${issue.message}`)
      .join('\n');

    console.error(`환경 변수 검증 실패:\n${missing}`);
    process.exit(1);
  }

  return result.data;
}

export const env = validateEnv();
```

```bash
# .env.example - 필요한 환경 변수 목록 (값은 예시)
NODE_ENV=development
PORT=3000

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
DB_POOL_SIZE=10

# Redis
REDIS_URL=redis://localhost:6379

# Authentication
JWT_SECRET=your-secret-key-at-least-32-characters-long
JWT_EXPIRES_IN=15m

# External Services (optional)
# SENTRY_DSN=https://xxx@sentry.io/123
# SMTP_HOST=smtp.example.com
# SMTP_PORT=587

# Feature Flags
ENABLE_NEW_CHECKOUT=false
```

### Pattern 3: GitHub Actions CI/CD 파이프라인

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # ===== 1단계: 코드 품질 검사 =====
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci
      - run: npm run lint
      - run: npm run format:check
      - run: npm run type-check

  # ===== 2단계: 테스트 =====
  test:
    runs-on: ubuntu-latest
    needs: quality
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: testdb
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci
      - run: npm run test:unit
      - run: npm run test:integration
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/testdb

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-report
          path: coverage/

  # ===== 3단계: 보안 스캔 =====
  security:
    runs-on: ubuntu-latest
    needs: quality
    steps:
      - uses: actions/checkout@v4
      - run: npm audit --audit-level=high
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'CRITICAL,HIGH'

  # ===== 4단계: Docker 빌드 & 푸시 =====
  build:
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.event_name == 'push'
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=
            type=ref,event=branch
            type=semver,pattern={{version}}

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ===== 5단계: 스테이징 배포 =====
  deploy-staging:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/develop'
    environment: staging
    steps:
      - name: Deploy to staging
        run: |
          echo "Deploying to staging..."
          # kubectl set image deployment/api api=$REGISTRY/$IMAGE_NAME:$GITHUB_SHA

  # ===== 6단계: 프로덕션 배포 (수동 승인) =====
  deploy-production:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://api.example.com
    steps:
      - name: Deploy to production
        run: |
          echo "Deploying to production..."
          # kubectl set image deployment/api api=$REGISTRY/$IMAGE_NAME:$GITHUB_SHA
```

### Pattern 4: Kubernetes 배포 매니페스트

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  labels:
    app: api-server
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # 배포 중 최대 추가 Pod
      maxUnavailable: 0   # 배포 중 최소 가용 Pod 보장
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      # 보안: non-root 실행
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001

      containers:
        - name: api
          image: ghcr.io/my-org/api-server:latest
          ports:
            - containerPort: 3000

          # 리소스 제한
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 1000m
              memory: 512Mi

          # 환경 변수 (시크릿 참조)
          envFrom:
            - configMapRef:
                name: api-config
            - secretRef:
                name: api-secrets

          # 헬스 체크
          startupProbe:
            httpGet:
              path: /health/live
              port: 3000
            failureThreshold: 30
            periodSeconds: 2

          livenessProbe:
            httpGet:
              path: /health/live
              port: 3000
            initialDelaySeconds: 0
            periodSeconds: 15
            timeoutSeconds: 3
            failureThreshold: 3

          readinessProbe:
            httpGet:
              path: /health/ready
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3

          # Graceful Shutdown
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 10"]

      terminationGracePeriodSeconds: 30

---
# 최소 가용 인스턴스 보장
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-server-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: api-server

---
# 수평 자동 확장
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-server-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-server
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

### Pattern 5: Graceful Shutdown

```typescript
import type { Server } from 'node:http';
import type { DataSource } from 'typeorm';
import type { Redis } from 'ioredis';

interface AppDependencies {
  server: Server;
  dataSource: DataSource;
  redis: Redis;
}

function setupGracefulShutdown(deps: AppDependencies): void {
  let isShuttingDown = false;

  async function shutdown(signal: string): Promise<void> {
    if (isShuttingDown) return;
    isShuttingDown = true;

    logger.info(`Received ${signal}. Starting graceful shutdown...`);

    // 1. 새로운 요청 수신 중단
    deps.server.close(() => {
      logger.info('HTTP server closed');
    });

    // 2. 진행 중인 요청 완료 대기 (최대 25초)
    const forceShutdownTimer = setTimeout(() => {
      logger.error('Forced shutdown due to timeout');
      process.exit(1);
    }, 25_000);

    try {
      // 3. 외부 연결 종료
      await deps.dataSource.destroy();
      logger.info('Database connection closed');

      await deps.redis.quit();
      logger.info('Redis connection closed');

      clearTimeout(forceShutdownTimer);
      logger.info('Graceful shutdown completed');
      process.exit(0);
    } catch (error) {
      logger.error('Error during shutdown', { error });
      process.exit(1);
    }
  }

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));

  // Unhandled rejection/exception 처리
  process.on('unhandledRejection', (reason) => {
    logger.error('Unhandled rejection', { reason });
    // 프로세스를 종료하지 않고 로그만 기록 (Sentry에서 포착)
  });

  process.on('uncaughtException', (error) => {
    logger.error('Uncaught exception', { error: error.message, stack: error.stack });
    shutdown('uncaughtException');
  });
}
```

### Pattern 6: 롤백 스크립트

```typescript
// scripts/rollback.ts
import { execSync } from 'node:child_process';

interface RollbackConfig {
  namespace: string;
  deployment: string;
  maxRevisions: number;
}

async function rollback(config: RollbackConfig, targetRevision?: number): Promise<void> {
  const { namespace, deployment } = config;

  console.log(`Rolling back ${deployment} in namespace ${namespace}...`);

  // 현재 배포 상태 확인
  const status = execSync(
    `kubectl rollout status deployment/${deployment} -n ${namespace} --timeout=10s`,
    { encoding: 'utf-8' },
  );
  console.log('Current status:', status);

  // 배포 이력 확인
  const history = execSync(
    `kubectl rollout history deployment/${deployment} -n ${namespace}`,
    { encoding: 'utf-8' },
  );
  console.log('Deployment history:\n', history);

  // 롤백 실행
  if (targetRevision) {
    execSync(
      `kubectl rollout undo deployment/${deployment} -n ${namespace} --to-revision=${targetRevision}`,
    );
    console.log(`Rolled back to revision ${targetRevision}`);
  } else {
    execSync(
      `kubectl rollout undo deployment/${deployment} -n ${namespace}`,
    );
    console.log('Rolled back to previous revision');
  }

  // 롤백 완료 대기
  execSync(
    `kubectl rollout status deployment/${deployment} -n ${namespace} --timeout=120s`,
  );
  console.log('Rollback completed successfully');
}

// 실행
const config: RollbackConfig = {
  namespace: process.env.K8S_NAMESPACE ?? 'production',
  deployment: process.env.K8S_DEPLOYMENT ?? 'api-server',
  maxRevisions: 5,
};

const targetRevision = process.argv[2] ? Number(process.argv[2]) : undefined;
rollback(config, targetRevision).catch(console.error);
```

---

## Anti-Patterns (NEVER)

### Anti-Pattern 1: 비최적화 Dockerfile

```dockerfile
# NEVER - 단일 스테이지, root 실행, latest 태그
FROM node:latest

WORKDIR /app
COPY . .
RUN npm install
# devDependencies까지 포함, node_modules가 이미지에 포함

EXPOSE 3000
CMD ["npm", "start"]
# root로 실행됨, 이미지 크기 1GB+
```

```dockerfile
# NEVER - 레이어 캐싱 무시
FROM node:20-alpine
WORKDIR /app

# 소스 코드 변경 시 npm install도 다시 실행됨!
COPY . .
RUN npm ci

# MUST - 패키지 파일을 먼저 복사
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
```

### Anti-Pattern 2: 하드코딩된 설정과 시크릿

```typescript
// NEVER - 코드에 직접 하드코딩
const dbConfig = {
  host: 'production-db.example.com',
  password: 'super-secret-password-123',
  port: 5432,
};

const jwtSecret = 'my-jwt-secret-key';
const apiKey = 'sk-1234567890abcdef';

// NEVER - Docker 이미지에 시크릿 포함
// Dockerfile
// ENV JWT_SECRET=my-secret-key
// ENV DATABASE_PASSWORD=password123

// MUST - 환경 변수로 주입, 시크릿 매니저 사용
const dbConfig = {
  host: env.DATABASE_HOST,
  password: env.DATABASE_PASSWORD, // Secrets Manager에서 주입
  port: env.DATABASE_PORT,
};
```

### Anti-Pattern 3: 롤백 불가능한 배포

```bash
# NEVER - 이전 버전 이미지를 삭제
docker rmi my-app:v1.0.0  # 롤백 불가!

# NEVER - DB 마이그레이션이 이전 버전과 호환되지 않음
# migration: ALTER TABLE users DROP COLUMN email;
# → 롤백 시 이전 버전 코드가 email 컬럼을 참조하여 에러!

# MUST - Backward compatible 마이그레이션
# Step 1 (v1.1): 새 컬럼 추가 (이전 버전도 동작)
# Step 2 (v1.2): 새 컬럼 사용으로 전환
# Step 3 (v1.3): 이전 컬럼 삭제 (v1.1 이전 버전 롤백 불가 지점)
```

### Anti-Pattern 4: CI/CD 없는 수동 배포

```bash
# NEVER - SSH로 직접 서버에 접속하여 배포
ssh production-server
cd /app
git pull origin main
npm install
npm run build
pm2 restart all
# → 재현 불가, 감사 추적 불가, 롤백 어려움

# NEVER - 로컬에서 직접 Docker 이미지 빌드 후 푸시
docker build -t my-app:latest .
docker push my-app:latest
# → 빌드 환경 불일치, 검증 단계 누락
```

### Anti-Pattern 5: 헬스 체크 없는 배포

```yaml
# NEVER - 헬스 체크 없이 배포
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: api
          image: my-app:latest
          # livenessProbe 없음
          # readinessProbe 없음
          # → 앱이 죽어도 트래픽이 계속 들어옴
          # → 새 버전이 시작도 안 됐는데 트래픽 라우팅
```

### Anti-Pattern 6: 모니터링 없는 프로덕션 배포

```bash
# NEVER - 배포 후 확인 안 함
kubectl apply -f deployment.yaml
echo "배포 완료!"
# → 에러 폭증 중인지, OOM인지, 정상인지 알 수 없음

# MUST - 배포 후 모니터링
kubectl apply -f deployment.yaml
kubectl rollout status deployment/api-server --timeout=120s

# 배포 후 메트릭 확인 스크립트
echo "Checking error rate after deploy..."
# curl -s prometheus/api/v1/query?query=rate(http_errors_total[5m])
echo "Checking p99 latency..."
# curl -s prometheus/api/v1/query?query=histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

---

## Checklist

배포 관련 작업 시 아래 항목을 확인한다:

- [ ] Dockerfile이 멀티 스테이지 빌드를 사용하고, non-root 사용자로 실행되는가?
- [ ] 베이스 이미지에 특정 버전 태그를 사용하는가? (`latest` 사용 금지)
- [ ] 환경 변수가 시작 시 스키마 검증되며, `.env` 파일이 Git에 포함되지 않는가?
- [ ] CI/CD 파이프라인이 린트, 테스트, 보안 스캔을 자동으로 실행하는가?
- [ ] 무중단 배포(Rolling Update / Blue-Green)가 설정되어 있는가?
- [ ] liveness/readiness probe가 올바르게 설정되어 있는가?
- [ ] 즉시 롤백이 가능하며, 이전 버전 이미지가 보관되어 있는가?
- [ ] 배포 후 15-30분간 집중 모니터링 절차가 수립되어 있는가?
