# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TaskMate is a Russian-language task management system for automotive dealerships with:
- **Frontend**: React 19.1 + TypeScript 5.9 + Vite 7.1 + Tailwind CSS (`TaskMateFrontend/`)
- **Backend**: Laravel 12 + PHP 8.4 + PostgreSQL + FrankenPHP (`TaskMateBackend/`)

The system includes a role-based access control (employee, observer, manager, owner), multi-tenant dealership management, and three types of tasks:
- **notification** — information-only tasks
- **completion** — tasks requiring completion mark
- **completion_with_proof** — tasks requiring file uploads (photos/videos/docs) with manager verification workflow

## Development Commands

### Docker Environment (Recommended)

```bash
# Start all services
docker compose up -d --build

# Backend initialization (after first startup)
docker compose exec backend_api composer install
docker compose exec backend_api php artisan migrate --force
docker compose exec backend_api php artisan db:seed-demo
docker compose exec backend_api php artisan storage:link

# Run backend tests
docker compose exec backend_api php artisan test

# Run specific test suites
docker compose exec backend_api composer test:unit
docker compose exec backend_api composer test:feature
docker compose exec backend_api composer test:api
```

### Frontend Commands

```bash
cd TaskMateFrontend
npm run dev          # Development server (localhost:5173)
npm run build        # Production build
npm run lint         # ESLint checking
```

### Backend Commands (inside container or local)

```bash
# All tests
composer test

# Specific test suites
composer test:unit          # Unit tests only
composer test:feature       # Feature tests only
composer test:api           # API endpoint tests
composer test:coverage      # With coverage report (min 50%)

# Code formatting
vendor/bin/pint             # Laravel Pint
vendor/bin/php-cs-fixer fix # PHP CS Fixer
```

### Concurrent Development Mode

```bash
# From TaskMateBackend - runs server, queue, logs, and vite concurrently
composer dev
```

## Access Points

- **Frontend**: http://localhost:8099
- **Backend API**: http://localhost:8007
- **Demo login**: admin/password, manager1/password, emp1_1/password

## Technology Stack

### Frontend (`TaskMateFrontend`)

- **Framework**: React 19.1
- **Build Tool**: Vite 7.1
- **Language**: TypeScript 5.9
- **State Management**: Zustand 5
- **Styling**: TailwindCSS 3.4
- **Routing**: React Router 7.9
- **API/Query**: TanStack Query (React Query) v5
- **Forms**: React Hook Form
- **Icons**: Heroicons

### Backend (`TaskMateBackend`)

- **Framework**: Laravel 12
- **Language**: PHP 8.4
- **API Auth**: Laravel Sanctum
- **Cache/Queue**: Valkey (Redis-compatible) via Predis
- **Testing**: Pest PHP
- **Database**: PostgreSQL 18

### Infrastructure

