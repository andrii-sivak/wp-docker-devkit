#!/usr/bin/env bash
# Focused regression checks for restore, cleanup, brownfield classification,
# copy ownership, Nginx denies, and the Docker build context.
set -Eeuo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
ROOT=${TMPDIR:-/tmp}/wp-devkit-safety-$$
mkdir -p "$ROOT"
PASS=0
FAIL=0
SKIP=0
say() { printf '\n== %s\n' "$*"; }
ok() { PASS=$((PASS + 1)); printf 'PASS %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$*"; }
skip() { SKIP=$((SKIP + 1)); printf 'SKIPPED %s\n' "$*"; }
assert() {
  local name=$1
  shift
  if "$@"; then ok "$name"; else bad "$name"; fi
}

cleanup() {
  docker rm -f wpdevkit-safety-nginx >/dev/null 2>&1 || true
  docker rmi wpdevkit-context-check >/dev/null 2>&1 || true
  if [[ -d "$ROOT/own-src" ]]; then
    docker compose --project-directory "$ROOT/own-src" down --remove-orphans >/dev/null 2>&1 || true
  fi
  docker run --rm -v "$ROOT:/work" alpine:3.20 rm -rf /work >/dev/null 2>&1 || true
  rm -rf "$ROOT"
}
trap cleanup EXIT

write_instance() {
  local dest=$1 project=$2 source=$3
  mkdir -p "$dest"
  printf '%s\n' "$project" > "$dest/.wp-devkit-instance"
  cat > "$dest/.wp-devkit-meta" <<EOF
project=$project
http_port=18080
old_url=http://127.0.0.1:18080
new_url=http://127.0.0.1:18081
source=$source
EOF
  printf 'COMPOSE_PROJECT_NAME=%s\nHTTP_PORT=18081\n' "$project" > "$dest/.env"
  printf "<?php define('DB_HOST', 'db');\n" > "$dest/wp-config.php"
  printf 'services: {}\n' > "$dest/compose.yaml"
  printf 'canary-row\n' > "$dest/db-canary"
}

say "restore refuses the original and ambiguous targets"
ORIGIN="$ROOT/original"
mkdir -p "$ORIGIN/bin" "$ORIGIN"
printf 'original-db-row\n' > "$ORIGIN/db-canary"
printf "<?php define('DB_HOST', 'localhost');\n" > "$ORIGIN/wp-config.php"
cp "$REPO/bin/wp-devkit-restore.sh" "$ORIGIN/bin/"
cp "$REPO/bin/wp-devkit-lib.sh" "$ORIGIN/bin/"
chmod +x "$ORIGIN/bin/"*.sh
SNAP="$ROOT/snap.sql"
printf 'INSERT INTO probe VALUES (1);\n' > "$SNAP"
LOG="$ROOT/docker.log"
: > "$LOG"
SHIM="$ROOT/shim"
mkdir -p "$SHIM"
REAL_DOCKER=$(command -v docker)
cat > "$SHIM/docker" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$LOG"
echo "unexpected docker: \$*" >&2
exit 99
EOF
chmod +x "$SHIM/docker"
set +e
PATH="$SHIM:$PATH" "$ORIGIN/bin/wp-devkit-restore.sh" "$SNAP" >"$ROOT/restore-notarget.txt" 2>&1
code_notarget=$?
PATH="$SHIM:$PATH" "$ORIGIN/bin/wp-devkit-restore.sh" --target "$ORIGIN" "$SNAP" >"$ROOT/restore-origin.txt" 2>&1
code_origin=$?
BAD="$ROOT/bad-instance"
write_instance "$BAD" "wpdevkitbad" "$ORIGIN"
printf 'COMPOSE_PROJECT_NAME=otherproject\n' > "$BAD/.env"
PATH="$SHIM:$PATH" "$REPO/bin/wp-devkit-restore.sh" --target "$BAD" "$SNAP" >"$ROOT/restore-mismatch.txt" 2>&1
code_mismatch=$?
set -e
assert "restore without --target exits non-zero" test "$code_notarget" -ne 0
assert "restore of the original exits non-zero" test "$code_origin" -ne 0
assert "restore with mismatched project exits non-zero" test "$code_mismatch" -ne 0
assert "original database canary unchanged" grep -qx 'original-db-row' "$ORIGIN/db-canary"
assert "refused restore did not call docker" test ! -s "$LOG"
grep -q 'missing .wp-devkit-instance' "$ROOT/restore-origin.txt" && ok "original refusal names the marker" || bad "original refusal names the marker"

say "cleanup default and custom workdirs"
unset WP_DEVKIT_WORKDIR
SITE="$ROOT/site"
mkdir -p "$SITE"
printf 'original-db-row\n' > "$SITE/db-canary"
DEFAULT_WORK="$ROOT/wp-devkit-work"
INST="$DEFAULT_WORK/instances/one"
write_instance "$INST" "wpdevkitone" "$SITE"
UNRELATED="$ROOT/unrelated-project"
mkdir -p "$UNRELATED"
printf 'keep-me\n' > "$UNRELATED/data"
assert "default-workdir cleanup removes the instance" "$REPO/bin/wp-devkit-cleanup.sh" "$INST"
assert "default-workdir instance directory is gone" test ! -d "$INST"
assert "original canary survives default cleanup" grep -qx 'original-db-row' "$SITE/db-canary"
assert "unrelated directory survives default cleanup" grep -qx 'keep-me' "$UNRELATED/data"
assert "cleanup did not create a nested workdir" test ! -d "$DEFAULT_WORK/wp-devkit-work"

export WP_DEVKIT_WORKDIR="$ROOT/custom-work"
mkdir -p "$WP_DEVKIT_WORKDIR"
CUSTOM="$WP_DEVKIT_WORKDIR/instances/two"
write_instance "$CUSTOM" "wpdevkittwo" "$SITE"
OUTSIDE="$ROOT/outside/instances/nope"
write_instance "$OUTSIDE" "wpdevkitnope" "$SITE"
set +e
"$REPO/bin/wp-devkit-cleanup.sh" "$OUTSIDE" >"$ROOT/cleanup-outside.txt" 2>&1
code_outside=$?
"$REPO/bin/wp-devkit-cleanup.sh" "$SITE" >"$ROOT/cleanup-site.txt" 2>&1
code_site=$?
set -e
assert "cleanup outside the custom workdir exits non-zero" test "$code_outside" -ne 0
assert "cleanup of the original exits non-zero" test "$code_site" -ne 0
assert "outside instance still exists" test -f "$OUTSIDE/db-canary"
assert "custom-workdir cleanup removes the instance" "$REPO/bin/wp-devkit-cleanup.sh" "$CUSTOM"
assert "custom instance directory is gone" test ! -d "$CUSTOM"
assert "original canary survives custom cleanup" grep -qx 'original-db-row' "$SITE/db-canary"
unset WP_DEVKIT_WORKDIR

say "brownfield classification"
if ! docker image inspect wp-devkit-php:8.4 >/dev/null 2>&1; then
  skip "entrypoint image wp-devkit-php:8.4 is not present"
else
  STUB="$ROOT/stub"
  mkdir -p "$STUB/wp-includes" "$STUB/wp-admin/includes" "$STUB/wp-content/plugins/custom"
  for f in index.php wp-includes/version.php wp-includes/functions.php wp-includes/load.php wp-includes/plugin.php wp-settings.php wp-load.php wp-login.php wp-admin/admin.php wp-admin/includes/admin.php; do
    printf '<?php\n' > "$STUB/$f"
  done
  printf '<?php echo "keep";\n' > "$STUB/wp-content/plugins/custom/plugin.php"
  before=$(find "$STUB" -type f | wc -l)
  set +e
  docker run --rm \
    -v "$REPO/bin/wp-devkit-entrypoint.sh:/usr/local/bin/wp-devkit-entrypoint.sh:ro" \
    -v "$STUB:/var/www/html" \
    --entrypoint wp-devkit-entrypoint.sh \
    wp-devkit-php:8.4 php-fpm -v >"$ROOT/stub.txt" 2>&1
  stub_code=$?
  set -e
  after=$(find "$STUB" -type f | wc -l)
  assert "seven-plus sentinel files are refused" test "$stub_code" -ne 0
  assert "incomplete stub gained no files" test "$before" = "$after"
  grep -q 'refusing to start' "$ROOT/stub.txt" && ok "stub refusal is explicit" || bad "stub refusal is explicit"

  FULL="$ROOT/full"
  mkdir -p "$FULL"
  docker run --rm -v "$FULL:/out" --entrypoint tar wp-devkit-php:8.4 -C /usr/src/wordpress -cf - . | tar -C "$FULL" -xf -
  mkdir -p "$FULL/wp-content/plugins/custom"
  printf '<?php echo "keep";\n' > "$FULL/wp-content/plugins/custom/plugin.php"
  plugin_hash=$(sha256sum "$FULL/wp-content/plugins/custom/plugin.php" | awk '{print $1}')
  docker run --rm \
    -v "$REPO/bin/wp-devkit-entrypoint.sh:/usr/local/bin/wp-devkit-entrypoint.sh:ro" \
    -v "$FULL:/var/www/html" \
    --entrypoint wp-devkit-entrypoint.sh \
    wp-devkit-php:8.4 php-fpm -v >"$ROOT/full.txt" 2>&1
  plugin_after=$(sha256sum "$FULL/wp-content/plugins/custom/plugin.php" | awk '{print $1}')
  grep -q 'state=complete' "$ROOT/full.txt" && ok "realistic core is complete" || bad "realistic core is complete"
  assert "custom plugin unchanged on complete start" test "$plugin_hash" = "$plugin_after"

  EMPTY="$ROOT/empty-template"
  mkdir -p "$EMPTY"
  printf 'services: {}\n' > "$EMPTY/compose.yaml"
  docker run --rm \
    -v "$REPO/bin/wp-devkit-entrypoint.sh:/usr/local/bin/wp-devkit-entrypoint.sh:ro" \
    -v "$EMPTY:/var/www/html" \
    --entrypoint wp-devkit-entrypoint.sh \
    wp-devkit-php:8.4 php-fpm -v >"$ROOT/empty.txt" 2>&1
  grep -q 'state=greenfield' "$ROOT/empty.txt" && ok "template-only directory is greenfield" || bad "template-only directory is greenfield"
  assert "greenfield copy created index.php" test -s "$EMPTY/index.php"
fi

say "copy preserves mixed ownership and does not touch the source"
if ! docker image inspect wp-devkit-php:8.4 >/dev/null 2>&1; then
  skip "copy image wp-devkit-php:8.4 is not present"
else
  OWN_SRC="$ROOT/own-src"
  mkdir -p "$OWN_SRC"
  tar -C "$REPO" -cf - compose.yaml Dockerfile .dockerignore .env.example nginx php bin prompt examples README.md .gitattributes | tar -C "$OWN_SRC" -xf -
  chmod +x "$OWN_SRC"/bin/*.sh
  printf 'COMPOSE_PROJECT_NAME=wpdevkitown\n' > "$OWN_SRC/.env"
  printf 'user-owned\n' > "$OWN_SRC/owned-by-user.txt"
  printf 'other-owned\n' > "$OWN_SRC/owned-by-33.txt"
  docker run --rm -v "$OWN_SRC/owned-by-33.txt:/file" alpine:3.20 chown 33:33 /file
  src_user=$(stat -c '%u:%g:%a' "$OWN_SRC/owned-by-user.txt")
  src_other=$(stat -c '%u:%g:%a' "$OWN_SRC/owned-by-33.txt")
  export WP_DEVKIT_WORKDIR="$ROOT/own-work"
  mkdir -p "$WP_DEVKIT_WORKDIR"
  OWN_DEST="$WP_DEVKIT_WORKDIR/instances/own"
  "$OWN_SRC/bin/wp-devkit-copy.sh" --source "$OWN_SRC" --dest "$OWN_DEST" --project wpdevkitown2 --port 18099 \
    --old-url "http://127.0.0.1:18098" --new-url "http://127.0.0.1:18099" >"$ROOT/copy-own.txt" 2>&1
  assert "source user-owned file unchanged" test "$(stat -c '%u:%g:%a' "$OWN_SRC/owned-by-user.txt")" = "$src_user"
  assert "source uid 33 file unchanged" test "$(stat -c '%u:%g:%a' "$OWN_SRC/owned-by-33.txt")" = "$src_other"
  assert "copy keeps user ownership" test "$(stat -c '%u:%g' "$OWN_DEST/owned-by-user.txt")" = "$(stat -c '%u:%g' "$OWN_SRC/owned-by-user.txt")"
  assert "copy keeps uid 33 ownership" test "$(stat -c '%u:%g' "$OWN_DEST/owned-by-33.txt")" = "33:33"
  unset WP_DEVKIT_WORKDIR
fi

say "nginx denies sensitive files and still serves uploads"
NGINX_IMAGE=nginx:1.30-alpine@sha256:47928bf67eb62a1863cb08d9ecb52d3e704304ba614eaee17884204677702951
if ! docker image inspect "$NGINX_IMAGE" >/dev/null 2>&1; then
  skip "nginx image is not present"
else
  WEB="$ROOT/web"
  mkdir -p "$WEB/wp-content/uploads/2024" "$WEB/.well-known" "$WEB/.git"
  printf 'secret\n' > "$WEB/.env"
  printf 'secret\n' > "$WEB/.git/HEAD"
  printf '<?php\n' > "$WEB/wp-config.php"
  printf '<?php\n' > "$WEB/wp-config.php.bak"
  printf 'static-ok\n' > "$WEB/wp-content/uploads/plain.txt"
  printf '<?php echo "EXECUTED";\n' > "$WEB/wp-content/uploads/2024/shell.php"
  printf '<?php echo "EXECUTED";\n' > "$WEB/wp-content/uploads/shell.phtml"
  printf 'ok\n' > "$WEB/.well-known/note.txt"
  printf 'home\n' > "$WEB/index.html"
  docker rm -f wpdevkit-safety-nginx >/dev/null 2>&1 || true
  docker run -d --name wpdevkit-safety-nginx \
    --add-host php:127.0.0.1 \
    -p 127.0.0.1:18991:80 \
    -v "$REPO/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro" \
    -v "$WEB:/var/www/html:ro" \
    "$NGINX_IMAGE" >/dev/null
  sleep 1
  code_of() { curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:18991$1" || echo 000; }
  assert "dotenv denied" test "$(code_of /.env)" = "403"
  assert "git denied" test "$(code_of /.git/HEAD)" = "403"
  assert "wp-config denied" test "$(code_of /wp-config.php)" = "403"
  assert "wp-config backup denied" test "$(code_of /wp-config.php.bak)" = "403"
  assert "upload php denied" test "$(code_of /wp-content/uploads/2024/shell.php)" = "403"
  assert "upload phtml denied" test "$(code_of /wp-content/uploads/shell.phtml)" = "403"
  assert "upload static served" test "$(code_of /wp-content/uploads/plain.txt)" = "200"
  assert "well-known served" test "$(code_of /.well-known/note.txt)" = "200"
  assert "homepage static served" test "$(code_of /index.html)" = "200"
  docker rm -f wpdevkit-safety-nginx >/dev/null
fi

say "docker build context excludes site files"
CTX="$ROOT/context"
mkdir -p "$CTX/wp-content" "$CTX/php" "$CTX/bin"
cp "$REPO/.dockerignore" "$CTX/.dockerignore"
cp "$REPO/php/devkit.ini" "$CTX/php/devkit.ini"
printf 'SECRET_CANARY\n' > "$CTX/wp-config.php"
dd if=/dev/zero of="$CTX/wp-content/big.bin" bs=1048576 count=4 status=none
cat > "$CTX/Dockerfile" <<'EOF'
FROM alpine:3.20
COPY php/devkit.ini /tmp/devkit.ini
EOF
docker build -t wpdevkit-context-check "$CTX" >"$ROOT/context-build.txt" 2>&1
size=$(python3 - "$ROOT/context-build.txt" <<'PY'
import re, sys
text=open(sys.argv[1], encoding="utf-8", errors="replace").read()
m=re.findall(r"transferring context:\s*([0-9.]+)([kKmM]?)B", text)
if not m:
    print(-1)
    raise SystemExit
num, unit = m[-1]
value=float(num)
if unit.lower()=="m":
    value*=1024*1024
elif unit.lower()=="k":
    value*=1024
print(int(value))
PY
)
assert "build context stays small" test "$size" -gt 0 -a "$size" -lt 200000
docker rmi wpdevkit-context-check >/dev/null

say "summary pass=$PASS fail=$FAIL skipped=$SKIP"
[[ "$FAIL" -eq 0 ]]
