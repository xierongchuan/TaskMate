#!/bin/bash

# Остановка при ошибке
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Проверка наличия .env файла
if [ ! -f .env ]; then
    log_error "Ошибка: Файл .env не найден!"
    echo "Пожалуйста, скопируйте .env.example в .env и заполните переменные."
    exit 1
fi

echo "🚀 Начинаем деплой в продакшн..."

# Опционально: затягиваем обновления
if [[ "$1" == "--pull" ]]; then
    echo "📥 Затягиваем обновления из git..."
    git pull origin main
    git submodule update --init --recursive
fi

# Определяем, первый ли это запуск
FIRST_RUN=false
if [[ "$1" == "--init" ]] || [[ "$2" == "--init" ]]; then
    FIRST_RUN=true
    log_warn "Режим первоначальной инициализации"
fi

echo "🏗️  Сборка и запуск контейнеров..."
podman compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build --remove-orphans

echo "⏳ Ожидание готовности базы данных..."
# Ждём готовности PostgreSQL (до 60 секунд)
RETRIES=12
until podman compose exec -T postgres pg_isready -U "${DB_USERNAME:-postgres}" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
    echo "   Ожидание PostgreSQL... (осталось попыток: $RETRIES)"
    RETRIES=$((RETRIES-1))
    sleep 5
done

if [ $RETRIES -eq 0 ]; then
    log_error "PostgreSQL не готов после 60 секунд"
    exit 1
fi
log_info "PostgreSQL готов"

echo "📦 Установка зависимостей PHP..."
podman compose exec -T api composer install --optimize-autoloader --no-dev --no-interaction

# Первоначальная инициализация
if [ "$FIRST_RUN" = true ]; then
    echo "🔑 Генерация ключа приложения..."
    podman compose exec -T api php artisan key:generate --force

    echo "🔗 Создание символической ссылки для storage..."
    podman compose exec -T api php artisan storage:link
fi

echo "🗄️  Выполнение миграций..."
podman compose exec -T api php artisan migrate --force

# Первоначальный seed (только при --init)
if [ "$FIRST_RUN" = true ]; then
    log_warn "Запуск начальных сидов..."
    podman compose exec -T api php artisan db:seed --force
fi

echo "⚡ Оптимизация Laravel..."
podman compose exec -T api php artisan config:cache
podman compose exec -T api php artisan route:cache
podman compose exec -T api php artisan view:cache
podman compose exec -T api php artisan event:cache

echo "🔄 Перезапуск очереди задач..."
podman compose exec -T scheduler php artisan queue:restart || true

echo "🧹 Очистка старых образов..."
podman image prune -f

echo "📊 Проверка статуса сервисов..."
podman compose -f docker-compose.yml -f docker-compose.prod.yml ps

log_info "Деплой завершен!"

echo ""
echo "📝 Полезные команды:"
echo "   Логи:      podman compose logs -f api"
echo "   Статус:    podman compose ps"
echo "   Миграции:  podman compose exec api php artisan migrate:status"
echo ""

if [ "$FIRST_RUN" = true ]; then
    log_warn "Не забудьте настроить SSL сертификаты:"
    echo "   podman compose --profile certbot run certbot certonly --webroot -w /var/www/certbot -d your-domain.com"
fi
