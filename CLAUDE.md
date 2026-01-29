# CLAUDE.md

Инструкции для Claude Code при работе с TaskMate — системой управления задачами для автосалонов.

## Архитектура

Monorepo с git submodules:

| Модуль | Путь | Стек |
|--------|------|------|
| Frontend | `TaskMateClient/` | React 19 + TypeScript + Vite + Tailwind |
| Backend | `TaskMateServer/` | Laravel 12 + PHP 8.4 + PostgreSQL 18 |
| Telegram Bot | `TaskMateTelegramBot/` | Python 3.12 + aiogram 3 |
| Инфраструктура | корень | podman compose + Nginx + Valkey + RabbitMQ |

Детальные инструкции — в `CLAUDE.md` каждого модуля.

## Доменная модель

- **Роли:** employee (1) → observer (2) → manager (3) → owner (4). Число = уровень доступа.
- **Задачи:** notification | completion | completion_with_proof. Структура: individual | group.
- **Multi-tenant:** каждый автосалон (AutoDealership) имеет свой timezone. Все даты — UTC (ISO 8601, суффикс `Z`).

## Быстрый старт

```bash
podman compose up -d --build

# Первый запуск backend
podman compose exec backend_api composer install
podman compose exec backend_api php artisan migrate --force
podman compose exec backend_api php artisan db:seed-demo
podman compose exec backend_api php artisan storage:link
```

**Demo:** admin/password, manager1/password, emp1_1/password

| Сервис | URL |
|--------|-----|
| Frontend | http://localhost:8099 |
| Backend API | http://localhost:8007 |
| RabbitMQ UI | http://localhost:15672 |

## Обязательные правила

1. **Язык** — русский для UI, комментариев, документации. Код на английском.
2. **Docker** — все команды через контейнеры. Не ставить зависимости на хосте.
3. **Тесты** — ВСЕГДА `podman compose exec backend_api php artisan test` после backend-изменений.
4. **Синхронизация** — при изменении API (backend) проверять frontend, и наоборот.
5. **PostgreSQL only** — не использовать MySQL-совместимый синтаксис.
6. **Даты в UTC** — хранение, передача, сравнение — всё в UTC.
7. **Покрытие** — минимум 50% тестами для backend.
8. **SOLID** — строгое соблюдение принципов SOLID при проектировании и разработке.



## Workflow задач

```
Создание:  Manager/Owner → TaskService::createTask() → status: pending
Выполнение: Employee → PATCH /tasks/{id}/status + proof_files → pending_review
Проверка:   Manager → POST /task-responses/{id}/approve|reject
Архивация:  Scheduler → tasks:archive-completed (каждые 10 мин)
```

## Docker сервисы

```yaml
# Основные
taskmate_postgres, taskmate_valkey, taskmate_rabbitmq
taskmate_src_frontend, taskmate_backend_api

# Workers (RabbitMQ)
taskmate_worker_cleanup         # file_cleanup
taskmate_worker_proof_upload    # proof_upload
taskmate_worker_shared_proof    # shared_proof_upload
taskmate_worker_generators      # task_generators

# Инфра
taskmate_backend_scheduler      # Supervisor (cron)
taskmate_nginx                  # Reverse proxy
```

## Команды

```bash
# Backend
podman compose exec backend_api php artisan test
podman compose exec backend_api composer test:coverage
podman compose exec backend_api vendor/bin/pint

# Frontend
cd TaskMateClient && npm run build
cd TaskMateClient && npm run lint

# Deploy
./deploy_prod.sh --pull --init   # первый раз
./deploy_prod.sh --pull          # обновление
```
