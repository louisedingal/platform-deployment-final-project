#!/bin/sh

if [ ! -f vendor/autoload.php ]; then
    composer install --no-dev --no-scripts --no-interaction
fi

mkdir -p var/cache var/log
chown -R www-data:www-data var

# Symfony console requires a .env file; Railway injects real values via environment
if [ ! -f .env ]; then
    {
        echo "APP_ENV=${APP_ENV:-prod}"
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
                break
            fi
            i=$((i + 1))
            sleep 2
        done
    fi

    su www-data -s /bin/sh -c "php bin/console cache:clear ${APP_ENV_FLAG}" || echo "cache:clear failed"
    su www-data -s /bin/sh -c "php bin/console assets:install public ${APP_ENV_FLAG}" || echo "assets:install failed"
    su www-data -s /bin/sh -c "php bin/console importmap:install ${APP_ENV_FLAG}" || echo "importmap:install failed"
    su www-data -s /bin/sh -c "php bin/console doctrine:migrations:migrate --no-interaction ${APP_ENV_FLAG}" || echo "migrations failed"

    echo "Background setup complete."
}

# Railway: start nginx immediately so healthchecks pass, setup runs in background
if [ -n "${PORT}" ]; then
    export PORT
    envsubst '${PORT}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    php-fpm -D
    run_setup &
    exec nginx -g 'daemon off;'
fi

exec "$@"
