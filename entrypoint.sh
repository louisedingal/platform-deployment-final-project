#!/bin/sh
set -e

ensure_vendor() {
    if [ -f vendor/autoload_runtime.php ]; then
        return 0
    fi

    echo "Installing Composer dependencies..."
    composer install --no-dev --no-interaction --optimize-autoloader --no-scripts

    if [ ! -f vendor/autoload_runtime.php ]; then
        echo "FATAL: vendor/autoload_runtime.php still missing after composer install."
        exit 1
    fi
}

ensure_vendor

mkdir -p var/cache var/log
chown -R www-data:www-data var

if [ ! -f .env ]; then
    {
        echo "APP_ENV=${APP_ENV:-prod}"
        echo "APP_DEBUG=${APP_DEBUG:-0}"
        echo "APP_SECRET=${APP_SECRET:-temporary_build_secret_change_in_railway}"
        [ -n "${DATABASE_URL}" ] && echo "DATABASE_URL=${DATABASE_URL}"
        [ -n "${DEFAULT_URI}" ] && echo "DEFAULT_URI=${DEFAULT_URI}"
        echo "MESSENGER_TRANSPORT_DSN=${MESSENGER_TRANSPORT_DSN:-doctrine://default?auto_setup=0}"
        echo "MAILER_DSN=${MAILER_DSN:-null://null}"
    } > .env
fi

APP_ENV_FLAG=""
if [ "${APP_ENV}" = "prod" ]; then
    APP_ENV_FLAG="--env=prod"
fi

run_setup() {
    echo "Running background setup..."

    if [ -n "${DATABASE_URL}" ]; then
        echo "Waiting for database..."
        i=0
        while [ "$i" -lt 30 ]; do
            if su www-data -s /bin/sh -c "php bin/console doctrine:query:sql 'SELECT 1' ${APP_ENV_FLAG}" 2>/dev/null; then
                echo "Database is ready."
                su www-data -s /bin/sh -c "php bin/console doctrine:migrations:migrate --no-interaction ${APP_ENV_FLAG}" || echo "migrations failed"
                break
            fi
            i=$((i + 1))
            sleep 2
        done
    fi

    su www-data -s /bin/sh -c "php bin/console cache:clear ${APP_ENV_FLAG}" || true
    su www-data -s /bin/sh -c "php bin/console cache:warmup ${APP_ENV_FLAG}" || true
    echo "Background setup complete."
}

# Railway: listen on PORT from platform
if [ -n "${PORT}" ]; then
    export PORT
    envsubst '${PORT}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    php-fpm -D
    run_setup &
    exec nginx -g 'daemon off;'
fi

# Local Docker Compose: Nginx on 80 + PHP-FPM
echo "Starting PHP-FPM..."
php-fpm -D
echo "Starting Nginx..."
run_setup &
exec nginx -g 'daemon off;'
