#!/bin/sh
# Runs after the upstream entrypoint has copied a new site. Create the
# directories PHP must be able to write, then start the real FPM binary.
set -e
html=/var/www/html
if [ "$(id -u)" -eq 0 ]; then
  mkdir -p "$html/wp-content/uploads" "$html/wp-content/cache"
  chown www-data:www-data "$html/wp-content/uploads" "$html/wp-content/cache" || true
fi
exec /usr/local/sbin/php-fpm "$@"
