#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
if [[ $# -gt 0 ]]; then
  root=$(cd "$1" && pwd)
fi
compose=(docker compose --project-directory "$root")
{
  echo "project_dir=$root"
  echo -n "php="
  "${compose[@]}" exec -T php php -r 'echo PHP_VERSION, PHP_EOL;'
  echo -n "wordpress="
  "${compose[@]}" exec -T php wp core version
  echo -n "wp_cli="
  "${compose[@]}" exec -T php wp cli version
  echo -n "composer="
  "${compose[@]}" exec -T php composer --version
  echo -n "database="
  "${compose[@]}" exec -T php wp db query "SELECT VERSION();" --skip-column-names
  echo -n "php_image="
  "${compose[@]}" images php --format '{{.ID}} {{.Repository}}:{{.Tag}}'
} 2>&1
