#!/bin/sh
# WP-CLI refuses to run as root. The site files are owned by www-data,
# so root invocations drop to that user and keep stdout/stdin intact.
set -e
phar=/usr/local/lib/wp-cli.phar
if [ "$(id -u)" -eq 0 ]; then
  exec runuser -u www-data -- env HOME=/tmp WP_CLI_CACHE_DIR="${WP_CLI_CACHE_DIR:-/tmp/wp-cli-cache}" php "$phar" "$@"
fi
exec php "$phar" "$@"
