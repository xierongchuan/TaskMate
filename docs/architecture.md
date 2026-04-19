# Архитектура TaskMate

[← Назад к README](../README.md) | [Далее: Доменная модель](domain-model.md)

## Обзор

TaskMate — это монолитное приложение для управления задачами в автодилерах, построенное на архитектуре микросервисов с использованием контейнеров. Проект организован как monorepo с git submodules для модульной разработки.

### Модули

| Модуль | Путь | Стек | Ответственность |
|--------|------|------|----------------|
| Backend | `TaskMateServer/` | Laravel 12 · PHP 8.4 · PostgreSQL 18 | REST API, бизнес-логика, очереди |
| Frontend | `TaskMateClient/` | React 19 · TypeScript · Vite · Tailwind | SPA интерфейс для менеджеров и сотрудников |
| Telegram Bot | `TaskMateTelegramBot/` | Python 3.12 · aiogram 3 · httpx · Valkey | Мобильный клиент для уведомлений и выполнения задач |
| Infrastructure | root | podman compose · Nginx · Valkey · RabbitMQ | Оркестрация, прокси, кеш, очереди |

## Архитектурные принципы

### Monorepo с Git Submodules

- Каждый модуль — отдельный git submodule для независимой разработки
- Общие правила и конвенции в корневом `AGENTS.md` и `CLAUDE.md`
- Синхронизация API: изменения в backend требуют проверки frontend и bot

### Микросервисы на контейнерах

- Все компоненты запускаются через podman compose
- Коммуникация между сервисами через REST API и RabbitMQ
- Разделение ответственности: backend — логика, frontend — UI, bot — мобильный доступ

### Многоарендность (Multi-tenant)

- Каждый автодилер — отдельный тенант с собственным timezone
- Изоляция данных через `dealership_id` в запросах
- Права доступа: employee (1), observer (2), manager (3), owner (4)

## Сервисы Docker

```yaml
# Хранилища данных
svc-postgres         # PostgreSQL 18 — основная БД
svc-valkey           # Valkey (Redis) — кеш, сессии бота
svc-rabbitmq         # RabbitMQ — асинхронные задачи

# Приложения
svc-frontend         # Nginx + React SPA
svc-api              # FrankenPHP + Laravel API
svc-telegram-bot     # Python aiogram бот

# Фоновые воркеры
svc-worker-cleanup   # Очистка файлов (file_cleanup очередь)
svc-worker-proof     # Загрузка доказательств (proof_upload)
svc-worker-shared    # Общие файлы для групповых задач (shared_proof_upload)
svc-worker-generator # Генерация задач из шаблонов (task_generators)

# Инфраструктура
svc-scheduler        # Supervisor + cron для периодических задач
svc-nginx            # Reverse proxy для frontend и API
```

## Backend (Laravel/PHP)

### Структура

```
TaskMateServer/
├── app/
│   ├── Http/Controllers/Api/V1/   # 18 контроллеров для REST API
│   ├── Http/Requests/Api/V1/      # Form Requests для валидации
│   ├── Models/                    # 19 Eloquent моделей
│   ├── Services/                  # 11 сервисов бизнес-логики
│   ├── Jobs/                      # 4 фоновые задачи RabbitMQ
│   ├── Enums/                     # Role, TaskStatus, TaskType, Priority
│   ├── Traits/                    # Auditable, HasDealershipAccess
│   ├── Helpers/TimeHelper.php     # UTC утилиты
│   └── Validation/FileValidation/ # Проверка файлов по magic bytes
├── routes/api.php                 # 50+ эндпоинтов /api/v1
├── tests/Feature/                 # 968 Pest тестов
└── CLAUDE.md                      # Детальные конвенции
```

### Ключевые сервисы

| Сервис | Ответственность |
|--------|----------------|
| TaskService | CRUD задач, назначения, дубликаты |
| TaskFilterService | Фильтрация и пагинация задач |
| TaskProofService | Загрузка/удаление файлов доказательств |
| TaskVerificationService | Одобрение/отклонение задач |
| SettingsService | Управление настройками дилера |

### Фоновые задачи (Jobs)

| Job | Очередь | Интервал | Описание |
|-----|---------|----------|----------|
| ProcessTaskGeneratorsJob | task_generators | 5 мин | Генерация задач из шаблонов |
| StoreTaskProofsJob | proof_upload | - | Асинхронная загрузка файлов |
| StoreTaskSharedProofsJob | shared_proof_upload | - | Групповые файлы |
| DeleteProofFileJob | file_cleanup | 1 час | Очистка временных файлов |

### Хранилище файлов

