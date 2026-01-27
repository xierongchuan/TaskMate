# TaskMate

Система управления задачами для автосалонов.

## Архитектура

```mermaid
flowchart TB
    subgraph Client["Frontend (React 19 + TypeScript)"]
        UI[UI Components]
        Zustand[Zustand Store]
        TanStack[TanStack Query]
        DateUtils[dateTime.ts<br/>UTC ↔ Local]
    end

    subgraph Server["Backend (Laravel 12 + PHP 8.4)"]
        API[REST API<br/>/api/v1]
        Controllers[Controllers]
        Services[Services<br/>TaskService<br/>SettingsService]
        Models[Eloquent Models]
        TimeHelper[TimeHelper<br/>UTC only]
        TZHelper[SettingsService<br/>getTimezone]
        Jobs[Jobs<br/>ProcessTaskGenerators<br/>ProcessRecurringTasks]
    end

    subgraph Infrastructure["Infrastructure"]
        FrankenPHP[FrankenPHP]
        Nginx[Nginx]
        Postgres[(PostgreSQL 18)]
        Valkey[(Valkey<br/>Cache + Queue)]
        Storage[Private Storage<br/>Signed URLs]
    end

    subgraph Workers["Background Workers"]
        Scheduler[Scheduler<br/>cron]
        QueueWorker[Queue Worker<br/>Supervisor]
    end

    UI --> TanStack
    TanStack --> DateUtils
    DateUtils -->|"UTC ISO 8601"| API
    Zustand --> UI

    Nginx --> FrankenPHP
    FrankenPHP --> API
    API --> Controllers
    Controllers --> Services
    Services --> Models
    Services --> TimeHelper
    Models --> TZHelper
    Models --> Postgres

    Jobs --> Valkey
    Scheduler --> Jobs
    QueueWorker --> Jobs

    Services --> Storage
```

## Работа с датами и временем

### Гибридный подход: UTC + Timezone для календарных дней

Система использует **гибридный подход** к работе с датами:

| Тип данных | Хранение | Пример |
|------------|----------|--------|
| **Моменты времени** (deadline, created_at) | UTC | `2026-01-27T10:00:00Z` |
| **Календарные дни** (выходные, праздники) | Дата + timezone автосалона | `2026-01-27` + `+05:00` |

```
┌─────────────┐    UTC ISO 8601     ┌─────────────┐
│   Frontend  │ ←─────────────────→ │   Backend   │
│ (браузер TZ)│  2026-01-27T10:00Z  │   (UTC)     │
└─────────────┘                     └─────────────┘
                                           │
                                           ▼
                              ┌────────────────────────┐
                              │ CalendarDay::isHoliday │
                              │ UTC → Dealership TZ    │
                              │ для определения даты   │
                              └────────────────────────┘
```

### Почему не чистый UTC?

**Проблема:** Календарные дни — это бизнес-концепция, привязанная к физическому расположению автосалона.

Пример: момент `2026-01-27T23:30:00Z` (UTC) — это:
- **27 января** в UTC+0 (Лондон)
- **28 января** в UTC+5 (Екатеринбург)

Если 28 января — выходной в Екатеринбурге, генератор задач не должен создавать задачи для этого момента, даже если по UTC это ещё 27-е число.

### Приоритет timezone

```
1. Timezone автосалона (auto_dealerships.timezone)
         ↓ если не задан
2. Глобальный timezone (settings.global_timezone)
         ↓ если не задан
3. Дефолт: +05:00
```

### Форматы данных

| Слой | Формат | Пример |
|------|--------|--------|
| API Request/Response | ISO 8601 + Z | `2026-01-27T10:00:00Z` |
| Database timestamps | UTC | `2026-01-27 10:00:00` |
| Database timezone | UTC offset | `+05:00` |
| Frontend Display | Local timezone | `27 янв 2026, 15:00` |

### Frontend утилиты (`src/utils/dateTime.ts`)

```typescript
// Отображение
formatDateTime(utcString)  // → "27 янв 2026, 15:00"
formatDate(utcString)      // → "27 янв 2026"
formatTime(utcString)      // → "15:00"

// Для input[type=datetime-local]
utcToDatetimeLocal(utcString)    // UTC → local для value
datetimeLocalToUtc(localString)  // local → UTC для отправки

// Для настроек времени (HH:mm)
utcTimeToLocal(timeString)   // "10:00" UTC → "15:00" local
localTimeToUtc(timeString)   // "15:00" local → "10:00" UTC
```

### Backend

- **TimeHelper** — все операции с моментами времени (UTC only)
- **SettingsService::getTimezone()** — получение timezone с fallback
- **CalendarDay::isHoliday()** — конвертирует UTC в timezone автосалона перед проверкой

## Быстрый старт

