#!/bin/bash
# Быстрая пересборка frontend без Docker кеша
# Использование: ./scripts/rebuild-frontend.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_ROOT/TaskMateClient"
CONTAINER_NAME="taskmate_src_frontend"

echo "🔨 Сборка frontend..."
cd "$FRONTEND_DIR"

# Определяем: podman или docker
if command -v podman &> /dev/null; then
    RUNTIME="podman"
    VOLUME_OPT=":Z"
else
    RUNTIME="docker"
    VOLUME_OPT=""
fi

# Сборка
$RUNTIME run --rm -v ".:/app${VOLUME_OPT}" -w /app node:22-alpine sh -c "npm ci && npm run build"

echo "📦 Копирование в контейнер..."
docker cp ./dist/. "$CONTAINER_NAME:/usr/share/nginx/html/"

echo "🔄 Перезапуск frontend..."
docker restart "$CONTAINER_NAME"

echo "✅ Готово! Обновите страницу (Ctrl+Shift+R)"
