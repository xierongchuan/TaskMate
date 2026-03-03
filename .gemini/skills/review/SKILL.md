---
name: review
description: Код-ревью текущих изменений в git. Проверяет качество, безопасность, соответствие конвенциям TaskMate.
disable-model-invocation: true
---

Проведи код-ревью текущих изменений в TaskMate.

## Контекст изменений

Staged изменения:
!`git diff --cached`

Unstaged изменения:
!`git diff`

Изменённые файлы:
!`git status --short`

## Чеклист проверки

Проверь каждое изменение по следующим критериям:

### Архитектура и SOLID
- Контроллеры тонкие, логика в сервисах
- Нет God-объектов, соблюдение Single Responsibility
- Правильное использование Form Requests для валидации

### Безопасность
- Параметризованные SQL-запросы (не raw с пользовательскими данными)
- Нет `exec`/`eval`/`shell_exec` с пользовательским вводом
- Валидация ввода на всех границах

### Даты и UTC
- Все даты в UTC (ISO 8601 с `Z`)
- Backend: `TimeHelper::nowUtc()`, `TimeHelper::toIsoZulu()`
- Frontend: утилиты из `dateTime.ts`
- Нет `now()`, `Carbon::now()` без UTC

### База данных (PostgreSQL)
- COALESCE вместо IFNULL
- Eager loading (нет N+1)
- Query Builder вместо raw SQL где возможно

### Frontend
- `usePermissions()` вместо прямой проверки ролей
- `dealershipId` в queryKey TanStack Query
- Zustand для клиентского стейта, TanStack Query для серверного

### Тесты
- Новый код покрыт тестами
- Pest `describe()/it()` синтаксис

## Формат ответа

Для каждого замечания укажи:
- **Файл:строка** — где проблема
- **Серьёзность** — критично / важно / рекомендация
- **Описание** — что не так и как исправить

В конце — общая оценка: готово к коммиту или нет.
