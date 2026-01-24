# TaskMate Dev Container

Полноценная среда разработки для проекта TaskMate с предустановленными инструментами и расширениями VS Code.

## 🚀 Быстрый старт

### 1. Предварительные требования

- **Docker Desktop** / **Docker Engine** + **Docker Compose** — или **Podman** (см. ниже)
- **Visual Studio Code** с расширением **Dev Containers**
  - Установите: `ms-vscode-remote.remote-containers`

#### Для Podman (Fedora / RHEL / SELinux)

```bash
# Установка
sudo dnf install podman-compose podman-docker

# Настройка VSCode (Settings JSON):
"dev.containers.dockerPath": "podman",
"dev.containers.dockerComposePath": "podman-compose"
```

> **Важно**: Dev Container для Podman использует `userns_mode: "keep-id"` и `x-podman: in_pod: false` для корректного маппинга UID в rootless-режиме. Подробнее см. секцию «Podman» ниже.

### 2. Открытие проекта в Dev Container

1. Откройте папку проекта в VS Code
2. Нажмите `F1` или `Ctrl+Shift+P` (Cmd+Shift+P на Mac)
3. Выберите: `Dev Containers: Reopen in Container`
4. Дождитесь сборки контейнера (первый запуск может занять 5-10 минут)

### 3. После запуска

Dev Container автоматически выполнит:
- ✅ Установку зависимостей Composer (Backend)
- ✅ Установку зависимостей npm (Frontend)
- ✅ Создание файла `.env` из `.env.example`
- ✅ Настройку прав доступа для Laravel
- ✅ Конфигурацию Git и установку полезных alias'ов

## 📦 Что включено

### Инструменты и утилиты

- **PHP 8.4** с расширениями (PDO PostgreSQL, Redis, GD, BCMath, Intl и др.)
- **Composer** (последняя версия)
- **Node.js LTS** + **npm** (через NVM)
- **PostgreSQL client** для работы с БД
- **Redis CLI** для работы с Valkey
- **Git** + **GitHub CLI**
- **Docker-in-Docker** (для запуска контейнеров внутри Dev Container)
- **Zsh** + **Oh My Zsh** (опционально, по умолчанию bash)

### Дополнительные CLI утилиты

- `htop` - монитор процессов
- `ncdu` - анализатор дисков
- `tree` - визуализация дерева файлов
- `jq` - обработка JSON
- `ripgrep` - быстрый поиск
- `bat` - улучшенный cat
- `fzf` - интерактивный поиск
- `tldr` - краткие справки по командам

### VS Code расширения

#### PHP разработка
- **Intelephense** - интеллектуальное автодополнение PHP
- **PHP Debug** - отладка Xdebug
- **Laravel Extra Intellisense** - автодополнение для Laravel
- **Laravel Blade** - подсветка синтаксиса Blade
- **Blade Formatter** - форматирование Blade шаблонов

#### JavaScript/TypeScript разработка
- **ESLint** - линтинг кода
- **Prettier** - форматирование кода
- **TypeScript** - поддержка TypeScript
- **React snippets** - сниппеты для React

#### Дополнительные расширения
- **Tailwind CSS IntelliSense** - автодополнение Tailwind классов
- **GitLens** - расширенные возможности Git
- **Git Graph** - визуализация истории Git
- **Docker** - управление контейнерами
- **SQLTools** + **PostgreSQL Driver** - работа с БД из VS Code
- **REST Client** - тестирование API запросов
- **GitHub Copilot** - AI ассистент (опционально)

## 🔧 Полезные команды и alias'ы

### Laravel / PHP

```bash
art               # php artisan
tinker            # php artisan tinker
migrate           # php artisan migrate
seed              # php artisan db:seed
test              # php artisan test
pint              # ./vendor/bin/pint (форматирование)
```

### Docker

```bash
dc                # docker compose
dcu               # docker compose up -d
dcd               # docker compose down
dcr               # docker compose restart
dcl               # docker compose logs -f
```

### Навигация

```bash
backend           # cd /workspace/TaskMateServer
frontend          # cd /workspace/TaskMateClient
```

### Git

