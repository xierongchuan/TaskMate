# TaskMate - Архитектура Системы Задач

## 1. Диаграмма Состояний Задачи

```mermaid
stateDiagram-v2
    [*] --> Pending: Создание задачи
    
    Pending --> Acknowledged: Сотрудник принимает (acknowledge)
    Pending --> Completed: Сотрудник выполняет (complete)
    Pending --> Overdue: Дедлайн истёк
    
    Acknowledged --> Completed: Сотрудник завершает
    Acknowledged --> Overdue: Дедлайн истёк
    
    Overdue --> Completed: Выполнение просроченной задачи
    
    Completed --> [*]: Задача завершена
    
    note right of Pending
        Статус по умолчанию
        Нет ответов (responses)
        is_active = true
    end note
    
    note right of Acknowledged
        Есть TaskResponse
        status = 'acknowledged'
    end note
    
    note right of Completed
        Есть TaskResponse
        status = 'completed'
    end note
    
    note right of Overdue
        is_active = true
        deadline < now
        Нет completed response
    end note
```

## 2. Структура Базы Данных

```mermaid
erDiagram
    TASKS ||--o{ TASK_ASSIGNMENTS : "assigned_to"
    TASKS ||--o{ TASK_RESPONSES : "has_responses"
    USERS ||--o{ TASK_ASSIGNMENTS : "assigned"
    USERS ||--o{ TASK_RESPONSES : "responds"
    USERS ||--o{ TASKS : "creates"
    AUTO_DEALERSHIPS ||--o{ TASKS : "belongs_to"
    AUTO_DEALERSHIPS ||--o{ USERS : "employs"
    
    TASKS {
        int id PK
        string title
        text description
        text comment
        int creator_id FK
        int dealership_id FK
        datetime appear_date
        datetime deadline
        enum recurrence "none|daily|weekly|monthly"
        time recurrence_time
        enum task_type "individual|group"
        enum response_type "acknowledge|complete"
        json tags
        boolean is_active
        int postpone_count
        datetime archived_at
        json notification_settings
    }
    
    TASK_ASSIGNMENTS {
        int id PK
        int task_id FK
        int user_id FK
        datetime created_at
    }
    
    TASK_RESPONSES {
        int id PK
        int task_id FK
        int user_id FK
        enum status "acknowledged|completed|postponed"
        text comment
        datetime responded_at
    }
    
    USERS {
        int id PK
        string full_name
        enum role "employee|manager|owner|observer"
        int dealership_id FK
        boolean is_active
    }
    
    AUTO_DEALERSHIPS {
        int id PK
        string name
        string address
    }
```

## 3. Жизненный Цикл Задачи

```mermaid
sequenceDiagram
    participant M as Manager/Owner
    participant API as TaskController
    participant DB as Database
    participant Bot as Telegram Bot
    participant E as Employee
    
    %% Создание задачи
    M->>API: POST /tasks (create)
    API->>DB: INSERT tasks
    API->>DB: INSERT task_assignments
    API-->>M: Task created (status: pending)
    
    %% Уведомление через бот
    Bot->>E: 📋 Новая задача: {title}
    
    %% Сотрудник принимает задачу
    E->>Bot: Нажимает "Принять"
    Bot->>DB: INSERT task_responses<br/>(status: acknowledged)
    Bot-->>E: ✅ Задача принята
    
    %% Админ проверяет статус
    M->>API: GET /tasks/{id}
    API->>DB: SELECT task + responses
    API->>API: calculate status<br/>(acknowledged)
    API-->>M: Task data (status: acknowledged)
    
    %% Сотрудник выполняет задачу
    E->>Bot: Нажимает "Выполнено"
    Bot->>DB: UPDATE task_responses<br/>(status: completed)
    Bot-->>E: ✅ Задача выполнена
    
    %% Финальная проверка
    M->>API: GET /tasks/{id}
    API->>DB: SELECT task + responses
    API->>API: calculate status<br/>(completed)
    API-->>M: Task data (status: completed)
```

## 4. Логика Вычисления Статуса (getStatusAttribute)

```mermaid
flowchart TD
    Start([Запрос статуса задачи]) --> CheckCompleted{Есть response<br/>status=completed?}
    
    CheckCompleted -->|Да| ReturnCompleted[Вернуть: COMPLETED]
    CheckCompleted -->|Нет| CheckAcknowledged{Есть response<br/>status=acknowledged?}
    
    CheckAcknowledged -->|Да| ReturnAcknowledged[Вернуть: ACKNOWLEDGED]
    CheckAcknowledged -->|Нет| CheckOverdue{is_active=true<br/>И deadline < now?}
    
    CheckOverdue -->|Да| ReturnOverdue[Вернуть: OVERDUE]
    CheckOverdue -->|Нет| ReturnPending[Вернуть: PENDING]
    
    ReturnCompleted --> End([Конец])
    ReturnAcknowledged --> End
    ReturnOverdue --> End
    ReturnPending --> End
    
    style ReturnCompleted fill:#90EE90
    style ReturnAcknowledged fill:#87CEEB
    style ReturnOverdue fill:#FFB6C1
    style ReturnPending fill:#FFE4B5
```

## 5. Обновление Статуса Через Admin Panel

