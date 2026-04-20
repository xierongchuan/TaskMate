# AGENTS.md

Краткое руководство для AI-агентов по проекту TaskMate.

- Проект: TaskMate — система управления задачами для автосалонов.
- Модули: Backend (`TaskMateServer/` — Laravel 12, PHP 8.4, Postgres), Frontend (`TaskMateClient/` — React+TS), Telegram Bot (`TaskMateTelegramBot/`), Infra (podman compose).
- Полная документация и правила: [docs/](docs/) и [CLAUDE.md](CLAUDE.md).

Ключевые правила для агентов
- Выполнять все команды в контейнерах (не на хосте).
- Использовать `apply_patch` для правок и `manage_todo_list` для многошаговых задач.
- Перед использованием скилла читать соответствующий `SKILL.md`.
- После изменений запускать контейнеризованные тесты (например, `podman compose exec api php artisan test`).
- Поддерживать ответы краткими и конкретными; в PR включать план и команды для проверки.
- Следовать принципам SOLID и DRY; применять лучшие практики (тесты, статический анализ, читаемый код).

Быстрые команды
```bash
podman compose up -d --build
podman compose exec api php artisan test
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run dev
```

Где смотреть детали: [docs/](docs/), [CLAUDE.md](CLAUDE.md), [.github/copilot-instructions.md](.github/copilot-instructions.md).


