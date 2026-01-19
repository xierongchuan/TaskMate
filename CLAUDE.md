# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TaskMate is a Russian-language task management system for automotive dealerships with:
- **Frontend**: React 19 + TypeScript 5.9 + Vite 7 + Tailwind CSS (`TaskMateFrontend/`)
- **Backend**: Laravel 12 + PHP 8.4 + PostgreSQL + FrankenPHP (`TaskMateBackend/`)
- **API Collection**: Bruno HTTP client collection (`TaskMateAPI/`)

The system includes a Telegram bot integration, role-based access control (employee, observer, manager, owner), and multi-tenant dealership management.

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
- Form Requests handle validation
- Service layer for complex business logic
- Eager loading to prevent N+1 queries

## Important Constraints

- **Russian language** throughout UI text and comments
- **PostgreSQL only** (not MySQL-compatible)
- **Minimum 50% test coverage** for backend
- **Bearer token authentication** via Laravel Sanctum (no sessions)
- Always run `php artisan test` before committing backend changes

## Additional Documentation

- [TaskMateFrontend/CLAUDE.md](TaskMateFrontend/CLAUDE.md) - Frontend architecture details
- [TaskMateBackend/CLAUDE.md](TaskMateBackend/CLAUDE.md) - Backend architecture and bot details
- [TaskMateBackend/README_WORKERS.md](TaskMateBackend/README_WORKERS.md) - Background job processing