```bash
gs                # git status
ga                # git add
gc                # git commit
gp                # git push
gl                # git pull
glog              # git log --oneline --graph --decorate
```

## 🌐 Проброшенные порты

Dev Container автоматически пробрасывает следующие порты:

| Порт | Сервис | URL |
|------|--------|-----|
| 5432 | PostgreSQL | `postgres://postgres@localhost:5432` |
| 6379 | Valkey (Redis) | `redis://localhost:6379` |
| 8007 | Backend API | `http://localhost:8007` |
| 8099 | Frontend | `http://localhost:8099` |
| 5173 | Vite Dev Server | `http://localhost:5173` |

## 🗄️ Персистентные данные

Dev Container использует именованные volumes для сохранения данных между перезапусками:

- **Bash history** - история команд сохраняется в `/commandhistory`
- **Composer cache** - кэш Composer в `~/.composer/cache`
- **npm cache** - кэш npm в `~/.npm`

## 🛠️ Типичные сценарии использования

### Первоначальная настройка проекта

```bash
# 1. Перейти в Backend
backend

# 2. Установить зависимости (если не установлены)
composer install

# 3. Настроить .env
cp .env.example .env
# Отредактируйте .env при необходимости

# 4. Сгенерировать ключ приложения
art key:generate

# 5. Запустить миграции
art migrate --force

# 6. Заполнить демо данными
art db:seed-demo

# 7. Создать символическую ссылку на storage
art storage:link
```

### Запуск проекта для разработки

**Backend (в одном терминале):**
```bash
backend
composer dev  # Запускает сервер, очереди, логи и Vite одновременно
```

**Frontend (в другом терминале):**
```bash
frontend
npm run dev
```

### Запуск тестов

```bash
backend

# Все тесты
art test

# Конкретные тесты
composer test:unit       # Unit тесты
composer test:feature    # Feature тесты
composer test:api        # API тесты

# С покрытием кода
composer test:coverage
```

### Работа с базой данных

**Через SQLTools (VS Code расширение):**
1. Нажмите на иконку Database в боковой панели
2. Создайте новое подключение PostgreSQL:
   - Host: `postgres`
   - Port: `5432`
   - Database: `postgres`
   - Username: `postgres`
   - Password: из `.env` файла

**Через CLI:**
```bash
# Подключиться к PostgreSQL
psql -h postgres -U postgres -d postgres

# Или использовать Laravel tinker
art tinker
```

### Форматирование кода

```bash
# Backend (PHP)
backend
pint                      # Laravel Pint
./vendor/bin/php-cs-fixer fix  # PHP CS Fixer

# Frontend (TypeScript/JavaScript)
frontend
npm run lint              # ESLint проверка
npm run lint:fix          # ESLint автоисправление
```

## 🔍 Отладка

### Xdebug для PHP

1. Xdebug уже настроен в контейнере
2. Установите breakpoint в коде
3. Запустите отладку в VS Code (F5)
4. Выберите конфигурацию "Listen for Xdebug"

### React DevTools

Установите расширение React Developer Tools в браузере для отладки React приложений.

## 📝 Настройка редактора

Dev Container автоматически настраивает VS Code:

- ✅ Форматирование при сохранении
- ✅ Автоисправление ESLint/Prettier
- ✅ Tab size: 4 для PHP, 2 для JS/TS
- ✅ Авто-сохранение через 1 секунду после изменений
- ✅ Подсветка синтаксиса для Blade, .env, nginx.conf
- ✅ Исключение vendor и node_modules из поиска

## 🐧 Podman (Fedora / RHEL / SELinux)

Dev Container полностью совместим с Podman в rootless-режиме. Ниже описаны ключевые отличия от Docker.

### Конфигурация devcontainer для Podman

Файл `docker-compose.devcontainer.yml` содержит Podman-специфичные настройки:

```yaml
x-podman:
  in_pod: false          # Отключает pods (конфликтуют с userns_mode)

services:
  devcontainer:
    userns_mode: "keep-id"  # Маппинг UID хоста → контейнера
    volumes:
      - .:/workspace:z      # SELinux метка :z для shared volume
```

### Почему нужен `userns_mode: "keep-id"`

