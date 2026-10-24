#!/usr/bin/env bash
# Export one logical SQL snapshot to the work directory, outside every HTTP root.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"
root=$(wp_devkit_root_from_script)
name=${1:-initial}
[[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || wp_devkit_die "snapshot name must be a simple filename"
work=$(wp_devkit_work_for "$root")
mkdir -p "$work/snapshots"
dest="$work/snapshots/$name.sql"
wp_devkit_snapshot_is_safe "$dest" "$root"
docker compose --project-directory "$root" exec -T php wp db export - > "$dest"
test -s "$dest" || wp_devkit_die "snapshot is empty: $dest"
echo "wp-devkit: wrote $dest"
