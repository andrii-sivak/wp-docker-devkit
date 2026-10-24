#!/usr/bin/env bash
# Shared helpers for the host-side scripts. Not a service manager.
set -Eeuo pipefail

wp_devkit_die() {
  echo "wp-devkit: $*" >&2
  exit 1
}

# Directory that contains compose.yaml. Scripts live in its bin/ folder.
wp_devkit_kit_from_script() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

# WordPress root: the parent of wp-devkit/.
wp_devkit_site_from_script() {
  dirname "$(wp_devkit_kit_from_script)"
}

wp_devkit_kit_of_site() {
  local site=$1
  [[ -d "$site/wp-devkit" ]] || wp_devkit_die "missing wp-devkit directory in $site"
  wp_devkit_realpath "$site/wp-devkit"
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

# Print the compose project name or exit. The argument is the copy's
# WordPress root, not the original and not the wp-devkit/ directory.
# Marker, metadata, .env, and (for restore) DB_HOST must agree.
wp_devkit_assert_instance() {
  local dest=$1 mode=${2:-cleanup}
  [[ -d "$dest" ]] || wp_devkit_die "not a directory: $dest"
  local kit=$dest/wp-devkit
  [[ -f "$kit/.wp-devkit-instance" ]] || wp_devkit_die "refusing $dest: missing wp-devkit/.wp-devkit-instance. The original project is not a restore or cleanup target."
  [[ -f "$kit/.wp-devkit-meta" ]] || wp_devkit_die "refusing $dest: missing wp-devkit/.wp-devkit-meta"
  [[ -f "$kit/.env" ]] || wp_devkit_die "refusing $dest: missing wp-devkit/.env"
  local marker meta_project env_project source
  marker=$(tr -d '[:space:]' < "$kit/.wp-devkit-instance")
  wp_devkit_assert_project "$marker"
  meta_project=$(wp_devkit_meta_get "$kit/.wp-devkit-meta" project || true)
  [[ "$meta_project" == "$marker" ]] || wp_devkit_die "refusing $dest: marker ($marker) does not match metadata project (${meta_project:-unset})"
  env_project=$(wp_devkit_env_project "$kit/.env" || true)
  [[ "$env_project" == "$marker" ]] || wp_devkit_die "refusing $dest: COMPOSE_PROJECT_NAME (${env_project:-unset}) does not match marker ($marker)"
  source=$(wp_devkit_meta_get "$kit/.wp-devkit-meta" source || true)
  if [[ -n "$source" && -d "$source" ]]; then
    [[ "$(wp_devkit_realpath "$source")" != "$(wp_devkit_realpath "$dest")" ]] || wp_devkit_die "refusing $dest: this path is the recorded original project"
  fi
  if [[ "$mode" == restore ]]; then
    local db_status
    db_status=$(wp_devkit_db_host_status "$dest/wp-config.php")
    [[ "$db_status" == OK ]] || wp_devkit_die "refusing $dest: database configuration is not this instance's db service ($db_status)"
  fi
  printf '%s\n' "$marker"
}

wp_devkit_assert_project() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9_-]{0,50}$ ]] || wp_devkit_die "project name must match [a-z0-9][a-z0-9_-]{0,50}: $1"
  [[ "$1" != "wp-devkit" ]] || wp_devkit_die "project name wp-devkit collides with the toolkit directory. Choose a unique COMPOSE_PROJECT_NAME."
}

wp_devkit_assert_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" >= 1 && "$1" <= 65535 )) || wp_devkit_die "invalid port: $1"
}

# Snapshot files must not live inside a WordPress root that contains wp-devkit/.
wp_devkit_snapshot_is_safe() {
  local snapshot=$1
  local dir
  [[ "$snapshot" != *.php ]] || wp_devkit_die "snapshot path must not be a PHP file"
  dir=$(dirname "$(wp_devkit_realpath "$snapshot")")
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/wp-devkit/compose.yaml" ]]; then
      wp_devkit_die "snapshot must stay outside the HTTP root $dir"
    fi
    dir=$(dirname "$dir")
  done
}

wp_devkit_snapshot_dir_for() {
  local site=$1
  site=$(wp_devkit_realpath "$site")
  printf '%s\n' "$(dirname "$site")/$(basename "$site")-snapshots"
}

# Print one row per Compose resource: "container <working_dir>", "volume <name>", or "network <name>".
# Compose 5.1 puts project.working_dir on containers. Volumes and networks carry the project name only.
wp_devkit_compose_resources() {
  local project=$1
  python3 - "$project" <<'PY'
import subprocess, sys
project = sys.argv[1]

def lines(args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        detail = proc.stderr.strip().splitlines()
        message = detail[-1] if detail else f"exit {proc.returncode}"
        print(f"wp-devkit: docker {' '.join(args[:2])} failed: {message}", file=sys.stderr)
        raise SystemExit(1)
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]

containers = lines(["docker", "ps", "-aq", "--filter", f"label=com.docker.compose.project={project}"])
for cid in containers:
    found = lines(["docker", "inspect", "-f", '{{index .Config.Labels "com.docker.compose.project.working_dir"}}', cid])
    print("container\t" + (found[0] if found else ""))
for vol in lines(["docker", "volume", "ls", "-q", "--filter", f"label=com.docker.compose.project={project}"]):
    print("volume\t" + vol)
for net in lines(["docker", "network", "ls", "-q", "--filter", f"label=com.docker.compose.project={project}"]):
    print("network\t" + net)
PY
}

