#!/usr/bin/env bash
# Shared helpers for the host-side scripts. Not a service manager.
set -Eeuo pipefail

wp_devkit_die() {
  echo "wp-devkit: $*" >&2
  exit 1
}

wp_devkit_root_from_script() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

wp_devkit_realpath() {
  python3 - "$1" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
}

wp_devkit_inside() {
  local child parent
  child=$(wp_devkit_realpath "$1")
  parent=$(wp_devkit_realpath "$2")
  [[ "$child" == "$parent" || "$child" == "$parent"/* ]]
}

wp_devkit_work_for() {
  local root=$1
  if [[ -n "${WP_DEVKIT_WORKDIR:-}" ]]; then
    mkdir -p "$WP_DEVKIT_WORKDIR"
    wp_devkit_realpath "$WP_DEVKIT_WORKDIR"
    return
  fi
  local parent
  parent=$(dirname "$(wp_devkit_realpath "$root")")
  mkdir -p "$parent/wp-devkit-work"
  wp_devkit_realpath "$parent/wp-devkit-work"
}

wp_devkit_assert_project() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9_-]{0,50}$ ]] || wp_devkit_die "project name must match [a-z0-9][a-z0-9_-]{0,50}: $1"
}

wp_devkit_assert_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" >= 1 && "$1" <= 65535 )) || wp_devkit_die "invalid port: $1"
}

wp_devkit_snapshot_is_safe() {
  local snapshot=$1
  shift
  local root
  [[ "$snapshot" != *.php ]] || wp_devkit_die "snapshot path must not be a PHP file"
  for root in "$@"; do
    if wp_devkit_inside "$snapshot" "$root"; then
      wp_devkit_die "snapshot must stay outside the HTTP root $root"
    fi
  done
}

# Print OK or the offending DB_HOST expression. Reads wp-config.php.
wp_devkit_db_host_status() {
  local config=$1
  [[ -f "$config" ]] || {
    echo "MISSING"
    return
  }
  python3 - "$config" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
match = re.search(r"define\s*\(\s*['\"]DB_HOST['\"]\s*,\s*(.+?)\)\s*;", text, re.S)
if not match:
    print("UNPARSEABLE")
    raise SystemExit
expr = " ".join(match.group(1).split())
if re.fullmatch(r"['\"]db['\"]", expr):
    print("OK")
elif "getenv_docker" in expr and "WORDPRESS_DB_HOST" in expr:
    print("OK")
else:
    print(expr)
PY
}
