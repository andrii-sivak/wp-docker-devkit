#!/usr/bin/env bash
# Remove one copied WordPress root and that Compose project's resources.
# Does not prune images, build cache, or any other project.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"

dest=${1:-}
[[ -n "$dest" && -d "$dest" ]] || wp_devkit_die "usage: wp-devkit-cleanup.sh /path/to/copy"
dest=$(wp_devkit_realpath "$dest")
project=$(wp_devkit_assert_instance "$dest" cleanup)
kit=$(wp_devkit_kit_of_site "$dest")
wp_devkit_assert_compose_ownership "$kit" "$project" owned
echo "wp-devkit: removing copy $dest"
echo "wp-devkit: docker compose down --volumes affects only project $project (containers, its network, and its named database volume)."
docker compose --project-directory "$kit" --project-name "$project" down --volumes --remove-orphans
docker run --rm -v "$dest:/work" alpine:3.20 sh -c 'rm -rf /work/* /work/.[!.]* /work/..?*'
rmdir "$dest"
echo "wp-devkit: removed $dest"
