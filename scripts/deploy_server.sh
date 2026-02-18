#!/bin/bash
# =============================================================
# Серверный деплой TaskMate (vfp.andcrm.ru)
#
# Использование:
#   ./scripts/deploy_server.sh              # полный деплой
#   ./scripts/deploy_server.sh --init       # первый запуск (+ seed)
#   ./scripts/deploy_server.sh --skip-build # только код + миграции
# =============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.server.yml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[OK] $1${NC}"; }
log_warn()  { echo -e "${YELLOW}[!!] $1${NC}"; }
log_error() { echo -e "${RED}[ERR] $1${NC}"; }
log_step()  { echo -e "\n${GREEN}==> $1${NC}"; }

COMPOSE="docker compose -f $COMPOSE_FILE"
FIRST_RUN=false
SKIP_BUILD=false

for arg in "$@"; do
    case $arg in
        --init)       FIRST_RUN=true ;;
        --skip-build) SKIP_BUILD=true ;;
    esac
done

cd "$PROJECT_ROOT"

if [ ! -f .env ]; then
    log_error "Файл .env не найден!"
    exit 1
fi

# ── 1. Git pull ──────────────────────────────────────────────
log_step "Обновление кода..."
git fetch origin
git checkout vfp
git pull origin vfp
git submodule update --init --recursive
log_info "Код обновлён"

# ── 2. Сборка образов ───────────────────────────────────────
if [ "$SKIP_BUILD" = false ]; then
    log_step "Сборка образов..."
    $COMPOSE build
    log_info "Образы собраны"
fi

# ── 3. Запуск / обновление контейнеров ───────────────────────
log_step "Запуск контейнеров..."
$COMPOSE up -d --remove-orphans
log_info "Контейнеры запущены"

# ── 4. Ожидание готовности БД ────────────────────────────────
log_step "Ожидание готовности PostgreSQL..."
RETRIES=12
until docker exec tm_postgres pg_isready -U taskmate -d taskmate > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
    echo "   Ожидание... (осталось: $RETRIES)"
    RETRIES=$((RETRIES-1))
    sleep 5
done
if [ $RETRIES -eq 0 ]; then
    log_error "PostgreSQL не готов"
    exit 1
fi
log_info "PostgreSQL готов"

# ── 5. Ожидание готовности API ───────────────────────────────
log_step "Ожидание готовности API..."
RETRIES=12
until docker exec tm_api php -r "@file_get_contents('http://127.0.0.1:8000/api/v1/up') or exit(1);" 2>/dev/null || [ $RETRIES -eq 0 ]; do
    echo "   Ожидание... (осталось: $RETRIES)"
    RETRIES=$((RETRIES-1))
    sleep 5
done
if [ $RETRIES -eq 0 ]; then
    log_error "API не готов"
    exit 1
fi
log_info "API готов"

# ── 6. Первоначальная инициализация ──────────────────────────
if [ "$FIRST_RUN" = true ]; then
    log_step "Первоначальная инициализация..."
    docker exec tm_api php /app/artisan key:generate --force
    docker exec tm_api php /app/artisan storage:link
    log_info "Ключ сгенерирован, storage привязан"
fi

# ── 7. Миграции ──────────────────────────────────────────────
log_step "Миграции..."
docker exec tm_api php /app/artisan migrate --force
log_info "Миграции выполнены"

if [ "$FIRST_RUN" = true ]; then
    log_step "Загрузка демо-данных..."
    docker exec tm_api php /app/artisan db:seed-demo --force
    log_info "Демо-данные загружены"
fi

# ── 8. Оптимизация Laravel ───────────────────────────────────
log_step "Оптимизация Laravel..."
docker exec tm_api php /app/artisan config:cache
docker exec tm_api php /app/artisan route:cache
docker exec tm_api php /app/artisan view:cache
docker exec tm_api php /app/artisan event:cache
log_info "Кеши Laravel оптимизированы"

# ── 9. Перезапуск воркеров ───────────────────────────────────
log_step "Перезапуск очередей..."
docker exec tm_api php /app/artisan queue:restart || true
log_info "Очереди перезапущены"

# ── 10. Очистка ──────────────────────────────────────────────
log_step "Очистка неиспользуемых образов..."
docker image prune -f > /dev/null 2>&1 || true

# ── 11. Проверка ─────────────────────────────────────────────
log_step "Статус сервисов:"
$COMPOSE ps

echo ""
log_info "Деплой завершён!"
