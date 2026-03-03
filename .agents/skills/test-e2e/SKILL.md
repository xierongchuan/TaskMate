---
name: test-e2e
description: Запустить E2E тесты Playwright для frontend. Используй /test-e2e для всех, /test-e2e pages для категории, /test-e2e dashboard для конкретного файла.
argument-hint: "[pages|roles|auth|файл.spec.ts] [--project chromium|role-tests|login|setup]"
disable-model-invocation: true
allowed-tools: Bash(podman *)
---

Запусти E2E тесты TaskMate (Playwright).

## Предварительная проверка

Убедись, что сервисы запущены:
```bash
podman compose ps --format '{{.Names}} {{.Status}}' | grep -E 'svc-frontend|svc-api|svc-nginx'
```

Если сервисы не запущены — сообщи пользователю и НЕ запускай тесты.

## Команда

Базовая команда:
```bash
podman run --rm --network host -v ./TaskMateClient:/app:z -w /app mcr.microsoft.com/playwright:v1.58.0-noble npx playwright test
```

### Аргументы (`$ARGUMENTS`)

Если аргументы указаны, интерпретируй их:

- **Категория** (`pages`, `roles`, `auth`): добавь `--project` для соответствующего проекта
  - `pages` → `--project chromium`
  - `roles` → `--project role-tests`
  - `auth` → `--project login`
- **Файл** (например `dashboard`, `tasks.spec.ts`): добавь имя файла к команде
  - `dashboard` → `npx playwright test dashboard`
  - `tasks.role-employee` → `npx playwright test tasks.role-employee`
- **--project** передай напрямую
- **--list** — только список тестов без запуска

Если аргументы НЕ указаны — запусти все тесты.

## После запуска

1. Сообщи итог: сколько тестов прошло, сколько упало, сколько пропущено
2. Если есть падения — покажи название теста и краткую причину ошибки
3. НЕ пытайся автоматически исправлять код — только отчитайся о результатах
