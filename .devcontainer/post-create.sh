#!/bin/bash
set -e

echo "🚀 TaskMate Dev Container - Post Create Setup"
echo "=============================================="

WORKSPACE="/workspace"
BACKEND="$WORKSPACE/TaskMateServer"
FRONTEND="$WORKSPACE/TaskMateClient"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Configure Git safe directory
print_status "Configuring Git safe directory..."
git config --global --add safe.directory "$WORKSPACE" || true
git config --global --add safe.directory "$BACKEND" || true
git config --global --add safe.directory "$FRONTEND" || true

# ============================================
# Backend Setup
# ============================================
echo ""
echo "📦 Setting up Backend..."

if [ -d "$BACKEND" ]; then
    cd "$BACKEND"

    # Install Composer dependencies if vendor doesn't exist
    if [ ! -d "vendor" ]; then
        print_status "Installing Composer dependencies..."
        composer install --no-interaction --prefer-dist || print_warning "Composer install failed"
    else
        print_status "Composer dependencies already installed"
    fi

    # Create .env if it doesn't exist
    if [ ! -f ".env" ] && [ -f ".env.example" ]; then
        cp .env.example .env
        print_status "Created .env from .env.example"

        # Update .env for devcontainer
        sed -i 's/DB_HOST=.*/DB_HOST=postgres/' .env 2>/dev/null || true
        sed -i 's/REDIS_HOST=.*/REDIS_HOST=valkey/' .env 2>/dev/null || true
    fi

    # Set permissions for Laravel
    chmod -R 775 storage bootstrap/cache 2>/dev/null || true
    print_status "Set storage permissions"
fi

# ============================================
# Frontend Setup
# ============================================
echo ""
echo "📦 Setting up Frontend..."

if [ -d "$FRONTEND" ]; then
    cd "$FRONTEND"

    # Install npm dependencies if node_modules doesn't exist
    if [ ! -d "node_modules" ]; then
        print_status "Installing npm dependencies..."
        npm install || print_warning "npm install failed"
    else
        print_status "npm dependencies already installed"
    fi
fi

# ============================================
# Create helpful aliases
# ============================================
echo ""
echo "⚙️ Creating helpful aliases..."

# Add aliases to bashrc
cat >> ~/.bashrc << 'ALIASES'

# TaskMate Aliases
alias art='php artisan'
alias tinker='php artisan tinker'
alias migrate='php artisan migrate'
alias seed='php artisan db:seed'
alias test='php artisan test'
alias pint='./vendor/bin/pint'

# Navigation
alias backend='cd /workspace/TaskMateServer'
alias frontend='cd /workspace/TaskMateClient'
alias api='cd /workspace/TaskMateAPI'
alias ws='cd /workspace'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias glog='git log --oneline --graph --decorate -10'

# Useful
alias ll='ls -alF'
alias la='ls -A'

ALIASES

print_status "Added aliases to .bashrc"

# ============================================
# Final message
# ============================================
echo ""
echo "=============================================="
echo -e "${GREEN}✨ Dev Container setup complete!${NC}"
echo "=============================================="
echo ""
echo "📚 Quick Start:"
echo "  1. cd /workspace/TaskMateServer"
echo "  2. php artisan migrate --force"
echo "  3. php artisan db:seed-demo"
echo "  4. php artisan storage:link"
echo ""
echo "🔗 URLs:"
echo "  - Frontend: http://localhost:8099"
echo "  - Backend API: http://localhost:8007"
echo ""
echo "🔑 Demo credentials: admin/password"
echo ""
