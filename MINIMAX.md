# MINIMAX - TaskMate Project Guide

## Обзор проекта

TaskMate - это комплексная система управления задачами и проектами, состоящая из множественных компонентов и интеграций. Проект включает в себя веб-интерфейс, API backend, Telegram боты и систему управления пользователями.

## Архитектура системы

### Основные компоненты

```
TaskMate/
├── TaskMateBackend/           # Laravel API Backend (закомментирован)
├── TaskMateFrontend/          # React Frontend Application  
├── TaskMateTelegramBot/       # Telegram Bot для управления задачами
├── VanillaFlowTelegramBot/    # Telegram Bot для управления расходами
├── Инфраструктура/            # Docker Compose services
│   ├── PostgreSQL            # Основная база данных
│   ├── Valkey               # Redis-подобное хранилище для кэша
│   ├── Nginx                # Reverse proxy и SSL termination
│   ├── PgAdmin              # Администрирование PostgreSQL
│   └── Certbot              # SSL сертификаты (Let's Encrypt)
```

### Активные сервисы (по docker-compose.yml)

1. **TaskMateFrontend** - React приложение (порт 8099)
2. **TaskMateTelegramBot** - Основной Telegram бот (порт 8007)
3. **TaskMateTelegramBot Scheduler** - Очереди и планировщик задач
4. **PostgreSQL** - База данных (порт 5432)
5. **Valkey** - Кэш и очереди (порт 6379)
6. **PgAdmin** - Управление БД (порт 8081)
7. **Nginx** - Reverse proxy (порты 8007, 443)

## Детальное описание компонентов

### TaskMateBackend (Laravel API)
- **Статус**: Закомментирован в docker-compose.yml
- **Технологии**: PHP 8.4.10, Laravel, MySQL/PostgreSQL
- **Назначение**: REST API для управления задачами и пользователями
- **Порт**: 9000 (внутри контейнера)

### TaskMateFrontend (React)
- **Технологии**: React, Vite
- **Назначение**: Веб-интерфейс для управления проектами
- **Порт**: 8099
- **Среда**: Docker container на nginx
- **API**: Подключается к telegram bot API

### TaskMateTelegramBot
- **Технологии**: PHP, Laravel, Nutgram (Telegram Bot Framework)
- **Назначение**: Основной Telegram бот для управления задачами
- **Порт**: 8007
- **Функции**:
  - Управление задачами через Telegram
  - Аутентификация пользователей
  - Синхронизация с внешними системами (VCRM)
  - Уведомления и алерты

### VanillaFlowTelegramBot
- **Статус**: Закомментирован в docker-compose.yml
- **Технологии**: PHP, Laravel, Nutgram
- **Назначение**: Бот для управления расходами (Vanilla Flow система)
- **Роли**: Cashier, Director, User
- **Функции**:
  - Создание заявок на расходы
  - Одобрение/отклонение расходов
  - История транзакций
  - Аудит операций

### Инфраструктурные компоненты

#### База данных
- **PostgreSQL 18**: Основная база данных
- **Базы данных**:
  - `task_mate_backend` (Laravel API)
  - `task_mate_telegram_bot` (Основной бот)
  - `vanilla_flow_telegram_bot` (Бот расходов)

#### Кэш и очереди
- **Valkey**: Redis-подобное хранилище
- **Использование**: Кэширование, очереди задач, сессии

#### Веб-сервер
- **Nginx**: Reverse proxy с поддержкой SSL
- **Конфигурация**: `/etc/nginx/conf.d/default.conf`
- **SSL**: Let's Encrypt сертификаты

#### Администрирование
- **PgAdmin 4**: Web-интерфейс для PostgreSQL
- **Port**: 8081
- **Настройки**: Задаются через переменные окружения

## Запуск проекта

### Полный запуск
```bash
docker compose up -d --build nginx postgres valkey src_laravel_api src_telegram_bot_api src_vanilla_flow_telegram_bot_api pgadmin --force-recreate
```

