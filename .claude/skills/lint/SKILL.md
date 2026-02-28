---
name: lint
description: Проверить и исправить стиль кода. Backend (Pint) и Frontend (ESLint).
disable-model-invocation: true
allowed-tools: Bash(podman *)
---

Проверь стиль кода во всех модулях TaskMate.

## Шаг 1 — Backend (Pint)

Сначала проверь без исправлений:
```bash
podman compose exec api php vendor/bin/pint --test
```

Если есть ошибки стиля — исправь:
```bash
podman compose exec api php vendor/bin/pint
```

## Шаг 2 — Frontend (ESLint)

```bash
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run lint
```

## Отчёт

Сообщи результат по каждому модулю:
- Backend Pint: чисто / исправлено N файлов
- Frontend ESLint: чисто / N ошибок / N предупреждений
