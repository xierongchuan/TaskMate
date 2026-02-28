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
# Backend
podman compose exec api php artisan test
podman compose exec api composer test:coverage
podman compose exec api php vendor/bin/pint

# Frontend
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run build
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run lint

# Deploy
./scripts/deploy_prod.sh --pull --init   # first time
./scripts/deploy_prod.sh --pull          # update
```

## Critical Rules

1. **Docker only** — ALL commands run through containers (see above).
2. **UTC dates** — Store/transmit/compare in UTC (ISO 8601, Z suffix). Backend: `TimeHelper`, frontend: `dateTime.ts`.
3. **PostgreSQL only** — Use COALESCE (not IFNULL), no GROUP BY without aggregation.
4. **Tests mandatory** — Always run tests after backend changes. Min 50% coverage.
5. **Language** — Russian for UI, comments, docs. Code in English.
6. **Sync** — When changing API (backend), verify frontend, and vice versa.
7. **SOLID** — Strict adherence in design and development.
8. **Security** — Parameterized SQL queries, validate all input, never use `exec`/`eval`/`shell_exec` with user data.

## Domain Model

- **Roles:** employee(1) → observer(2) → manager(3) → owner(4). Number = access level.
- **Tasks:** notification · completion · completion_with_proof. Structure: individual · group.
- **Multi-tenant:** each AutoDealership has its own timezone.

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

## Module Details

See `CLAUDE.md` in each module for conventions, structure, and forbidden patterns.
