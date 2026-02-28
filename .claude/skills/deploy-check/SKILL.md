---
name: deploy-check
description: Предеплойная проверка — тесты, стиль, сборка, git-статус. Запускай перед деплоем.
disable-model-invocation: true
allowed-tools: Bash(podman *), Bash(git *)
---

Проведи полную предеплойную проверку TaskMate.

Выполняй все шаги последовательно. При первой критической ошибке — продолжай остальные проверки, но отметь итог как FAIL.

## Шаг 1 — Git статус

```bash
git status --short
```

Проверь: нет ли незакоммиченных изменений. Предупреди если есть.

## Шаг 2 — Backend тесты

```bash
podman compose exec api php artisan test
```

## Шаг 3 — Backend стиль (Pint)

```bash
podman compose exec api php vendor/bin/pint --test
```

## Шаг 4 — Frontend сборка

```bash
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run build
```

## Шаг 5 — Frontend линтинг

```bash
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run lint
```

## Итоговый отчёт

```
ПРЕДЕПЛОЙНАЯ ПРОВЕРКА TaskMate
================================
Git статус:      OK / WARN (незакоммиченные изменения)
Backend тесты:   OK (N passed) / FAIL (N failed)
Backend стиль:   OK / FAIL (N файлов)
Frontend build:  OK / FAIL
Frontend lint:   OK / FAIL (N ошибок)
================================
ИТОГ: ГОТОВО К ДЕПЛОЮ / НЕ ГОТОВО
```
