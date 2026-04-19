# Справочник API

[← Назад: Telegram Bot](telegram-bot.md) | [Далее: Правила и конвенции](rules-conventions.md)

## Обзор

TaskMate API предоставляет REST интерфейс для управления задачами в автодилерах. Все эндпоинты используют JSON формат и требуют аутентификации через Bearer токены (Sanctum).

**Base URL:** `/api/v1`

**Аутентификация:** `Authorization: Bearer {token}`

**Формат дат:** UTC ISO 8601 с Z суффиксом (`2024-01-15T10:30:00Z`)

## Аутентификация

### POST /auth/login

Аутентификация пользователя.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "password"
}
```

**Response:**
```json
{
  "data": {
    "user": {
      "id": 1,
      "name": "Иван Иванов",
      "email": "user@example.com",
      "role": "employee"
    },
    "token": "1|abc123..."
  }
}
```

## Пользователи (Users)

### GET /users

Получить список пользователей дилера.

**Query Parameters:**
- `search` — поиск по имени/email
- `role` — фильтр по роли
- `per_page` — элементов на страницу

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "Иван Иванов",
      "email": "user@example.com",
      "role": "employee",
      "created_at": "2024-01-15T10:30:00Z"
    }
  ],
  "meta": { "per_page": 15, "total": 50 }
}
```

### GET /users/{id}

Получить пользователя по ID.

### POST /users

Создать пользователя.

**Request:**
```json
{
  "name": "Новый Пользователь",
  "email": "new@example.com",
  "password": "password123",
  "role": "employee"
}
```

### PUT /users/{id}

Обновить пользователя.

### DELETE /users/{id}

Удалить пользователя (soft delete).

## Автодилеры (Dealerships)

### GET /dealerships

Список дилеров (для owner).

### GET /dealerships/{id}

Детали дилера.

### POST /dealerships

Создать дилер.

### PUT /dealerships/{id}

Обновить дилер.

### DELETE /dealerships/{id}

Удалить дилер.

## Смены (Shifts)

### GET /shifts

Список смен.

**Query Parameters:**
- `user_id` — фильтр по пользователю
- `date_from`, `date_to` — диапазон дат
- `status` — active/completed

### GET /shifts/current

Текущая активная смена пользователя.

### GET /shifts/my

Мои смены.

### POST /shifts

Создать смену.

**Request:**
```json
{
  "user_id": 1,
  "schedule_id": 1,
  "start_time": "2024-01-15T09:00:00Z",
  "end_time": "2024-01-15T18:00:00Z"
}
```

### PUT /shifts/{id}

Обновить смену.

### DELETE /shifts/{id}

Удалить смену.

## Задачи (Tasks)

### GET /tasks

Список задач.

**Query Parameters:**
- `status` — pending/in_progress/pending_review/verified/rejected
- `type` — notification/completion/completion_with_proof
- `assigned_user_id` — задачи пользователя
- `creator_id` — созданные пользователем
- `date_from`, `date_to` — диапазон дат
- `priority` — low/medium/high
- `search` — поиск по названию/описанию

### GET /tasks/my-history

История моих задач.

### GET /tasks/{id}

Детали задачи.

**Response:**
```json
{
  "data": {
    "id": 1,
    "title": "Проверить документы",
    "description": "Проверить документы клиента",
    "type": "completion_with_proof",
    "status": "pending",
    "priority": "medium",
    "created_at": "2024-01-15T10:30:00Z",
    "deadline": "2024-01-16T10:30:00Z",
    "creator": { "id": 2, "name": "Менеджер" },
    "assignments": [
      {
        "user": { "id": 1, "name": "Сотрудник" },
        "assigned_at": "2024-01-15T10:30:00Z"
      }
    ],
    "responses": []
  }
}
```

### POST /tasks

Создать задачу.

**Request:**
```json
{
  "title": "Новая задача",
  "description": "Описание",
  "type": "completion",
  "priority": "medium",
  "deadline": "2024-01-16T10:30:00Z",
  "assigned_user_ids": [1, 2]
}
```

