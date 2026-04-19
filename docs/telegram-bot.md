# Telegram Bot (Python)

[← Назад: Frontend](frontend.md) | [Далее: Справочник API](api-reference.md)

## Обзор

Telegram бот предоставляет мобильный интерфейс для сотрудников автодилера. Реализован на Python с aiogram 3, работает асинхронно и получает все данные через REST API backend.

## Стек технологий

- **Python**: 3.12
- **Framework**: aiogram 3.x (асинхронный)
- **HTTP Client**: httpx (асинхронный)
- **Scheduler**: APScheduler 4.x
- **Cache/Sessions**: Valkey (redis.asyncio)
- **Queues**: RabbitMQ consumer
- **Config**: pydantic-settings

## Архитектура

### Принцип: Данные только через API

Бот НЕ имеет прямого доступа к базе данных. Все операции через REST API `/api/v1/*`.

```
TaskMateServer (Laravel API)
       ↑ REST API (httpx)
TaskMateTelegramBot
       ↓ Telegram Bot API
Пользователи (Telegram)
```

### Асинхронная коммуникация

- **RabbitMQ Consumer**: Асинхронные уведомления о новых задачах
- **APScheduler**: Периодический опрос API для уведомлений
- **Valkey**: Сессии пользователей и кеш

## Структура проекта

```
src/
├── main.py                 # Точка входа: бот + scheduler + consumer
├── config.py               # pydantic-settings для переменных окружения
├── api/
│   └── client.py           # httpx клиент к TaskMateServer
├── bot/
│   ├── bot.py              # Инициализация, AuthMiddleware
│   ├── messages.py         # Шаблоны сообщений (русский язык)
│   ├── keyboards.py        # Inline клавиатуры
│   └── handlers/           # common/, auth/, tasks/, shifts/
├── scheduler/
│   └── polling.py          # Опрос API для уведомлений
├── storage/
│   └── sessions.py         # Сессии chat_id ↔ token в Valkey
└── consumers/              # RabbitMQ для асинхронных задач
```

## Конвенции разработки

### Async everywhere

Весь код асинхронный — aiogram, httpx, redis.asyncio. Синхронные операции запрещены.

```python
# ПРАВИЛЬНО: async/await везде
async def get_tasks(user_id: int) -> list[Task]:
    async with httpx.AsyncClient() as client:
        response = await client.get(f'/api/v1/tasks?user_id={user_id}')
        return response.json()

# НЕПРАВИЛЬНО: синхронный код запрещён
def get_tasks(user_id):
    return requests.get(...).json()  # Blocking!
```

### Данные только через API

```python
# ПРАВИЛЬНО: REST API
await api_client.get('/tasks')

# НЕПРАВИЛЬНО: прямой доступ к БД (запрещён)
# Нет доступа к PostgreSQL/Valkey напрямую
```

### FSM для многошаговых операций

Finite State Machine для загрузки proof файлов и авторизации.

```python
# src/bot/handlers/tasks.py
class UploadProofStates(StatesGroup):
    waiting_file = State()
    waiting_comment = State()

@router.message(UploadProofStates.waiting_file)
async def process_file(message: Message, state: FSMContext):
    # Обработка загруженного файла
    await state.set_state(UploadProofStates.waiting_comment)
```

### Аутентификация (AuthMiddleware)

Middleware проверяет сессию в Valkey перед каждым handler.

```python
# src/bot/bot.py
class AuthMiddleware(BaseMiddleware):
    async def __call__(self, handler, event, data):
        chat_id = event.chat.id
        token = await redis.get(f'chat:{chat_id}:token')
        if not token:
            await event.answer('Выполните /login')
            return
        data['token'] = token
        return await handler(event, data)
```

## Команды бота

| Команда | Доступ | Описание |
|---------|--------|----------|
| `/start` | публичный | Приветствие + инструкция по авторизации |
| `/help` | публичный | Справка по командам |
| `/login` | публичный | FSM авторизация (ввод email/password) |
| `/logout` | auth | Выход, очистка сессии |
| `/tasks` | auth | Список назначенных задач |
| `/task {id}` | auth | Детали задачи + действия |
| `/shift` | auth | Текущая смена сотрудника |
| `/shifts` | auth | История смен |

