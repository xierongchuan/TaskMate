# CLAUDE.md

Инструкции для Claude Code при работе с TaskMate.

## О проекте

TaskMate — система управления задачами для автосалонов (на русском языке).

**Технологический стек:**

| Компонент | Технология | Версия |
|-----------|------------|--------|
| Frontend | React + TypeScript + Vite + Tailwind | 19.1.1 / 5.9.3 / 7.1.7 / 3.4.18 |
| Backend | Laravel + PHP | 12.0 / 8.4 |
| Database | PostgreSQL | 18.1 |
| Cache/Queue | Valkey (Redis-compatible) | 9.0.1 |
| Message Queue | RabbitMQ | 4.x |
| Auth | Laravel Sanctum | 4.2 |
| Testing | Pest PHP | 4.0 |

**Архитектура:** Monorepo с git submodules (`TaskMateClient/`, `TaskMateServer/`).

**Роли:** employee, observer, manager, owner (иерархия уровней: 1, 2, 3, 4).

**Типы задач:** notification, completion, completion_with_proof.

**Типы задач по структуре:** individual (один исполнитель), group (несколько).

## Быстрый старт

```bash
# Запуск всех сервисов
docker compose up -d --build

# Инициализация backend (первый запуск)
docker compose exec backend_api composer install
docker compose exec backend_api php artisan migrate --force
docker compose exec backend_api php artisan db:seed-demo
docker compose exec backend_api php artisan storage:link

# Тесты backend (ОБЯЗАТЕЛЬНО после изменений)
docker compose exec backend_api php artisan test
```

**Access Points (Development):**

| Сервис | URL | Описание |
|--------|-----|----------|
| Frontend | http://localhost:8099 | React SPA |
| Backend API | http://localhost:8007 | Laravel API |
| RabbitMQ UI | http://localhost:15672 | Queue management |
| PgAdmin | http://localhost:8081 | Database UI (profile: dev) |
| PostgreSQL | localhost:5432 | Database |
| Valkey | localhost:6379 | Cache/Sessions |

**Demo credentials:** admin/password, manager1/password, emp1_1/password

## Docker сервисы

```yaml
# Основные
taskmate_postgres       # PostgreSQL 18.1 (БД + test DB)
taskmate_valkey         # Valkey 9.0.1 (кеш, сессии)
taskmate_rabbitmq       # RabbitMQ 4.x (очереди)
taskmate_src_frontend   # React frontend (Nginx)
taskmate_backend_api    # Laravel API (FrankenPHP)

# Фоновые задачи
taskmate_backend_scheduler     # Supervisor (cron + scheduler)
taskmate_worker_cleanup        # Очередь: file_cleanup
taskmate_worker_proof_upload   # Очередь: proof_upload
taskmate_worker_shared_proof   # Очередь: shared_proof_upload
taskmate_worker_generators     # Очередь: task_generators

# Инфраструктура
taskmate_nginx          # Reverse proxy
taskmate_certbot        # SSL сертификаты (prod)
taskmate_pgadmin        # PostgreSQL UI (dev only)
```

## Правила разработки

### Обязательные требования

1. **Язык**: Русский для UI, комментариев, документации
2. **Docker**: Все команды через Docker контейнеры
3. **Тесты**: ВСЕГДА запускать `docker compose exec backend_api php artisan test` после изменений backend
4. **Синхронизация**: При изменении Backend — проверять Frontend, и наоборот
5. **PostgreSQL only**: Не MySQL-совместимый синтаксис
6. **Минимум 50% покрытия тестами** для backend
7. **Даты в UTC**: Все даты хранятся и передаются в UTC (ISO 8601 с Z суффиксом)

### Backend

- Controllers → `toApiArray()` методы моделей для форматирования
- Form Requests для валидации (`app/Http/Requests/Api/V1/`)
- Service layer для бизнес-логики (`TaskService`, `TaskFilterService`, `TaskProofService`, `TaskVerificationService`)
- Eager loading для предотвращения N+1 (все контроллеры используют `with()`)
- SoftDeletes на User, Task, TaskAssignment
- Приватные файлы: `storage/app/private/task_proofs/`, доступ через подписанные URL (60 мин)
- Trait `Auditable` для автоматического логирования изменений

### Frontend

- UI компоненты из `components/ui/` (Button, Card, Modal, Badge, etc.)
- `usePermissions()` для проверки ролей (canManageTasks, canCreateUsers, etc.)
- `placeholderData: (prev) => prev` в TanStack Query для предотвращения мигания
- Zustand для client state (authStore, workspaceStore, sidebarStore)
- TanStack Query для server state
- API модули в `src/api/` (15 модулей)
- ThemeContext для dark/light mode + accent colors

## Архитектура

### Аутентификация

```
Bearer token (Sanctum) → localStorage (Zustand authStore)
    → Axios interceptors (auto header) → API
    → 401: logout + redirect /login
    → 403: log "Недостаточно прав"
    → 429: Rate limit toast + retry
```

