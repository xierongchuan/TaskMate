#!/usr/bin/env bash
set -euo pipefail

# Скрипт запуска функциональных E2E тестов для TaskMate
# Использование:
#   ./scripts/run-functional-tests.sh              — полный прогон
#   ./scripts/run-functional-tests.sh --grep "01"   — конкретный файл

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Функциональные E2E тесты TaskMate ==="
echo ""

# 1. Сброс БД до admin-only
echo "[1/3] Сброс БД (migrate:fresh + AdminSeeder)..."
podman compose -f "$PROJECT_DIR/compose.yaml" exec api \
  php artisan migrate:fresh --seed --seeder=AdminSeeder --force

# 2. Очистка предыдущего state
echo "[2/3] Очистка shared state..."
rm -f "$PROJECT_DIR/TaskMateClient/tests/.state/functional-state.json"

# 3. Запуск Playwright
echo "[3/3] Запуск Playwright (functional-setup + functional)..."
podman run --rm --network host \
  -v "$PROJECT_DIR/TaskMateClient:/app:z" \
  -w /app \
  mcr.microsoft.com/playwright:v1.58.0-noble \
  npx playwright test \
    --project=functional-setup \
    --project=functional \
    "$@"

echo ""
echo "=== Готово ==="
