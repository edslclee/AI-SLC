# Chapter 06: Git 워크플로우

> 일관된 Git 워크플로우는 팀 협업의 기반이다. 브랜치 전략, 커밋 메시지, PR 프로세스를 표준화하여 코드 이력의 추적성과 배포 안정성을 보장한다.

---

## Rules (MUST)

### Rule 1: 브랜치 네이밍 컨벤션을 준수한다

브랜치 이름은 `{type}/{ticket-id}-{short-description}` 형식을 따른다.

- **type**: `feature`, `fix`, `hotfix`, `chore`, `refactor`, `docs`, `test`
- **ticket-id**: 이슈 트래커 번호 (예: PROJ-123)
- **short-description**: 케밥 케이스, 3-5 단어 이내

```
feature/PROJ-123-user-authentication
fix/PROJ-456-login-redirect-loop
hotfix/PROJ-789-critical-payment-error
chore/PROJ-101-update-dependencies
refactor/PROJ-202-extract-auth-service
```

### Rule 2: Conventional Commits 형식으로 커밋 메시지를 작성한다

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

- **type**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`
- **scope**: 변경 영역 (예: auth, api, db)
- **description**: 명령형, 소문자 시작, 마침표 없음, 50자 이내
- **body**: 변경 이유와 맥락 설명, 72자 줄 바꿈
- **footer**: `BREAKING CHANGE:`, `Closes #123`, `Refs #456`

```
feat(auth): add JWT refresh token rotation

기존 단일 토큰 방식에서 refresh token rotation으로 변경하여
토큰 탈취 시 피해를 최소화한다.

Closes #PROJ-123
```

### Rule 3: PR은 반드시 코드 리뷰를 거친 후 머지한다

- PR 생성 시 **템플릿**을 사용한다 (변경 내용, 테스트 방법, 스크린샷)
- 최소 **1명 이상**의 리뷰어 승인이 필요하다
- CI/CD 파이프라인이 **모두 통과**해야 머지할 수 있다
- PR 크기는 **변경 파일 10개, 코드 300줄** 이내를 권장한다
- 셀프 머지는 **금지**한다 (긴급 hotfix 제외, 사후 리뷰 필수)

### Rule 4: 머지 전략을 브랜치 유형에 따라 구분한다

| 상황 | 전략 | 이유 |
|------|------|------|
| feature -> develop | Squash Merge | 깔끔한 커밋 이력 유지 |
| develop -> main | Merge Commit | 릴리스 경계 명확화 |
| hotfix -> main | Merge Commit | 핫픽스 이력 보존 |
| main -> develop (역머지) | Merge Commit | 핫픽스 반영 추적 |

### Rule 5: main/develop 브랜치에 직접 푸시하지 않는다

- `main`과 `develop` 브랜치는 **보호 브랜치**로 설정한다
- 직접 커밋, force push를 **금지**한다
- 모든 변경은 **PR을 통해서만** 반영한다

### Rule 6: Feature Branch 워크플로우를 따른다

```
main ─────────────────────────────────────────→
  │                                    ↑
  └─→ develop ──────────────────────→ merge
        │              ↑
        └─→ feature ─→ squash merge
```

1. `develop`에서 feature 브랜치를 생성한다
2. feature 브랜치에서 작업하고 커밋한다
3. PR을 생성하고 리뷰를 받는다
4. 승인 후 `develop`에 squash merge한다
5. 릴리스 시 `develop`을 `main`에 merge commit한다

### Rule 7: 릴리스 관리와 태그/버전을 표준화한다

- **Semantic Versioning** (MAJOR.MINOR.PATCH)을 사용한다
- 릴리스 태그는 `v{version}` 형식이다 (예: `v1.2.3`)
- `BREAKING CHANGE`가 포함되면 MAJOR 버전을 올린다
- 새 기능 추가 시 MINOR, 버그 수정 시 PATCH를 올린다
- 릴리스 노트는 Conventional Commits 기반으로 **자동 생성**한다

### Rule 8: 충돌 해결 시 원본 의도를 반드시 확인한다

- 충돌 발생 시 **양쪽 변경의 의도**를 파악한 후 해결한다
- 기계적으로 한쪽만 선택하지 않는다
- 충돌 해결 후 반드시 **테스트를 실행**한다
- 대규모 충돌은 **원저자와 함께** 해결한다