```mermaid
sequenceDiagram
    participant Admin as Admin Panel
    participant API as TaskController
    participant DB as Database
    
    Admin->>API: PATCH /tasks/{id}/status<br/>{status: "pending"}
    
    alt status = "pending"
        API->>DB: DELETE FROM task_responses<br/>WHERE task_id = {id}
        Note over API,DB: Полный сброс<br/>всех ответов
    
    else status = "acknowledged" или "completed"
        API->>DB: INSERT/UPDATE task_responses<br/>(user_id = admin, status = {status})
        Note over API,DB: Создаёт ответ<br/>от имени админа
    
    end
    
    API->>DB: SELECT task + responses
    API->>API: Вычислить статус
    API-->>Admin: Обновлённая задача
```

## 6. Повторяющиеся Задачи (Recurrence)

```mermaid
flowchart LR
    A[Scheduled Job<br/>SendScheduledTasksJob] -->|Проверяет| B{recurrence<br/>!= 'none'?}
    
    B -->|Нет| Z[Пропустить]
    B -->|Да| C{Время совпадает?}
    
    C -->|Нет| Z
    C -->|Да| D[Создать TaskInstance<br/>или отправить уведомление]
    
    D --> E{recurrence_type}
    
    E -->|daily| F[Каждый день<br/>в recurrence_time]
    E -->|weekly| G[Каждую неделю<br/>в день recurrence_day_of_week]
    E -->|monthly| H[Каждый месяц<br/>в день recurrence_day_of_month]
    
    F --> I[Обновить last_recurrence_at]
    G --> I
    H --> I
```

## 7. Проблемные Места и Логические Несостыковки

### 🔴 Проблема 1: Двойственность Статуса
**Описание**: Статус задачи не хранится в БД, а вычисляется на основе `task_responses`. Это создаёт несколько проблем:

1. **Групповые задачи**: Если task_type = 'group', один сотрудник может отметить как 'completed', а остальные - нет. Какой статус у задачи?
   ```
   Задача (group) → 3 сотрудника
   Сотрудник 1: completed
   Сотрудник 2: acknowledged
   Сотрудник 3: (нет ответа)
   
   Текущая логика: status = 'completed' (первый completed побеждает)
   Проблема: Админ видит "Выполнено", хотя 2/3 не выполнили
   ```

2. **Admin vs Employee конфликт**: Админ может установить статус через API (создав response от своего имени), но это НЕ реальный ответ сотрудника.

### 🔴 Проблема 2: Отложенные Задачи (Postponed)
**Текущее состояние**: 
- В БД есть `postpone_count`
- В Telegram боте есть PostponeTaskConversation
- TaskResponse может иметь status='postponed'
- Но мы УДАЛИЛИ 'postponed' из Admin Panel

**Несостыковка**:
- Сотрудник откладывает задачу через бота → `postpone_count` увеличивается
- Админ смотрит в панель → статус показывает 'pending' (т.к. мы удалили postponed логику)
- `postponed()` метод в TaskController ВСЕГДА возвращает задачи с `postpone_count > 0`, но никто его не использует

### 🔴 Проблема 3: Recurrence и Responses
**Сценарий**:
1. Создаётся повторяющаяся задача (daily)
2. Сотрудник выполняет её сегодня → создаётся TaskResponse(status='completed')
3. Завтра задача должна появиться снова
4. Но TaskResponse с вчерашнего дня ВСЁ ЕЩЁ существует
5. Статус показывает 'completed', хотя это новый день

**Отсутствующая логика**: Нет очистки responses для recurring задач.

### 🔴 Проблема 4: response_type Игнорируется
**Поля**:
- `task.response_type` = 'acknowledge' | 'complete'
- `task_response.status` = 'acknowledged' | 'completed' | 'postponed'

**Проблема**: 
- Если task.response_type = 'acknowledge', сотрудник ВСЕГДА может нажать "Выполнено" → status='completed'
- Поле response_type НЕ влияет на доступные действия сотрудника
- Цель поля неясна

### 🟡 Проблема 5: is_active Не Используется Консистентно
**Использование**:
- `index()`: Фильтрует `whereNull('archived_at')` (НЕ проверяет is_active)
- `getStatusAttribute`: Проверяет `is_active` для overdue
- Telegram бот: Не проверяет is_active

**Вопрос**: Что означает `is_active=false`? Это то же самое что `archived_at`? Почему два флага?

## 8. Рекомендации по Улучшению

### Вариант 1: Хранить Статус в БД
```sql
ALTER TABLE tasks ADD COLUMN status VARCHAR(50) DEFAULT 'pending';
CREATE INDEX idx_tasks_status ON tasks(status);
```

**Плюсы**:
- Простые запросы (WHERE status = 'completed')
- Нет вычислений при каждом SELECT
- Явный, предсказуемый статус

**Минусы**:
- Нужна синхронизация при создании/обновлении responses
- Дублирование данных

### Вариант 2: Создавать Новые Task Instances для Recurring
```
recurring_tasks (template)
  └─> task_instances (actual occurrences)
       └─> task_responses
```

**Плюсы**:
- Каждый день - новая задача с чистыми responses
- История выполнения сохраняется
- Нет конфликтов статусов

**Минусы**:
- Больше записей в БД
- Сложнее миграция

### Вариант 3: Удалить Групповые Задачи или Изменить Логику
**Если task_type='group'**:
- Вариант A: Статус = 'completed' только если ВСЕ ответили 'completed'
- Вариант B: Хранить отдельный статус для каждого assignee
- Вариант C: Убрать групповые задачи полностью

### Вариант 4: Унифицировать Postponed
**Либо**:
- Вернуть 'postponed' в Admin Panel
- Показывать postpone_count в UI
- Использовать `postponed()` endpoint

**Либо**:
- Удалить весь функционал postpone
- Удалить PostponeTaskConversation из бота
- Убрать `postpone_count` из БД