```bash
# Запуск
docker compose up -d --build

# Инициализация (первый раз)
docker compose exec backend_api composer install
docker compose exec backend_api php artisan migrate --force
docker compose exec backend_api php artisan db:seed-demo
docker compose exec backend_api php artisan storage:link
```

**Доступ:**
- Frontend: http://localhost:8099
- Backend API: http://localhost:8007
- Логин: `admin` / `password`

## Технологии

| Frontend | Backend | Infrastructure |
|----------|---------|----------------|
| React 19 | Laravel 12 | PostgreSQL 18 |
| TypeScript 5.9 | PHP 8.4 | Valkey (Redis) |
| Vite 7 | FrankenPHP | Nginx |
| Tailwind CSS 3.4 | Pest PHP | Docker |
| TanStack Query v5 | Sanctum | Supervisor |
| Zustand | | |

## Структура проекта

```
.
├── TaskMateClient/          # Frontend
│   ├── src/
│   │   ├── api/             # API клиенты
│   │   ├── components/      # React компоненты
│   │   │   └── ui/          # UI библиотека
│   │   ├── hooks/           # Custom hooks
│   │   ├── pages/           # Страницы
│   │   ├── stores/          # Zustand stores
│   │   ├── types/           # TypeScript типы
│   │   └── utils/           # Утилиты (dateTime.ts)
│   └── CLAUDE.md            # Документация frontend
│
├── TaskMateServer/          # Backend
│   ├── app/
│   │   ├── Http/
│   │   │   ├── Controllers/ # API контроллеры
│   │   │   └── Requests/    # Form Requests
│   │   ├── Models/          # Eloquent модели
│   │   ├── Services/        # Бизнес-логика
│   │   ├── Helpers/         # TimeHelper и др.
│   │   └── Jobs/            # Фоновые задачи
│   └── CLAUDE.md            # Документация backend
│
├── docker-compose.yml       # Docker конфигурация
└── CLAUDE.md                # Общие инструкции
```

## Типы задач

| Тип | Описание |
|-----|----------|
| `notification` | Уведомление без ответа |
| `completion` | Требует отметки о выполнении |
| `completion_with_proof` | Требует загрузки доказательств (до 5 файлов, 200MB) |

**Workflow верификации:** Employee → `pending_review` → Manager → `verified` / `rejected`

## Фоновые процессы

| Процесс | Интервал | Описание |
|---------|----------|----------|
| `ProcessTaskGeneratorsJob` | 5 мин | Генерация задач из шаблонов |
| `ProcessRecurringTasksJob` | 1 час | Создание повторяющихся задач |
| `tasks:archive-completed` | 10 мин | Архивация выполненных задач |
| `tasks:archive-overdue-after-shift` | 1 час | Архивация просроченных после смены |

## Разработка

```bash
# Backend тесты (ОБЯЗАТЕЛЬНО после изменений)
docker compose exec backend_api php artisan test

# Frontend dev server
cd TaskMateClient && npm run dev

# Форматирование PHP
docker compose exec backend_api vendor/bin/pint
```

## Podman (Fedora/RHEL)

Для систем с SELinux:
1. Используйте полные имена образов: `docker.io/library/postgres:18.1`
2. Добавляйте `:z` или `:Z` к volume mounts
3. После `podman compose build` удаляйте старый образ для применения изменений

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| Permission denied (storage) | `docker compose down && docker compose up -d --build` |
| Изменения не применяются в worker | `docker compose build --no-cache && docker compose up -d` |
| Database connection refused | Проверьте `DB_HOST=postgres` в `.env` |
| Изменения frontend не применяются (submodule) | См. ниже |

### Изменения в git submodule не применяются при Docker build

**Проблема:** TaskMateClient и TaskMateServer — это git submodules. Docker/Podman при сборке использует `COPY . .`, который копирует файлы из рабочей директории. Однако незакоммиченные изменения в submodule могут не попадать в контекст сборки даже с `--no-cache`.

**Решение:** Собрать frontend локально с примонтированным volume и скопировать результат в контейнер:

```bash
# В директории TaskMateClient:
cd TaskMateClient

# Сборка с volume mount (обходит кеш Docker)
podman run --rm -v .:/app:Z -w /app node:22-alpine sh -c "npm ci && npm run build"

# Копирование в работающий контейнер
docker cp ./dist/. taskmate_src_frontend:/usr/share/nginx/html/
```

Альтернатива — закоммитить изменения в submodule перед сборкой:
```bash
cd TaskMateClient
git add -A && git commit -m "WIP"
cd ..
docker compose build src_frontend --no-cache
docker compose up -d src_frontend
```

---

License: Proprietary © 2023-2026 [xierongchuan](https://github.com/xierongchuan)