### Rule 9: Git Hooks로 품질 게이트를 자동화한다

- `pre-commit`: 린트, 포맷팅 검사
- `commit-msg`: 커밋 메시지 형식 검증
- `pre-push`: 테스트 실행
- Husky + lint-staged를 사용하여 설정한다

---

## Patterns (권장 패턴)

### Pattern 1: Git Hooks 설정 (Husky + lint-staged)

```json
// package.json
{
  "scripts": {
    "prepare": "husky install"
  },
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md}": [
      "prettier --write"
    ]
  }
}
```

```bash
# .husky/pre-commit
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx lint-staged
```

```bash
# .husky/commit-msg
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx --no -- commitlint --edit ${1}
```

```typescript
// commitlint.config.ts
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      ['feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'perf', 'ci', 'build'],
    ],
    'subject-max-length': [2, 'always', 50],
    'body-max-line-length': [2, 'always', 72],
    'scope-case': [2, 'always', 'lower-case'],
  },
};
```

### Pattern 2: PR 템플릿

```markdown
<!-- .github/pull_request_template.md -->
## 변경 내용
<!-- 이 PR에서 변경한 내용을 간략히 설명해주세요 -->

## 변경 이유
<!-- 왜 이 변경이 필요한지 설명해주세요 -->

## 관련 이슈
<!-- Closes #이슈번호 -->

## 테스트 방법
<!-- 리뷰어가 이 변경을 어떻게 테스트할 수 있는지 설명해주세요 -->
- [ ] 단위 테스트 추가/수정
- [ ] 통합 테스트 추가/수정
- [ ] 수동 테스트 완료

## 스크린샷 (UI 변경 시)
<!-- UI 변경이 있는 경우 스크린샷을 첨부해주세요 -->

## 체크리스트
- [ ] 코드 컨벤션을 준수했습니다
- [ ] 셀프 리뷰를 완료했습니다
- [ ] 관련 문서를 업데이트했습니다
- [ ] 파괴적 변경(Breaking Change)이 없습니다
```

### Pattern 3: 브랜치 보호 규칙 설정

```typescript
// GitHub Branch Protection 설정 스크립트 (GitHub API 활용)
import { Octokit } from '@octokit/rest';

const octokit = new Octokit({ auth: process.env.GITHUB_TOKEN });

async function setupBranchProtection(): Promise<void> {
  await octokit.repos.updateBranchProtection({
    owner: 'my-org',
    repo: 'my-repo',
    branch: 'main',
    required_status_checks: {
      strict: true,
      contexts: ['ci/build', 'ci/test', 'ci/lint'],
    },
    enforce_admins: true,
    required_pull_request_reviews: {
      required_approving_review_count: 1,
      dismiss_stale_reviews: true,
      require_code_owner_reviews: true,
    },
    restrictions: null,
    allow_force_pushes: false,
    allow_deletions: false,
  });
}
```

### Pattern 4: 릴리스 자동화 (standard-version)

```json
// package.json
{
  "scripts": {
    "release": "standard-version",
    "release:minor": "standard-version --release-as minor",
    "release:major": "standard-version --release-as major",
    "release:patch": "standard-version --release-as patch"
  }
}
```

```typescript
// .versionrc.ts - 릴리스 노트 커스터마이징
export default {
  types: [
    { type: 'feat', section: '새로운 기능' },
    { type: 'fix', section: '버그 수정' },
    { type: 'perf', section: '성능 개선' },
    { type: 'refactor', section: '리팩토링' },
    { type: 'docs', section: '문서', hidden: true },
    { type: 'style', section: '스타일', hidden: true },
    { type: 'chore', section: '기타', hidden: true },
    { type: 'test', section: '테스트', hidden: true },
    { type: 'ci', section: 'CI/CD', hidden: true },
  ],
};
```

### Pattern 5: 충돌 해결 워크플로우

