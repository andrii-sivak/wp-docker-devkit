#!/usr/bin/env bash
# Export a logical snapshot next to this WordPress root, outside every served root.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"
site=$(wp_devkit_site_from_script)
kit=$(wp_devkit_kit_from_script)
name=${1:-initial}
[[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || wp_devkit_die "snapshot name must be a simple filename"
snap_dir=$(wp_devkit_snapshot_dir_for "$site")
mkdir -p "$snap_dir"
dest="$snap_dir/$name.sql"
wp_devkit_snapshot_is_safe "$dest"
docker compose --project-directory "$kit" exec -T php wp db export - \
  | wp_devkit_strip_sandbox_directive > "$dest"
test -s "$dest" || wp_devkit_die "snapshot is empty: $dest"
echo "wp-devkit: wrote $dest"
echo "wp-devkit: do not edit the source site or its database until this snapshot has been restored into each copy."
