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
if [[ -e "$dest" || -L "$dest" ]]; then
  wp_devkit_die "snapshot already exists: $dest"
fi
tmp=$(mktemp "$snap_dir/.${name}.XXXXXX")
chmod 600 "$tmp"
snap_published=0
cleanup_snapshot_tmp() {
  local status=$?
  trap - EXIT INT TERM
  if [[ "$snap_published" -eq 0 && -n "${tmp:-}" && -e "$tmp" ]]; then
    rm -f "$tmp"
  fi
  exit "$status"
}
trap cleanup_snapshot_tmp EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if ! docker compose --project-directory "$kit" exec -T php wp db export - \
  | wp_devkit_strip_sandbox_directive > "$tmp"; then
  wp_devkit_die "snapshot export failed: $dest"
fi
[[ -s "$tmp" ]] || wp_devkit_die "snapshot is empty: $dest"
# ln fails if the name exists, including when it appears during export.
# mv -n can return 0 without replacing the temporary name.
if ! ln -T "$tmp" "$dest"; then
  wp_devkit_die "snapshot already exists: $dest"
fi
chmod 600 "$dest"
rm -f "$tmp"
snap_published=1
echo "wp-devkit: wrote $dest"
echo "wp-devkit: do not edit the source site or its database until this snapshot has been restored into each copy."