```bash
# 1. develop 브랜치 최신화
git checkout develop
git pull origin develop

# 2. feature 브랜치로 이동 후 rebase
git checkout feature/PROJ-123-user-auth
git rebase develop

# 3. 충돌 발생 시 하나씩 해결
# (에디터에서 충돌 마커 확인 후 수정)
git add <resolved-files>
git rebase --continue

# 4. 충돌 해결 후 테스트 실행
npm test

# 5. force push (rebase 후 필수)
git push --force-with-lease origin feature/PROJ-123-user-auth
```

---

## Anti-Patterns (NEVER)

### Anti-Pattern 1: 의미 없는 커밋 메시지

```bash
# NEVER - 무의미한 메시지
git commit -m "fix"
git commit -m "update"
git commit -m "asdf"
git commit -m "WIP"
git commit -m "수정"
git commit -m "."

# MUST - Conventional Commits 형식
git commit -m "fix(auth): resolve token expiration check on refresh"
git commit -m "feat(user): add email verification flow"
```

### Anti-Pattern 2: 거대한 커밋 / 거대한 PR

```bash
# NEVER - 하나의 커밋에 관련 없는 변경을 모두 포함
git add .
git commit -m "feat: add user feature, fix login bug, update deps, refactor utils"

# MUST - 논리적 단위로 분리
git add src/auth/
git commit -m "fix(auth): resolve login redirect loop"

git add src/user/
git commit -m "feat(user): add profile edit functionality"

git add package.json package-lock.json
git commit -m "chore(deps): update express to v4.18.2"
```

### Anti-Pattern 3: main 브랜치에 직접 push

```bash
# NEVER
git checkout main
git commit -m "feat: quick fix"
git push origin main

# NEVER - force push
git push --force origin main
git push --force origin develop

# MUST - PR 워크플로우
git checkout -b fix/PROJ-456-quick-fix
git commit -m "fix(api): resolve null pointer in user endpoint"
git push origin fix/PROJ-456-quick-fix
# GitHub에서 PR 생성 -> 리뷰 -> 머지
```

### Anti-Pattern 4: .gitignore 없이 민감 정보 커밋

```bash
# NEVER - 비밀 정보가 커밋 이력에 남는다
git add .env
git commit -m "add env config"

# NEVER - 빌드 결과물 커밋
git add dist/ node_modules/
git commit -m "add build files"
```

```gitignore
# MUST - .gitignore에 반드시 포함
.env
.env.local
.env.*.local
node_modules/
dist/
build/
*.log
.DS_Store
coverage/
```

### Anti-Pattern 5: 충돌 해결 시 기계적으로 한쪽만 선택

```typescript
// NEVER - 상대방 변경을 확인하지 않고 "내 것 유지"
// <<<<<<< HEAD
const MAX_RETRY = 5;    // 내가 변경한 값
// =======
// const MAX_RETRY = 3; // 동료가 변경한 값 (성능 이슈로 줄임)
// >>>>>>> develop

// MUST - 양쪽 의도를 파악하고 최적의 값을 선택
// 동료가 성능 이슈로 3으로 줄였으므로, 이유를 확인한 후 결정
const MAX_RETRY = 3; // 성능 이슈 (PROJ-789)로 감소
```

### Anti-Pattern 6: rebase 중 히스토리 오염

```bash
# NEVER - 공유 브랜치(main, develop)에 rebase
git checkout develop
git rebase feature/my-branch  # 공유 브랜치 히스토리가 변경됨!

# MUST - feature 브랜치에서만 rebase
git checkout feature/my-branch
git rebase develop  # 내 브랜치의 히스토리만 변경
```

---

## Checklist

PR 제출 전 아래 항목을 확인한다:

- [ ] 브랜치 이름이 `{type}/{ticket-id}-{short-description}` 형식인가?
- [ ] 모든 커밋 메시지가 Conventional Commits 형식을 따르는가?
- [ ] PR 크기가 적절한가? (파일 10개, 코드 300줄 이내 권장)
- [ ] PR 템플릿이 빠짐없이 작성되었는가?
- [ ] CI/CD 파이프라인이 모두 통과했는가?
- [ ] `.gitignore`에 민감 정보와 빌드 결과물이 포함되어 있는가?
- [ ] 충돌이 올바르게 해결되었고, 해결 후 테스트를 실행했는가?
- [ ] main/develop 브랜치에 직접 push하지 않았는가?
