#!/usr/bin/env bash
# Follow-up checks that the first pilot left incomplete.
# Removes only the Compose projects this script creates.
set -Eeuo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WP_DEVKIT_FOLLOWUP:-/run/media/user/dev_ssd/tmp/wp-devkit-followup}
export WP_DEVKIT_WORKDIR="$WORK"
LOG="$WORK/log"
mkdir -p "$LOG"
PASS=0
FAIL=0
DIRS=()

say() { printf '\n== %s\n' "$*"; }
ok() { PASS=$((PASS + 1)); printf 'PASS %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$*"; }
assert() {
  local name=$1
  shift
  if "$@"; then ok "$name"; else bad "$name"; fi
}

reset_dir() {
  local dir=$1
  if [[ -d "$dir" ]]; then
    docker run --rm -v "$dir:/work" alpine:3.20 sh -c 'rm -rf /work/* /work/.[!.]* /work/..?*' >/dev/null
  fi
  rm -rf "$dir"
}

cleanup() {
  local dir
  for dir in "${DIRS[@]}"; do
    if [[ -f "$dir/compose.yaml" ]]; then
      echo "cleanup: down --volumes for $dir"
      docker compose --project-directory "$dir" down --volumes --remove-orphans >"$LOG/cleanup.txt" 2>&1 || true
    fi
    reset_dir "$dir" || true
  done
}
trap cleanup EXIT

copy_template() {
  local dest=$1
  DIRS+=("$dest")
  mkdir -p "$dest"
  tar -C "$REPO" -cf - \
    compose.yaml Dockerfile .dockerignore .env.example .gitattributes README.md \
    nginx php bin prompt examples \
    | tar -C "$dest" -xf -
  chmod +x "$dest"/bin/*.sh
}

wait_healthy() {
  local dir=$1
  local i states
  for i in $(seq 1 70); do
    states=$(docker compose --project-directory "$dir" ps --format '{{.Service}} {{.Health}}' 2>/dev/null || true)
    if grep -q '^nginx healthy' <<<"$states" && grep -q '^php healthy' <<<"$states" && grep -q '^db healthy' <<<"$states"; then
      return 0
    fi
    sleep 5
  done
  docker compose --project-directory "$dir" ps >"$LOG/ps-timeout.txt" || true
  docker compose --project-directory "$dir" logs >"$LOG/logs-timeout.txt" || true
  return 1
}

install_site() {
  local dir=$1 url=$2
  docker compose --project-directory "$dir" exec -T php wp core install \
    --url="$url" --title='Devkit Followup' --admin_user=devkit \
    --admin_password='Devkit-Test-Pass-1' --admin_email=devkit@example.com --skip-email \
    >"$LOG/install-$(basename "$dir").txt" 2>&1
}

hash_core() {
  local dir=$1
  docker compose --project-directory "$dir" exec -T php sha256sum \
    index.php wp-settings.php wp-includes/version.php wp-includes/functions.php
}

PHP74_BASE='wordpress:php7.4-fpm@sha256:0b4b629f3f1389cb4e42570c452188d6f1ebe74d31aee6395bbb010450a0640e'
MYSQL_IMAGE='mysql:8.4@sha256:76f0358884cb92d9a086d24e5671c38048d3fef40f2588703d73eb55392d6b69'

say "php 7.4 image tools"
docker run --rm --entrypoint php wp-devkit-php:7.4 -r 'echo PHP_VERSION, PHP_EOL;' >"$LOG/php74-version.txt"
docker run --rm --entrypoint php wp-devkit-php:7.4 -m >"$LOG/php74-modules.txt"
docker run --rm --entrypoint composer wp-devkit-php:7.4 --version >"$LOG/php74-composer.txt"
docker run --rm --entrypoint wp wp-devkit-php:7.4 cli version >"$LOG/php74-wpcli.txt"
docker run --rm --entrypoint mariadb wp-devkit-php:7.4 --version >"$LOG/php74-sql.txt"
docker run --rm --entrypoint bash wp-devkit-php:7.4 -lc 'test ! -e /etc/apt/preferences.d/wp-devkit-skip-broken-security && command -v cgi-fcgi' >"$LOG/php74-fcgi.txt"
grep -q '^7\.4\.33' "$LOG/php74-version.txt" && ok "php 7.4.33" || bad "php 7.4.33"
grep -qx mysqli "$LOG/php74-modules.txt" && ok "php 7.4 mysqli" || bad "php 7.4 mysqli"
grep -q 'Composer version 2.10.3' "$LOG/php74-composer.txt" && ok "php 7.4 composer" || bad "php 7.4 composer"
grep -q 'WP-CLI 2.12.0' "$LOG/php74-wpcli.txt" && ok "php 7.4 wp-cli" || bad "php 7.4 wp-cli"
grep -q '10\.5\.23-MariaDB' "$LOG/php74-sql.txt" && ok "php 7.4 sql client" || bad "php 7.4 sql client"
grep -q cgi-fcgi "$LOG/php74-fcgi.txt" && ok "php 7.4 fcgi ping helper" || bad "php 7.4 fcgi ping helper"

say "php 7.4 wordpress install"
P74="$WORK/php74"
reset_dir "$P74"
copy_template "$P74"
cat > "$P74/.env" <<EOF
COMPOSE_PROJECT_NAME=wpdevkit74
HTTP_PORT=18101
WP_HOME=http://127.0.0.1:18101
WP_SITEURL=http://127.0.0.1:18101
PHP_IMAGE=wp-devkit-php:7.4
PHP_BASE_IMAGE=${PHP74_BASE}
PHP_MEM_LIMIT=512m
DB_MEM_LIMIT=768m
EOF
docker compose --project-directory "$P74" up -d --build >"$LOG/up-74.txt" 2>&1
assert "php 7.4 stack healthy" wait_healthy "$P74"
code=$(curl -sS -o "$LOG/healthz-74.txt" -w '%{http_code}' http://127.0.0.1:18101/healthz || echo 000)
assert "php 7.4 healthz before install" test "$code" = "200"
install_site "$P74" "http://127.0.0.1:18101"
assert "php 7.4 core installed" docker compose --project-directory "$P74" exec -T php wp core is-installed
home=$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:18101/ || echo 000)
assert "php 7.4 homepage" test "$home" = "200"
docker compose --project-directory "$P74" exec -T php wp db query "SELECT 1 AS ok;" --skip-column-names >"$LOG/php74-db.txt"
grep -q 1 "$LOG/php74-db.txt" && ok "php 7.4 database query" || bad "php 7.4 database query"
docker compose --project-directory "$P74" exec -T -u www-data php php -r 'file_put_contents("wp-content/uploads/php74.txt","ok");'
assert "php 7.4 uploads writable" test -f "$P74/wp-content/uploads/php74.txt"

say "switch php 8.4 site to php 7.4 without replacing core"
SRC="$WORK/src84"
reset_dir "$SRC"
copy_template "$SRC"
cat > "$SRC/.env" <<'EOF'
COMPOSE_PROJECT_NAME=wpdevkit84
HTTP_PORT=18111
WP_HOME=http://127.0.0.1:18111
WP_SITEURL=http://127.0.0.1:18111
PHP_IMAGE=wp-devkit-php:8.4
PHP_MEM_LIMIT=512m
DB_MEM_LIMIT=768m
EOF
docker compose --project-directory "$SRC" up -d --build >"$LOG/up-84.txt" 2>&1
assert "php 8.4 stack healthy" wait_healthy "$SRC"
install_site "$SRC" "http://127.0.0.1:18111"
docker compose --project-directory "$SRC" exec -T -u www-data php sh -c 'mkdir -p wp-content/plugins/custom && printf "<?php\n// custom-marker\n" > wp-content/plugins/custom/plugin.php'
hash_core "$SRC" >"$LOG/hash-before.txt"
SW="$WORK/instances/phpswitch"
reset_dir "$SW"
( cd "$SRC" && bin/wp-devkit-copy.sh --source "$SRC" --dest "$SW" --project wpdevkit74b --port 18112 \
    --old-url "http://127.0.0.1:18111" --new-url "http://127.0.0.1:18112" ) >"$LOG/copy-switch.txt" 2>&1
DIRS+=("$SW")
python3 - "$SW/.env" "$PHP74_BASE" <<'PY'
import sys
path, base = sys.argv[1:]
lines = open(path).read().splitlines()
out=[]
seen=set()
for line in lines:
    if line.startswith("PHP_BASE_IMAGE=") or line.startswith("PHP_IMAGE="):
        continue
    out.append(line)
out.append("PHP_IMAGE=wp-devkit-php:7.4")
out.append(f"PHP_BASE_IMAGE={base}")
open(path,"w").write("\n".join(out)+"\n")
PY
docker compose --project-directory "$SW" up -d >"$LOG/up-switch.txt" 2>&1
assert "switched stack healthy" wait_healthy "$SW"
php_sw=$(docker compose --project-directory "$SW" exec -T php php -r 'echo PHP_VERSION;' | tr -d '[:space:]')
assert "switched runtime is 7.4" test "$php_sw" = "7.4.33"
hash_core "$SW" >"$LOG/hash-after.txt"
assert "core hashes unchanged after php switch" cmp -s "$LOG/hash-before.txt" "$LOG/hash-after.txt"
( cd "$SRC" && bin/wp-devkit-snapshot.sh switch ) >"$LOG/snap-switch.txt" 2>&1
( cd "$SW" && bin/wp-devkit-restore.sh "$WORK/snapshots/switch.sql" ) >"$LOG/restore-switch.txt" 2>&1
( cd "$SW" && bin/wp-devkit-adapt-urls.sh ) >"$LOG/adapt-switch.txt" 2>&1
sw_home=$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:18112/ || echo 000)
assert "switched site still responds" test "$sw_home" = "200"
hash_core "$SW" >"$LOG/hash-after-restore.txt"
assert "core hashes unchanged after restore" cmp -s "$LOG/hash-before.txt" "$LOG/hash-after-restore.txt"

say "wordpress latest from a fresh 6.8.3 database"
LATEST="$WORK/latest"
reset_dir "$LATEST"
copy_template "$LATEST"
cat > "$LATEST/.env" <<'EOF'
COMPOSE_PROJECT_NAME=wpdevkitlatest
HTTP_PORT=18113
WP_HOME=http://127.0.0.1:18113
WP_SITEURL=http://127.0.0.1:18113
PHP_IMAGE=wp-devkit-php:8.4
PHP_MEM_LIMIT=512m
DB_MEM_LIMIT=768m
EOF
docker compose --project-directory "$LATEST" up -d >"$LOG/up-latest.txt" 2>&1
assert "latest stack healthy" wait_healthy "$LATEST"
docker compose --project-directory "$LATEST" exec -T php wp core download --version=6.8.3 --force >"$LOG/download-683.txt" 2>&1
ver_before=$(docker compose --project-directory "$LATEST" exec -T php wp core version | tr -d '[:space:]')
install_site "$LATEST" "http://127.0.0.1:18113"
ver_installed=$(docker compose --project-directory "$LATEST" exec -T php wp core version | tr -d '[:space:]')
docker compose --project-directory "$LATEST" exec -T php wp core check-update >"$LOG/check-update.txt" 2>&1 || true
docker compose --project-directory "$LATEST" exec -T php wp core update >"$LOG/update-default.txt" 2>&1
ver_default=$(docker compose --project-directory "$LATEST" exec -T php wp core version | tr -d '[:space:]')
docker compose --project-directory "$LATEST" exec -T php wp core update --version=7.1.3 >"$LOG/update-specific.txt" 2>&1
docker compose --project-directory "$LATEST" exec -T php wp core update-db >"$LOG/update-db.txt" 2>&1 || true
ver_after=$(docker compose --project-directory "$LATEST" exec -T php wp core version | tr -d '[:space:]')
echo "before=$ver_before installed=$ver_installed default=$ver_default specific=$ver_after" | tee "$LOG/latest-versions.txt"
assert "fresh install stayed on 6.8.3" test "$ver_installed" = "6.8.3"
assert "default core update moved past 6.8.3" test "$ver_default" != "6.8.3"
assert "specific core update reached 7.1.3" test "$ver_after" = "7.1.3"

say "mysql 8.4 wordpress install and logical restore"
MY="$WORK/mysql"
MY2="$WORK/instances/mysql2"
reset_dir "$MY"
copy_template "$MY"
cat > "$MY/.env" <<EOF
COMPOSE_PROJECT_NAME=wpdevkitmy
HTTP_PORT=18121
WP_HOME=http://127.0.0.1:18121
WP_SITEURL=http://127.0.0.1:18121
PHP_IMAGE=wp-devkit-php:8.4
DB_ENGINE=mysql
DB_IMAGE=${MYSQL_IMAGE}
PHP_MEM_LIMIT=512m
DB_MEM_LIMIT=1024m
PMA_PORT=18131
EOF
docker compose --project-directory "$MY" up -d >"$LOG/up-mysql.txt" 2>&1
assert "mysql stack healthy" wait_healthy "$MY"
install_site "$MY" "http://127.0.0.1:18121"
docker compose --project-directory "$MY" exec -T php wp option update blogdescription mysql-marker >"$LOG/mysql-marker.txt"
docker compose --project-directory "$MY" exec -T php wp db query "SELECT VERSION();" --skip-column-names >"$LOG/mysql-version.txt"
grep -q '8\.4\.' "$LOG/mysql-version.txt" && ok "mysql server is 8.4" || bad "mysql server is 8.4"
( cd "$MY" && bin/wp-devkit-snapshot.sh mysql ) >"$LOG/snap-mysql.txt" 2>&1
reset_dir "$MY2"
( cd "$MY" && bin/wp-devkit-copy.sh --source "$MY" --dest "$MY2" --project wpdevkitmy2 --port 18122 \
    --old-url "http://127.0.0.1:18121" --new-url "http://127.0.0.1:18122" ) >"$LOG/copy-mysql.txt" 2>&1
DIRS+=("$MY2")
# Keep the second copy on MySQL. The copy script preserves DB_IMAGE from .env.
docker compose --project-directory "$MY2" up -d >"$LOG/up-mysql2.txt" 2>&1
assert "mysql copy healthy" wait_healthy "$MY2"
( cd "$MY2" && bin/wp-devkit-restore.sh "$WORK/snapshots/mysql.sql" ) >"$LOG/restore-mysql.txt" 2>&1
( cd "$MY2" && bin/wp-devkit-adapt-urls.sh ) >"$LOG/adapt-mysql.txt" 2>&1
desc=$(docker compose --project-directory "$MY2" exec -T php wp option get blogdescription | tr -d '[:space:]')
assert "mysql restore kept blogdescription" test "$desc" = "mysql-marker"
my_home=$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:18122/ || echo 000)
assert "mysql copy homepage" test "$my_home" = "200"

say "phpmyadmin"
docker compose --project-directory "$MY" --profile pma up -d >"$LOG/up-pma.txt" 2>&1
pma_code=$(curl -sS -o "$LOG/pma.html" -w '%{http_code}' --max-time 30 http://127.0.0.1:18131/ || echo 000)
assert "phpmyadmin http" test "$pma_code" = "200"
grep -qi phpmyadmin "$LOG/pma.html" && ok "phpmyadmin body" || bad "phpmyadmin body"
# Log in and confirm the server answered rather than a connection error.
curl -sS -c "$LOG/pma.cookies" -b "$LOG/pma.cookies" -o "$LOG/pma-login.html" \
  --data-urlencode "pma_username=wordpress" \
  --data-urlencode "pma_password=wordpress" \
  --data-urlencode "server=1" \
  http://127.0.0.1:18131/index.php >"$LOG/pma-login-code.txt" || true
if grep -q mysql-marker "$LOG/pma-login.html" || grep -qi 'server_databases\|navigation' "$LOG/pma-login.html"; then
  ok "phpmyadmin authenticated to mysql"
else
  # Some versions redirect. Follow redirects with the cookie.
  curl -sS -L -c "$LOG/pma.cookies" -b "$LOG/pma.cookies" -o "$LOG/pma-home.html" http://127.0.0.1:18131/index.php || true
  if grep -qi 'MySQL' "$LOG/pma-home.html" && ! grep -qi 'Cannot connect' "$LOG/pma-home.html"; then
    ok "phpmyadmin reached mysql"
  else
    bad "phpmyadmin reached mysql"
  fi
fi

say "summary pass=$PASS fail=$FAIL"
[[ "$FAIL" -eq 0 ]]
