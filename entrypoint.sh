#!/bin/sh
set -e

if [ ! -f vendor/autoload.php ]; then
    composer install --no-dev --no-scripts --no-interaction
fi

mkdir -p var/cache var/log
chown -R www-data:www-data var

APP_ENV_FLAG=""
if [ "${APP_ENV}" = "prod" ]; then
    APP_ENV_FLAG="--env=prod"
fi

# Wait for MySQL (Railway injects DATABASE_URL when MySQL is linked)
if [ -n "${DATABASE_URL}" ]; then
    echo "Waiting for database..."
    i=0
    while [ "$i" -lt 30 ]; do
        if su www-data -s /bin/sh -c "php bin/console doctrine:query:sql 'SELECT 1' ${APP_ENV_FLAG} 2>/dev/null"; then
            echo "Database is ready."
            break
        fi
        i=$((i + 1))
        sleep 2
    done
fi

su www-data -s /bin/sh -c "php bin/console cache:clear ${APP_ENV_FLAG}"
su www-data -s /bin/sh -c "php bin/console assets:install public ${APP_ENV_FLAG}"
su www-data -s /bin/sh -c "php bin/console importmap:install ${APP_ENV_FLAG}"
su www-data -s /bin/sh -c "php bin/console doctrine:migrations:migrate --no-interaction ${APP_ENV_FLAG}"

# Railway: nginx on $PORT + php-fpm on localhost:9000
if [ -n "${PORT}" ]; then
    export PORT
    envsubst '${PORT}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf
    php-fpm -D
    exec nginx -g 'daemon off;'
fi

exec "$@"