## API клиент

### httpx клиент

```python
# src/api/client.py
class TaskMateAPI:
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.client = httpx.AsyncClient(
            headers={'Authorization': f'Bearer {token}'}
        )
    
    async def get_tasks(self, user_id: int) -> list[dict]:
        response = await self.client.get(f'/users/{user_id}/tasks')
        return response.json()
```

## Сессии и кеш

### Valkey для сессий

```python
# src/storage/sessions.py
class SessionStorage:
    def __init__(self, redis: redis.asyncio.Redis):
        self.redis = redis
    
    async def set_token(self, chat_id: int, token: str):
        await self.redis.setex(f'chat:{chat_id}:token', 86400, token)  # 24 часа
    
    async def get_token(self, chat_id: int) -> str | None:
        return await self.redis.get(f'chat:{chat_id}:token')
```

## RabbitMQ Consumer

### Асинхронные уведомления

```python
# src/consumers/tasks.py
async def consume_task_notifications():
    connection = await aio_pika.connect(os.getenv('RABBITMQ_URL'))
    channel = await connection.channel()
    queue = await channel.declare_queue('task_notifications')
    
    async with queue.iterator() as queue_iter:
        async for message in queue_iter:
            # Отправка уведомления пользователю
            await bot.send_message(chat_id, f'Новая задача: {task.title}')
```

## Переменные окружения

| Переменная | Описание | Пример |
|------------|----------|--------|
| `TELEGRAM_BOT_TOKEN` | Токен от @BotFather | `123456:ABCdef...` |
| `TASKMATE_API_URL` | URL backend API | `http://api:8000/api/v1` |
| `VALKEY_HOST` | Хост Redis | `svc-valkey` |
| `VALKEY_PORT` | Порт Redis | `6379` |
| `VALKEY_DB` | Номер БД | `0` |
| `RABBITMQ_HOST` | Хост RabbitMQ | `svc-rabbitmq` |
| `RABBITMQ_USER` | Пользователь | `guest` |
| `RABBITMQ_PASSWORD` | Пароль | `guest` |
| `LOG_LEVEL` | Уровень логирования | `INFO` |

Примечание: для FSM (многошаговых операций) бот использует Redis/Valkey как хранилище состояний. Убедитесь, что `VALKEY_HOST`/`VALKEY_PORT` настроены и доступны. При необходимости включите Redis-FSM через `VALKEY_FSM_ENABLED=true`.

## Запуск

### Через podman compose

```bash
# Запуск бота
podman compose --profile bot up -d --build

# Логи
podman compose logs -f telegram-bot
```

### Локально (разработка)

```bash
cd TaskMateTelegramBot
pip install -r requirements.txt
python -m src.main
```

## Сообщения и локализация

### Шаблоны сообщений

```python
# src/bot/messages.py
MESSAGES = {
    'welcome': 'Добро пожаловать в TaskMate Bot!',
    'login_prompt': 'Введите email и пароль через пробел:',
    'task_created': 'Задача "{title}" создана',
    'task_completed': 'Задача выполнена ✅',
}
```

### Клавиатуры

```python
# src/bot/keyboards.py
def task_actions_keyboard(task_id: int) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text='✅ Выполнить', callback_data=f'complete_{task_id}')],
        [InlineKeyboardButton(text='📎 Добавить файл', callback_data=f'upload_{task_id}')],
    ])
```

## Обработка ошибок

### Try/except для API вызовов

```python
try:
    tasks = await api_client.get_tasks(user_id)
except httpx.HTTPError as e:
    await message.answer('Ошибка подключения к серверу')
    logger.error(f'API error: {e}')
```

## Производительность

- **Async/Await**: Все операции неблокирующие
- **Connection Pooling**: httpx переиспользует соединения
- **Кеш сессий**: Valkey для быстрого доступа к токенам
- **Rate Limiting**: Защита от спама через middleware

## Безопасность

- **Токены в Valkey**: С TTL 24 часа, не в памяти
- **AuthMiddleware**: Проверка перед каждым handler
- **FSM**: Защищенные многошаговые операции
- **Валидация**: Проверка входных данных

[← Назад: Frontend](frontend.md) | [Далее: Справочник API](api-reference.md)
