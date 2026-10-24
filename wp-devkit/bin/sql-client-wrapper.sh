#!/bin/sh
# WP-CLI starts the client with --no-defaults, which skips /etc/mysql/conf.d.
# The local server certificate is then rejected. Put --skip-ssl immediately
# after --no-defaults. Any other invocation keeps the caller's arguments and
# the client configuration files.
base=$(basename "$0")
real="/usr/bin/$base"
if [ "${1-}" = "--no-defaults" ]; then
  shift
  exec "$real" --no-defaults --skip-ssl "$@"
fi
exec "$real" "$@"
