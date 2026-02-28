---
name: test
description: Запустить backend-тесты Laravel (Pest). Используй /test для всех тестов или /test ClassName для фильтрации.
argument-hint: "[--filter ClassName]"
disable-model-invocation: true
allowed-tools: Bash(podman *)
---

Запусти backend-тесты TaskMate.

## Команда

Если аргументы указаны (`$ARGUMENTS`):
```bash
podman compose exec api php artisan test --filter $ARGUMENTS
```

Если аргументы НЕ указаны — запусти все тесты:
```bash
podman compose exec api php artisan test
```

## После запуска

1. Сообщи итог: сколько тестов прошло, сколько упало
2. Если есть падения — покажи название теста и краткую причину ошибки
3. НЕ пытайся автоматически исправлять код — только отчитайся о результатах
