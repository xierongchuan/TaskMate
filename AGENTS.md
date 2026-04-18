# AGENTS.md

TaskMate — task management system for auto dealerships. See `CLAUDE.md` for detailed Russian instructions.

## Architecture

Monorepo with git submodules:

| Module | Path | Stack |
|--------|------|-------|
| Backend | `TaskMateServer/` | Laravel 12 · PHP 8.4 · PostgreSQL 18 |
| Frontend | `TaskMateClient/` | React 19 · TypeScript · Vite · Tailwind |
| Telegram Bot | `TaskMateTelegramBot/` | Python 3.12 · aiogram 3 · httpx · Valkey |
| Infrastructure | root | podman compose · Nginx · Valkey · RabbitMQ |

## Commands (ALL via containers)

npm/node/composer/php are **NOT** installed on host.

```bash
# Backend — all tests
podman compose exec api php artisan test
# Backend — single test class
podman compose exec api php artisan test --filter=TaskControllerTest
# Backend — single test method
podman compose exec api php artisan test --filter="TaskControllerTest::test_user_can_create_task"
# Backend — coverage (min 50%)
podman compose exec api composer test:coverage
# Backend — lint/format
podman compose exec api php vendor/bin/pint              # auto-fix
podman compose exec api php vendor/bin/pint --test       # check only

# Frontend — dev / build / lint
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run dev
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run build
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run lint
# Frontend — install package
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm install <pkg>

# E2E (Playwright) — requires running svc-frontend, svc-api, svc-nginx
podman run --rm --network host -v ./TaskMateClient:/app:z -w /app mcr.microsoft.com/playwright:v1.58.0-noble npx playwright test
podman run --rm --network host -v ./TaskMateClient:/app:z -w /app mcr.microsoft.com/playwright:v1.58.0-noble npx playwright test dashboard  # single file


```

## Critical Rules

1. **Docker only** — ALL commands run through containers (see above).
2. **UTC dates** — Store/transmit/compare in UTC (ISO 8601, Z suffix). Backend: `TimeHelper`, frontend: `dateTime.ts`. Hybrid: moments in UTC, calendar days in dealership timezone.
3. **PostgreSQL only** — Use COALESCE (not IFNULL), no GROUP BY without aggregation.
4. **Tests mandatory** — Always run tests after backend changes. Min 50% coverage.
5. **Language** — Russian for UI, comments, docs. Code in English.
6. **Sync** — When changing API (backend), verify frontend, and vice versa.
7. **SOLID** — Strict adherence in design and development.
8. **Security** — Parameterized SQL queries, validate all input, never use `exec`/`eval`/`shell_exec` with user data.

## Code Style — Backend (PHP/Laravel)

- **Architecture:** Controller → Service → Model. Thin controllers; business logic in Services.
- **Validation:** Form Requests ONLY in `app/Http/Requests/Api/V1/`. Never `$request->validate()` in controllers.
- **Eager loading:** Mandatory. `Task::with(['creator', 'assignments.user'])->get()`.
- **Responses:** Use `toApiArray()` on models (NOT API Resources, except User/Shift). Guarantees UTC dates with Z suffix.
- **Naming:** Controllers `PascalCaseController`, services `PascalCaseService`, snake_case DB columns, camelCase PHP methods.
- **Imports:** Group order — PHP std, vendor, App. Alphabetical within groups. No unused imports.
- **Error handling:** Throw typed exceptions in services; catch in controllers via global handler. Use `abort(4xx)` for auth/validation errors.
- **Dates:** Always `TimeHelper::nowUtc()`, `TimeHelper::toIsoZulu($carbon)`, `TimeHelper::dayBoundariesForTimezone()`.

## Code Style — Frontend (React/TypeScript)

