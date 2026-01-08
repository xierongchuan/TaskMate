# The TaskMate Project

Комплексная система управления задачами, включающая Telegram-бота для сотрудников и веб-интерфейс для управления процессами.

## 📂 Структура репозитория

```
.
├─ docker-compose.yml                 # Общие настройки сервисов
├─ docker-compose.override.yml        # Локальные правки (порты, pgadmin)
├─ docker-compose.prod.yml            # Прод-параметры (SSL, Nginx)
├─ nginx/
│   ├─ nginx.local.conf               # Nginx для локальной разработки
│   └─ nginx.prod.conf                # Nginx для продакшна (SSL)
├─ TaskMateFrontend/                 # Frontend (React 19, TypeScript, Vite 7)
├─ TaskMateTelegramBot/              # Backend & Bot (Laravel 12, PHP 8.4)
├─ TaskMateAPI/                      # Коллекция API (Bruno)
└─ ...
```

---

# 🚀 Быстрый старт — локальная разработка

1. Скопируйте `.env.example` в `.env` и заполните значения.
   **Важно:** Обязательно укажите параметры БД и токены Telegram.

```bash
cp .env.example .env
```

2. Запустить контейнеры:

```bash
docker compose up -d --build
```

3. Для инструментов разработки (pgAdmin) используйте профиль `dev`:

```bash
docker compose --profile dev up -d
```

4. Выполнить миграции и сидинг (при первом запуске):

```bash
docker compose exec src_telegram_bot_api php artisan migrate --seed
```

---

# 🛠 Технологический стек

### Frontend
- **Framework**: React 19
- **Build Tool**: Vite 7
- **Styling**: Tailwind CSS
- **State**: Zustand
- **Query**: TanStack Query v5

### Backend & Bot
- **Framework**: Laravel 12
- **Language**: PHP 8.4
- **Bot SDK**: Nutgram
- **Database**: PostgreSQL 16
- **Cache**: Valkey (Redis-compatible)

---

# ✨ Основные функции и особенности

* **Telegram Bot** — оперативный интерфейс для сотрудников (открытие/закрытие смен, выполнение задач).
* **Web Interface** — мощная админ-панель для контроля и аналитики.
* **Unified UI** — единый стиль компонентов (`PageContainer`, `PageHeader`) и полная поддержка **Dark Mode**.
* **Theme Persistence** — выбор темы (Светлая, Тёмная, Системная) с сохранением в настройках.
* **Task Generators** — автоматическое создание повторяющихся задач по расписанию.
* **Notification Center** — гибкая настройка уведомлений через Telegram и другие каналы.
* **Shifts Control** — контроль рабочего времени с фотофиксацией.

---

# Что поменялось (чтобы не теряться)

* `docker-compose.yml` — теперь **общий** файл: сервисы, тома, сеть и healthchecks. По умолчанию НЕ пробрасывает все порты на хост (безопасно).
* `docker-compose.override.yml` — локальные удобные правки: проброс портов (`postgres:5432`, `valkey:6379`, `frontend:8099`), добавление `pgadmin` в профиль `dev`.
* `docker-compose.prod.yml` — prod-правки: nginx 80/443, certs; используйте при деплое.
* nginx split: `nginx/nginx.local.conf` (локалка) и `nginx/nginx.prod.conf` (prod — letsencrypt).
* Используем `profiles` (например `dev`) для сервисов, которые поднимать в проде не нужно (pgadmin, certbot).

---

# Полезные команды и советы

* Поднять один сервис:

```bash
docker compose up -d src_telegram_bot_api
```

* Пересобрать один сервис:

```bash
docker compose build --no-cache src_telegram_bot_api
docker compose up -d src_telegram_bot_api
```

* Выполнить команду внутри контейнера:

```bash
docker compose exec src_telegram_bot_api bash
# или для миграций Laravel:
docker compose exec src_telegram_bot_api php artisan migrate --force
```

* Очистка тома PostgreSQL (внимание — удалит данные):

```bash
docker compose down
docker volume rm <repo_name>_postgres_data
```

* Если nginx не может подключиться к php-fpm — проверьте `fastcgi_pass` (имя сервиса + порт, например `src_telegram_bot_api:9000`) и что сервис поднят.

* Для `depends_on` в docker compose: это не ждёт пока сервис полностью готов. Для корректного тайминга используйте `healthcheck` или `wait-for-it.sh`/`dockerize`.

---

# Переменные окружения (.env)

Обновлённый `.env.example` включает основные переменные:

* `DEBUG_MODE`, `APP_ENVIRONMENT`, `APP_TIMEZONE`
* `DB_*` (`DB_HOST=postgres`, `DB_PORT=5432`, `DB_USERNAME`, `DB_PASSWORD`)
* `VITE_API_BASE_URL` (локально `http://localhost:8007/api/v1`, в проде `https://api.yourdomain.com/api/v1`)
* `TASK_MATE_TELEGRAM_BOT_TOKEN` и другие токены — **никогда** в публичный репозиторий

---

# Безопасность и best-practices

* Не публикуйте `.env` с секретами.
* Не пробрасывайте порты БД/Valkey в проде.
* Используйте `docker compose` с двумя файлами (`-f docker-compose.yml -f docker-compose.prod.yml`) для предсказуемости.
* Храните бэкапы Postgres (pg_dump) и снимки томов.

---

# Troubleshooting (частые грабли)

* `Permission denied` при записи в `storage` — проверьте права и владельца в контейнере: `chown -R www-data:www-data storage bootstrap/cache`.
* `Cannot connect to database` — проверьте `.env` в контейнере и `DB_HOST` (`postgres` в сети `web`).
* `Ports already in use` — проверьте процессы на хосте: `ss -tulpn | grep :8007` и измените `docker-compose.override.yml` или освободите порт.

---

# CI/CD (коротко)

Пример шага в CI для деплоя:

```bash
# pull новых образов и поднять только prod-override
docker compose -f docker-compose.yml -f docker-compose.prod.yml pull
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --remove-orphans
```

Секреты подставляйте через CI переменные, не храните в репозитории.

---

## Лицензия

License: Proprietary License
Copyright: © 2023-2026 [谢榕川](https://github.com/xierongchuan) All rights reserved.
