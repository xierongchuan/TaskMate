#!/bin/bash
set -e

echo "🔄 Running post-start tasks..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Wait for database to be ready
print_status "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if pg_isready -h postgres -U postgres >/dev/null 2>&1; then
        print_status "PostgreSQL is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warning "PostgreSQL is not responding, but continuing anyway..."
    fi
    sleep 1
done

# Wait for Valkey/Redis to be ready
print_status "Waiting for Valkey to be ready..."
for i in {1..15}; do
    if redis-cli -h valkey ping >/dev/null 2>&1; then
        print_status "Valkey is ready!"
        break
    fi
    if [ $i -eq 15 ]; then
        print_warning "Valkey is not responding, but continuing anyway..."
    fi
    sleep 1
done

# Ensure storage permissions
if [ -d "/workspaces/TaskMate/TaskMateBackend/storage" ]; then
    chmod -R 775 /workspaces/TaskMate/TaskMateBackend/storage 2>/dev/null || true
    chmod -R 775 /workspaces/TaskMate/TaskMateBackend/bootstrap/cache 2>/dev/null || true
fi

print_status "✨ Dev Container is ready for development!"
echo ""
echo "📚 Quick Start Guide:"
echo "  1. Check services: docker compose ps"
echo "  2. Run migrations: cd TaskMateBackend && php artisan migrate"
echo "  3. Seed demo data: php artisan db:seed-demo"
echo "  4. Start backend: composer dev (runs server + queue + logs)"
echo "  5. Start frontend: cd TaskMateFrontend && npm run dev"
echo ""
echo "🔗 URLs:"
echo "  - Frontend: http://localhost:8099"
echo "  - Backend API: http://localhost:8007"
echo "  - Database: postgres://postgres@postgres:5432/postgres"
echo ""
