#!/usr/bin/env bash
# Remove one devkit instance directory and the Compose resources of its project.
# Does not prune images, build cache, or any other project.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"
dest=${1:-}
[[ -n "$dest" && -d "$dest" ]] || wp_devkit_die "usage: wp-devkit-cleanup.sh /path/to/instance"
dest=$(wp_devkit_realpath "$dest")
[[ -f "$dest/.wp-devkit-instance" ]] || wp_devkit_die "refusing to delete a directory without .wp-devkit-instance"
project=$(tr -d '[:space:]' < "$dest/.wp-devkit-instance")
wp_devkit_assert_project "$project"
work=$(wp_devkit_work_for "$(dirname "$dest")")
# Instances live in the work directory. Also accept a work dir recorded next to the source.
if ! wp_devkit_inside "$dest" "$work"; then
  wp_devkit_die "refusing to delete $dest because it is outside $work"
fi
echo "wp-devkit: docker compose down --volumes will delete containers, the project network, and the named database volume for project $project."
docker compose --project-directory "$dest" --project-name "$project" down --volumes --remove-orphans
docker run --rm -v "$dest:/work" alpine:3.20 sh -c 'rm -rf /work/* /work/.[!.]* /work/..?*'
rmdir "$dest"
echo "wp-devkit: removed $dest"
