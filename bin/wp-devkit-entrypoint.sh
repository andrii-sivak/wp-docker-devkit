#!/usr/bin/env bash
# Classify the bind-mounted tree before the upstream WordPress entrypoint.
# The upstream script copies core into any directory that lacks both
# index.php and wp-includes/version.php, including a nonempty incomplete tree.
set -Eeuo pipefail

cd /var/www/html

required=(
  index.php
  wp-includes/version.php
  wp-includes/functions.php
  wp-includes/load.php
  wp-includes/plugin.php
  wp-settings.php
  wp-load.php
  wp-login.php
  wp-admin/admin.php
  wp-admin/includes/admin.php
)

# Top-level names that ship with this template or are created by its scripts.
# Anything else, without a complete core, is an incomplete site.
allow='^(compose\.yaml|Dockerfile|\.dockerignore|\.env|\.env\.example|\.gitattributes|README\.md|nginx|php|bin|prompt|examples|\.wp-devkit-instance|\.wp-devkit-meta)$'

all_required=1
any_required=0
missing=()
for file in "${required[@]}"; do
  if [[ -s "$file" ]]; then
    any_required=1
  else
    all_required=0
    missing+=("$file")
  fi
done

unexpected=()
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  if [[ ! "$name" =~ $allow ]]; then
    unexpected+=("$name")
  fi
done < <(find . -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)

if [[ "$all_required" -eq 1 ]]; then
  state=complete
  # A handful of sentinel files is not a WordPress tree. Real cores ship
  # hundreds of files under wp-includes and wp-admin.
  if ! grep -q '\$wp_version' wp-includes/version.php; then
    state=incomplete
    missing+=("wp-includes/version.php (no \$wp_version)")
  fi
  includes_n=$(find wp-includes -type f | wc -l)
  admin_n=$(find wp-admin -type f | wc -l)
  includes_n=${includes_n// /}
  admin_n=${admin_n// /}
  if [[ "$includes_n" -lt 40 || "$admin_n" -lt 15 || ! -d wp-content ]]; then
    state=incomplete
    missing+=("wp-includes files=${includes_n} (need >= 40), wp-admin files=${admin_n} (need >= 15), wp-content directory")
  fi
elif [[ "$any_required" -eq 1 || ${#unexpected[@]} -gt 0 ]]; then
  state=incomplete
else
  state=greenfield
fi

if [[ "$state" == incomplete ]]; then
  echo "wp-devkit: refusing to start. This tree is not a complete WordPress site and is not an empty template directory." >&2
  echo "wp-devkit: the upstream entrypoint would copy core into an incomplete tree. No files were changed." >&2
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "wp-devkit: missing or empty core files:" >&2
    printf '  - %s\n' "${missing[@]}" >&2
  fi
  if [[ ${#unexpected[@]} -gt 0 ]]; then
    echo "wp-devkit: top-level entries that are not part of the template:" >&2
    printf '  - %s\n' "${unexpected[@]}" >&2
  fi
  exit 1
fi

if [[ "$state" == complete ]]; then
  echo "wp-devkit: site state=complete; upstream core copy will not run." >&2
  if [[ "$(id -u)" -eq 0 && "${WP_DEVKIT_FIX_UPLOAD_PERMS:-1}" == "1" ]]; then
    for dir in wp-content/uploads wp-content/cache; do
      if [[ -d "$dir" ]]; then
        chown -R www-data:www-data "$dir" || echo "wp-devkit: warning: could not chown $dir" >&2
      fi
    done
  fi
else
  echo "wp-devkit: site state=greenfield; upstream entrypoint may copy core into this template directory." >&2
fi

# /usr/local/sbin/php-fpm would win over the writable-directory shim otherwise.
export PATH="/usr/local/bin:${PATH}"
exec docker-entrypoint.sh "$@"
