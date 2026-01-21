#!/bin/bash

echo "🔄 TaskMate Dev Container - Starting..."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Wait for PostgreSQL
print_status "Checking PostgreSQL connection..."
for i in {1..30}; do
    if pg_isready -h postgres -U postgres >/dev/null 2>&1; then
        print_status "PostgreSQL is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warning "PostgreSQL not responding (may need more time)"
    fi
    sleep 1
done

# Wait for Valkey/Redis
print_status "Checking Valkey connection..."
for i in {1..15}; do
    if redis-cli -h valkey ping >/dev/null 2>&1; then
        print_status "Valkey is ready!"
        break
    fi
    if [ $i -eq 15 ]; then
        print_warning "Valkey not responding"
    fi
    sleep 1
done

# Ensure permissions
if [ -d "/workspace/TaskMateBackend/storage" ]; then
    chmod -R 775 /workspace/TaskMateBackend/storage 2>/dev/null || true
    chmod -R 775 /workspace/TaskMateBackend/bootstrap/cache 2>/dev/null || true
fi

echo ""
print_status "Dev Container is ready!"
echo ""
echo "📂 Workspace: /workspace"
echo "   ├── TaskMateBackend/   (Laravel API)"
echo "   └── TaskMateFrontend/  (React App)"
echo ""
echo "🚀 Quick commands:"
echo "   backend   - Go to Laravel project"
echo "   frontend  - Go to React project"
echo "   art       - php artisan shortcut"
echo ""
