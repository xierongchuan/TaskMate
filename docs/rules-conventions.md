# Правила и конвенции

[← Назад: Справочник API](api-reference.md) | [Далее: Установка и развертывание](setup-deployment.md)

## Общие правила

### 1. Docker Only

**ВСЕ команды** выполняются через контейнеры. NPM/PHP/Composer не устанавливаются на хост.

```bash
# Backend
podman compose exec api php artisan test

# Frontend
podman run --rm -v ./TaskMateClient:/app:z -w /app node:22-alpine npm run dev

# Bot
podman compose --profile bot up -d --build
```

### 2. Даты в UTC

Хранить/передавать/сравнивать даты ТОЛЬКО в UTC. Формат: ISO 8601 с Z суффиксом.

```json
{
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Гибридный подход:**
- Моменты времени (deadlines): UTC
- Календарные дни (выходные): UTC → timezone дилера

### 3. PostgreSQL Only

Использовать COALESCE вместо IFNULL. Всегда агрегация при GROUP BY.

```sql
-- ПРАВИЛЬНО
SELECT COALESCE(name, 'Unknown') FROM users;

-- НЕПРАВИЛЬНО
SELECT IFNULL(name, 'Unknown') FROM users;
```

### 4. Тесты обязательны

После изменений backend — всегда запускать тесты. Минимум 50% покрытия.

```bash
php artisan test                            # Все тесты
php artisan test --filter=TaskControllerTest # Конкретный класс
composer test:coverage                       # С покрытием
```

### 5. Язык

- **UI, комментарии, документация:** Русский
- **Код:** Английский

### 6. Синхронизация модулей

При изменении API (backend) — проверить frontend и bot. И наоборот.

### 7. SOLID принципы

Строгое соблюдение в дизайне и разработке.

### 8. Безопасность

- Параметризованные SQL запросы
- Валидация всего ввода
- Никогда не использовать `exec`/`eval`/`shell_exec` с пользовательскими данными

## Backend (Laravel/PHP)

### Архитектура

- **Controller → Service → Model** — Логика в сервисах, контроллеры тонкие
- **Form Requests** — Валидация ТОЛЬКО в `app/Http/Requests/Api/V1/`
- **Eager Loading** — Обязательно: `Task::with(['creator', 'assignments.user'])->get()`
- **API Resources** — Для сериализации, гарантируют UTC даты с Z

### Форматирование ответов

```php
// ПРАВИЛЬНО: API Resource
return new TaskResource($task);

// Без обёртки data
return response()->json(TaskResource::make($task)->resolve());
```

### Работа с датами

```php
use App\Helpers\TimeHelper;

$now = TimeHelper::nowUtc(); // Carbon UTC
$iso = TimeHelper::toIsoZulu($carbon); // "2024-01-15T10:30:00Z"
$boundaries = TimeHelper::dayBoundariesForTimezone($dealership->timezone);
```

### Хранилище файлов

- Disk: `task_proofs` (private)
- Доступ: signed URLs (60 мин TTL)
- Валидация: magic bytes, не расширение

### Команды

```bash
php artisan test                            # Тесты
php artisan test --filter=TaskControllerTest # Конкретный
composer test:coverage                       # Покрытие
php vendor/bin/pint                          # Форматирование
php vendor/bin/pint --test                   # Проверка
```

## Frontend (React/TypeScript)

### Управление состоянием

- **Zustand** — Клиентское состояние (auth, workspace, sidebar)
- **TanStack Query** — Серверные данные с `dealershipId` в queryKey

```typescript
// ПРАВИЛЬНО
useQuery({
  queryKey: ['tasks', dealershipId, filters],
  queryFn: () => tasksApi.getAll({ ...filters, dealership_id: dealershipId }),
  placeholderData: (prev) => prev,
});
```

### Права доступа

```typescript
// ПРАВИЛЬНО: usePermissions()
const { canManageTasks } = usePermissions();

// НЕПРАВИЛЬНО
if (user.role === 'owner') { ... }
```

### API модули

```typescript
// ПРАВИЛЬНО: через модули
import { tasksApi } from '@/api/tasks';

// НЕПРАВИЛЬНО: прямой axios
axios.get('/api/v1/tasks')
```

### Даты

```typescript
import { formatDateTime, toUtcIso } from '@/utils/dateTime';

formatDateTime("2024-01-15T10:30:00Z"); // "15 янв 2024, 15:30"
toUtcIso(localDate);                     // "2024-01-15T10:30:00Z"
```

### Multi-tenant

```typescript
// ПРАВИЛЬНО: useWorkspace()
const { dealershipId } = useWorkspace();

// НЕПРАВИЛЬНО: из authStore
const dealershipId = useAuthStore((state) => state.user.dealership_id);
```

## Telegram Bot (Python)

### Async everywhere

- **aiogram, httpx, redis.asyncio** — асинхронно
- Синхронный код запрещён

```python
# ПРАВИЛЬНО
async def get_tasks(user_id: int):
    async with httpx.AsyncClient() as client:
        response = await client.get(f'/api/v1/tasks?user_id={user_id}')
        return response.json()

# НЕПРАВИЛЬНО
def get_tasks(user_id):
    return requests.get(...).json()
```

### Данные только через API

- **REST API только** — `/api/v1/*`
- Нет прямого доступа к БД

### FSM для многошаговых операций

```python
class UploadProofStates(StatesGroup):
    waiting_file = State()
    waiting_comment = State()
```

### Аутентификация

- **AuthMiddleware** — проверка сессии перед каждым handler
- Токены в Valkey с TTL 24 часа

## Запрещенные паттерны

### Общие

- MySQL-совместимый SQL (IFNULL, GROUP BY без агрегации)
- Даты не в UTC
- Прямой доступ к storage — использовать `task_proofs` disk + signed URLs
- Логика в контроллерах — выносить в Services
- Модели без eager loading
- `user.role === 'owner'` — использовать `usePermissions()`
- Серверные данные в Zustand — использовать TanStack Query
- `keepPreviousData` (deprecated) — использовать `placeholderData: (prev) => prev`
- Прямой axios — использовать API модули из `src/api/`
- Синхронный код в Telegram bot — async only

### Backend

- Валидация в контроллерах через `$request->validate()`
- N+1 queries (без eager loading)
- SoftDeletes без учёта в запросах

### Frontend

- Отображение дат без конвертации из UTC
- Доступ к dealershipId напрямую из `useAuthStore`

### Bot

- Хранение sensitive данных (tokens) в памяти
- Выполнение shell-команд
- Блокирующие операции (sleep)

## Исключения

Все правила могут иметь исключения только с явным обоснованием и документированием причины.

[← Назад: Справочник API](api-reference.md) | [Далее: Установка и развертывание](setup-deployment.md)
