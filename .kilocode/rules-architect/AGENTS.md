# AGENTS.md — Architect Mode

This file provides non-obvious architectural constraints for this codebase.

## Architecture Overview

### Monorepo with Git Submodules
```
TaskMate/
├── TaskMateClient/     # React 19 + TypeScript + Vite
├── TaskMateServer/     # Laravel 12 + PHP 8.4
├── TaskMateTelegramBot/ # Python aiogram 3
├── docker-compose.yml  # Infrastructure
└── AGENTS.md
```

## Critical Architectural Decisions

### 1. UTC-Only Dates
- All dates stored/transmitted in UTC (ISO 8601 with Z suffix)
- Backend: `TimeHelper` in `app/Helpers/TimeHelper.php`
- Frontend: `dateTime.ts` utilities
- Each dealership has its own timezone for display purposes only

### 2. Multi-Tenant with Dealership Timezone
- `AutoDealership` entity has `timezone` field
- Date comparisons use `TimeHelper::dayBoundariesForTimezone($timezone)`
- Frontend displays in user's local timezone

### 3. Two-Layer State Management
- **Zustand** — Client state (auth, workspace, sidebar), persisted in localStorage
- **TanStack Query** — Server state with `dealershipId` in queryKey

### 4. Backend Layered Architecture
- Controller → Service → Model
- Models use `toApiArray()` for API responses
- Form Requests for validation (`app/Http/Requests/Api/V1/`)
- Eager loading mandatory (`->with(['relations'])`)

### 5. File Storage
- Private disk `task_proofs` in `storage/app/private/task_proofs/`
- Access via signed URLs (60-minute expiry)
- `TaskProofService` handles uploads

### 6. Queue Workers (RabbitMQ)
- `ProcessTaskGeneratorsJob` — Task generation from templates
- `StoreTaskProofsJob` — Async file uploads
- `StoreTaskSharedProofsJob` — Group task files
- `DeleteProofFileJob` — File cleanup

## Service URLs
- Frontend: http://localhost:8099
- Backend API: http://localhost:8007
- RabbitMQ UI: http://localhost:15672

## Demo Credentials
admin/password, manager1/password, emp1_1/password
