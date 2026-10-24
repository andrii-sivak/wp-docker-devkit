#!/bin/sh
# WP-CLI calls the SQL client with --no-defaults, which skips
# /etc/mysql/conf.d. MySQL 8.4 then rejects the self-signed server
# certificate. A command-line flag still applies.
base=$(basename "$0")
real="/usr/bin/$base"
# --no-defaults is ignored unless it is the first argument.
if [ "${1-}" = "--no-defaults" ]; then
  shift
  exec "$real" --no-defaults --skip-ssl "$@"
fi
exec "$real" --skip-ssl "$@"
