# Backend (Laravel/PHP)

[← Назад: Доменная модель](domain-model.md) | [Далее: Frontend](frontend.md)

## Обзор

Backend TaskMate построен на Laravel 12 с PHP 8.4. Архитектура следует принципам SOLID, с четким разделением ответственности: контроллеры для HTTP, сервисы для бизнес-логики, модели для данных.

## Стек технологий

- **Framework**: Laravel 12
- **PHP**: 8.4
- **Database**: PostgreSQL 18
- **Cache/Session**: Valkey (Redis)
- **Queues**: RabbitMQ (laravel-queue-rabbitmq 14)
- **Auth**: Sanctum 4.2
- **Testing**: Pest 4 (968 тестов)
- **Server**: FrankenPHP

## Архитектура

### Принцип: Controller → Service → Model

Бизнес-логика вынесена в сервисы, контроллеры остаются тонкими.

```php
// app/Http/Controllers/Api/V1/TaskController.php
public function store(StoreTaskRequest $request): JsonResponse
{
    $task = $this->taskService->createTask($request->validated(), $request->user());
    return $this->createdResponse(TaskResource::make($task)->resolve(), 'Задача создана');
}
```

### Структура директорий

```
app/
├── Http/
│   ├── Controllers/Api/V1/   # 18 контроллеров
│   └── Requests/Api/V1/      # Form Requests
├── Models/                   # 19 Eloquent моделей
├── Services/                 # 11 бизнес-сервисов
├── Jobs/                     # 4 фоновые задачи
├── Enums/                    # TaskStatus, Role, Priority
├── Traits/                   # Auditable, HasDealershipAccess
├── Helpers/TimeHelper.php    # UTC утилиты
└── Validation/FileValidation/# Magic bytes проверка

routes/api.php                # 50+ эндпоинтов /api/v1
tests/Feature/                # Pest тесты
```

## Конвенции разработки

### Form Requests для валидации

Валидация ТОЛЬКО в `app/Http/Requests/Api/V1/`, никогда в контроллерах.

```php
// app/Http/Requests/Api/V1/StoreTaskRequest.php
public function rules(): array
{
    return [
        'title' => 'required|string|max:255',
        'description' => 'nullable|string',
        'type' => 'required|in:notification,completion,completion_with_proof',
        'assigned_user_ids' => 'required|array|min:1',
        'assigned_user_ids.*' => 'exists:users,id',
    ];
}
```

### Eager Loading (обязательно)

Предотвращение N+1 queries через eager loading.

```php
// ПРАВИЛЬНО
$tasks = Task::with(['creator', 'assignments.user', 'responses.proofs'])->get();

// НЕПРАВИЛЬНО
$tasks = Task::all();
foreach ($tasks as $task) {
    $task->creator->name; // N+1 query
}
```

### API Resources для сериализации

Использование API Resources для гарантии UTC дат с Z суффиксом.

```php
// app/Http/Resources/TaskResource.php
public function toArray(Request $request): array
{
    return [
        'id' => $this->id,
        'title' => $this->title,
        'created_at' => TimeHelper::toIsoZulu($this->created_at), // "2024-01-15T10:30:00Z"
        'creator' => UserResource::make($this->whenLoaded('creator')),
    ];
}

// Использование
return new TaskResource($task);
return response()->json(TaskResource::make($task)->resolve()); // Без обёртки data
```

### Работа с датами (TimeHelper)

Все операции с моментами времени в UTC.

```php
use App\Helpers\TimeHelper;

$now = TimeHelper::nowUtc(); // Carbon UTC
$iso = TimeHelper::toIsoZulu(Carbon::now()); // "2024-01-15T10:30:00Z"
$boundaries = TimeHelper::dayBoundariesForTimezone($dealership->timezone); // День в TZ дилера
```

## Ключевые сервисы

| Сервис | Методы | Ответственность |
|--------|--------|----------------|
| TaskService | createTask, updateTask, deleteTask, syncAssignments | CRUD задач |
| TaskFilterService | filter, paginate | Фильтрация с date_range, status, priority |
| TaskProofService | storeProofs, deleteProof | Файлы доказательств |
| TaskVerificationService | approve, reject | Верификация задач |
| SettingsService | getTimezone | Настройки дилера |

### Пример сервиса