- **State:** Zustand for client state (auth, workspace, sidebar, persisted in localStorage). TanStack Query for server data — always include `dealershipId` in queryKey + `placeholderData: (prev) => prev`.
- **Permissions:** ALWAYS use `usePermissions()`. NEVER check `user.role` directly.
- **API calls:** Use modules from `src/api/`. NEVER use axios directly.
- **Dates:** Use `src/utils/dateTime.ts` — `formatDateTime()`, `toUtcIso()`, `parseUtcDate()`.
- **Multi-tenant:** `useWorkspace()` is the single source for `dealershipId`.
- **Naming:** Components `PascalCase`, hooks `useCamelCase`, utilities `camelCase`, files `kebab-case.tsx` for components, `camelCase.ts` for utils.
- **Imports:** Absolute `@/` aliases. Order: React, external libs, `@/` internal, relative. Blank line between groups.
- **Types:** Prefer `interface` for objects, `type` for unions/intersections. No `any` — use `unknown` + narrowing.
- **Error handling:** API errors via interceptors in `api/client.ts`. Components show toast via error boundary. Use `zod` schemas for runtime validation where needed.

## Code Style — Telegram Bot (Python)

- **Async everywhere** — aiogram, httpx, redis.asyncio. Synchronous code is forbidden.
- **Data only via API** — No direct DB access. All through REST `/api/v1/*`.
- **FSM** — For multi-step flows (proof uploads, auth).
- **Naming:** handlers `snake_case`, modules `snake_case.py`, classes `PascalCase`.
- **Error handling:** Catch httpx errors, log with structlog, send user-friendly Russian messages.
- **No blocking:** Use `asyncio.sleep()`, never `time.sleep()`.

## Domain Model

- **Roles:** employee(1) → observer(2) → manager(3) → owner(4). Number = access level.
- **Tasks:** notification · completion · completion_with_proof. Structure: individual · group.
- **Multi-tenant:** each AutoDealership has its own timezone.
- **File storage:** Private disk `task_proofs`, access via signed URLs (60 min expiry).
- **Queue workers:** `proof_upload`, `shared_proof_upload`, `task_generators`, `file_cleanup`.

### Task Workflow

```
Create:   Manager/Owner → TaskService::createTask() → status: pending
Execute:  Employee → PATCH /tasks/{id}/status + proof_files → pending_review
Verify:   Manager → POST /task-responses/{id}/approve|reject
Archive:  Scheduler → tasks:archive-completed (every 10 min)
```

## Docker Services

```yaml
svc-postgres, svc-valkey, svc-rabbitmq     # Data stores
svc-frontend, svc-api                       # App services
svc-worker-cleanup, svc-worker-proof,       # RabbitMQ workers
  svc-worker-shared, svc-worker-generator
svc-scheduler                               # Supervisor cron
svc-nginx                                   # Reverse proxy
```

## Quick Start

```bash
podman compose up -d --build
podman compose exec api composer install
podman compose exec api php artisan migrate --force
podman compose exec api php artisan db:seed-demo
podman compose exec api php artisan storage:link
```

Demo: `admin/password`, `manager1/password`, `emp1_1/password`

| Service | URL |
|---------|-----|
| Frontend | http://localhost:8099 |
| Backend API | http://localhost:8007 |
| RabbitMQ UI | http://localhost:15672 |

## Forbidden Patterns

- MySQL-compatible SQL (IFNULL, GROUP BY without aggregation)
- Dates not in UTC
- Direct storage access — use `task_proofs` disk + signed URLs
- Logic in controllers — move to Services
- Models without eager loading
- `user.role === 'owner'` — use `usePermissions()`
- Server data in Zustand — use TanStack Query
- `keepPreviousData` (deprecated) — use `placeholderData: (prev) => prev`
- Direct axios — use API modules from `src/api/`
- Synchronous code in Telegram bot — async only

## Module Details

See `CLAUDE.md` in each module for full conventions, structure, and additional forbidden patterns:
- `TaskMateServer/CLAUDE.md` — API Resources, Jobs, file storage limits
- `TaskMateClient/CLAUDE.md` — E2E test structure, theme/styling conventions
- `TaskMateTelegramBot/CLAUDE.md` — FSM, RabbitMQ consumer, Valkey sessions
