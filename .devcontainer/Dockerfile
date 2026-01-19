FROM mcr.microsoft.com/devcontainers/php:1-8.4-bookworm

# Install system packages
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        mariadb-client \
        git unzip zip \
        libzip-dev libonig-dev libxml2-dev \
        libpng-dev libjpeg-dev libfreetype6-dev \
        libpq-dev postgresql-client \
        curl \
        supervisor \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        mbstring exif pcntl bcmath zip \
        pdo pdo_mysql mysqli gd \
        pdo_pgsql pgsql

# Install Redis extension
RUN set -eux; \
    pecl install redis && \
    docker-php-ext-enable redis

# Install Composer (if not already present)
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install Node.js
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && nvm install --lts" 2>&1

# Install global Node.js packages for development
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g concurrently typescript ts-node" 2>&1

# Install additional development tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        htop \
        ncdu \
        tree \
        jq \
        ripgrep \
        bat \
        fzf \
        redis-tools \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Set up Oh My Zsh for vscode user (optional)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true

# Configure Composer to use parallel downloads
RUN su vscode -c "composer global config --no-plugins allow-plugins.composer/installers true" 2>&1

# Set working directory
WORKDIR /workspaces/TaskMate
