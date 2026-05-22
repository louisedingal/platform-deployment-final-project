#!/bin/sh
set -e

composer install --no-scripts

mkdir -p var/cache var/log
chown -R www-data:www-data var

# Run Symfony setup as www-data (same user as php-fpm) to avoid cache permission errors
su www-data -s /bin/sh -c "php bin/console cache:clear"
su www-data -s /bin/sh -c "php bin/console assets:install public"
su www-data -s /bin/sh -c "php bin/console importmap:install"
su www-data -s /bin/sh -c "php bin/console doctrine:migrations:migrate --no-interaction"

exec "$@"
