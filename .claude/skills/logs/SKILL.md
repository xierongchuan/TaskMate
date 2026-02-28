---
name: logs
description: Показать и проанализировать логи контейнера. Используй /logs api, /logs worker-proof и т.д.
argument-hint: "[service-name]"
disable-model-invocation: true
allowed-tools: Bash(podman *)
---

Покажи логи сервиса TaskMate и проанализируй ошибки.

## Доступные сервисы

api, frontend, postgres, valkey, rabbitmq, nginx, scheduler,
worker-cleanup, worker-proof, worker-shared, worker-generator, worker-shifts,
telegram-bot, telegram-bot-worker

## Команда

Если сервис указан (`$ARGUMENTS`):
```bash
podman compose logs --tail=80 $ARGUMENTS
```

Если сервис НЕ указан — покажи логи API:
```bash
podman compose logs --tail=80 api
```

## Анализ

После получения логов:

1. Выдели **ошибки** (ERROR, Exception, Fatal, CRITICAL) — покажи каждую с контекстом
2. Выдели **предупреждения** (WARNING, WARN) — кратко перечисли
3. Если ошибок нет — сообщи что логи чистые
4. Если есть повторяющиеся ошибки — укажи частоту и возможную причину
