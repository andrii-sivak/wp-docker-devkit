#!/usr/bin/env bash
# Point stored URLs at this copy. Serialized values are updated with wp search-replace.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"
root=$(wp_devkit_root_from_script)
old_url=${1:-}
new_url=${2:-}
if [[ -z "$old_url" && -f "$root/.wp-devkit-meta" ]]; then
  # shellcheck disable=SC1091
  source "$root/.wp-devkit-meta"
  old_url=${old_url:-}
  new_url=${new_url:-}
fi
[[ -n "$old_url" && -n "$new_url" ]] || wp_devkit_die "usage: wp-devkit-adapt-urls.sh OLD_URL NEW_URL"
[[ "$old_url" != "$new_url" ]] || wp_devkit_die "old and new URLs are the same"
docker compose --project-directory "$root" exec -T php wp search-replace "$old_url" "$new_url" --all-tables --skip-columns=guid
docker compose --project-directory "$root" exec -T php wp option update home "$new_url"
docker compose --project-directory "$root" exec -T php wp option update siteurl "$new_url"
echo "wp-devkit: URLs now $new_url"
echo "wp-devkit: URL constants already defined in wp-config.php are not rewritten. Check WP_HOME and WP_SITEURL if the site still redirects."