В rootless Podman без этой опции UID 1000 внутри контейнера НЕ соответствует UID 1000 на хосте. Файлы проекта, примонтированные в `/workspace`, будут недоступны для записи.

С `keep-id` UID хоста (1000) маппится на UID контейнера (devuser, 1000) — файлы доступны без проблем с правами.

### Почему нужен `x-podman: in_pod: false`

`podman-compose` по умолчанию объединяет все сервисы в один pod. Флаг `--userns` несовместим с pods, что вызывает ошибку:

```
Error: --userns and --pod cannot be set together
```

Отключение pods переключает сетевое взаимодействие на обычные bridge-сети (как в Docker Compose).

### SELinux метки на volumes

На системах с SELinux каждый bind-mount должен иметь метку:

- `:z` (shared) — том монтируется в несколько контейнеров
- `:Z` (private) — том уникален для одного контейнера
- Без метки — SELinux заблокирует доступ с ошибкой `permission denied`

### Полные имена образов

Podman не использует Docker Hub по умолчанию. Все `FROM` в Dockerfile должны содержать полный путь:

```dockerfile
FROM docker.io/dunglas/frankenphp:1-php8.4          # не frankenphp:1-php8.4
COPY --from=docker.io/library/composer:latest ...   # не composer:latest
```

Без `docker.io/` префикса сборка завершится ошибкой:
```
short-name resolution enforced but cannot prompt without a TTY
```

### Запуск Dev Container с Podman

```bash
# Убедитесь, что .env файл существует
cp .env.example .env  # и заполните DB_USERNAME, DB_PASSWORD

# Создайте директории для certbot (bind-mounts)
mkdir -p certbot/www certbot/conf

# Откройте VSCode и запустите Dev Container
# F1 → "Dev Containers: Reopen in Container"
```

### Проверка работы

```bash
# Внутри Dev Container:
id                    # uid=1000(devuser) gid=1000(devuser)
ls -la /workspace/    # Файлы принадлежат devuser
touch /workspace/test && rm /workspace/test  # Запись работает
php -v && node -v && composer --version      # Инструменты доступны
```

---

## 🚨 Troubleshooting

### Dev Container не запускается

1. Убедитесь, что Docker запущен
2. Проверьте логи: `View -> Command Palette -> Dev Containers: Show Container Log`
3. Попробуйте пересобрать контейнер: `Dev Containers: Rebuild Container`

### База данных не подключается

```bash
# Проверить статус сервисов
docker compose ps

# Перезапустить PostgreSQL
docker compose restart postgres

# Проверить логи
docker compose logs postgres
```

### Проблемы с правами доступа

```bash
# Установить правильные права для Laravel
backend
chmod -R 775 storage bootstrap/cache
```

### Podman: "short-name resolution enforced"

Образ в Dockerfile не содержит полный путь. Добавьте `docker.io/` префикс:
```dockerfile
# Было:
FROM node:22-alpine
# Стало:
FROM docker.io/library/node:22-alpine
```

### Podman: "--userns and --pod cannot be set together"

Отсутствует `x-podman: in_pod: false` в compose-файле. Добавьте в начало `docker-compose.devcontainer.yml`:
```yaml
x-podman:
  in_pod: false
```

### Podman: "SELinux permission denied" при монтировании

Добавьте метку `:z` или `:Z` к volume:
```yaml
volumes:
  - .:/workspace:z    # :z для shared, :Z для private
```

### npm install/composer install не работает

Запустите вручную в терминале Dev Container:
```bash
backend && composer install
frontend && npm install
```

## 🎯 Рекомендации

1. **Используйте встроенный терминал VS Code** вместо внешнего
2. **Commit changes регулярно** - Git настроен на сохранение истории
3. **Используйте SQLTools** для работы с БД вместо внешних клиентов
4. **Проверяйте тесты** перед коммитом: `art test`
5. **Форматируйте код** перед коммитом: `pint` для PHP, `npm run lint:fix` для JS

## 🔗 Полезные ссылки

- [Dev Containers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Laravel Documentation](https://laravel.com/docs)
- [React Documentation](https://react.dev/)
- [Vite Documentation](https://vitejs.dev/)

## 📄 Лицензия

См. [LICENSE.md](../LICENSE.md) в корне проекта.
