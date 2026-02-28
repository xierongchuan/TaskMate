# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Architecture

Monorepo with git submodules:
- **Client**: `TaskMateClient/` — React 19 + TypeScript + Vite + Tailwind + Capacitor (mobile app)
- **Server**: `TaskMateServer/` — Laravel 12 + PHP 8.4 + PostgreSQL 18
- **Telegram Bot**: `TaskMateTelegramBot/` — Python 3.12 + aiogram 3
- **Infrastructure**: Root — podman compose + Nginx + Valkey + RabbitMQ

## Critical Non-Obvious Rules

1. **Docker-based development** — npm/node/composer/php are NOT installed on host. ALL commands run through containers:
   - Backend: `podman compose exec api <command>`
   - Frontend: `podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine <command>`
   - Android: `podman compose --profile android exec android-builder <command>`

2. **UTC-only dates** — All dates stored/transmitted in UTC (ISO 8601 with Z suffix). Backend uses `TimeHelper` (`app/Helpers/TimeHelper.php`), frontend uses `dateTime.ts` utilities.

3. **Role hierarchy** — employee(1) → observer(2) → manager(3) → owner(4). Number = access level.

4. **Multi-tenant with timezone** — Each AutoDealership has its own timezone. All date comparisons in backend use dealership's timezone via `TimeHelper::dayBoundariesForTimezone()`.

5. **Language** — Russian for UI, comments, documentation. Code in English.

6. **Tests mandatory** — Always run `podman compose exec api php artisan test` after backend changes.

7. **PostgreSQL only** — Do not use MySQL-compatible syntax (GROUP BY without aggregation, use COALESCE not IFNULL).

## Security Rules

1. **Security First** — Security must be a priority when writing any code. All user data must be validated and sanitized.

2. **XSS Prevention (Cross-Site Scripting)**
   - Never output unvalidated user data directly to HTML
   - For API responses, Laravel's `response()->json()` automatically escapes strings
   - Validate and sanitize all input data

3. **SQL Injection Prevention**
   - ALWAYS use parameterized queries (bindings)
   - NEVER use concatenation to build SQL queries
   - Use Eloquent ORM or Query Builder with parameter bindings

4. **CSRF Protection**
   - Laravel uses Sanctum for API authentication (token-based)
   - For SPA/mobile clients: Sanctum automatically handles CSRF via cookies
   - Ensure `SANCTUM_STATEFUL_DOMAINS` is configured correctly

5. **Access Control and Authorization**
   - Check permissions at every layer (client + server)
   - Use Policy classes in Laravel
   - Never trust client data without validation

6. **Secure File Handling**
   - Prevent execution of uploaded files
   - Validate MIME type and file extension
   - Use secure paths for storage (outside web root)
   - Generate random filenames when saving

7. **Session and Authentication Management**
   - API-first: Use Laravel Sanctum with token-based authentication
   - Use secure cookies with `HttpOnly`, `Secure`, `SameSite` flags for SPA
   - Implement token expiration and refresh mechanisms
   - Use bcrypt/argon2 for password hashing

8. **Memory Leak Prevention**
   - Clean up event subscriptions and listeners
   - Use WeakMap/WeakSet for caches in JavaScript
   - Clear timers and intervals on component unmount
   - Avoid closures that capture large objects

9. **Memory Overflow Prevention**
   - Limit uploaded file sizes
   - Use pagination for large database queries
   - Process data in streams for large files
   - Set limits on number of records in queries

10. **Privilege Escalation Prevention**
    - Never execute commands with root privileges unless absolutely necessary
    - Use Principle of Least Privilege
    - Avoid using `eval()`, `exec()`, `system()` with user data
    - Check permissions before executing privileged operations

11. **Arbitrary Code Execution (RCE Prevention)**
    - NEVER use `eval()`, `exec()`, `shell_exec()` with user data
    - Use whitelist approach for parameter validation
    - Validate and sanitize all input data before using in system calls

12. **API Security**
    - Use rate limiting for DDoS protection
    - Validate Content-Type for all requests
    - Limit request body size
    - Return only necessary data (don't expose internal structures)

## Commands

```bash
# Backend
podman compose exec api php artisan test
podman compose exec api composer test:coverage
podman compose exec api vendor/bin/pint

# Client
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run build
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run lint

# Deploy
./scripts/deploy_prod.sh --pull --init   # first time
./scripts/deploy_prod.sh --pull          # update
```

## Demo Credentials

admin/password, manager1/password, emp1_1/password

## Service URLs

- Frontend: http://localhost:8099
- Backend API: http://localhost:8007
- RabbitMQ UI: http://localhost:15672
