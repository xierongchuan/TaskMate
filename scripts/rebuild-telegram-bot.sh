#!/bin/bash
# Пересборка и перезапуск Telegram-бота
# Использование: ./scripts/rebuild-telegram-bot.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Определяем: podman или docker
if command -v podman &> /dev/null; then
    COMPOSE="podman compose"
else
    COMPOSE="docker compose"
fi

cd "$PROJECT_ROOT"

echo "🔨 Сборка образа telegram-bot..."
$COMPOSE build --no-cache telegram-bot telegram-bot-worker

echo "🔄 Перезапуск контейнеров..."
$COMPOSE up -d --force-recreate telegram-bot telegram-bot-worker

echo "📋 Логи запуска:"
sleep 2
$COMPOSE logs --tail=10 telegram-bot telegram-bot-worker

echo ""
echo "✅ Готово! Бот перезапущен."
