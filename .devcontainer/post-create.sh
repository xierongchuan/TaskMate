#!/bin/bash
set -e

echo "🚀 Running post-create setup for TaskMate Dev Container..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Configure Git safe directory
print_status "Configuring Git safe directory..."
git config --global --add safe.directory /workspaces/TaskMate || true

# Install Backend dependencies
if [ -d "/workspaces/TaskMate/TaskMateBackend" ]; then
    print_status "Installing Backend (Composer) dependencies..."
    cd /workspaces/TaskMate/TaskMateBackend

    if [ -f "composer.json" ]; then
        composer install --no-interaction --optimize-autoloader || print_warning "Composer install failed, will retry later"
    fi
fi

# Install Frontend dependencies
if [ -d "/workspaces/TaskMate/TaskMateFrontend" ]; then
    print_status "Installing Frontend (npm) dependencies..."
    cd /workspaces/TaskMate/TaskMateFrontend

    if [ -f "package.json" ]; then
        # Load NVM
        export NVM_DIR="/usr/local/share/nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        npm install || print_warning "npm install failed, will retry later"
    fi
fi

# Set up environment files if they don't exist
cd /workspaces/TaskMate
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    print_status "Creating .env file from .env.example..."
    cp .env.example .env
fi

# Set proper permissions for Laravel storage and cache
if [ -d "/workspaces/TaskMate/TaskMateBackend/storage" ]; then
    print_status "Setting permissions for Laravel storage..."
    chmod -R 775 /workspaces/TaskMate/TaskMateBackend/storage || true
    chmod -R 775 /workspaces/TaskMate/TaskMateBackend/bootstrap/cache || true
fi

# Create bash history directory
mkdir -p /commandhistory
touch /commandhistory/.bash_history
chown -R vscode:vscode /commandhistory || true

# Configure bash history persistence
if ! grep -q "HISTFILE=/commandhistory/.bash_history" ~/.bashrc; then
    echo 'export HISTFILE=/commandhistory/.bash_history' >> ~/.bashrc
    echo 'export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"' >> ~/.bashrc
fi

# Configure zsh history persistence if using zsh
if [ -f ~/.zshrc ]; then
    if ! grep -q "HISTFILE=/commandhistory/.zsh_history" ~/.zshrc; then
        echo 'export HISTFILE=/commandhistory/.zsh_history' >> ~/.zshrc
        echo 'export SAVEHIST=10000' >> ~/.zshrc
        echo 'export HISTSIZE=10000' >> ~/.zshrc
    fi
fi

# Install useful CLI tools
print_status "Installing additional CLI tools..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    htop \
    ncdu \
    tree \
    jq \
    ripgrep \
    bat \
    tldr \
    fzf \
    2>/dev/null || print_warning "Some optional tools failed to install"

# Set up Git configuration
print_status "Setting up Git configuration..."
git config --global core.editor "code --wait"
git config --global init.defaultBranch main
git config --global pull.rebase false

# Create useful aliases
print_status "Creating useful aliases..."
cat >> ~/.bashrc << 'EOF'

# TaskMate Project Aliases
alias art='php artisan'
alias tinker='php artisan tinker'
alias migrate='php artisan migrate'
alias seed='php artisan db:seed'
alias test='php artisan test'
alias pint='./vendor/bin/pint'

# Docker shortcuts
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcr='docker compose restart'
alias dcl='docker compose logs -f'

# Directory shortcuts
alias backend='cd /workspaces/TaskMate/TaskMateBackend'
alias frontend='cd /workspaces/TaskMate/TaskMateFrontend'
alias api='cd /workspaces/TaskMate/TaskMateAPI'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias glog='git log --oneline --graph --decorate'

# Productivity
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF

if [ -f ~/.zshrc ]; then
    cat >> ~/.zshrc << 'EOF'

# TaskMate Project Aliases
alias art='php artisan'
alias tinker='php artisan tinker'
alias migrate='php artisan migrate'
alias seed='php artisan db:seed'
alias test='php artisan test'
alias pint='./vendor/bin/pint'

# Docker shortcuts
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcr='docker compose restart'
alias dcl='docker compose logs -f'

# Directory shortcuts
alias backend='cd /workspaces/TaskMate/TaskMateBackend'
alias frontend='cd /workspaces/TaskMate/TaskMateFrontend'
alias api='cd /workspaces/TaskMate/TaskMateAPI'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias glog='git log --oneline --graph --decorate'

# Productivity
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF
fi

print_status "✨ Post-create setup completed!"
echo ""
print_status "Available commands:"
echo "  - Backend: cd TaskMateBackend && php artisan serve"
echo "  - Frontend: cd TaskMateFrontend && npm run dev"
echo "  - Tests: cd TaskMateBackend && php artisan test"
echo "  - Database: Use SQLTools extension or 'psql -h postgres -U postgres'"
echo ""
print_status "Quick aliases:"
echo "  - art = php artisan"
echo "  - backend/frontend/api = navigate to directories"
echo "  - dc = docker compose"
echo "  - gs = git status"