### PUT /tasks/{id}

Обновить задачу.

### DELETE /tasks/{id}

Удалить задачу.

### PATCH /tasks/{id}/status

Изменить статус задачи.

**Request:**
```json
{
  "status": "in_progress",
  "proof_files": [
    { "name": "doc.pdf", "size": 1024000, "mime_type": "application/pdf" }
  ]
}
```

## Верификация задач

### POST /task-responses/{id}/approve

Одобрить задачу.

**Request:**
```json
{
  "comment": "Хорошо выполнено"
}
```

### POST /task-responses/{id}/reject

Отклонить задачу.

**Request:**
```json
{
  "comment": "Нужно исправить"
}
```

## Доказательства задач (Task Proofs)

### GET /task-proofs/{id}/download

Скачать файл доказательства (signed URL).

### DELETE /task-proofs/{id}

Удалить файл доказательства.

## Генераторы задач (Task Generators)

### GET /task-generators

Список генераторов.

### GET /task-generators/{id}

Детали генератора.

### GET /task-generators/{id}/tasks

Сгенерированные задачи.

### POST /task-generators

Создать генератор.

**Request:**
```json
{
  "name": "Ежедневная проверка",
  "template": {
    "title": "Проверка оборудования",
    "type": "completion_with_proof",
    "schedule": "daily",
    "assigned_user_ids": [1]
  },
  "active": true
}
```

### PUT /task-generators/{id}

Обновить генератор.

### DELETE /task-generators/{id}

Удалить генератор.

### POST /task-generators/{id}/pause

Приостановить генератор.

### POST /task-generators/{id}/resume

Возобновить генератор.

## Архив задач

### GET /archived-tasks

Архивные задачи.

### POST /archived-tasks/{id}/restore

Восстановить задачу из архива.

## Настройки (Settings)

### GET /settings

Все настройки дилера.

### GET /settings/{key}

Конкретная настройка.

### PUT /settings/{key}

Обновить настройку.

## Календарь

### GET /calendar/{year}

Календарь на год.

### GET /calendar/{year}/holidays

Праздничные дни.

### PUT /calendar/{date}

Обновить день календаря.

## Dashboard

### GET /dashboard

Статистика для dashboard.

**Response:**
```json
{
  "data": {
    "today_tasks": {
      "overdue": 5,
      "pending": 10,
      "completed": 8
    },
    "weekly_stats": {
      "created": 25,
      "completed": 22,
      "verified": 20
    },
    "user_stats": {
      "my_overdue": 2,
      "my_pending": 3
    }
  }
}
```

## Отчеты (Reports)

### GET /reports

Общие отчеты.

### GET /reports/issues/{type}

Детали по проблемам.

## Важные ссылки (Links)

### GET /links

Список важных ссылок.

### POST /links

Создать ссылку.

### PUT /links/{id}

Обновить ссылку.

### DELETE /links/{id}

Удалить ссылку.

## Конфигурация загрузки файлов

### GET /config/file-upload

Общая конфигурация загрузки.

### GET /config/file-upload/{preset}

Конфигурация для preset.

## Уведомления

### GET /notification-settings

Настройки уведомлений.

### PUT /notification-settings/{channelType}

Обновить настройки канала.

### POST /notification-settings/bulk

Массовое обновление.

### POST /notification-settings/reset

Сброс к дефолтам.

## Ошибки

API возвращает стандартные HTTP статусы:

- `200` — Успех
- `201` — Создано
- `400` — Bad Request (валидация)
- `401` — Unauthorized
- `403` — Forbidden (права доступа)
- `404` — Not Found
- `422` — Unprocessable Entity (бизнес-логика)
- `500` — Internal Server Error

**Формат ошибки:**
```json
{
  "message": "Validation failed",
  "errors": {
    "title": ["Поле обязательно для заполнения"]
  }
}
```

## Rate Limiting

Все аутентифицированные эндпоинты ограничены: 60 запросов в минуту.

[← Назад: Telegram Bot](telegram-bot.md) | [Далее: Правила и конвенции](rules-conventions.md)
