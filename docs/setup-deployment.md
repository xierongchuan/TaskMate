# Установка и развертывание

[← Назад: Правила и конвенции](rules-conventions.md) | [Далее: Руководство по контрибьютингу](contributing.md)

## Быстрый старт

### Полная установка

```bash
# 1. Запуск сервисов
podman compose up -d --build

# 2. Backend: установка зависимостей
podman compose exec api composer install

# 3. Backend: миграции и сидеры
podman compose exec api php artisan migrate --force
podman compose exec api php artisan db:seed-demo

# 4. Backend: симлинк для storage
podman compose exec api php artisan storage:link
```

### Доступ

- **Frontend:** http://localhost:8099
- **Backend API:** http://localhost:8007
- **RabbitMQ UI:** http://localhost:15672

### Demo аккаунты

| Роль | Логин | Пароль |
|------|-------|--------|
| Admin (Owner) | admin | password |
| Manager | manager1 | password |
| Employee | emp1_1 | password |

## Детальная установка по модулям

### Backend (Laravel)

```bash
# Зависимости
podman compose exec api composer install

# Миграции
podman compose exec api php artisan migrate --force

# Сидеры (демо-данные)
podman compose exec api php artisan db:seed-demo

# Storage симлинк
podman compose exec api php artisan storage:link

# Очистка кеша
podman compose exec api php artisan cache:clear
podman compose exec api php artisan config:clear
```

### Frontend (React)

```bash
# Dev server
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run dev

# Production build
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run build

# Линтинг
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run lint

# Установка пакета
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm install <package>
```

### Telegram Bot (Python)

```bash
# Локально (разработка)
cd TaskMateTelegramBot
pip install -r requirements.txt
python -m src.main

# Через podman
podman compose --profile bot up -d --build

# Логи
podman compose logs -f telegram-bot
```

## Команды разработки

### Backend

```bash
# Тесты
podman compose exec api php artisan test
podman compose exec api php artisan test --filter=TaskControllerTest
podman compose exec api php artisan test --filter="TaskControllerTest::test_user_can_create_task"
podman compose exec api composer test:coverage

# Линтинг и форматирование
podman compose exec api php vendor/bin/pint              # Авто-фикс
podman compose exec api php vendor/bin/pint --test       # Проверка только
```

### Frontend

```bash
# Dev server
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run dev

# Build
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run build

# Линтинг
podman run --rm -v ./TaskMateClient:/app:z -w /app docker.io/library/node:22-alpine npm run lint

# E2E тесты
podman run --rm --network host -v ./TaskMateClient:/app:z -w /app mcr.microsoft.com/playwright:v1.58.0-noble npx playwright test
podman run --rm --network host -v ./TaskMateClient:/app:z -w /app mcr.microsoft.com/playwright:v1.58.0-noble npx playwright test dashboard
```

### Общие

```bash
# Логи сервисов
podman compose logs -f svc-api
podman compose logs -f svc-frontend
podman compose logs -f telegram-bot

# Перезапуск сервиса
podman compose restart svc-api

# Остановка всех
podman compose down
```

## Развертывание

### Production окружение

1. **Клонировать репозиторий**
2. **Настроить .env файлы** для каждого модуля
3. **Запустить сервисы** `podman compose up -d --build`
4. **Выполнить миграции** и сидеры
5. **Настроить reverse proxy** (Nginx/Caddy)

### Переменные окружения

#### Backend (.env)

```env
APP_NAME=TaskMate
APP_ENV=production
APP_KEY=base64:key
APP_DEBUG=false
APP_URL=https://your-domain.com

DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=taskmate
DB_USERNAME=user
DB_PASSWORD=password

CACHE_DRIVER=redis
QUEUE_CONNECTION=rabbitmq

REDIS_HOST=valkey
RABBITMQ_HOST=rabbitmq

SANCTUM_STATEFUL_DOMAINS=your-domain.com
```

#### Frontend (.env)

```env
VITE_API_URL=https://your-domain.com/api/v1
VITE_APP_ENV=production
```

#### Telegram Bot (.env)

```env
TELEGRAM_BOT_TOKEN=your_bot_token
TASKMATE_API_URL=https://your-domain.com/api/v1
VALKEY_HOST=valkey
RABBITMQ_HOST=rabbitmq
```

### SSL сертификаты

Использовать Certbot для автоматических сертификатов:

```bash
podman run --rm -v ./certbot:/etc/letsencrypt certbot/certbot certonly --standalone -d your-domain.com
```

## Android приложение

### Сборка APK

```bash
# Первая сборка (JDK + Android SDK)
podman compose --profile android build android-builder

# Debug APK
./scripts/build-android.sh

# Release APK
./scripts/build-android.sh --release
```

### Настройка API URL

```env
# Через туннель
ANDROID_API_URL=http://your-server.com/api/v1

# Через LAN
ANDROID_API_URL=http://192.168.1.100:8099/api/v1
```

### Установка на устройство

```bash
# Wi-Fi debugging
ADB_CONNECT=192.168.1.XX:YYYY ./scripts/build-android.sh --deploy
```

## Troubleshooting

### Общие проблемы

| Проблема | Решение |
|----------|---------|
| Permission denied | `podman compose down && podman compose up -d --build` |
| Changes not applied | `podman compose build --no-cache` |
| Database connection | Проверить `DB_HOST=postgres` |
| CORS issues | Настроить `SANCTUM_STATEFUL_DOMAINS` |

### Podman specific

```bash
# Rootless permissions
./scripts/fix-permissions.sh
podman compose restart svc-api

# SELinux issues
# Добавить :z или :Z к volume mounts
```

### Submodule issues

```bash
# Пересборка frontend
./scripts/rebuild-frontend.sh

# Пересборка bot
./scripts/rebuild-telegram-bot.sh
```

## Мониторинг

### Логи

```bash
# Все сервисы
podman compose logs

# Конкретный сервис
podman compose logs svc-api

# Follow logs
podman compose logs -f svc-worker-proof
```

### Health checks

```bash
# API health
curl http://localhost:8007/api/v1/up

# Frontend
curl http://localhost:8099

# RabbitMQ
curl http://localhost:15672
```

[← Назад: Правила и конвенции](rules-conventions.md) | [Далее: Руководство по контрибьютингу](contributing.md)
