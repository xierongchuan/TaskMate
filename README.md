# TaskMate

Система управления задачами для автосалонов.

## О проекте

TaskMate — комплексное решение для автоматизации рабочих процессов в автодилерах. Включает веб-интерфейс для менеджеров, мобильное приложение для сотрудников и Telegram бот для уведомлений.

### Возможности

- **Многоарендность:** Поддержка нескольких автодилеров с индивидуальными настройками
- **Гибридный подход к датам:** UTC для моментов времени + timezone для календарных дней
- **Типы задач:** Уведомления, выполнение, выполнение с доказательствами
- **Автоматизация:** Генераторы задач, фоновые процессы, архивация
- **Интеграции:** API, Telegram бот, мобильное приложение

## Быстрый старт

```bash
# Запуск сервисов
podman compose up -d --build

# Инициализация backend
podman compose exec api composer install
podman compose exec api php artisan migrate --force
podman compose exec api php artisan db:seed-demo
podman compose exec api php artisan storage:link
```

### Доступ

- **Frontend:** http://localhost:8099
- **Backend API:** http://localhost:8007
- **RabbitMQ UI:** http://localhost:15672

### Demo аккаунты

| Роль | Логин | Пароль |
|------|-------|--------|
| Admin (Owner) | admin | password |
| Manager | manager1 | password |
| Employee | emp1_1 | password |

## Технологии

| Модуль | Стек |
|--------|------|
| Backend | Laravel 12 · PHP 8.4 · PostgreSQL 18 |
| Frontend | React 19 · TypeScript · Vite · Tailwind |
| Telegram Bot | Python 3.12 · aiogram 3 · httpx · Valkey |
| Infrastructure | podman compose · Nginx · Valkey · RabbitMQ |

## Структура проекта

```
.
├── TaskMateClient/          # Frontend (React SPA)
├── TaskMateServer/          # Backend (Laravel API)
├── TaskMateTelegramBot/     # Telegram бот (Python)
├── docker-compose.yml       # Контейнеры
├── docs/                    # Подробная документация
└── scripts/                 # Утилиты сборки
```

## Документация

Подробная документация находится в [docs/](docs/):

- [Архитектура](docs/architecture.md) — модули, сервисы, диаграммы
- [Доменная модель](docs/domain-model.md) — роли, задачи, workflow
- [Backend](docs/backend.md) — Laravel/PHP детали
- [Frontend](docs/frontend.md) — React/TypeScript детали
- [Telegram Bot](docs/telegram-bot.md) — Python aiogram реализация
- [API справочник](docs/api-reference.md) — все эндпоинты
- [Правила и конвенции](docs/rules-conventions.md) — кодстайл, запреты
- [Установка](docs/setup-deployment.md) — детальная настройка
- [Контрибьютинг](docs/contributing.md) — разработка и PR

## Разработка

```bash
# Backend тесты
podman compose exec api php artisan test

# Frontend dev server
cd TaskMateClient && npm run dev

# Пересборка frontend
./scripts/rebuild-frontend.sh
```

## Лицензия

Proprietary © 2023-2026
