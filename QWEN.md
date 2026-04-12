# QWEN.md — TaskMate

Система управления задачами для автосалонов.

## Обзор проекта

TaskMate — монорепозиторий с git submodules, включающий backend (Laravel 12), frontend (React 19), Telegram-бот (Python 3.12) и инфраструктуру (Podman Compose). Система поддерживает multi-tenant архитектуру с индивидуальными timezone для каждого автосалона, роли сотрудников (employee → observer → manager → owner), и workflow задач с верификацией и загрузкой доказательств.

## Архитектура

| Модуль | Путь | Стек |
|--------|------|------|
| **Backend** | `TaskMateServer/` | Laravel 12 · PHP 8.4 · PostgreSQL 18 · FrankenPHP |
| **Frontend** | `TaskMateClient/` | React 19 · TypeScript 5.9 · Vite 7.3 · Tailwind 3.4 |
| **Telegram Bot** | `TaskMateTelegramBot/` | Python 3.12 · aiogram 3 · httpx · APScheduler · Valkey |
| **Инфраструктура** | корень | Podman Compose · Nginx 1.27 · Valkey 9.0 · RabbitMQ 4 |

### Docker-сервисы

| Сервис | Контейнер | Описание |
|--------|-----------|----------|
| PostgreSQL | `svc-postgres` | Основная БД |
| Valkey | `svc-valkey` | Кэш и сессии |
| RabbitMQ | `svc-rabbitmq` | Очереди задач |
| Frontend | `svc-frontend` | React SPA |
| API | `svc-api` | Laravel REST API |
| Scheduler | `svc-scheduler` | Supervisor + cron |
| Workers | `svc-worker-{cleanup,proof,shared,generator,shifts}` | Фоновые обработчики |
| Nginx | `svc-nginx` | Reverse proxy |
| Telegram Bot | `svc-telegram-bot` + `svc-telegram-bot-worker` | Бот |
| Certbot | `svc-certbot` | SSL сертификаты (profile: certbot) |
| Android Builder | `android-builder` (profile: android) | Сборка APK |

## Команды

**ВАЖНО:** npm/node/composer/php НЕ установлены на хосте. ВСЕ команды запускаются через контейнеры.

### Быстрый старт

```bash
podman compose up -d --build
# Инициализация (первый раз)
podman compose exec api composer install
podman compose exec api php artisan migrate --force
podman compose exec api php artisan db:seed-demo
podman compose exec api php artisan storage:link
```

Demo-доступ: `admin/password`, `manager1/password`, `emp1_1/password`

### Backend (PHP/Laravel)

```bash
# Все тесты
podman compose exec api php artisan test
# Один тест-класс
podman compose exec api php artisan test --filter=TaskControllerTest
# Один тест-метод
podman compose exec api php artisan test --filter="TaskControllerTest::test_user_can_create_task"
# Покрытие (мин. 50%)
podman compose exec api composer test:coverage
# Форматирование
podman compose exec api php vendor/bin/pint           # авто-исправление
podman compose exec api php vendor/bin/pint --test    # проверка
```

### Frontend (React/TypeScript)

```bash
# Dev / Build / Lint
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run dev
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run build
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run lint
# Установка пакета
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm install <pkg>
```

### E2E тесты (Playwright)

```bash
# Требует запущенных svc-frontend, svc-api, svc-nginx
podman run --rm --network host -v ./TaskMateClient:/app:z -w /app mcr.microsoft.com/playwright:v1.58.0-noble npx playwright test
# Один файл
podman run --rm --network host -v ./TaskMateClient:/app:z -w /app mcr.microsoft.com/playwright:v1.58.0-noble npx playwright test dashboard
```

### Android (Capacitor 8)

```bash
# Первая сборка образа
podman compose --profile android build android-builder
# Debug APK
./scripts/build-android.sh
# Release APK
./scripts/build-android.sh --release
# С установкой на устройство
ADB_CONNECT=192.168.1.XX:YYYYY ./scripts/build-android.sh --deploy
```

### Деплой

```bash
./scripts/deploy_prod.sh --pull --init   # первый раз
./scripts/deploy_prod.sh --pull          # обновление
```

### Утилиты

```bash
# Пересборка frontend (обходит кеш Docker)
./scripts/rebuild-frontend.sh
# Настройка прав для rootless Podman
./scripts/fix-permissions.sh
```

## Доменная модель

### Роли

`employee` (1) → `observer` (2) → `manager` (3) → `owner` (4). Число = уровень доступа.

### Типы задач

| Тип | Описание |
|-----|----------|
| `notification` | Уведомление без ответа |
| `completion` | Требует отметки о выполнении |
| `completion_with_proof` | Требует загрузки доказательств (до 5 файлов, 200MB) |

### Workflow задач

```
Создание:   Manager/Owner → TaskService::createTask() → status: pending
Выполнение: Employee → PATCH /tasks/{id}/status + proof_files → pending_review
Проверка:   Manager → POST /task-responses/{id}/approve|reject
Архивация:  Scheduler → tasks:archive-completed (каждые 10 мин)
```

### Структура задач

- **individual** — назначается одному сотруднику
- **group** — назначается группе сотрудников

### Фоновые процессы

| Процесс | Интервал | Описание |
|---------|----------|----------|
| `ProcessTaskGeneratorsJob` | 5 мин | Генерация задач из шаблонов |
| `tasks:archive-completed` | 10 мин | Архивация выполненных задач |
| `tasks:archive-overdue-after-shift` | 1 час | Архивация просроченных после смены |
| `proofs:cleanup-temp` | 1 час | Очистка временных файлов доказательств |

## Работа с датами и временем

