#!/bin/bash
# =============================================================
# Быстрая пересборка frontend без Docker кеша
#
# Использование:
#   ./scripts/rebuild-frontend.sh          # Production (без error overlay)
#   ./scripts/rebuild-frontend.sh --debug  # Development (error overlay включён)
# =============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_ROOT/TaskMateClient"

# Определяем: podman или docker
if command -v podman &> /dev/null; then
    RUNTIME="podman"
    COMPOSE="podman compose"
    VOLUME_OPT=":Z"
else
    RUNTIME="docker"
    COMPOSE="docker compose"
    VOLUME_OPT=""
fi

# Режим сборки
VITE_MODE="production"
for arg in "$@"; do
    case $arg in
        --debug) VITE_MODE="development" ;;
    esac
done

echo "==> Сборка frontend (mode: $VITE_MODE)..."
cd "$FRONTEND_DIR"

# Сборка
# development → error overlay в index.html
# production  → без overlay
$RUNTIME run --rm -v ".:/app${VOLUME_OPT}" -w /app node:22-alpine sh -c "npm ci && npx vite build --mode $VITE_MODE"

# Находим контейнер frontend по имени сервиса
CONTAINER_NAME=$($RUNTIME ps --filter "name=frontend" --format "{{.Names}}" 2>/dev/null | head -1)
if [ -z "$CONTAINER_NAME" ]; then
    echo "==> Контейнер frontend не запущен. Запустите: $COMPOSE up -d frontend"
    exit 1
fi

echo "==> Копирование в контейнер ($CONTAINER_NAME)..."
$RUNTIME cp ./dist/. "$CONTAINER_NAME:/usr/share/nginx/html/"

echo "==> Перезапуск frontend..."
$RUNTIME restart "$CONTAINER_NAME"

echo "==> Готово! Обновите страницу (Ctrl+Shift+R)"
