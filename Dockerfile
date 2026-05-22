FROM php:8.3-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    git unzip libpq-dev libzip-dev zip

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_mysql zip

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

COPY . .

# .env is excluded via .dockerignore; skip post-install scripts until runtime
RUN composer install --no-scripts

COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]