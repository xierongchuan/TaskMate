# CLAUDE.md

Инструкции для Claude Code при работе с TaskMate.

## О проекте

TaskMate — система управления задачами для автосалонов (на русском языке).

- **Frontend**: React 19 + TypeScript + Vite + Tailwind (`TaskMateFrontend/`)
- **Backend**: Laravel 12 + PHP 8.4 + PostgreSQL (`TaskMateBackend/`)

Роли: employee, observer, manager, owner. Типы задач: notification, completion, completion_with_proof.

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

**Access Points:**

- Frontend: <http://localhost:8099>
- Backend API: <http://localhost:8007>
- Demo: admin/password, manager1/password, emp1_1/password

## Правила разработки

### Обязательные требования

1. **Язык**: Русский для UI, комментариев, документации
2. **Docker**: Все команды через Docker контейнеры
3. **Тесты**: ВСЕГДА запускать `docker compose exec backend_api php artisan test` после изменений backend
4. **Синхронизация**: При изменении Backend — проверять Frontend, и наоборот
5. **PostgreSQL only**: Не MySQL-совместимый
6. **Минимум 50% покрытия тестами** для backend

### Backend

- Controllers → API Resources для форматирования ответов
- Form Requests для валидации (`app/Http/Requests/Api/V1/`)
- Service layer для бизнес-логики (`TaskService`, `TaskFilterService`, `TaskProofService`)
- Eager loading для предотвращения N+1
- SoftDeletes на User, AutoDealership, Task
- Приватные файлы: `storage/app/private/task_proofs/`, доступ через подписанные URL

### Frontend

- UI компоненты из `components/ui/`
- `usePermissions()` для проверки ролей
- `placeholderData: (prev) => prev` в TanStack Query
- Zustand для client state, TanStack Query для server state
- API модули в `src/api/`

## Архитектура

### Аутентификация

Bearer token через Laravel Sanctum → localStorage (Zustand authStore) → Axios interceptors → `usePermissions` hook

### Загрузка файлов (completion_with_proof)

- До 5 файлов, max 200MB
- Форматы: JPG/PNG/GIF/WebP, MP4/MOV, PDF/ZIP
- Приватное хранилище + подписанные URL (60 мин)
- Валидация содержимого (magic bytes)

### Фоновые задачи

- `SendScheduledTasksJob` (5 мин) — отправка задач по appear_date
- `CheckOverdueTasksJob` (10 мин) — просроченные задачи
- `CheckUpcomingDeadlinesJob` (15 мин) — напоминания о дедлайнах
- `SendDailySummaryJob` (20:00) — сводка для менеджеров
- `ArchiveOldTasksJob` (02:00) — архивация старых задач

### API Endpoints

Base: `/api/v1` — `/session`, `/users`, `/dealerships`, `/shifts`, `/tasks`, `/settings`, `/dashboard`

## Команды

```bash
# Backend
docker compose exec backend_api php artisan test          # Все тесты
docker compose exec backend_api composer test:coverage    # С покрытием
docker compose exec backend_api vendor/bin/pint          # Форматирование

# Frontend
cd TaskMateFrontend && npm run dev      # Dev server
cd TaskMateFrontend && npm run build    # Production build
cd TaskMateFrontend && npm run lint     # ESLint
```

## Дополнительная документация

- [TaskMateFrontend/CLAUDE.md](TaskMateFrontend/CLAUDE.md) — архитектура frontend
- [TaskMateBackend/CLAUDE.md](TaskMateBackend/CLAUDE.md) — архитектура backend
