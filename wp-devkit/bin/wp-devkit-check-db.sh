#!/usr/bin/env bash
# Fail when wp-config.php points this tree at a database other than the service "db".
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"
root=${1:-$(wp_devkit_site_from_script)}
status=$(wp_devkit_db_host_status "$root/wp-config.php")
case "$status" in
  OK)
    echo "wp-devkit: DB_HOST points at this environment's db service."
    ;;
  MISSING)
    echo "wp-devkit: no wp-config.php yet. A greenfield start can create one with WORDPRESS_DB_HOST=db."
    ;;
  UNPARSEABLE)
    wp_devkit_die "wp-config.php has no DB_HOST define. Fix it before the first start."
    ;;
  *)
    wp_devkit_die "DB_HOST is ${status}. It must be the internal service name db before this copy starts. From wp-devkit/: docker compose run --rm --no-deps php wp config set DB_HOST db --type=constant"
    ;;
esac