### Multi-tenant (Dealerships)

- Каждый автосалон имеет свой `timezone` (для обработки календарных дней)
- `workspaceStore` хранит выбранный `dealershipId`
- Employee: только свой автосалон
- Manager/Observer: назначенные автосалоны
- Owner: все автосалоны или конкретный

### Загрузка файлов (completion_with_proof)

- До 5 файлов, max 200MB total
- Форматы: JPG/PNG/GIF/WebP (5MB), MP4/MOV (100MB), PDF/ZIP (50MB)
- Приватное хранилище + подписанные URL (60 мин)
- Валидация содержимого (magic bytes, не только расширение)
- Асинхронное сохранение через Jobs

### Фоновые задачи

**Jobs (через RabbitMQ):**

| Job | Очередь | Описание |
|-----|---------|----------|
| ProcessTaskGeneratorsJob | task_generators | Генерация задач из шаблонов (каждые 5 мин) |
| StoreTaskProofsJob | proof_upload | Сохранение файлов доказательств |
| StoreTaskSharedProofsJob | shared_proof_upload | Сохранение общих файлов |
| DeleteProofFileJob | file_cleanup | Удаление файлов |

**Commands (через Scheduler):**

| Команда | Расписание | Описание |
|---------|------------|----------|
| tasks:archive-completed | каждые 10 мин | Архивация завершённых задач |
| tasks:archive-overdue-after-shift | каждый час | Архивация просроченных после смены |
| cleanup:temp-proofs | каждый час | Очистка временных файлов |

### API Endpoints

Base: `/api/v1`

| Группа | Endpoints | Доступ |
|--------|-----------|--------|
| /session | login, logout, current | public / auth |
| /users | CRUD, status | read: all, write: manager/owner |
| /dealerships | CRUD | read: all, write: owner |
| /shifts | CRUD, current, statistics, photos | auth |
| /tasks | CRUD, status, proofs | read: all, write: manager/owner |
| /task-generators | CRUD, pause/resume, stats | manager/owner |
| /task-responses | approve, reject | manager/owner |
| /task-proofs | download, delete | auth |
| /archived-tasks | list, restore, export | manager/owner |
| /settings | configs (shift, notification, archive, task) | read: all, write: owner |
| /calendar | CRUD holidays/workdays | manager/owner |
| /dashboard | statistics | auth |
| /reports | analytics | manager/owner |
| /audit-logs | history | owner |
| /links | important links | auth |
| /notification-settings | CRUD | manager/owner |
| /config/file-upload | upload limits | public |

## Команды

```bash
# Backend
docker compose exec backend_api php artisan test          # Все тесты
docker compose exec backend_api composer test:coverage    # С покрытием (min 50%)
docker compose exec backend_api vendor/bin/pint          # Форматирование кода

# Frontend
cd TaskMateClient && npm run dev      # Dev server
cd TaskMateClient && npm run build    # Production build
cd TaskMateClient && npm run lint     # ESLint

# Production deploy
./deploy_prod.sh --pull --init        # Первый деплой
./deploy_prod.sh --pull               # Обновление
```

## Workflow задач

### Создание задачи

```
Manager/Owner создаёт Task
  → TaskService::createTask()
  → TaskAssignments для исполнителей
  → Status: pending
```

### Выполнение (completion_with_proof)

```
Employee загружает файлы → PATCH /tasks/{id}/status
  → TaskProofService::storeProofs()
  → TaskResponse.status = pending_review
```

### Верификация

```
Manager проверяет → POST /task-responses/{id}/approve или /reject
  → TaskVerificationService::approve() / reject()
  → TaskVerificationHistory записывается
  → При reject: файлы удаляются, rejection_count++
```

### Архивация

```
Command tasks:archive-completed
  → Проверяет archive_completed_time из Settings
  → Task.is_active = false, archived_at = now()
  → archive_reason = 'completed' | 'expired'
```

## Ключевые модели

| Модель | Описание | Traits |
|--------|----------|--------|
| User | Пользователи (4 роли) | HasApiTokens, SoftDeletes, Auditable |
| AutoDealership | Автосалоны (timezone) | Auditable |
| Task | Задачи | SoftDeletes, Auditable |
| TaskResponse | Ответы на задачи | - |
| TaskProof | Файлы доказательств | - |
| TaskSharedProof | Общие файлы (group tasks) | - |
| TaskGenerator | Шаблоны генерации | Auditable |
| Shift | Смены (open/closed) | - |
| Setting | Системные настройки | - |
| CalendarDay | Выходные/рабочие дни | - |
| AuditLog | Журнал изменений | - |

## Дополнительная документация

- [TaskMateClient/CLAUDE.md](TaskMateClient/CLAUDE.md) — детальная архитектура frontend
- [TaskMateServer/CLAUDE.md](TaskMateServer/CLAUDE.md) — детальная архитектура backend
- [README.md](README.md) — общее описание проекта
