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
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g concurrently" 2>&1
