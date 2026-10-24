#!/usr/bin/env bash
# Remove one devkit instance directory and that Compose project's resources.
# Does not prune images, build cache, or any other project.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"

dest=${1:-}
[[ -n "$dest" && -d "$dest" ]] || wp_devkit_die "usage: wp-devkit-cleanup.sh /path/to/instance"
dest=$(wp_devkit_realpath "$dest")
project=$(wp_devkit_assert_instance "$dest" cleanup)
work=$(wp_devkit_instance_work "$dest")
echo "wp-devkit: removing instance $dest"
echo "wp-devkit: docker compose down --volumes affects only project $project (containers, its network, and its named database volume)."
docker compose --project-directory "$dest" --project-name "$project" down --volumes --remove-orphans
docker run --rm -v "$dest:/work" alpine:3.20 sh -c 'rm -rf /work/* /work/.[!.]* /work/..?*'
rmdir "$dest"
echo "wp-devkit: removed $dest from work directory $work"
