FROM php:8.3-fpm

ENV COMPOSER_ALLOW_SUPERUSER=1

# Install dependencies (nginx for Railway single-container deploy)
RUN apt-get update && apt-get install -y \
    git unzip libpq-dev libzip-dev zip libicu-dev g++ libxml2-dev \
    nginx gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_mysql zip intl

# Pass Railway env vars into PHP-FPM workers
RUN sed -i 's/;clear_env = no/clear_env = no/' /usr/local/etc/php-fpm.d/www.conf

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

# Install PHP dependencies first (cached layer)
COPY composer.json composer.lock symfony.lock ./
RUN composer install --no-dev --no-interaction --optimize-autoloader --no-scripts \
    && test -f vendor/autoload_runtime.php

# Copy application code (vendor/ is in .dockerignore — keep the layer above)
COPY . .
RUN test -f vendor/autoload_runtime.php

COPY nginx-railway.conf.template /etc/nginx/templates/default.conf.template
COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && rm -f /etc/nginx/sites-enabled/default

EXPOSE 8080

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
