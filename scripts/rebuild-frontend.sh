#!/bin/bash
# Быстрая пересборка frontend без Docker кеша
# Использование: ./scripts/rebuild-frontend.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_ROOT/TaskMateClient"
echo "🔨 Сборка frontend..."
cd "$FRONTEND_DIR"

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

# Сборка
$RUNTIME run --rm -v ".:/app${VOLUME_OPT}" -w /app node:22-alpine sh -c "npm ci && npm run build"

# Находим контейнер frontend по имени сервиса
CONTAINER_NAME=$($RUNTIME ps --filter "name=frontend" --format "{{.Names}}" 2>/dev/null | head -1)
if [ -z "$CONTAINER_NAME" ]; then
    echo "⚠️  Контейнер frontend не запущен. Запустите: $COMPOSE up -d frontend"
    exit 1
fi

echo "📦 Копирование в контейнер ($CONTAINER_NAME)..."
$RUNTIME cp ./dist/. "$CONTAINER_NAME:/usr/share/nginx/html/"

echo "🔄 Перезапуск frontend..."
$RUNTIME restart "$CONTAINER_NAME"

echo "✅ Готово! Обновите страницу (Ctrl+Shift+R)"