- **Containerization**: Docker Compose
- **Application Server**: FrankenPHP v1 (Caddy-based)
- **Reverse Proxy**: Nginx (frontend + SSL termination)
- **Database**: PostgreSQL 18
- **Cache**: Valkey (Redis-compatible)
- **SSL**: Certbot (Let's Encrypt)

## Project Structure

- `TaskMateFrontend/`: Исходный код веб-приложения (React)
- `TaskMateBackend/`: Исходный код бэкенда REST API (Laravel)
- `nginx/`: Конфигурации Nginx для dev и prod
- `docker-compose*.yml`: Оркестрация контейнеров

## Architecture

### Authentication Flow
1. Frontend authenticates via `/api/v1/session` → receives Bearer token
2. Token stored in localStorage via Zustand authStore
3. Axios interceptors attach token to all requests
4. Protected routes check roles via `usePermissions` hook

### State Management
- **Client state**: Zustand stores (e.g., `authStore.ts`)
- **Server state**: TanStack Query v5 with `placeholderData` for UX optimization
- Query invalidation on mutations maintains data consistency

### File Upload & Security
- **Task proofs**: Private storage (`task_proofs` disk) for completion_with_proof tasks
- **Limits**: Up to 5 files, max 200MB total per task
- **Formats**: Images (JPG/PNG/GIF/WebP), Video (MP4/MOV), Documents (PDF/ZIP)
- **Security**:
  - Files stored in private directory (not web-accessible)
  - Signed temporary URLs (60 min expiration)
  - Triple-layer auth: URL signature + Bearer token + access control
  - Content validation (getimagesize, magic bytes for PDF/ZIP)
  - Transactional upload with rollback on errors
- **S3-ready**: Can migrate to S3-compatible storage (AWS S3, DigitalOcean Spaces, MinIO, Yandex Object Storage)

### Background Processing
Queue workers handle notifications and scheduled tasks via Valkey (Redis-compatible):
- `SendScheduledTasksJob` (every 5 min) - sends tasks when appear_date arrives
- `CheckOverdueTasksJob` (every 10 min) - marks overdue, notifies users
- `CheckUpcomingDeadlinesJob` (every 15 min) - deadline reminders
- `SendDailySummaryJob` (daily 20:00) - manager summaries
- `ArchiveOldTasksJob` (daily 02:00) - cleanup old completed tasks

### API Endpoints
Base URL: `/api/v1`
- `/session` - Authentication
- `/users` - User management with pagination
- `/dealerships` - Dealership CRUD
- `/shifts` - Shift management with photos
- `/tasks` - Task management with filtering
- `/settings` - System configuration
- `/dashboard` - Analytics

## Key Patterns

### Frontend
- Use Unified UI components from `components/ui/` (Button, Card, Input, Badge, etc.)
- Use `usePermissions()` hook for role-based rendering
- Use `placeholderData: (prev) => prev` in TanStack Query to prevent loading flashes
- Follow existing API module patterns in `src/api/`

### Backend
- Controllers return API Resources for consistent response formatting
- Form Requests handle validation (`app/Http/Requests/Api/V1/`)
- Service layer for complex business logic:
  - `TaskService` — создание, обновление задач, проверка дубликатов
  - `TaskFilterService` — фильтрация задач по параметрам
  - `TaskProofService` — загрузка и валидация доказательств выполнения
  - `DashboardService` — оптимизированные запросы для дашборда
  - `ShiftService` — управление сменами
  - `SettingsService` — системные настройки
- Custom exceptions (`DuplicateTaskException`, `AccessDeniedException`)
- Eager loading to prevent N+1 queries
- SoftDeletes на ключевых моделях (User, AutoDealership, Task)

## Important Constraints

- **Язык**: Русский (UI, комментарии, документация)
- **PostgreSQL only** (not MySQL-compatible)
- **Minimum 50% test coverage** for backend
- **Bearer token authentication** via Laravel Sanctum (no sessions)

## Правила разработки (User Rules)

### Общие правила

1. **Язык**: Русский для всех UI, комментариев и документации
2. **Работа с инструментами**: При работе с инструментами окружения используй всё через Docker контейнеры

### Backend

1. **ВСЕГДА** запускать тесты при любых изменениях: `docker compose exec backend_api php artisan test` (193 теста)
2. Проверять актуальность существующих тестов при изменении логики
3. Обновлять README.md после успешного внедрения изменений
4. Приватные файлы хранятся в `storage/app/private/task_proofs/`, доступ через подписанные URL
5. Система готова к миграции на S3 (см. `config/filesystems.php`)
6. Минимальное покрытие тестами: 50%
7. PostgreSQL only (не MySQL-совместимый)

### Frontend & API

1. При изменении Backend **обязательно** проверять совместимость с Frontend и документацией API
2. При изменении Frontend сверяться с документацией API и проверять корректность запросов
3. Поддерживать синхронизацию между Backend, Frontend и API-коллекцией

### Development Workflow

1. Используй Docker для запуска всех сервисов: `docker compose up -d --build`
2. Backend тесты: `docker compose exec backend_api php artisan test`
3. Для разработки с автоперезагрузкой: `composer dev` (внутри контейнера)

## Additional Documentation

- [TaskMateFrontend/CLAUDE.md](TaskMateFrontend/CLAUDE.md) - Frontend architecture details
- [TaskMateBackend/CLAUDE.md](TaskMateBackend/CLAUDE.md) - Backend architecture and bot details
- [TaskMateBackend/README_WORKERS.md](TaskMateBackend/README_WORKERS.md) - Background job processing