### Гибридный подход: UTC + Timezone

| Тип данных | Хранение | Пример |
|------------|----------|--------|
| Моменты времени (deadline, created_at) | UTC | `2026-01-27T10:00:00Z` |
| Календарные дни (выходные, праздники) | Дата + timezone автосалона | `2026-01-27` + `+05:00` |

### Приоритет timezone

1. Timezone автосалона (`auto_dealerships.timezone`)
2. Глобальный timezone (`settings.global_timezone`)
3. Дефолт: `+05:00`

### Backend

- `TimeHelper::nowUtc()`, `TimeHelper::toIsoZulu()`, `TimeHelper::dayBoundariesForTimezone()` — все операции в UTC
- `SettingsService::getTimezone()` — получение timezone с fallback

### Frontend

- `src/utils/dateTime.ts` — `formatDateTime()`, `toUtcIso()`, `parseUtcDate()`, `utcToDatetimeLocal()`, `datetimeLocalToUtc()`

## Обязательные правила

1. **Docker only** — ВСЕ команды через контейнеры
2. **UTC даты** — Хранение/передача/сравнение в UTC (ISO 8601, Z суффикс)
3. **PostgreSQL** — COALESCE (не IFNULL), без GROUP BY без агрегации
4. **Тесты обязательны** — Минимум 50% покрытие, запускать после backend-изменений
5. **Язык** — Русский для UI/комментов/доков. Код на английском
6. **Синхронизация** — API изменения на backend → проверять frontend, и наоборот
7. **SOLID** — Строгое соблюдение
8. **Безопасность** — Параметризованные SQL, валидация ввода, никаких exec/eval/shell_exec с пользовательскими данными

### Запрещённые паттерны

- MySQL SQL (IFNULL, GROUP BY без агрегации)
- Даты не в UTC
- Прямой доступ к хранилищу — используй `task_proofs` disk + signed URLs (60 мин)
- Логика в контроллерах — переносить в Services
- Модели без eager loading
- `user.role === 'owner'` — использовать `usePermissions()`
- Серверные данные в Zustand — использовать TanStack Query
- `keepPreviousData` — использовать `placeholderData: (prev) => prev`
- Прямой axios — использовать API модули из `src/api/`
- Синхронный код в Telegram-боте — только async

## Стиль кода

### Backend (PHP/Laravel)

- **Архитектура:** Controller → Service → Model (тонкие контроллеры)
- **Валидация:** Form Requests в `app/Http/Requests/Api/V1/`. Никакого `$request->validate()` в контроллерах
- **Eager loading:** Обязателен. `Task::with(['creator', 'assignments.user'])->get()`
- **Ответы:** `toApiArray()` на моделях (не API Resources, кроме User/Shift). UTC даты с Z суффиксом
- **Именование:** Контроллеры `PascalCaseController`, сервисы `PascalCaseService`, БД snake_case, PHP camelCase
- **Импорты:** Группы — PHP std, vendor, App. Алфавит внутри групп. Без неиспользованных
- **Ошибки:** Типизированные исключения в сервисах; `abort(4xx)` для auth/validation

### Frontend (React/TypeScript)

- **State:** Zustand — клиентский state (auth, workspace, sidebar, localStorage). TanStack Query — серверные данные (queryKey с `dealershipId`, `placeholderData: (prev) => prev`)
- **Разрешения:** ВСЕГДА `usePermissions()`. НИКОГДА не проверять `user.role` напрямую
- **API:** Модули из `src/api/`. НИКОГДА не использовать axios напрямую
- **Именование:** Компоненты `PascalCase`, хуки `useCamelCase`, утилиты `camelCase`, файлы `kebab-case.tsx` / `camelCase.ts`
- **Импорты:** `@/` алиасы. Порядок: React, внешние, `@/`, относительные. Пустая строка между группами
- **Типы:** `interface` для объектов, `type` для union/intersection. Никакого `any`

### Telegram Bot (Python)

- **Async везде** — aiogram, httpx, redis.asyncio. Синхронный код запрещён
- **Только API** — Никакого прямого доступа к БД. Всё через REST `/api/v1/*`
- **FSM** — Для многошаговых процессов (загрузка доказательств, авторизация)
- **Ошибки:** Перехват httpx ошибок, логирование через structlog, user-friendly сообщения на русском

## Сервисы

| Сервис | URL |
|--------|-----|
| Frontend | http://localhost:8099 |
| Backend API | http://localhost:8007 |
| RabbitMQ UI | http://localhost:15672 |

## Траблшутинг

| Проблема | Решение |
|----------|---------|
| Permission denied (storage) | `podman compose down && podman compose up -d --build` |
| CORS 403 / Permission denied (rootless Podman) | `./scripts/fix-permissions.sh` затем `podman compose restart svc-api` |
| Изменения не применяются в worker | `podman compose build --no-cache && podman compose up -d` |
| Database connection refused | Проверьте `DB_HOST=postgres` в `.env` |
| Изменения frontend не применяются (submodule) | `./scripts/rebuild-frontend.sh` |
| CSS/Tailwind изменения не применяются | Удалить образ: `podman rmi localhost/svc-frontend:latest`, затем `podman compose build --no-cache src_frontend` |

## Скрипты

| Скрипт | Описание |
|--------|----------|
| `scripts/build-android.sh` | Сборка Android APK |
| `scripts/fix-permissions.sh` | Настройка ACL для rootless Podman |
| `scripts/rebuild-frontend.sh` | Пересборка frontend без кеша Docker |
| `scripts/rebuild-telegram-bot.sh` | Пересборка Telegram-бота |
| `scripts/deploy_prod.sh` | Деплой в production |