- **Disk**: `task_proofs` → `storage/app/private/task_proofs/`
- **Доступ**: Только через signed URLs (TTL 60 мин)
- **Лимиты**: 5 файлов, 200MB total (изображения 5MB, видео 100MB, документы 50MB)
- **Валидация**: Magic bytes, не только расширение файла

## Frontend (React/TypeScript)

### Структура

```
TaskMateClient/
├── src/
│   ├── api/            # 15 модулей API клиентов (Axios)
│   ├── components/
│   │   ├── ui/         # UI Kit: Button, Card, Modal, Badge
│   │   ├── common/     # DealershipSelector, StatusBadge
│   │   ├── layout/     # Layout, Sidebar, WorkspaceSwitcher
│   │   ├── tasks/      # TaskModal, TaskDetailsModal
│   │   └── [domain]/   # generators, shifts, users
│   ├── pages/          # 17 страниц-роутов
│   ├── hooks/          # usePermissions, useWorkspace
│   ├── stores/         # Zustand: auth, workspace, sidebar
│   ├── types/          # TypeScript типы
│   ├── utils/          # dateTime, errorHandling
│   └── context/        # ThemeContext (light/dark)
├── tests/              # E2E Playwright тесты
└── CLAUDE.md           # Детальные конвенции
```

### Управление состоянием

- **Zustand**: Клиентское состояние (auth, workspace, sidebar) с persist в localStorage
- **TanStack Query**: Серверные данные с `dealershipId` в queryKey и `placeholderData: (prev) => prev`

### API интеграция

- Модули в `src/api/` для типизированных запросов
- `usePermissions()` для проверки прав доступа
- `useWorkspace()` как единственный источник `dealershipId`

### E2E тесты (Playwright)

```
tests/
├── setup/auth.setup.ts   # Аутентификация для 4 ролей
├── auth/login.spec.ts    # Тесты логина
├── pages/                # 16 тестов страниц (admin роль)
├── roles/                # 5 ролевых проверок доступа
└── .auth/                # Storage state (gitignored)
```

## Telegram Bot (Python)

### Структура

```
TaskMateTelegramBot/
├── src/
│   ├── main.py              # Точка входа: бот + scheduler + consumer
│   ├── config.py            # pydantic-settings для env
│   ├── api/client.py        # httpx клиент к API
│   ├── bot/
│   │   ├── bot.py           # Инициализация, AuthMiddleware
│   │   ├── handlers/        # common, auth, tasks, shifts
│   │   ├── keyboards.py     # Inline клавиатуры
│   │   └── messages.py      # Шаблоны сообщений (русский)
│   ├── scheduler/polling.py # Опрос API для уведомлений
│   ├── storage/sessions.py  # Сессии в Valkey
│   └── consumers/           # RabbitMQ для задач
└── CLAUDE.md                # Детальные конвенции
```

### Архитектура коммуникаций

- **REST API**: Все данные через `/api/v1/*` (нет прямого доступа к БД)
- **RabbitMQ Consumer**: Асинхронные уведомления о задачах
- **APScheduler**: Периодический опрос для уведомлений
- **Valkey**: Сессии и кеш (async Redis)

### FSM для многошаговых операций

```python
class UploadProofStates(StatesGroup):
    waiting_file = State()
    waiting_comment = State()
```

### Команды бота

| Команда | Доступ | Описание |
|---------|--------|----------|
| /start | публичный | Приветствие + авторизация |
| /tasks | auth | Список задач |
| /task {id} | auth | Детали задачи |
| /shift | auth | Текущая смена |

## Коммуникации между модулями

### Синхронизация API

1. Изменения в backend API требуют обновления frontend и bot
2. Все запросы включают `dealership_id` для multi-tenant
3. Даты передаются в UTC ISO 8601 с Z суффиксом

### Очереди RabbitMQ

- **task_generators**: Генерация задач из шаблонов
- **proof_upload**: Асинхронная обработка файлов
- **shared_proof_upload**: Групповые доказательства
- **file_cleanup**: Удаление временных файлов

### Кеш Valkey

- Сессии бота: `chat:{chat_id}:token`
- Кеш API ответов для производительности

## Безопасность

- **Sanctum**: JWT токены для API аутентификации
- **AuthMiddleware**: Проверка сессий в боте
- **File validation**: Magic bytes и размер файлов
- **Signed URLs**: Временный доступ к файлам
- **Role-based access**: Проверка прав на backend через policies

## Масштабируемость

- **Горизонтальное масштабирование**: Множественные инстансы воркеров
- **База данных**: PostgreSQL с индексами и партиционированием
- **Кеш**: Valkey для горячих данных
- **Файлы**: Приватное хранилище с CDN-ready signed URLs

[← Назад к README](../README.md) | [Далее: Доменная модель](domain-model.md)