```php
// app/Services/TaskService.php
class TaskService
{
    public function createTask(array $data, User $creator): Task
    {
        DB::transaction(function () use ($data, $creator) {
            $task = Task::create([
                'title' => $data['title'],
                'dealership_id' => $creator->dealership_id,
                'creator_id' => $creator->id,
            ]);
            
            $this->syncAssignments($task, $data['assigned_user_ids']);
            return $task;
        });
    }
}
```

## Фоновые задачи (Jobs)

Асинхронная обработка через RabbitMQ.

| Job | Очередь | Триггер | Описание |
|-----|---------|---------|----------|
| ProcessTaskGeneratorsJob | task_generators | Каждые 5 мин | Генерация задач из шаблонов |
| StoreTaskProofsJob | proof_upload | При загрузке | Сохранение файлов |
| StoreTaskSharedProofsJob | shared_proof_upload | Групповые файлы | Общие доказательства |
| DeleteProofFileJob | file_cleanup | Каждый час | Очистка storage |

### Пример Job

```php
// app/Jobs/StoreTaskProofsJob.php
class StoreTaskProofsJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function handle(): void
    {
        // Асинхронная обработка файлов
        $proofs = TaskProof::where('status', 'uploading')->get();
        foreach ($proofs as $proof) {
            Storage::disk('task_proofs')->put($proof->path, $proof->temp_file);
        }
    }
}
```

## Модели и связи

### Основные модели

- **User**: Аутентификация, роли, dealership_id
- **Task**: Задачи с типами и статусами
- **TaskAssignment**: Связь задач и пользователей
- **TaskProof**: Файлы доказательств
- **AutoDealership**: Тенанты с timezone

### Traits

- **Auditable**: Логирование изменений
- **HasDealershipAccess**: Проверка доступа к дилеру
- **ApiResponses**: Стандартизированные ответы

## API Структура

### Эндпоинты

Base: `/api/v1`

| Ресурс | Methods | Описание |
|--------|---------|----------|
| `/tasks` | GET, POST | Список и создание задач |
| `/tasks/{id}` | GET, PATCH, DELETE | Детали, обновление, удаление |
| `/tasks/{id}/status` | PATCH | Изменение статуса |
| `/task-responses/{id}` | POST | approve/reject |
| `/users` | GET | Список пользователей |
| `/shifts` | GET, POST | Управление сменами |

### Аутентификация

- **Bearer Token** через Sanctum
- Middleware: `auth:sanctum`
- Multi-tenant: проверка `dealership_id`

### Валидация

- Form Requests для всех POST/PATCH
- Custom rules для файлов и бизнес-логики

## Тестирование

### Pest тесты

968 тестов в `tests/Feature/`.

```bash
# Все тесты
php artisan test

# Конкретный класс
php artisan test --filter=TaskControllerTest

# Конкретный метод
php artisan test --filter="TaskControllerTest::test_user_can_create_task"

# Покрытие (min 50%)
composer test:coverage
```

### Структура тестов

```php
// tests/Feature/TaskControllerTest.php
test('user can create task', function () {
    $user = User::factory()->create(['role' => Role::Manager]);
    $assignee = User::factory()->create();

    $response = $this->actingAs($user)
        ->postJson('/api/v1/tasks', [
            'title' => 'Test Task',
            'assigned_user_ids' => [$assignee->id],
        ]);

    $response->assertCreated();
});
```

## Команды разработки

```bash
# Тесты
php artisan test                            # Все тесты
php artisan test --filter=TaskControllerTest # Конкретный тест
composer test:coverage                       # С покрытием

# Кодстайл
php vendor/bin/pint                          # Авто-фикс
php vendor/bin/pint --test                   # Проверка

# Миграции
php artisan migrate                          # Применить
php artisan migrate:rollback                 # Откат

# Очистка
php artisan cache:clear                      # Кеш
php artisan config:clear                     # Конфиг
```

## Хранилище файлов

- **Disk**: `task_proofs` (private)
- **Путь**: `storage/app/private/task_proofs/`
- **Доступ**: Signed URLs (60 мин TTL)
- **Валидация**: FileValidation по magic bytes

## Производительность

- **Eager Loading** для предотвращения N+1
- **Индексы** на частые запросы (dealership_id, status, created_at)
- **Кеш** через Valkey для горячих данных
- **Queues** для тяжелых операций

[← Назад: Доменная модель](domain-model.md) | [Далее: Frontend](frontend.md)
