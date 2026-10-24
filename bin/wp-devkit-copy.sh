#!/usr/bin/env bash
# Copy one WordPress root to a directory outside that root.
# Previously created devkit instances (marked .wp-devkit-instance) are not copied.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"

source_dir=$(wp_devkit_root_from_script)
dest=""
project=""
port=""
old_url=""
new_url=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) source_dir=$2; shift 2 ;;
    --dest) dest=$2; shift 2 ;;
    --project) project=$2; shift 2 ;;
    --port) port=$2; shift 2 ;;
    --old-url) old_url=$2; shift 2 ;;
    --new-url) new_url=$2; shift 2 ;;
    *) wp_devkit_die "unknown argument: $1" ;;
  esac
done

[[ -n "$dest" && -n "$project" && -n "$port" && -n "$new_url" ]] || wp_devkit_die "required: --dest --project --port --new-url"
wp_devkit_assert_project "$project"
wp_devkit_assert_port "$port"
[[ -d "$source_dir" ]] || wp_devkit_die "source does not exist: $source_dir"
source_dir=$(wp_devkit_realpath "$source_dir")
mkdir -p "$(dirname "$dest")"
if [[ -e "$dest" ]]; then
  wp_devkit_die "destination already exists: $dest"
fi
dest_parent=$(wp_devkit_realpath "$(dirname "$dest")")
dest="$dest_parent/$(basename "$dest")"
if wp_devkit_inside "$dest" "$source_dir"; then
  wp_devkit_die "destination must be outside the source WordPress root"
fi

work=$(wp_devkit_work_for "$source_dir")
if ! wp_devkit_inside "$dest" "$work"; then
  wp_devkit_die "destination must be inside the work directory $work"
fi

while IFS= read -r link; do
  target=$(readlink -f "$link" || true)
  if [[ -z "$target" ]] || ! wp_devkit_inside "$target" "$source_dir"; then
    wp_devkit_die "refusing symlink that escapes the source: $link"
  fi
done < <(find "$source_dir" -type l)

excludes=()
while IFS= read -r marker; do
  dir=$(dirname "$marker")
  [[ "$dir" == "$source_dir" ]] && continue
  rel=${dir#"$source_dir"/}
  excludes+=(--exclude "./$rel")
done < <(find "$source_dir" -name .wp-devkit-instance -print)

mkdir -p "$dest"
# Host tar records uid 33. Extracting as root applies it; a non-root extract
# would reown the tree and PHP could not update plugins or core.
tar -C "$source_dir" "${excludes[@]}" -cf - . \
  | docker compose --project-directory "$source_dir" run --rm --no-deps -T \
      --entrypoint tar \
      -v "$dest:/dest" \
      php -C /dest --numeric-owner -xf -
# The copied root is uid 33. Let the host create the marker and .env in that
# directory only; file ownership inside the tree stays with www-data.
docker compose --project-directory "$source_dir" run --rm --no-deps -T \
  --entrypoint chmod \
  -v "$dest:/dest" \
  php 1777 /dest
printf '%s\n' "$project" > "$dest/.wp-devkit-instance"
cat > "$dest/.wp-devkit-meta" <<EOF
project=$project
http_port=$port
old_url=$old_url
new_url=$new_url
source=$source_dir
EOF

env_file="$dest/.env"
if [[ -f "$source_dir/.env" ]]; then
  cp "$source_dir/.env" "$env_file"
elif [[ -f "$source_dir/.env.example" ]]; then
  cp "$source_dir/.env.example" "$env_file"
else
  : > "$env_file"
fi
python3 - "$env_file" "$project" "$port" "$new_url" <<'PY'
import sys
path, project, port, url = sys.argv[1:]
keys = {
    "COMPOSE_PROJECT_NAME": project,
    "HTTP_PORT": port,
    "WP_HOME": url,
    "WP_SITEURL": url,
    "PHP_IMAGE": f"wp-devkit-php:{project}",
}
lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
seen = set()
out = []
for line in lines:
    name = line.split("=", 1)[0] if "=" in line and not line.startswith("#") else None
    if name in keys:
        out.append(f"{name}={keys[name]}")
        seen.add(name)
    else:
        out.append(line)
for name, value in keys.items():
    if name not in seen:
        out.append(f"{name}={value}")
open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
PY

echo "wp-devkit: copied to $dest (project $project, port $port)."
"$(dirname "$0")/wp-devkit-check-db.sh" "$dest"
echo "wp-devkit: do not start this copy until the database check above succeeded."
