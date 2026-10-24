#!/usr/bin/env bash
# Point stored URLs at this copy. Serialized values are updated with wp search-replace.
# Metadata is read as text. It is never sourced or evaluated.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"
kit=$(wp_devkit_kit_from_script)
site=$(dirname "$kit")
old_url=${1:-}
new_url=${2:-}
meta="$kit/.wp-devkit-meta"
[[ -f "$kit/.wp-devkit-instance" ]] || wp_devkit_die "refusing URL adaptation without an instance marker. Run this from a copy, not the source."
if [[ -z "$old_url" || -z "$new_url" ]]; then
  [[ -f "$meta" ]] || wp_devkit_die "usage: wp-devkit-adapt-urls.sh OLD_URL NEW_URL"
  [[ -n "$old_url" ]] || old_url=$(wp_devkit_meta_get "$meta" old_url || true)
  [[ -n "$new_url" ]] || new_url=$(wp_devkit_meta_get "$meta" new_url || true)
fi
source_root=$(wp_devkit_meta_get "$meta" source || true)
if [[ -n "$source_root" && -d "$source_root" ]]; then
  [[ "$(wp_devkit_realpath "$source_root")" != "$(wp_devkit_realpath "$site")" ]] || wp_devkit_die "refusing to adapt URLs on the recorded source"
fi
[[ -n "$old_url" && -n "$new_url" ]] || wp_devkit_die "usage: wp-devkit-adapt-urls.sh OLD_URL NEW_URL"
[[ "$old_url" != "$new_url" ]] || wp_devkit_die "old and new URLs are the same"
docker compose --project-directory "$kit" exec -T php wp search-replace "$old_url" "$new_url" --all-tables --skip-columns=guid
docker compose --project-directory "$kit" exec -T php wp option update home "$new_url"
docker compose --project-directory "$kit" exec -T php wp option update siteurl "$new_url"
echo "wp-devkit: URLs now $new_url"
echo "wp-devkit: URL constants already defined in wp-config.php are not rewritten. Check WP_HOME and WP_SITEURL if the site still redirects."