### Текущий активный запуск
```bash
docker compose up -d --build nginx postgres valkey src_frontend src_telegram_bot_api src_telegram_bot_scheduler pgadmin
```

### SSL сертификаты
```bash
docker compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot --email you@example.com --agree-tos --no-eff-email -d taskmate.andcrm.ru -d telegram.taskmate.andcrm.ru -d vanilla.taskmate.andcrm.ru
```

## Переменные окружения

### Основные настройки
- `DEBUG_MODE`: Режим отладки
- `APP_ENVIRONMENT`: Окружение (local, production)
- `APP_TIMEZONE`: Часовой пояс приложения

### База данных
- `DB_CONNECTION`: Тип подключения (pgsql)
- `DB_HOST`: Хост базы данных
- `DB_PORT`: Порт базы данных
- `DB_USERNAME`: Пользователь БД
- `DB_PASSWORD`: Пароль БД
- `DB_DATABASE_TASK_MATE_TELEGRAM_BOT`: Имя БД для основного бота
- `DB_DATABASE_VANILLA_FLOW_TELEGRAM_BOT`: Имя БД для бота расходов

### Telegram Bot настройки
- `TASK_MATE_TELEGRAM_BOT_TOKEN`: Токен основного бота
- `VANILLA_FLOW_TELEGRAM_BOT_TOKEN`: Токен бота расходов
- `NUTGRAM_LOG_CHAT_ID`: ID чата для логов

### Внешние интеграции
- `VCRM_API_URL`: URL внешней CRM системы
- `VCRM_API_TOKEN`: Токен для доступа к CRM API

## Безопасность

### SSL/TLS
- Автоматическое получение SSL сертификатов через Certbot
- Поддержка множественных доменов
- Автоматическое обновление сертификатов

### Аутентификация
- Laravel Sanctum для API аутентификации
- JWT токены для Telegram ботов
- Интеграция с внешними системами (VCRM)

## Мониторинг и логирование

### Система логов
- Laravel логирование в контейнерах
- Централизованное хранение логов в volumes
- Настройки логирования в `config/logging.php`

### Мониторинг
- PgAdmin для мониторинга БД
- Nginx access/error логи
- Supervisor для мониторинга процессов

## Разработка

### Локальная разработка
1. Клонирование репозитория
2. Настройка `.env` файла
3. Запуск `docker-compose up`
4. Доступ к приложениям через браузер

### Тестирование
- PHPUnit для PHP компонентов
- Pest тестовый фреймворк для Laravel
- Интеграционные тесты для ботов

### Структура проекта
```
├── docker-compose.yml          # Docker Compose конфигурация
├── nginx.conf                 # Nginx конфигурация
├── .env                       # Переменные окружения
├── certbot/                   # SSL сертификаты
│   ├── conf/                 # Сертификаты Let's Encrypt
│   └── www/                  # Webroot для certbot
├── valkey.conf               # Конфигурация Valkey
└── init-multiple-dbs.sh     # Скрипт инициализации БД
```

## Лицензирование

**Proprietary License**  
Copyright: © 2023-2025 [谢榕川](https://github.com/xierongchuan) All rights reserved.

## Поддерживаемые технологии

### Backend
- **PHP**: 8.4.10
- **Laravel**: Framework для API
- **PostgreSQL**: 18
- **Valkey**: Redis-подобное хранилище

### Frontend  
- **React**: JavaScript фреймворк
- **Vite**: Build tool и dev server

### Infrastructure
- **Docker**: Контейнеризация
- **Nginx**: Reverse proxy
- **Certbot**: SSL сертификаты
- **PgAdmin**: Администрирование БД

### APIs и интеграции
- **REST API**: Laravel API endpoints
- **Telegram Bot API**: Через Nutgram
- **VCRM API**: Интеграция с внешней CRM

## Контактная информация

Для получения дополнительной информации или поддержки обращайтесь к владельцу проекта: [谢榕川](https://github.com/xierongchuan)

---

*Последнее обновление: 2025-10-29*
