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

# Work directory used when creating copies of a source WordPress root.
# Explicit WP_DEVKIT_WORKDIR wins. Otherwise the sibling wp-devkit-work
# of that source root is created. Call this with the source root, not with
# an instance path.
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

wp_devkit_meta_get() {
  local file=$1 key=$2
  [[ -f "$file" ]] || return 1
  python3 - "$file" "$key" <<'PY'
import sys
path, key = sys.argv[1:]
prefix = key + "="
for line in open(path, encoding="utf-8", errors="replace"):
    if line.startswith(prefix):
        print(line[len(prefix):].rstrip("\n"))
        raise SystemExit
raise SystemExit(1)
PY
}

wp_devkit_env_project() {
  local env_file=$1
  [[ -f "$env_file" ]] || return 1
  grep -E '^COMPOSE_PROJECT_NAME=' "$env_file" | tail -1 | cut -d= -f2- | tr -d '[:space:]'
}

# Existing work directory that owns an instance. Does not create directories.
# WP_DEVKIT_WORKDIR, when set, is the only acceptable root. Otherwise use the
# sibling wp-devkit-work of the source recorded in .wp-devkit-meta, then a
# parent directory literally named wp-devkit-work.
wp_devkit_instance_work() {
  local dest=$1
  if [[ -n "${WP_DEVKIT_WORKDIR:-}" ]]; then
    [[ -d "$WP_DEVKIT_WORKDIR" ]] || wp_devkit_die "WP_DEVKIT_WORKDIR does not exist: $WP_DEVKIT_WORKDIR"
    wp_devkit_realpath "$WP_DEVKIT_WORKDIR"
    return
  fi
  local source sibling dir
  if [[ -f "$dest/.wp-devkit-meta" ]]; then
    source=$(wp_devkit_meta_get "$dest/.wp-devkit-meta" source || true)
    if [[ -n "$source" && -d "$source" ]]; then
      sibling="$(dirname "$(wp_devkit_realpath "$source")")/wp-devkit-work"
      if [[ -d "$sibling" ]]; then
        wp_devkit_realpath "$sibling"
        return
      fi
    fi
  fi
  dir=$(wp_devkit_realpath "$dest")
  while [[ "$dir" != "/" ]]; do
    if [[ "$(basename "$dir")" == "wp-devkit-work" ]]; then
      echo "$dir"
      return
    fi
    dir=$(dirname "$dir")
  done
  wp_devkit_die "cannot resolve a work directory for $dest. Set WP_DEVKIT_WORKDIR, or keep the instance under the source's sibling wp-devkit-work."
}

# Print the compose project name or exit. Instances only: the original site
# has no marker and is refused. Marker, metadata, .env, and (for restore)
# DB_HOST must agree. The directory must sit inside the resolved workdir
# and must not be the recorded source tree.
wp_devkit_assert_instance() {
  local dest=$1 mode=${2:-cleanup}
  [[ -d "$dest" ]] || wp_devkit_die "not a directory: $dest"
  [[ -f "$dest/.wp-devkit-instance" ]] || wp_devkit_die "refusing $dest: missing .wp-devkit-instance. The original project is not a restore or cleanup target."
  [[ -f "$dest/.wp-devkit-meta" ]] || wp_devkit_die "refusing $dest: missing .wp-devkit-meta"
  [[ -f "$dest/.env" ]] || wp_devkit_die "refusing $dest: missing .env"
  local marker meta_project env_project source
  marker=$(tr -d '[:space:]' < "$dest/.wp-devkit-instance")
  wp_devkit_assert_project "$marker"
  meta_project=$(wp_devkit_meta_get "$dest/.wp-devkit-meta" project || true)
  [[ "$meta_project" == "$marker" ]] || wp_devkit_die "refusing $dest: marker ($marker) does not match metadata project (${meta_project:-unset})"
  env_project=$(wp_devkit_env_project "$dest/.env" || true)
  [[ "$env_project" == "$marker" ]] || wp_devkit_die "refusing $dest: COMPOSE_PROJECT_NAME (${env_project:-unset}) does not match marker ($marker)"
  source=$(wp_devkit_meta_get "$dest/.wp-devkit-meta" source || true)
  if [[ -n "$source" && -d "$source" ]]; then
    [[ "$(wp_devkit_realpath "$source")" != "$(wp_devkit_realpath "$dest")" ]] || wp_devkit_die "refusing $dest: this path is the recorded original project"
  fi
  local work
  work=$(wp_devkit_instance_work "$dest")
  wp_devkit_inside "$dest" "$work" || wp_devkit_die "refusing $dest: outside work directory $work"
  if [[ "$mode" == restore ]]; then
    local db_status
    db_status=$(wp_devkit_db_host_status "$dest/wp-config.php")
    [[ "$db_status" == OK ]] || wp_devkit_die "refusing $dest: database configuration is not this instance's db service ($db_status)"
  fi
  printf '%s\n' "$marker"
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
