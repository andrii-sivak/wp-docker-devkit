#!/usr/bin/env bash
# Import a logical snapshot into this environment's own database.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"
root=$(wp_devkit_root_from_script)
snapshot=${1:-}
[[ -n "$snapshot" && -f "$snapshot" ]] || wp_devkit_die "usage: wp-devkit-restore.sh /path/to/snapshot.sql"
snapshot=$(wp_devkit_realpath "$snapshot")
wp_devkit_snapshot_is_safe "$snapshot" "$root"
docker compose --project-directory "$root" exec -T php wp db import - < "$snapshot"
echo "wp-devkit: imported $snapshot"
