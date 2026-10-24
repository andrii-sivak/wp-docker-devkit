#!/usr/bin/env bash
# Import a logical snapshot into one explicit devkit instance.
# The directory that contains this script is not the target.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"

target=""
snapshot=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || wp_devkit_die "usage: wp-devkit-restore.sh --target INSTANCE SNAPSHOT.sql"
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

[[ -n "$target" && -n "$snapshot" && -f "$snapshot" ]] || wp_devkit_die "usage: wp-devkit-restore.sh --target INSTANCE SNAPSHOT.sql"
[[ -d "$target" ]] || wp_devkit_die "target instance does not exist: $target"
target=$(wp_devkit_realpath "$target")
snapshot=$(wp_devkit_realpath "$snapshot")
project=$(wp_devkit_assert_instance "$target" restore)
source_root=$(wp_devkit_meta_get "$target/.wp-devkit-meta" source || true)
if [[ -n "$source_root" && -d "$source_root" ]]; then
  wp_devkit_snapshot_is_safe "$snapshot" "$target" "$source_root"
else
  wp_devkit_snapshot_is_safe "$snapshot" "$target"
fi
echo "wp-devkit: importing $snapshot into instance $target (project $project) only."
sed '/enable the sandbox mode/d' "$snapshot" \
  | docker compose --project-directory "$target" --project-name "$project" exec -T php wp db import -
echo "wp-devkit: imported $snapshot into project $project"
