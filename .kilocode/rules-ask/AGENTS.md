# AGENTS.md — Ask Mode

This file provides non-obvious documentation context for this codebase.

## Project Structure

### Modules
- **TaskMateClient/** — React 19 frontend (SPA)
- **TaskMateServer/** — Laravel 12 REST API
- **TaskMateTelegramBot/** — Python aiogram bot
- **docker-compose.yml** — Infrastructure (PostgreSQL, Valkey, RabbitMQ, Nginx)

### Key Directories

#### Backend
- `app/Http/Controllers/Api/V1/` — 18 REST controllers
- `app/Services/` — 11 business logic services
- `app/Models/` — 19 Eloquent models
- `app/Jobs/` — RabbitMQ jobs
- `app/Helpers/TimeHelper.php` — UTC date utilities

#### Frontend
- `src/api/` — Axios API modules
- `src/components/ui/` — Reusable UI components
- `src/hooks/` — Custom React hooks
- `src/stores/` — Zustand state stores
- `src/utils/dateTime.ts` — Date conversion utilities

## Domain Model

### Roles (access level in parentheses)
- employee (1), observer (2), manager (3), owner (4)

### Task Types
- notification, completion, completion_with_proof

### Task Structure
- individual, group

### Multi-tenant
- Each AutoDealership has its own timezone
- All date comparisons use dealership's timezone via `TimeHelper::dayBoundariesForTimezone()`

## API Endpoints

Base URL: http://localhost:8007/api/v1

- Tasks: `/tasks`, `/tasks/{id}`
- Users: `/users`, `/users/{id}`
- Dealerships: `/dealerships`
- Shifts: `/shifts`
- Reports: `/reports`

## Documentation

- Backend API: `TaskMateServer/swagger.yaml`
- Full specs: `TaskMateServer/ТЗ_TaskMateServer.md`
