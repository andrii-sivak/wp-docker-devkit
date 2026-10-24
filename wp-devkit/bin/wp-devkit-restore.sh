#!/usr/bin/env bash
# Import a logical snapshot into one explicit copied WordPress root.
# The directory that contains this script is not the target.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"

target=""
snapshot=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || wp_devkit_die "usage: wp-devkit-restore.sh --target COPY SNAPSHOT.sql"
      target=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      wp_devkit_die "unknown argument: $1"
      ;;
    *)
      if [[ -n "$snapshot" ]]; then
        wp_devkit_die "only one snapshot file is accepted"
      fi
      snapshot=$1
      shift
      ;;
  esac
done

[[ -n "$target" && -n "$snapshot" && -f "$snapshot" ]] || wp_devkit_die "usage: wp-devkit-restore.sh --target COPY SNAPSHOT.sql"
[[ -d "$target" ]] || wp_devkit_die "target copy does not exist: $target"
target=$(wp_devkit_realpath "$target")
snapshot=$(wp_devkit_realpath "$snapshot")
project=$(wp_devkit_assert_instance "$target" restore)
kit=$(wp_devkit_kit_of_site "$target")
wp_devkit_assert_compose_ownership "$kit" "$project" owned
wp_devkit_snapshot_is_safe "$snapshot"
echo "wp-devkit: importing $snapshot into copy $target (project $project) only."
wp_devkit_strip_sandbox_directive < "$snapshot" \
  | docker compose --project-directory "$kit" --project-name "$project" exec -T php wp db import -
echo "wp-devkit: imported $snapshot into project $project"