# mode=exclusive: the project name must have zero resources (new copy).
# mode=owned: every container must belong to this kit. Volumes and networks
# have no working directory on Compose 5.1, so they are accepted only when a
# container proves ownership. A bare volume or network is ambiguous and refused.
wp_devkit_assert_compose_ownership() {
  local kit=$1 project=$2 mode=$3
  kit=$(wp_devkit_realpath "$kit")
  local containers=0 unscoped=0 kind value resolved resources=""
  if ! resources=$(wp_devkit_compose_resources "$project"); then
    wp_devkit_die "could not inspect Docker resources for project $project. Refusing to continue."
  fi
  while IFS=$'\t' read -r kind value; do
    [[ -n "$kind" ]] || continue
    if [[ "$mode" == exclusive ]]; then
      wp_devkit_die "compose project $project already has resources. Choose another COMPOSE_PROJECT_NAME."
    fi
    if [[ "$kind" == container ]]; then
      containers=1
      if [[ -z "$value" || ! -d "$value" ]]; then
        wp_devkit_die "compose project $project has a container whose working directory is not this kit ($kit)"
      fi
      resolved=$(wp_devkit_realpath "$value")
      [[ "$resolved" == "$kit" ]] || wp_devkit_die "compose project $project belongs to $value, not $kit"
    else
      unscoped=1
    fi
  done <<< "$resources"
  if [[ "$mode" == owned && "$unscoped" -eq 1 && "$containers" -eq 0 ]]; then
    wp_devkit_die "compose project $project has a volume or network and no container that proves it belongs to $kit"
  fi
}

# Bytes free on the filesystem that holds this path. WP_DEVKIT_FREE_BYTES,
# when set, replaces df so a test can force a refusal without filling the disk.
wp_devkit_free_bytes() {
  local path=$1
  if [[ -n "${WP_DEVKIT_FREE_BYTES:-}" ]]; then
    printf '%s\n' "$WP_DEVKIT_FREE_BYTES"
    return
  fi
  df -B1 --output=avail "$path" 2>/dev/null | awk 'NR==2 {print $1}'
}

wp_devkit_tree_bytes() {
  local path=$1
  if [[ ! -e "$path" ]]; then
    printf '0\n'
    return
  fi
  du -sb "$path" | awk '{print $1}'
}

# Print one-copy and two-copy file estimates. Refuse when this copy clearly
# does not fit. Database volumes, snapshots, images, quotas, and caches are
# not part of the number.
wp_devkit_check_copy_space() {
  local source=$1 dest_parent=$2 uploads=$3
  local site_bytes up_bytes with_one without_one need free
  site_bytes=$(wp_devkit_tree_bytes "$source")
  if [[ -d "$source/wp-content/uploads" ]]; then
    up_bytes=$(wp_devkit_tree_bytes "$source/wp-content/uploads")
  else
    up_bytes=0
  fi
  if (( up_bytes > site_bytes )); then
    with_one=$((site_bytes + up_bytes))
    without_one=$site_bytes
  else
    with_one=$site_bytes
    without_one=$((site_bytes - up_bytes))
  fi
  if [[ "$uploads" == exclude ]]; then
    need=$without_one
  else
    need=$with_one
  fi
  echo "wp-devkit: source files about ${site_bytes} bytes; uploads about ${up_bytes} bytes."
  echo "wp-devkit: one copy with uploads about ${with_one} bytes; without uploads about ${without_one} bytes."
  echo "wp-devkit: two copies with uploads about $((with_one * 2)) bytes; without uploads about $((without_one * 2)) bytes."
  echo "wp-devkit: this ${uploads} copy needs about ${need} bytes of file space. SQL snapshots, database volumes, Docker images, quotas, and caches are extra. This is not a guaranteed upper bound."
  free=$(wp_devkit_free_bytes "$dest_parent" || true)
  if [[ -z "$free" || ! "$free" =~ ^[0-9]+$ ]]; then
    echo "wp-devkit: could not read free space on $dest_parent. Capacity is unverified." >&2
    return 0
  fi
  echo "wp-devkit: about ${free} bytes free on $dest_parent."
  if (( free < need )); then
    wp_devkit_die "not enough free space for this copy (need about ${need} bytes, free ${free}). Nothing was written."
  fi
}

# Other sibling copies must record the same uploads mode.
wp_devkit_assert_same_uploads() {
  local source=$1 uploads=$2
  local parent base name sib meta got
  source=$(wp_devkit_realpath "$source")
  parent=$(dirname "$source")
  base=$(basename "$source")
  for name in "${base}-baseline" "${base}-candidate"; do
    sib="$parent/$name"
    meta="$sib/wp-devkit/.wp-devkit-meta"
    [[ -f "$meta" ]] || continue
    got=$(wp_devkit_meta_get "$meta" uploads || true)
    [[ -z "$got" || "$got" == "$uploads" ]] || wp_devkit_die "uploads mode is ${uploads} but $sib was copied with uploads=${got}. Both copies must use the same mode."
  done
}

# Remove only the MariaDB dump directive that older clients treat as a command.
# The line is exactly: /*M!999999\- enable the sandbox mode */
# Statements that merely contain those words, including multi-row INSERTs, stay.
wp_devkit_strip_sandbox_directive() {
  sed -E '/^[[:space:]]*\/\*M!999999\\- enable the sandbox mode \*\/[[:space:]]*$/d'
}

# Print OK, MISSING, UNPARSEABLE, or MISMATCH. Never print the expression.
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
    print("MISMATCH")
PY
}
