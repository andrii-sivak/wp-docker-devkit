#!/usr/bin/env bash
# Copy one WordPress root to a sibling directory outside that root.
# Previously created test trees are not copied. An existing destination is refused.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"

source_dir=$(wp_devkit_site_from_script)
dest=""
project=""
port=""
old_url=""
new_url=""
role=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) source_dir=$2; shift 2 ;;
    --dest) dest=$2; shift 2 ;;
    --role) role=$2; shift 2 ;;
    --project) project=$2; shift 2 ;;
    --port) port=$2; shift 2 ;;
    --old-url) old_url=$2; shift 2 ;;
    --new-url) new_url=$2; shift 2 ;;
    *) wp_devkit_die "unknown argument: $1" ;;
  esac
done

[[ -n "$project" && -n "$port" && -n "$new_url" ]] || wp_devkit_die "required: --project --port --new-url, plus --dest or --role baseline|candidate"
wp_devkit_assert_project "$project"
wp_devkit_assert_port "$port"
[[ "$old_url" != *$'\n'* && "$new_url" != *$'\n'* ]] || wp_devkit_die "URLs must be single lines"
[[ -d "$source_dir" ]] || wp_devkit_die "source does not exist: $source_dir"
source_dir=$(wp_devkit_realpath "$source_dir")
source_kit=$(wp_devkit_kit_of_site "$source_dir")

if [[ -z "$dest" ]]; then
  [[ "$role" == baseline || "$role" == candidate ]] || wp_devkit_die "required: --dest, or --role baseline|candidate"
  dest="$(dirname "$source_dir")/$(basename "$source_dir")-${role}"
fi
if [[ -e "$dest" || -L "$dest" ]]; then
  wp_devkit_die "destination already exists: $dest. Choose another path. Existing directories are not overwritten."
fi
dest_parent=$(dirname "$dest")
[[ -d "$dest_parent" && -w "$dest_parent" ]] || wp_devkit_die "destination parent is not writable: $dest_parent. Choose another path."
dest_parent=$(wp_devkit_realpath "$dest_parent")
dest="$dest_parent/$(basename "$dest")"
if wp_devkit_inside "$dest" "$source_dir"; then
  wp_devkit_die "destination must be outside the source WordPress root"
fi
wp_devkit_assert_compose_ownership "$dest/wp-devkit" "$project" exclusive

while IFS= read -r link; do
  target=$(readlink -f "$link" || true)
  if [[ -z "$target" ]] || ! wp_devkit_inside "$target" "$source_dir"; then
    wp_devkit_die "refusing symlink that escapes the source: $link"
  fi
done < <(find "$source_dir" -type l)

excludes=()
while IFS= read -r marker; do
  dir=$(dirname "$marker")
  [[ "$dir" == "$source_dir" || "$dir" == "$source_kit" ]] && continue
  rel=${dir#"$source_dir"/}
  excludes+=(--exclude "./$rel")
done < <(find "$source_dir" -name .wp-devkit-instance -print)
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  case "$name" in
    *-baseline|*-candidate|*-snapshots)
      excludes+=(--exclude "./$name")
      ;;
  esac
done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -printf '%f\n')

src_project=$(wp_devkit_env_project "$source_kit/.env" || true)
tar_project=()
cleanup_tar_project=0
if [[ -n "$src_project" ]]; then
  tar_project=(--project-name "$src_project")
else
  src_project="wpdevkittar$(id -u)"
  wp_devkit_assert_compose_ownership "$source_kit" "$src_project" exclusive
  tar_project=(--project-name "$src_project")
  cleanup_tar_project=1
fi

mkdir -p "$dest"
# Preserve each source uid/gid, including mixed ownership. The original tree
# is only read. Extracting as root lets those numeric ids stick.
if ! tar -C "$source_dir" "${excludes[@]}" -cf - . \
  | docker compose --project-directory "$source_kit" "${tar_project[@]}" run --rm --no-deps -T \
      --entrypoint tar \
      -v "$dest:/dest" \
      php -C /dest --numeric-owner -xf -; then
  wp_devkit_die "copy failed"
fi
kit="$dest/wp-devkit"
[[ -d "$kit" ]] || wp_devkit_die "copy has no wp-devkit directory"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
env_file="$stage/.env"
if [[ -f "$source_kit/.env" ]]; then
  cp "$source_kit/.env" "$env_file"
elif [[ -f "$source_kit/.env.example" ]]; then
  cp "$source_kit/.env.example" "$env_file"
else
  : > "$env_file"
fi
python3 - "$env_file" "$stage" "$project" "$port" "$new_url" "$old_url" "$source_dir" <<'PY'
import sys
env_path, stage, project, port, url, old_url, source = sys.argv[1:]
keys = {
    "COMPOSE_PROJECT_NAME": project,
    "HTTP_PORT": port,
    "WP_HOME": url,
    "WP_SITEURL": url,
    "PHP_IMAGE": f"wp-devkit-php:{project}",
}
lines = open(env_path, encoding="utf-8", errors="replace").read().splitlines()
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
open(env_path, "w", encoding="utf-8").write("\n".join(out) + "\n")
open(f"{stage}/.wp-devkit-instance", "w", encoding="utf-8").write(project + "\n")
open(f"{stage}/.wp-devkit-meta", "w", encoding="utf-8").write(
    f"project={project}\nhttp_port={port}\nold_url={old_url}\nnew_url={url}\nsource={source}\n"
)
PY

uid=$(id -u)
gid=$(id -g)
if [[ -w "$kit" ]]; then
  cp "$stage/.wp-devkit-instance" "$stage/.wp-devkit-meta" "$stage/.env" "$kit/"
  chmod 644 "$kit/.wp-devkit-instance" "$kit/.wp-devkit-meta" "$kit/.env"
else
  docker compose --project-directory "$source_kit" ${src_project:+--project-name "$src_project"} run --rm --no-deps -T --user 0 \
    --entrypoint sh \
    -v "$stage:/stage:ro" \
    -v "$kit:/kit" \
    php -c "cp /stage/.wp-devkit-instance /stage/.wp-devkit-meta /stage/.env /kit/ && chown ${uid}:${gid} /kit/.wp-devkit-instance /kit/.wp-devkit-meta /kit/.env && chmod 644 /kit/.wp-devkit-instance /kit/.wp-devkit-meta /kit/.env"
fi

if [[ "$cleanup_tar_project" -eq 1 ]]; then
  docker compose --project-directory "$source_kit" --project-name "$src_project" down --remove-orphans >/dev/null
fi

echo "wp-devkit: copied to $dest (project $project, port $port)."
echo "wp-devkit: do not edit the source site or its database until both copies have been restored from the same snapshot."
"$(dirname "$0")/wp-devkit-check-db.sh" "$dest"
echo "wp-devkit: do not start this copy until the database check above succeeded."
