# CLAUDE.md

Инструкции для Claude Code при работе с TaskMate — системой управления задачами для автосалонов.

## Стек и архитектура

Monorepo с git submodules:

| Модуль | Путь | Стек |
|--------|------|------|
| Frontend | `TaskMateClient/` | React 19 + TypeScript + Vite + Tailwind |
| Backend | `TaskMateServer/` | Laravel 12 + PHP 8.4 + PostgreSQL 18 |
| Telegram Bot | `TaskMateTelegramBot/` | Python 3.12 + aiogram 3 + httpx + APScheduler + Valkey |
| Инфраструктура | корень | podman compose + Nginx + Valkey + RabbitMQ |

## Быстрый старт

```bash
podman compose up -d --build

# Первый запуск backend
podman compose exec api composer install
podman compose exec api php artisan migrate --force
podman compose exec api php artisan db:seed-demo
podman compose exec api php artisan storage:link
```

Demo: `admin/password`, `manager1/password`, `emp1_1/password`

| Сервис | URL |
|--------|-----|
| Frontend | http://localhost:8099 |
| Backend API | http://localhost:8007 |
| RabbitMQ UI | http://localhost:15672 |

## Команды (ВСЕ через контейнеры)

```bash
# Backend
podman compose exec api php artisan test
podman compose exec api composer test:coverage
podman compose exec api php vendor/bin/pint                    # Code formatting
podman compose exec api php vendor/bin/pint --test             # Check style

# Frontend
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run dev
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run build
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run lint
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm install <package>

# Deploy
./scripts/deploy_prod.sh --pull --init   # первый раз
./scripts/deploy_prod.sh --pull          # обновление
```

## Доменная модель

- **Роли:** `employee` (1) → `observer` (2) → `manager` (3) → `owner` (4). Число = уровень доступа.
- **Задачи:** типы `notification` | `completion` | `completion_with_proof`. Структура: `individual` | `group`.
- **Multi-tenant:** каждый `AutoDealership` имеет свой timezone. Все даты хранятся и передаются в **UTC (ISO 8601 с суффиксом `Z`)**.

### Workflow задач

```
Создание:  Manager/Owner → TaskService::createTask() → status: pending
Выполнение: Employee → PATCH /tasks/{id}/status + proof_files → pending_review
Проверка:   Manager → POST /task-responses/{id}/approve|reject
Архивация:  Scheduler → tasks:archive-completed (каждые 10 мин)
```

## Обязательные правила

1. **Язык:** русский для UI, комментариев, документации. Код на английском.
2. **Даты:** ТОЛЬКО UTC. Хранение, передача, сравнение — всё в UTC. Backend: `TimeHelper::nowUtc()`, `TimeHelper::toIsoZulu()`. Frontend: `dateTime.ts` утилиты.
3. **PostgreSQL:** используй COALESCE (не IFNULL), массивы типов с CAST, предпочитай Query Builder vs raw SQL.
4. **Тесты:** ВСЕГДА `podman compose exec api php artisan test` после backend-изменений. Минимум 50% покрытие.
5. **Docker:** npm/node/composer/php НЕ на хосте. ВСЕ команды — в контейнерах (см. выше).
6. **Синхронизация:** при изменении API (backend) проверять frontend, и наоборот.
7. **SOLID:** строгое соблюдение при проектировании.
8. **Безопасность:** параметризованные SQL-запросы, валидация ввода, никаких `exec`/`eval`/`shell_exec` с пользовательскими данными.

## Docker сервисы

```yaml
# Основные
svc-postgres, svc-valkey, svc-rabbitmq
svc-frontend, svc-api

# Workers (RabbitMQ)
svc-worker-cleanup         # file_cleanup
svc-worker-proof           # proof_upload
svc-worker-shared          # shared_proof_upload
svc-worker-generator       # task_generators

# Инфра
svc-scheduler              # Supervisor (cron)
svc-nginx                  # Reverse proxy
```

## Модули специфика

Детальные инструкции по структуре, конвенциям и запретам — в `CLAUDE.md` каждого модуля:
- `TaskMateServer/CLAUDE.md` — controller→service→model, eager loading, Form Requests, TimeHelper
- `TaskMateClient/CLAUDE.md` — Zustand vs TanStack Query, usePermissions, API модули, dateTime
- `TaskMateTelegramBot/CLAUDE.md` — async/await, FSM, RabbitMQ consumer, API communication
