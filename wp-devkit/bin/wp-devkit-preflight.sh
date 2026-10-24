#!/usr/bin/env bash
# Reject a Compose project name that already belongs to another working directory.
# Run this from wp-devkit/ before `docker compose up` and before cleanup.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"
kit=$(wp_devkit_kit_from_script)
if [[ $# -gt 0 ]]; then
  if [[ -f "$1/compose.yaml" ]]; then
    kit=$(wp_devkit_realpath "$1")
  elif [[ -f "$1/wp-devkit/compose.yaml" ]]; then
    kit=$(wp_devkit_realpath "$1/wp-devkit")
  else
    wp_devkit_die "not a wp-devkit directory: $1"
  fi
fi
project=$(wp_devkit_env_project "$kit/.env" || true)
[[ -n "$project" ]] || wp_devkit_die "set COMPOSE_PROJECT_NAME in $kit/.env before starting"
wp_devkit_assert_project "$project"
wp_devkit_assert_compose_ownership "$kit" "$project" owned
echo "wp-devkit: compose project $project belongs only to $kit"
