#!/usr/bin/env bash
# Run HTTP smoke checks and write a compact Markdown report.
# Exit 0 when no check is FAIL or ERROR. Exit 1 when any check is FAIL or ERROR.
set -Eeuo pipefail
source "$(dirname "$0")/wp-devkit-lib.sh"
site=$(wp_devkit_site_from_script)
kit=$(wp_devkit_kit_from_script)
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      if [[ -f "$2/wp-devkit/compose.yaml" ]]; then
        site=$(cd "$2" && pwd)
        kit="$site/wp-devkit"
      else
        kit=$(cd "$2" && pwd)
        site=$(dirname "$kit")
      fi
      shift 2
      ;;
    --output) output=$2; shift 2 ;;
    *) wp_devkit_die "unknown argument: $1" ;;
  esac
done
root=$site

port=8080
if [[ -f "$kit/.env" ]]; then
  value=$(grep -E '^HTTP_PORT=' "$kit/.env" | tail -1 | cut -d= -f2- || true)
  [[ -n "$value" ]] && port=$value
fi
base="http://127.0.0.1:${port}"

results=()
fail=0
record() {
  local status=$1 name=$2 detail=$3 code=$4
  results+=("| $name | $status | $code | $detail |")
  if [[ "$status" == FAIL || "$status" == ERROR ]]; then
    fail=1
  fi
}

probe() {
  local name=$1 path=$2 expect=$3
  local body code
  body=$(mktemp)
  if ! code=$(curl -sS -o "$body" -w '%{http_code}' --max-time 20 "$base$path"); then
    record ERROR "$name" "curl could not complete $path" "n/a"
    rm -f "$body"
    return
  fi
  if [[ "$code" == "$expect" ]]; then
    record PASS "$name" "$path returned $code" "$code"
  else
    record FAIL "$name" "$path returned $code, expected $expect" "$code"
  fi
  rm -f "$body"
}

probe "nginx readiness" "/healthz" "200"
probe "homepage" "/" "200"
admin_body=$(mktemp)
if admin_code=$(curl -sS -o "$admin_body" -w '%{http_code}' --max-time 20 "$base/wp-login.php"); then
  if [[ "$admin_code" == 200 || "$admin_code" == 302 ]]; then
    record PASS "administration route" "/wp-login.php returned $admin_code" "$admin_code"
  else
    record FAIL "administration route" "/wp-login.php returned $admin_code" "$admin_code"
  fi
else
  record ERROR "administration route" "curl could not complete /wp-login.php" "n/a"
fi
rm -f "$admin_body"

if [[ -n "${PROJECT_CHECK_COMMAND:-}" ]]; then
  set +e
  project_out=$(cd "$root" && bash -lc "$PROJECT_CHECK_COMMAND" 2>&1)
  project_code=$?
  set -e
  if [[ "$project_code" -eq 0 ]]; then
    record PASS "project check" "command exited 0" "$project_code"
  elif [[ "$project_code" -eq 127 ]]; then
    record ERROR "project check" "command could not start" "$project_code"
  else
    record FAIL "project check" "command failed" "$project_code"
  fi
else
  record "NOT CONFIGURED" "project check" "PROJECT_CHECK_COMMAND is unset" "n/a"
fi
record SKIPPED "external integrations" "template does not intercept SMTP, webhooks, or other outbound calls" "n/a"

report=$(mktemp)
{
  echo "# Smoke report"
  echo
  echo "- Goal: confirm HTTP readiness of one local environment."
  echo "- Comparison dimension: none (single environment)."
  echo "- Root: \`$root\`"
  echo "- URL: \`$base\`"
  echo "- Smoke checks do not prove that every feature or external integration works."
  echo
  echo "| Check | Status | Exit or HTTP code | Detail |"
  echo "| --- | --- | --- | --- |"
  printf '%s\n' "${results[@]}"
  echo
  echo "Statuses used: PASS, FAIL, SKIPPED, NOT CONFIGURED, ERROR."
} > "$report"

if [[ -n "$output" ]]; then
  cp "$report" "$output"
fi
cat "$report"
rm -f "$report"
exit "$fail"
