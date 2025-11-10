# The TaskMate Project

## Структура репозитория (рекомендуемая)

```
.
├─ docker-compose.yml                 # общий (common) файлы сервисов / тома / сети
├─ docker-compose.override.yml        # локальные правки (подхватывается автоматически)
├─ docker-compose.prod.yml            # prod-параметры (SSL, открытые порты)
├─ nginx/
│   ├─ nginx.local.conf               # nginx для локалки (без SSL)
│   └─ nginx.prod.conf                # nginx для продакшна (SSL + acme)
├─ certbot/                           # место для certs и webroot
│   ├─ conf/
│   └─ www/
├─ .env.example
└─ сервисы/ (TaskMateBackend, TaskMateFrontend, TaskMateTelegramBot, ...)
```

---

# Быстрый старт — локальная разработка

1. Скопируйте `.env.example` в `.env` и заполните значения (особенно `DB_USERNAME`, `DB_PASSWORD`, `PGADMIN_*` и т.д.).
   **Важно:** не коммитьте `.env` с секретами в репозиторий.

```bash
cp .env.example .env
# отредактировать .env
```

2. Запустить контейнеры (override подхватится автоматически — удобнее для разработки):

```bash
docker compose up -d --build
```

3. Если хотите включить pgAdmin и certbot (dev-удобства), используйте профиль `dev`:

```bash
docker compose --profile dev up -d --build
```

4. Проверить логи одного сервиса:

```bash
docker compose logs -f src_telegram_bot_api
```

5. Остановить (и удалить) контейнеры:

```bash
docker compose down
```

---

# Запуск в продакшн (пример)

В проде мы используем отдельный override (`docker-compose.prod.yml`) с nginx на 80/443 и минимальным набором открытых портов. Всё управление сертификатами — вручную или через CI.

Пример запуска:

```bash
# собрали и подняли прод-стек (используется docker-compose.prod.yml)
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build --remove-orphans
```

**Ключевые принципы для продакшна**

* В проде открываем только `nginx` порты (80/443). БД, valkey и другие сервисы — доступны только внутри сети `web`.
* Секреты — через CI secret manager или docker secrets, не в открытом `.env`.
* Логи и метрики — подключить внешнюю систему (ELK/remote syslog) или собирать с помощью `docker logs` + ротация.

---

# Получение SSL (Let’s Encrypt + certbot)

1. Убедитесь, что DNS домена указывает на сервер с портом 80/443.
2. В `docker-compose.prod.yml` монтируется `./certbot/www` как webroot (см. `nginx.prod.conf`).

Пример запуска получения сертификатов:

```bash
# временно запустить nginx, чтобы ACME- challange работал
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d nginx

# запустить certbot для доменов (замените на свои домены и email)
docker compose -f docker-compose.yml -f docker-compose.prod.yml run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  --email admin@yourdomain.com --agree-tos --no-eff-email \
  -d taskmate.domen.com -d telegram.taskmate.domen.com -d vanilla.taskmate.domen.com

# после получения сертификатов перезапустите nginx (чтобы он подхватил новые файлы)
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d nginx
```

Автообновление сертификатов:

```bash
# Проверка/обновление
docker compose -f docker-compose.yml -f docker-compose.prod.yml run --rm certbot renew --quiet
```

Рекомендуется настроить cron/systemd timer или CI задачу, вызывающую выше команду.

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
Copyright: © 2023-2025 [谢榕川](https://github.com/xierongchuan) All rights reserved.
