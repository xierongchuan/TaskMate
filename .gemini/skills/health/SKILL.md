---
name: health
description: Проверить состояние всех сервисов TaskMate (контейнеры, БД, очереди).
disable-model-invocation: true
allowed-tools: Bash(podman *), Bash(curl *)
---

Проверь здоровье всех сервисов TaskMate.

## Шаг 1 — Статус контейнеров

```bash
podman compose ps -a
```

## Шаг 2 — Проверка доступности

Проверь каждый сервис:

**API:**
```bash
curl -sf http://localhost:8007/api/v1/health 2>&1 || echo "API недоступен"
```

**PostgreSQL:**
```bash
podman compose exec postgres pg_isready -U taskmate
```

**Valkey:**
```bash
podman compose exec valkey valkey-cli ping
```

**RabbitMQ:**
```bash
curl -sf http://localhost:15672/api/overview -u guest:guest 2>&1 | head -c 200 || echo "RabbitMQ UI недоступен"
```

## Шаг 3 — Очереди RabbitMQ

```bash
podman compose exec rabbitmq rabbitmqctl list_queues name messages consumers
```

## Отчёт

Выведи таблицу:

| Сервис | Статус | Детали |
|--------|--------|--------|
| API | OK/FAIL | ... |
| PostgreSQL | OK/FAIL | ... |
| Valkey | OK/FAIL | ... |
| RabbitMQ | OK/FAIL | ... |
| Frontend | OK/FAIL | ... |
| Workers | OK/FAIL | количество запущенных |

Если есть проблемы — предложи шаги для исправления.
