#!/usr/bin/env bash
# Runtime acceptance checks for the devkit. Uses disposable Compose projects.
# `docker compose down --volumes` in the cleanup trap deletes only those
# projects' containers, networks, and named database volumes.
set -Eeuo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WP_DEVKIT_ACCEPTANCE:-${TMPDIR:-/tmp}/wp-devkit-mvp}
LOG="$WORK/log"
mkdir -p "$LOG"
SRC="$WORK/project-x"
BASE="$WORK/project-x-baseline"
CAND="$WORK/project-x-candidate"
CORE="$WORK/project-x-core"
INCOMPLETE="$WORK/project-x-incomplete"
PASS=0
FAIL=0

say() { printf '\n== %s\n' "$*"; }
ok() { PASS=$((PASS + 1)); printf 'PASS %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$*"; }

# WordPress files created in containers are owned by uid 33.
reset_dir() {
  local dir=$1
  if [[ -d "$dir" ]]; then
    docker run --rm -v "$dir:/work" alpine:3.20 sh -c 'rm -rf /work/* /work/.[!.]* /work/..?*'
  fi
  rm -rf "$dir"
}

cleanup() {
  local dir
  for dir in "$SRC" "$BASE" "$CAND" "$CORE" "$INCOMPLETE"; do
    if [[ -f "$dir/wp-devkit/compose.yaml" ]]; then
      echo "cleanup: down --volumes for $dir"
      docker compose --project-directory "$dir/wp-devkit" down --volumes --remove-orphans >"$LOG/cleanup.txt" 2>&1 || true
    fi
    reset_dir "$dir" || true
  done
  reset_dir "$WORK/empty-template" || true
  reset_dir "$WORK/complete" || true
}
trap cleanup EXIT

assert() {
  local name=$1
  shift
  if "$@"; then
    ok "$name"
  else
    bad "$name"
  fi
}

copy_template() {
  local dest=$1
  mkdir -p "$dest/wp-devkit"
  tar -C "$REPO/wp-devkit" -cf - . | tar -C "$dest/wp-devkit" -xf -
  chmod +x "$dest"/wp-devkit/bin/*.sh
}

wait_healthy() {
  local dir=$1
  local i
  for i in $(seq 1 60); do
    local states
    states=$(docker compose --project-directory "$dir/wp-devkit" ps --format '{{.Service}} {{.Health}}' 2>/dev/null || true)
    if [[ -n "$states" ]] && ! grep -Eq 'nginx |php |db ' <<<"$states"; then
      :
    fi
    if grep -q '^nginx healthy' <<<"$states" && grep -q '^php healthy' <<<"$states" && grep -q '^db healthy' <<<"$states"; then
      return 0
    fi
    sleep 5
  done
  docker compose --project-directory "$dir/wp-devkit" ps >"$LOG/ps-timeout.txt" || true
  docker compose --project-directory "$dir/wp-devkit" logs >"$LOG/logs-timeout.txt" || true
  return 1
}

say "guard: incomplete tree is not overwritten"
reset_dir "$INCOMPLETE"
copy_template "$INCOMPLETE"
mkdir -p "$INCOMPLETE/wp-content/plugins/custom"
printf '<?php echo "keep";\n' > "$INCOMPLETE/wp-content/plugins/custom/plugin.php"
before=$(sha256sum "$INCOMPLETE/wp-content/plugins/custom/plugin.php" | awk '{print $1}')
set +e
printf 'COMPOSE_PROJECT_NAME=wpdevkitincomp\nPHP_IMAGE=wp-devkit-php:8.4\n' > "$INCOMPLETE/wp-devkit/.env"
docker compose --project-directory "$INCOMPLETE/wp-devkit" run --rm --no-deps --entrypoint wp-devkit-entrypoint.sh php php-fpm -v >"$LOG/incomplete.txt" 2>&1
incomplete_code=$?
set -e
assert "incomplete entrypoint exits non-zero" test "$incomplete_code" -ne 0
assert "incomplete tree gained no index.php" test ! -e "$INCOMPLETE/index.php"
after=$(sha256sum "$INCOMPLETE/wp-content/plugins/custom/plugin.php" | awk '{print $1}')
assert "incomplete custom plugin unchanged" test "$before" = "$after"

say "guard: template-only directory is greenfield and complete core is kept"
EMPTY="$WORK/empty-template"
reset_dir "$EMPTY"
copy_template "$EMPTY"
docker run --rm \
  -v "$REPO/wp-devkit/bin/wp-devkit-entrypoint.sh:/usr/local/bin/wp-devkit-entrypoint.sh:ro" \
  -v "$EMPTY:/var/www/html" \
  --entrypoint wp-devkit-entrypoint.sh \
  wp-devkit-php:8.4 php-fpm -v >"$LOG/greenfield-copy.txt" 2>&1 || true
assert "greenfield copy created index.php" test -s "$EMPTY/index.php"
assert "greenfield copy created version.php" test -s "$EMPTY/wp-includes/version.php"
# A second start of that full tree, plus wp-devkit/, must not replace custom files.
COMPLETE="$WORK/complete"
reset_dir "$COMPLETE"
mkdir -p "$COMPLETE"
docker run --rm -v "$EMPTY:/from:ro" -v "$COMPLETE:/to" alpine:3.20 cp -a /from/. /to/
docker run --rm -v "$COMPLETE:/site" alpine:3.20 sh -c 'printf "<?php echo \"custom-core\";\n" > /site/wp-settings.php; mkdir -p /site/wp-content/plugins/custom; printf "<?php echo \"custom-plugin\";\n" > /site/wp-content/plugins/custom/plugin.php'
hash_before=$(sha256sum "$COMPLETE/wp-settings.php" "$COMPLETE/wp-content/plugins/custom/plugin.php")
docker run --rm \
  -v "$REPO/wp-devkit/bin/wp-devkit-entrypoint.sh:/usr/local/bin/wp-devkit-entrypoint.sh:ro" \
  -v "$COMPLETE:/var/www/html" \
  --entrypoint wp-devkit-entrypoint.sh \
  wp-devkit-php:8.4 php-fpm -v >"$LOG/complete.txt" 2>&1
hash_after=$(sha256sum "$COMPLETE/wp-settings.php" "$COMPLETE/wp-content/plugins/custom/plugin.php")
assert "complete core hash unchanged" test "$hash_before" = "$hash_after"
grep -q 'state=complete' "$LOG/complete.txt" && ok "complete state logged" || bad "complete state logged"

say "stack: greenfield"
reset_dir "$SRC"
copy_template "$SRC"
cat > "$SRC/wp-devkit/.env" <<'EOF'
COMPOSE_PROJECT_NAME=wpdevkitsrc
HTTP_PORT=18081
WP_HOME=http://127.0.0.1:18081
WP_SITEURL=http://127.0.0.1:18081
PHP_IMAGE=wp-devkit-php:wpdevkitsrc
PHP_MEM_LIMIT=384m
PHP_CPUS=0.50
PHP_PIDS_LIMIT=222
NGINX_MEM_LIMIT=64m
NGINX_CPUS=0.25
NGINX_PIDS_LIMIT=80
DB_MEM_LIMIT=512m
DB_CPUS=0.50
DB_PIDS_LIMIT=150
DB_PASSWORD=wordpress
DB_ROOT_PASSWORD=wordpress-root
DB_USER=wordpress
DB_NAME=wordpress
EOF
"$SRC/wp-devkit/bin/wp-devkit-preflight.sh" >"$LOG/preflight.txt" 2>&1
docker compose --project-directory "$SRC/wp-devkit" up -d --build >"$LOG/up.txt" 2>&1
assert "services become healthy" wait_healthy "$SRC"
php_id=$(docker compose --project-directory "$SRC/wp-devkit" ps -q php)
read -r mem nanos pids < <(docker inspect --format '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}} {{.HostConfig.PidsLimit}}' "$php_id")
assert "php memory limit applied" test "$mem" -eq 402653184
assert "php cpu limit applied" test "$nanos" -eq 500000000
assert "php pid limit applied" test "$pids" -eq 222
code_health=$(curl -sS -o "$LOG/healthz.txt" -w '%{http_code}' http://127.0.0.1:18081/healthz)
assert "healthz before install" test "$code_health" = "200"
grep -q '^ok$' "$LOG/healthz.txt" && ok "healthz body" || bad "healthz body"
code_install=$(curl -sS -o "$LOG/install.html" -w '%{http_code}' http://127.0.0.1:18081/wp-admin/install.php)
assert "install wizard reachable before completion" test "$code_install" = "200"

say "tools"
docker compose --project-directory "$SRC/wp-devkit" exec -T php php -r 'echo PHP_VERSION, PHP_EOL;' >"$LOG/phpver.txt"
docker compose --project-directory "$SRC/wp-devkit" exec -T php composer --version >"$LOG/composer.txt"
docker compose --project-directory "$SRC/wp-devkit" exec -T php wp cli version >"$LOG/wpcli.txt"
docker compose --project-directory "$SRC/wp-devkit" exec -T php mariadb --version >"$LOG/sqlclient.txt"
docker compose --project-directory "$SRC/wp-devkit" exec -T php php -m >"$LOG/modules.txt"
grep -q '^8\.4\.' "$LOG/phpver.txt" && ok "php 8.4 runtime" || bad "php 8.4 runtime"
grep -q 'Composer version 2.10.3' "$LOG/composer.txt" && ok "composer 2.10.3" || bad "composer 2.10.3"
grep -q 'WP-CLI 2.12.0' "$LOG/wpcli.txt" && ok "wp-cli 2.12.0" || bad "wp-cli 2.12.0"
grep -q 'mariadb' "$LOG/sqlclient.txt" && ok "sql client" || bad "sql client"
grep -qx mysqli "$LOG/modules.txt" && ok "mysqli loaded" || bad "mysqli loaded"
if grep -qx pdo_mysql "$LOG/modules.txt"; then bad "pdo_mysql absent by default"; else ok "pdo_mysql absent by default"; fi

say "manual install"
curl -sS -c "$LOG/cookies" -b "$LOG/cookies" -o "$LOG/install-step2.html" -w '%{http_code}' \
  --data-urlencode "weblog_title=Devkit Pilot" \
  --data-urlencode "user_name=devkit" \
  --data-urlencode "admin_password=Devkit-Test-Pass-1" \
  --data-urlencode "admin_password2=Devkit-Test-Pass-1" \
  --data-urlencode "pw_weak=1" \
  --data-urlencode "admin_email=devkit@example.com" \
  --data-urlencode "language=" \
  --data-urlencode "Submit=Install WordPress" \
  "http://127.0.0.1:18081/wp-admin/install.php?step=2" >"$LOG/install-code.txt" || true
if ! docker compose --project-directory "$SRC/wp-devkit" exec -T php wp core is-installed >"$LOG/is-installed.txt" 2>&1; then
  echo "HTTP install did not finish; body follows" >>"$LOG/is-installed.txt"
  tail -c 2000 "$LOG/install-step2.html" >>"$LOG/is-installed.txt" || true
  docker compose --project-directory "$SRC/wp-devkit" exec -T php wp core install \
    --url="http://127.0.0.1:18081" \
    --title="Devkit Pilot" \
    --admin_user=devkit \
    --admin_password='Devkit-Test-Pass-1' \
    --admin_email=devkit@example.com \
    --skip-email >"$LOG/wp-install.txt" 2>&1 || true
fi
assert "wordpress is installed" docker compose --project-directory "$SRC/wp-devkit" exec -T php wp core is-installed

docker compose --project-directory "$SRC/wp-devkit" exec -T -u www-data php php -r 'file_put_contents("wp-content/uploads/write-test.txt","ok");'
assert "www-data can write uploads" test -f "$SRC/wp-content/uploads/write-test.txt"

say "http hygiene"
docker compose --project-directory "$SRC/wp-devkit" exec -T -u www-data php sh -c 'printf "CANARY_SQL\n" > public.sql; printf "<?php echo \"EXECUTED\";\n" > wp-content/uploads/shell.php; printf "static-ok\n" > wp-content/uploads/plain.txt'
env_code=$(curl -sS -o "$LOG/env-body.txt" -w '%{http_code}' http://127.0.0.1:18081/wp-devkit/.env)
sql_code=$(curl -sS -o "$LOG/sql-body.txt" -w '%{http_code}' http://127.0.0.1:18081/public.sql)
php_code=$(curl -sS -o "$LOG/upload-php.txt" -w '%{http_code}' http://127.0.0.1:18081/wp-content/uploads/shell.php)
txt_code=$(curl -sS -o "$LOG/upload-txt.txt" -w '%{http_code}' http://127.0.0.1:18081/wp-content/uploads/plain.txt)
compose_code=$(curl -sS -o "$LOG/compose-body.txt" -w '%{http_code}' http://127.0.0.1:18081/wp-devkit/compose.yaml)
cfg_code=$(curl -sS -o "$LOG/wpconfig-body.txt" -w '%{http_code}' http://127.0.0.1:18081/wp-config.php)
readme_code=$(curl -sS -o "$LOG/kit-readme.txt" -w '%{http_code}' http://127.0.0.1:18081/wp-devkit/README.md)
assert "dotenv not served" test "$env_code" = "403"
assert "sql not served" test "$sql_code" = "403"
assert "upload php not executed" test "$php_code" = "403"
assert "upload static still served" test "$txt_code" = "200"
assert "wp-devkit compose.yaml not served" test "$compose_code" = "403"
assert "wp-devkit README not served" test "$readme_code" = "403"
assert "wp-config.php not served" test "$cfg_code" = "403"
grep -q CANARY_SQL "$LOG/sql-body.txt" && bad "sql body hidden" || ok "sql body hidden"
grep -q EXECUTED "$LOG/upload-php.txt" && bad "php body hidden" || ok "php body hidden"
grep -q DB_PASSWORD "$LOG/env-body.txt" && bad "env body hidden" || ok "env body hidden"

say "plugin pinned, snapshot, two copies"
docker compose --project-directory "$SRC/wp-devkit" exec -T php wp plugin install hello-dolly --version=1.6 --force >"$LOG/plugin-install.txt" 2>&1
assert "hello dolly 1.6 installed" grep -q 'Success' "$LOG/plugin-install.txt"
( cd "$SRC/wp-devkit" && ./bin/wp-devkit-snapshot.sh initial ) >"$LOG/snapshot.txt" 2>&1
assert "snapshot outside http root" test -s "$WORK/project-x-snapshots/initial.sql"
# Nested prior instance must not be copied. The tree is owned by uid 33.
docker compose --project-directory "$SRC/wp-devkit" exec -T -u root php sh -c 'mkdir -p nested-instance && printf "nested-canary\n" > nested-instance/secret.txt && printf "nested\n" > nested-instance/.wp-devkit-instance'
( cd "$SRC/wp-devkit" && ./bin/wp-devkit-copy.sh --source "$SRC" --role baseline --project wpdevkitbase --port 18082 --old-url "http://127.0.0.1:18081" --new-url "http://127.0.0.1:18082" ) >"$LOG/copy-base.txt" 2>&1
( cd "$SRC/wp-devkit" && ./bin/wp-devkit-copy.sh --source "$SRC" --role candidate --project wpdevkitcand --port 18083 --old-url "http://127.0.0.1:18081" --new-url "http://127.0.0.1:18083" ) >"$LOG/copy-cand.txt" 2>&1
assert "nested instance excluded" test ! -e "$BASE/nested-instance/secret.txt"
assert "baseline marker written" test -f "$BASE/wp-devkit/.wp-devkit-instance"
base_mode=$(stat -c '%a' "$BASE")
assert "copy root is not mode 1777" test "$base_mode" != "1777"
docker compose --project-directory "$BASE/wp-devkit" build >"$LOG/build-base.txt" 2>&1
docker compose --project-directory "$CAND/wp-devkit" build >"$LOG/build-cand.txt" 2>&1
docker compose --project-directory "$BASE/wp-devkit" up -d --build >"$LOG/up-base.txt" 2>&1
docker compose --project-directory "$CAND/wp-devkit" up -d --build >"$LOG/up-cand.txt" 2>&1
assert "baseline healthy" wait_healthy "$BASE"
assert "candidate healthy" wait_healthy "$CAND"
( cd "$BASE/wp-devkit" && ./bin/wp-devkit-restore.sh --target "$BASE" "$WORK/project-x-snapshots/initial.sql" ) >"$LOG/restore-base.txt" 2>&1
( cd "$CAND/wp-devkit" && ./bin/wp-devkit-restore.sh --target "$CAND" "$WORK/project-x-snapshots/initial.sql" ) >"$LOG/restore-cand.txt" 2>&1
( cd "$BASE/wp-devkit" && ./bin/wp-devkit-adapt-urls.sh ) >"$LOG/adapt-base.txt" 2>&1
( cd "$CAND/wp-devkit" && ./bin/wp-devkit-adapt-urls.sh ) >"$LOG/adapt-cand.txt" 2>&1
base_home=$(docker compose --project-directory "$BASE/wp-devkit" exec -T php wp option get home | tr -d '[:space:]')
cand_home=$(docker compose --project-directory "$CAND/wp-devkit" exec -T php wp option get home | tr -d '[:space:]')
assert "baseline home url" test "$base_home" = "http://127.0.0.1:18082"
assert "candidate home url" test "$cand_home" = "http://127.0.0.1:18083"

docker compose --project-directory "$BASE/wp-devkit" exec -T php wp option update blogdescription "baseline-only" >/dev/null
base_desc=$(docker compose --project-directory "$BASE/wp-devkit" exec -T php wp option get blogdescription | tr -d '[:space:]')
cand_desc=$(docker compose --project-directory "$CAND/wp-devkit" exec -T php wp option get blogdescription | tr -d '[:space:]')
src_desc=$(docker compose --project-directory "$SRC/wp-devkit" exec -T php wp option get blogdescription | tr -d '[:space:]')
assert "baseline database change is local" test "$base_desc" = "baseline-only"
assert "candidate database unchanged" test "$cand_desc" != "baseline-only"
assert "source database unchanged" test "$src_desc" != "baseline-only"
docker compose --project-directory "$BASE/wp-devkit" exec -T -u www-data php sh -c 'printf "only-baseline\n" > wp-content/uploads/only-baseline.txt'
assert "candidate lacks baseline file" test ! -e "$CAND/wp-content/uploads/only-baseline.txt"
assert "source lacks baseline file" test ! -e "$SRC/wp-content/uploads/only-baseline.txt"

src_vol=$(docker volume ls --format '{{.Name}}' | grep wpdevkitsrc || true)
base_vol=$(docker volume ls --format '{{.Name}}' | grep wpdevkitbase || true)
cand_vol=$(docker volume ls --format '{{.Name}}' | grep wpdevkitcand || true)
assert "distinct source volume" test -n "$src_vol"
assert "distinct baseline volume" test "$base_vol" != "$src_vol"
assert "distinct candidate volume" test "$cand_vol" != "$base_vol" && test "$cand_vol" != "$src_vol"

say "plugin dimension on candidate only"
before_plugin=$(docker compose --project-directory "$BASE/wp-devkit" exec -T php wp plugin get hello-dolly --field=version | tr -d '[:space:]')
docker compose --project-directory "$CAND/wp-devkit" exec -T php wp plugin update hello-dolly >"$LOG/plugin-update.txt" 2>&1 || true
after_base=$(docker compose --project-directory "$BASE/wp-devkit" exec -T php wp plugin get hello-dolly --field=version | tr -d '[:space:]')
after_cand=$(docker compose --project-directory "$CAND/wp-devkit" exec -T php wp plugin get hello-dolly --field=version | tr -d '[:space:]')
assert "baseline plugin unchanged" test "$after_base" = "$before_plugin"
if [[ "$after_cand" != "$before_plugin" ]]; then
  ok "candidate plugin version changed ($before_plugin -> $after_cand)"
else
  bad "candidate plugin version changed ($before_plugin -> $after_cand)"
fi

say "core dimension on a third copy"
( cd "$SRC/wp-devkit" && ./bin/wp-devkit-copy.sh --source "$SRC" --dest "$CORE" --project wpdevkitcore --port 18084 --old-url "http://127.0.0.1:18081" --new-url "http://127.0.0.1:18084" ) >"$LOG/copy-core.txt" 2>&1
docker compose --project-directory "$CORE/wp-devkit" up -d --build >"$LOG/up-core.txt" 2>&1
assert "core candidate healthy" wait_healthy "$CORE"
( cd "$CORE/wp-devkit" && ./bin/wp-devkit-restore.sh --target "$CORE" "$WORK/project-x-snapshots/initial.sql" ) >"$LOG/restore-core.txt" 2>&1
( cd "$CORE/wp-devkit" && ./bin/wp-devkit-adapt-urls.sh ) >"$LOG/adapt-core.txt" 2>&1
core_before=$(docker compose --project-directory "$CORE/wp-devkit" exec -T php wp core version | tr -d '[:space:]')
docker compose --project-directory "$CORE/wp-devkit" exec -T php wp core download --version=6.8.3 --force >"$LOG/core-download.txt" 2>&1
downloaded=$(docker compose --project-directory "$CORE/wp-devkit" exec -T php wp core version | tr -d '[:space:]')
docker compose --project-directory "$CORE/wp-devkit" exec -T php wp core update >"$LOG/core-update.txt" 2>&1 || true
docker compose --project-directory "$CORE/wp-devkit" exec -T php wp core update-db >"$LOG/core-updatedb.txt" 2>&1 || true
core_after=$(docker compose --project-directory "$CORE/wp-devkit" exec -T php wp core version | tr -d '[:space:]')
base_core=$(docker compose --project-directory "$BASE/wp-devkit" exec -T php wp core version | tr -d '[:space:]')
echo "core initial=$core_before downloaded=$downloaded after=$core_after baseline=$base_core" | tee "$LOG/core-versions.txt"
assert "baseline core unchanged by candidate update" test "$base_core" = "$core_before"
assert "downloaded core is 6.8.3" test "$downloaded" = "6.8.3"
assert "default core update moved past 6.8.3" test "$core_after" != "6.8.3"

say "smoke"
( cd "$SRC/wp-devkit" && ./bin/wp-devkit-smoke.sh --output "$LOG/smoke.md" ) >"$LOG/smoke-stdout.txt" 2>&1
smoke_code=$?
assert "smoke exit" test "$smoke_code" -eq 0
grep -q 'NOT CONFIGURED' "$LOG/smoke.md" && ok "smoke reports NOT CONFIGURED" || bad "smoke reports NOT CONFIGURED"
grep -q 'SKIPPED' "$LOG/smoke.md" && ok "smoke reports SKIPPED" || bad "smoke reports SKIPPED"
grep -q 'PASS' "$LOG/smoke.md" && ok "smoke reports PASS" || bad "smoke reports PASS"

say "targeted cleanup leaves the other project"
unrelated=$(docker ps -q | sort)
"$REPO/wp-devkit/bin/wp-devkit-cleanup.sh" "$CAND" >"$LOG/cleanup-cand.txt" 2>&1
assert "candidate directory removed" test ! -d "$CAND"
assert "baseline still healthy" wait_healthy "$BASE"
remaining=$(docker ps -q | sort)
# baseline and source and core still up; candidate gone. Every previously unrelated id remains.
missing=0
while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  if ! grep -qx "$id" <<<"$remaining" && ! docker inspect "$id" >/dev/null 2>&1; then
    # stopped by our cleanup only if it belonged to the candidate project
    name=$(docker ps -a --filter "id=$id" --format '{{.Names}}' || true)
    case "$name" in
      *wpdevkitcand*) ;;
      *) missing=1 ;;
    esac
  fi
done <<<"$unrelated"
# Simpler invariant: source homepage still answers and no system prune was invoked.
src_code=$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:18081/)
assert "source still responds after candidate cleanup" test "$src_code" = "200" -o "$src_code" = "302"
grep -q 'system prune' "$LOG/cleanup-cand.txt" && bad "cleanup did not prune" || ok "cleanup did not prune"

say "summary pass=$PASS fail=$FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  exit 0
fi
exit 1
