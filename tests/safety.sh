#!/usr/bin/env bash
# Focused regression checks for restore, cleanup, brownfield classification,
# copy ownership, Nginx denies, and the Docker build context.
set -Eeuo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/wp-devkit-safety.XXXXXX")
TAG=$(basename "$ROOT" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
TAG=${TAG: -10}
NGINX_CNAME="wpdsngx${TAG}"
FOREIGN_CNAME="wpdsfor${TAG}"
CTX_IMAGE="wpdsctx${TAG}"
DB_CNAME="wpdsdb${TAG}"
P_ONE="wpone${TAG}"
P_FOREIGN="wpfor${TAG}"
P_OWN="wpown${TAG}"
P_OWN2="wpn2${TAG}"
P_OWN3="wpn3${TAG}"
P_CLASH="wpcl${TAG}"
P_ADAPT="wpad${TAG}"
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
  docker rm -f "$NGINX_CNAME" >/dev/null 2>&1 || true
  docker rm -f -v "$DB_CNAME" >/dev/null 2>&1 || true
  docker rmi "$CTX_IMAGE" >/dev/null 2>&1 || true
  docker volume rm "wpdskeep${TAG}" >/dev/null 2>&1 || true
  if [[ -d "$ROOT/own-src/wp-devkit" ]]; then
    docker compose --project-directory "$ROOT/own-src/wp-devkit" --project-name "$P_OWN" down --remove-orphans >/dev/null 2>&1 || true
  fi
  docker rm -f "$FOREIGN_CNAME" >/dev/null 2>&1 || true
  if [[ -d "$ROOT" ]]; then
    docker run --rm -v "$ROOT:/work" alpine:3.20 rm -rf /work >/dev/null 2>&1 || true
    rm -rf "$ROOT"
  fi
}
trap cleanup EXIT

write_instance() {
  local dest=$1 project=$2 source=$3
  mkdir -p "$dest/wp-devkit"
  printf '%s\n' "$project" > "$dest/wp-devkit/.wp-devkit-instance"
  cat > "$dest/wp-devkit/.wp-devkit-meta" <<EOF
project=$project
http_port=18080
old_url=http://127.0.0.1:18080
new_url=http://127.0.0.1:18081
source=$source
EOF
  printf 'COMPOSE_PROJECT_NAME=%s\nHTTP_PORT=18081\n' "$project" > "$dest/wp-devkit/.env"
  printf 'name: %s\nservices: {}\n' "$project" > "$dest/wp-devkit/compose.yaml"
  printf "<?php define('DB_HOST', 'db');\n" > "$dest/wp-config.php"
  printf 'canary-row\n' > "$dest/db-canary"
}

say "restore refuses the original and ambiguous targets"
ORIGIN="$ROOT/original"
mkdir -p "$ORIGIN/bin" "$ORIGIN"
printf 'original-db-row\n' > "$ORIGIN/db-canary"
printf "<?php define('DB_HOST', 'localhost');\n" > "$ORIGIN/wp-config.php"
cp "$REPO/wp-devkit/bin/wp-devkit-restore.sh" "$ORIGIN/bin/"
cp "$REPO/wp-devkit/bin/wp-devkit-lib.sh" "$ORIGIN/bin/"
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
printf 'COMPOSE_PROJECT_NAME=otherproject\n' > "$BAD/wp-devkit/.env"
PATH="$SHIM:$PATH" "$REPO/wp-devkit/bin/wp-devkit-restore.sh" --target "$BAD" "$SNAP" >"$ROOT/restore-mismatch.txt" 2>&1
code_mismatch=$?
set -e
assert "restore without --target exits non-zero" test "$code_notarget" -ne 0
assert "restore of the original exits non-zero" test "$code_origin" -ne 0
assert "restore with mismatched project exits non-zero" test "$code_mismatch" -ne 0
assert "original database canary unchanged" grep -qx 'original-db-row' "$ORIGIN/db-canary"
assert "refused restore did not call docker" test ! -s "$LOG"
grep -q 'missing wp-devkit/.wp-devkit-instance' "$ROOT/restore-origin.txt" && ok "original refusal names the marker" || bad "original refusal names the marker"

say "cleanup refuses the source and a foreign compose project"
SITE="$ROOT/site"
mkdir -p "$SITE"
printf 'original-db-row\n' > "$SITE/db-canary"
INST="$ROOT/site-baseline"
write_instance "$INST" "$P_ONE" "$SITE"
UNRELATED="$ROOT/unrelated-project"
mkdir -p "$UNRELATED"
printf 'keep-me\n' > "$UNRELATED/data"
assert "cleanup removes the sibling copy" "$REPO/wp-devkit/bin/wp-devkit-cleanup.sh" "$INST"
assert "sibling copy directory is gone" test ! -d "$INST"
assert "original canary survives cleanup" grep -qx 'original-db-row' "$SITE/db-canary"
assert "unrelated directory survives cleanup" grep -qx 'keep-me' "$UNRELATED/data"

FOREIGN="$ROOT/site-candidate"
write_instance "$FOREIGN" "$P_FOREIGN" "$SITE"
docker run -d --name "$FOREIGN_CNAME" \
  --label "com.docker.compose.project=${P_FOREIGN}" \
  --label com.docker.compose.project.working_dir=/tmp/not-this-kit \
  alpine:3.20 sleep 120 >/dev/null
set +e
"$REPO/wp-devkit/bin/wp-devkit-cleanup.sh" "$FOREIGN" >"$ROOT/cleanup-foreign.txt" 2>&1
code_foreign=$?
"$REPO/wp-devkit/bin/wp-devkit-cleanup.sh" "$SITE" >"$ROOT/cleanup-site.txt" 2>&1
code_site=$?
set -e
assert "cleanup with a foreign compose owner exits non-zero" test "$code_foreign" -ne 0
assert "foreign-owned copy was not deleted" test -f "$FOREIGN/db-canary"
assert "cleanup of the original exits non-zero" test "$code_site" -ne 0
assert "original canary survives refused cleanup" grep -qx 'original-db-row' "$SITE/db-canary"
docker rm -f "$FOREIGN_CNAME" >/dev/null
"$REPO/wp-devkit/bin/wp-devkit-cleanup.sh" "$FOREIGN" >"$ROOT/cleanup-foreign-after.txt" 2>&1
assert "cleanup succeeds after the foreign resource is gone" test ! -d "$FOREIGN"

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
    -v "$REPO/wp-devkit/bin/wp-devkit-entrypoint.sh:/usr/local/bin/wp-devkit-entrypoint.sh:ro" \
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
    -v "$REPO/wp-devkit/bin/wp-devkit-entrypoint.sh:/usr/local/bin/wp-devkit-entrypoint.sh:ro" \
    -v "$FULL:/var/www/html" \
    --entrypoint wp-devkit-entrypoint.sh \
    wp-devkit-php:8.4 php-fpm -v >"$ROOT/full.txt" 2>&1
  plugin_after=$(sha256sum "$FULL/wp-content/plugins/custom/plugin.php" | awk '{print $1}')
  grep -q 'state=complete' "$ROOT/full.txt" && ok "realistic core is complete" || bad "realistic core is complete"
  assert "custom plugin unchanged on complete start" test "$plugin_hash" = "$plugin_after"

  EMPTY="$ROOT/empty-template"
  mkdir -p "$EMPTY/wp-devkit"
  printf 'kit\n' > "$EMPTY/wp-devkit/README.md"
  docker run --rm \
    -v "$REPO/wp-devkit/bin/wp-devkit-entrypoint.sh:/usr/local/bin/wp-devkit-entrypoint.sh:ro" \
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
  mkdir -p "$OWN_SRC/wp-devkit" "$OWN_SRC/old-baseline"
  tar -C "$REPO/wp-devkit" -cf - . | tar -C "$OWN_SRC/wp-devkit" -xf -
  chmod +x "$OWN_SRC"/wp-devkit/bin/*.sh
  printf 'COMPOSE_PROJECT_NAME=%s\nPHP_IMAGE=wp-devkit-php:8.4\n' "$P_OWN" > "$OWN_SRC/wp-devkit/.env"
  printf 'user-owned\n' > "$OWN_SRC/owned-by-user.txt"
  printf 'other-owned\n' > "$OWN_SRC/owned-by-33.txt"
  printf 'do-not-copy\n' > "$OWN_SRC/old-baseline/secret.txt"
  docker run --rm -v "$OWN_SRC/owned-by-33.txt:/file" alpine:3.20 chown 33:33 /file
  src_user=$(stat -c '%u:%g:%a' "$OWN_SRC/owned-by-user.txt")
  src_other=$(stat -c '%u:%g:%a' "$OWN_SRC/owned-by-33.txt")
  OWN_DEST="$ROOT/own-src-baseline"
  "$OWN_SRC/wp-devkit/bin/wp-devkit-copy.sh" --source "$OWN_SRC" --role baseline --project "$P_OWN2" --port 18099 \
    --old-url "http://127.0.0.1:18098" --new-url "http://127.0.0.1:18099" >"$ROOT/copy-own.txt" 2>&1
  assert "source user-owned file unchanged" test "$(stat -c '%u:%g:%a' "$OWN_SRC/owned-by-user.txt")" = "$src_user"
  assert "source uid 33 file unchanged" test "$(stat -c '%u:%g:%a' "$OWN_SRC/owned-by-33.txt")" = "$src_other"
  assert "copy keeps user ownership" test "$(stat -c '%u:%g' "$OWN_DEST/owned-by-user.txt")" = "$(stat -c '%u:%g' "$OWN_SRC/owned-by-user.txt")"
  assert "copy keeps uid 33 ownership" test "$(stat -c '%u:%g' "$OWN_DEST/owned-by-33.txt")" = "33:33"
  assert "copy root is not mode 1777" test "$(stat -c '%a' "$OWN_DEST")" != "1777"
  assert "prior baseline directory was not copied" test ! -e "$OWN_DEST/old-baseline/secret.txt"
  set +e
  "$OWN_SRC/wp-devkit/bin/wp-devkit-copy.sh" --source "$OWN_SRC" --role baseline --project "$P_OWN3" --port 18097 \
    --old-url "http://127.0.0.1:18098" --new-url "http://127.0.0.1:18097" >"$ROOT/copy-exists.txt" 2>&1
  code_exists=$?
  set -e
  assert "existing destination is refused" test "$code_exists" -ne 0
  docker run -d --name "$FOREIGN_CNAME" \
    --label "com.docker.compose.project=${P_CLASH}" \
    --label com.docker.compose.project.working_dir=/tmp/other-kit \
    alpine:3.20 sleep 120 >/dev/null
  set +e
  "$OWN_SRC/wp-devkit/bin/wp-devkit-copy.sh" --source "$OWN_SRC" --dest "$ROOT/own-src-candidate" --project "$P_CLASH" --port 18096 \
    --old-url "http://127.0.0.1:18098" --new-url "http://127.0.0.1:18096" >"$ROOT/copy-clash.txt" 2>&1
  code_clash=$?
  set -e
  docker rm -f "$FOREIGN_CNAME" >/dev/null
  assert "duplicate compose project name is refused" test "$code_clash" -ne 0
  assert "clashing destination was not created" test ! -e "$ROOT/own-src-candidate"
fi

say "uploads include, exclude, and disk refusal"
UP="$ROOT/up-src"
mkdir -p "$UP/wp-devkit" "$UP/wp-content/uploads/2024/nested" "$UP/wp-content/plugins"
printf 'media-keep\n' > "$UP/wp-content/uploads/2024/nested/photo.txt"
printf 'plugin-keep\n' > "$UP/wp-content/plugins/keep.php"
printf 'COMPOSE_PROJECT_NAME=wpup%s\n' "$TAG" > "$UP/wp-devkit/.env"
photo_hash=$(sha256sum "$UP/wp-content/uploads/2024/nested/photo.txt" | awk '{print $1}')
export WP_DEVKIT_FREE_BYTES=1
set +e
"$REPO/wp-devkit/bin/wp-devkit-copy.sh" --source "$UP" --dest "$ROOT/up-too-small" --project "wpd${TAG}" --port 18095 \
  --new-url "http://127.0.0.1:18095" --uploads include >"$ROOT/disk.txt" 2>&1
disk_code=$?
set -e
unset WP_DEVKIT_FREE_BYTES
assert "low free space exits non-zero" test "$disk_code" -ne 0
assert "low free space wrote nothing" test ! -e "$ROOT/up-too-small"
grep -q 'Nothing was written' "$ROOT/disk.txt" && ok "low free space message" || bad "low free space message"
if ! docker image inspect wp-devkit-php:8.4 >/dev/null 2>&1; then
  skip "uploads copy image wp-devkit-php:8.4 is not present"
else
  tar -C "$REPO/wp-devkit" -cf - . | tar -C "$UP/wp-devkit" -xf -
  chmod +x "$UP"/wp-devkit/bin/*.sh
  printf 'COMPOSE_PROJECT_NAME=wpup%s\nPHP_IMAGE=wp-devkit-php:8.4\n' "$TAG" > "$UP/wp-devkit/.env"
  "$UP/wp-devkit/bin/wp-devkit-copy.sh" --source "$UP" --dest "$ROOT/up-included" --project "wpi${TAG}" --port 18094 \
    --new-url "http://127.0.0.1:18094" --uploads include >"$ROOT/up-include.txt" 2>&1
  assert "include keeps nested upload" test "$(cat "$ROOT/up-included/wp-content/uploads/2024/nested/photo.txt")" = "media-keep"
  assert "include keeps plugin" test -f "$ROOT/up-included/wp-content/plugins/keep.php"
  "$UP/wp-devkit/bin/wp-devkit-copy.sh" --source "$UP" --role baseline --project "wpe${TAG}" --port 18093 \
    --new-url "http://127.0.0.1:18093" --uploads exclude >"$ROOT/up-exclude-base.txt" 2>&1
  set +e
  "$UP/wp-devkit/bin/wp-devkit-copy.sh" --source "$UP" --role candidate --project "wpm${TAG}" --port 18092 \
    --new-url "http://127.0.0.1:18092" --uploads include >"$ROOT/up-mismatch.txt" 2>&1
  mismatch_code=$?
  set -e
  assert "different uploads mode is refused" test "$mismatch_code" -ne 0
  assert "mismatched candidate was not created" test ! -e "$ROOT/up-src-candidate"
  "$UP/wp-devkit/bin/wp-devkit-copy.sh" --source "$UP" --role candidate --project "wpc${TAG}" --port 18092 \
    --new-url "http://127.0.0.1:18092" --uploads exclude >"$ROOT/up-exclude-cand.txt" 2>&1
  assert "exclude omits nested upload" test ! -e "$ROOT/up-src-baseline/wp-content/uploads/2024/nested/photo.txt"
  assert "exclude omits candidate upload" test ! -e "$ROOT/up-src-candidate/wp-content/uploads/2024"
  assert "exclude leaves uploads directory" test -d "$ROOT/up-src-baseline/wp-content/uploads"
  assert "exclude uploads directory is empty" test -z "$(find "$ROOT/up-src-baseline/wp-content/uploads" -mindepth 1 -print -quit)"
  assert "exclude uploads directory is writable" test -w "$ROOT/up-src-baseline/wp-content/uploads"
  grep -q '^uploads=exclude$' "$ROOT/up-src-baseline/wp-devkit/.wp-devkit-meta" && ok "baseline records uploads exclude" || bad "baseline records uploads exclude"
  grep -q '^uploads=exclude$' "$ROOT/up-src-candidate/wp-devkit/.wp-devkit-meta" && ok "candidate records uploads exclude" || bad "candidate records uploads exclude"
  assert "source upload unchanged" test "$(sha256sum "$UP/wp-content/uploads/2024/nested/photo.txt" | awk '{print $1}')" = "$photo_hash"
fi

say "consecutive copies do not keep the helper volume"
if ! docker image inspect wp-devkit-php:8.4 >/dev/null 2>&1; then
  skip "consecutive copy image wp-devkit-php:8.4 is not present"
else
  SEQ="$ROOT/seq-src"
  mkdir -p "$SEQ/wp-devkit"
  tar -C "$REPO/wp-devkit" -cf - . | tar -C "$SEQ/wp-devkit" -xf -
  chmod +x "$SEQ"/wp-devkit/bin/*.sh
  rm -f "$SEQ/wp-devkit/.env"
  printf 'media\n' > "$SEQ/keep.txt"
  docker volume create "wpdskeep${TAG}" >/dev/null
  helper_vols_before=$(docker volume ls -q | grep '^wpdevkittar' || true)
  helper_nets_before=$(docker network ls --format '{{.Name}}' | grep wpdevkittar || true)
  "$SEQ/wp-devkit/bin/wp-devkit-copy.sh" --source "$SEQ" --role baseline --project "seqb${TAG}" --port 18091 \
    --new-url "http://127.0.0.1:18091" >"$ROOT/seq-base.txt" 2>&1
  "$SEQ/wp-devkit/bin/wp-devkit-copy.sh" --source "$SEQ" --role candidate --project "seqc${TAG}" --port 18090 \
    --new-url "http://127.0.0.1:18090" >"$ROOT/seq-cand.txt" 2>&1
  helper_vols_after=$(docker volume ls -q | grep '^wpdevkittar' || true)
  helper_nets_after=$(docker network ls --format '{{.Name}}' | grep wpdevkittar || true)
  assert "second copy wrote the candidate" test -f "$ROOT/seq-src-candidate/keep.txt"
  assert "helper volumes match the pre-copy set" test "$helper_vols_before" = "$helper_vols_after"
  assert "helper networks match the pre-copy set" test "$helper_nets_before" = "$helper_nets_after"
  assert "unrelated volume survived consecutive copies" docker volume inspect "wpdskeep${TAG}"
  docker volume rm "wpdskeep${TAG}" >/dev/null
fi

say "sql client wrapper flags"
if ! docker image inspect wp-devkit-php:8.4 >/dev/null 2>&1; then
  skip "sql client wrapper image wp-devkit-php:8.4 is not present"
else
  cat > "$ROOT/fake-client" <<'EOF'
#!/bin/sh
printf '%s %s\n' "$(basename "$0")" "$*"
EOF
  chmod 755 "$ROOT/fake-client"
  client_mounts=()
  for cmd in mysql mariadb mysqldump mariadb-dump mysqlcheck mariadb-check; do
    client_mounts+=(-v "$REPO/wp-devkit/bin/sql-client-wrapper.sh:/usr/local/bin/${cmd}:ro")
    client_mounts+=(-v "$ROOT/fake-client:/usr/bin/${cmd}:ro")
  done
  docker run --rm "${client_mounts[@]}" --entrypoint sh wp-devkit-php:8.4 -c '
    mysql --no-defaults -e "select 1"
    mysql -e "select 1"
    mariadb --no-defaults -e "select 1"
    mariadb -e "select 1"
    mysqldump --no-defaults wordpress
    mysqldump wordpress
    mariadb-dump --no-defaults wordpress
    mariadb-dump wordpress
    mysqlcheck --no-defaults wordpress
    mysqlcheck wordpress
    mariadb-check --no-defaults wordpress
    mariadb-check wordpress
  ' >"$ROOT/client-args.txt" 2>&1
  assert "mysql --no-defaults adds --skip-ssl after it" grep -qx 'mysql --no-defaults --skip-ssl -e select 1' "$ROOT/client-args.txt"
  assert "mysql without --no-defaults is unchanged" grep -qx 'mysql -e select 1' "$ROOT/client-args.txt"
  assert "mariadb --no-defaults adds --skip-ssl after it" grep -qx 'mariadb --no-defaults --skip-ssl -e select 1' "$ROOT/client-args.txt"
  assert "mariadb without --no-defaults is unchanged" grep -qx 'mariadb -e select 1' "$ROOT/client-args.txt"
  assert "mysqldump --no-defaults adds --skip-ssl after it" grep -qx 'mysqldump --no-defaults --skip-ssl wordpress' "$ROOT/client-args.txt"
  assert "mysqldump without --no-defaults is unchanged" grep -qx 'mysqldump wordpress' "$ROOT/client-args.txt"
  assert "mariadb-dump --no-defaults adds --skip-ssl after it" grep -qx 'mariadb-dump --no-defaults --skip-ssl wordpress' "$ROOT/client-args.txt"
  assert "mariadb-dump without --no-defaults is unchanged" grep -qx 'mariadb-dump wordpress' "$ROOT/client-args.txt"
  assert "mysqlcheck --no-defaults adds --skip-ssl after it" grep -qx 'mysqlcheck --no-defaults --skip-ssl wordpress' "$ROOT/client-args.txt"
  assert "mysqlcheck without --no-defaults is unchanged" grep -qx 'mysqlcheck wordpress' "$ROOT/client-args.txt"
  assert "mariadb-check --no-defaults adds --skip-ssl after it" grep -qx 'mariadb-check --no-defaults --skip-ssl wordpress' "$ROOT/client-args.txt"
  assert "mariadb-check without --no-defaults is unchanged" grep -qx 'mariadb-check wordpress' "$ROOT/client-args.txt"
fi

say "acceptance override refuses existing data"
OV="$ROOT/override-nonempty"
mkdir -p "$OV"
printf 'keep-user\n' > "$OV/user-data"
printf 'not-a-directory\n' > "$ROOT/not-a-dir"
set +e
WP_DEVKIT_ACCEPTANCE="$OV" bash "$REPO/tests/acceptance.sh" >"$ROOT/override.txt" 2>&1
ov_code=$?
WP_DEVKIT_ACCEPTANCE="$ROOT/not-a-dir" bash "$REPO/tests/acceptance.sh" >"$ROOT/override-file.txt" 2>&1
file_code=$?
set -e
assert "non-empty acceptance directory is refused" test "$ov_code" -eq 2
assert "acceptance left pre-existing data" grep -qx 'keep-user' "$OV/user-data"
assert "non-directory acceptance path is refused" test "$file_code" -eq 2
assert "non-directory acceptance path unchanged" grep -qx 'not-a-directory' "$ROOT/not-a-dir"

say "nginx denies sensitive files and still serves uploads"
NGINX_IMAGE=nginx:1.30-alpine@sha256:47928bf67eb62a1863cb08d9ecb52d3e704304ba614eaee17884204677702951
if ! docker image inspect "$NGINX_IMAGE" >/dev/null 2>&1; then
  skip "nginx image is not present"
else
  WEB="$ROOT/web"
  mkdir -p "$WEB/wp-content/uploads/2024" "$WEB/.well-known/acme-challenge" "$WEB/.git" "$WEB/wp-devkit"
  printf 'secret\n' > "$WEB/.env"
  printf 'secret\n' > "$WEB/wp-devkit/.env"
  printf 'secret\n' > "$WEB/.git/HEAD"
  printf '<?php\n' > "$WEB/wp-config.php"
  printf '<?php\n' > "$WEB/wp-config.php.bak"
  printf 'static-ok\n' > "$WEB/wp-content/uploads/plain.txt"
  printf '<?php echo "EXECUTED";\n' > "$WEB/wp-content/uploads/2024/shell.php"
  printf '<?php echo "EXECUTED";\n' > "$WEB/wp-content/uploads/shell.phtml"
  printf 'ok\n' > "$WEB/.well-known/note.txt"
  printf 'challenge\n' > "$WEB/.well-known/acme-challenge/token"
  printf 'secret\n' > "$WEB/.well-known/.env"
  printf 'secret\n' > "$WEB/.well-known/dump.sql"
  printf '<?php\n' > "$WEB/.well-known/wp-config.php"
  printf 'home\n' > "$WEB/index.html"
  printf 'readme\n' > "$WEB/wp-devkit/README.md"
  NGINX_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
  docker rm -f "$NGINX_CNAME" >/dev/null 2>&1 || true
  docker run -d --name "$NGINX_CNAME" \
    --add-host php:127.0.0.1 \
    -p "127.0.0.1:${NGINX_PORT}:80" \
    -v "$REPO/wp-devkit/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro" \
    -v "$WEB:/var/www/html:ro" \
    "$NGINX_IMAGE" >/dev/null
  sleep 1
  code_of() { curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${NGINX_PORT}$1" || echo 000; }
  assert "dotenv denied" test "$(code_of /.env)" = "403"
  assert "git denied" test "$(code_of /.git/HEAD)" = "403"
  assert "wp-config denied" test "$(code_of /wp-config.php)" = "403"
  assert "wp-config backup denied" test "$(code_of /wp-config.php.bak)" = "403"
  assert "upload php denied" test "$(code_of /wp-content/uploads/2024/shell.php)" = "403"
  assert "upload phtml denied" test "$(code_of /wp-content/uploads/shell.phtml)" = "403"
  assert "upload static served" test "$(code_of /wp-content/uploads/plain.txt)" = "200"
  assert "well-known served" test "$(code_of /.well-known/note.txt)" = "200"
  assert "acme challenge served" test "$(code_of /.well-known/acme-challenge/token)" = "200"
  assert "well-known dotenv denied" test "$(code_of /.well-known/.env)" = "403"
  assert "well-known sql denied" test "$(code_of /.well-known/dump.sql)" = "403"
  assert "well-known wp-config denied" test "$(code_of /.well-known/wp-config.php)" = "403"
  assert "wp-devkit denied" test "$(code_of /wp-devkit/README.md)" = "403"
  assert "homepage static served" test "$(code_of /index.html)" = "200"
  docker rm -f "$NGINX_CNAME" >/dev/null
fi

say "docker build context excludes site files"
CTX="$ROOT/context"
mkdir -p "$CTX/wp-content" "$CTX/php" "$CTX/bin"
cp "$REPO/wp-devkit/.dockerignore" "$CTX/.dockerignore"
cp "$REPO/wp-devkit/php/devkit.ini" "$CTX/php/devkit.ini"
printf 'SECRET_CANARY\n' > "$CTX/wp-config.php"
dd if=/dev/zero of="$CTX/wp-content/big.bin" bs=1048576 count=4 status=none
cat > "$CTX/Dockerfile" <<'EOF'
FROM alpine:3.20
COPY php/devkit.ini /tmp/devkit.ini
EOF
docker build -t "$CTX_IMAGE" "$CTX" >"$ROOT/context-build.txt" 2>&1
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
docker rmi "$CTX_IMAGE" >/dev/null

say "url adaptation does not execute metadata"
ADAPT="$ROOT/adapt-copy"
mkdir -p "$ADAPT/wp-devkit/bin"
cp "$REPO/wp-devkit/bin/wp-devkit-adapt-urls.sh" "$REPO/wp-devkit/bin/wp-devkit-lib.sh" "$ADAPT/wp-devkit/bin/"
chmod +x "$ADAPT"/wp-devkit/bin/*.sh
printf '%s\n' "$P_ADAPT" > "$ADAPT/wp-devkit/.wp-devkit-instance"
python3 - "$ADAPT/wp-devkit/.wp-devkit-meta" "$ROOT/pwned" "$P_ADAPT" <<'PY'
import sys
path, pwned, project = sys.argv[1:]
open(path, "w", encoding="utf-8").write(
    f"project={project}\n"
    f"old_url=http://old.example/$(touch {pwned})\n"
    "new_url=http://new.example/\n"
    f"source=/tmp/not-the-adapt-copy\n"
)
PY
printf 'COMPOSE_PROJECT_NAME=%s\n' "$P_ADAPT" > "$ADAPT/wp-devkit/.env"
: > "$ROOT/adapt-docker.log"
cat > "$SHIM/docker" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$ROOT/adapt-docker.log"
exit 99
EOF
set +e
PATH="$SHIM:$PATH" "$ADAPT/wp-devkit/bin/wp-devkit-adapt-urls.sh" >"$ROOT/adapt.txt" 2>&1
code_adapt=$?
set -e
assert "metadata url adaptation exits non-zero without a stack" test "$code_adapt" -ne 0
assert "metadata was not executed" test ! -e "$ROOT/pwned"
grep -q 'touch' "$ROOT/adapt-docker.log" && ok "metadata reached docker as text" || bad "metadata reached docker as text"

say "sandbox directive keeps legitimate SQL"
# shellcheck disable=SC1091
source "$REPO/wp-devkit/bin/wp-devkit-lib.sh"
cat > "$ROOT/sandbox-in.sql" <<'SQL'
/*M!999999\- enable the sandbox mode */
  /*M!999999\- enable the sandbox mode */
CREATE TABLE sandbox_notes (id INT PRIMARY KEY, body TEXT);
INSERT INTO sandbox_notes (id, body) VALUES (1, 'enable the sandbox mode');
INSERT INTO sandbox_notes (id, body) VALUES (2, 'enable the sandbox mode'), (3, 'prefix enable the sandbox mode suffix');
INSERT INTO sandbox_notes (id, body) VALUES
(4, 'enable the sandbox mode'),
(5, '/*M!999999\- enable the sandbox mode */');
SQL
wp_devkit_strip_sandbox_directive < "$ROOT/sandbox-in.sql" > "$ROOT/sandbox-out.sql"
directive_left=$(grep -Ec '^[[:space:]]*/\*M!999999\\- enable the sandbox mode \*/[[:space:]]*$' "$ROOT/sandbox-out.sql" || true)
assert "sandbox directive lines removed" test "$directive_left" -eq 0
assert "single-row insert kept" grep -qF "VALUES (1, 'enable the sandbox mode')" "$ROOT/sandbox-out.sql"
assert "extended insert kept" grep -qF "VALUES (2, 'enable the sandbox mode'), (3, 'prefix enable the sandbox mode suffix')" "$ROOT/sandbox-out.sql"
assert "continued insert kept" grep -qF "(4, 'enable the sandbox mode')" "$ROOT/sandbox-out.sql"
assert "directive stored as data kept" grep -qF "(5, '/*M!999999\\- enable the sandbox mode */')" "$ROOT/sandbox-out.sql"
DB_IMAGE='mariadb:11.8@sha256:f16d7a344413e519dff518f27bdb221388f84b0d274c97c4fb5f2cb0dc1b34fa'
if ! docker image inspect "$DB_IMAGE" >/dev/null 2>&1; then
  skip "mariadb image is not present for snapshot round trip"
else
  docker run -d --name "$DB_CNAME" \
    -e MARIADB_ROOT_PASSWORD=wordpress-root \
    -e MARIADB_DATABASE=wordpress \
    "$DB_IMAGE" >/dev/null
  ready=0
  for _ in $(seq 1 40); do
    if docker exec "$DB_CNAME" mariadb -uroot -pwordpress-root -e 'SELECT 1' wordpress >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 2
  done
  assert "sandbox database became ready" test "$ready" -eq 1
  set +e
  wp_devkit_strip_sandbox_directive < "$ROOT/sandbox-in.sql" \
    | docker exec -i "$DB_CNAME" mariadb -uroot -pwordpress-root wordpress >"$ROOT/sandbox-import.txt" 2>&1
  import_code=$?
  set -e
  assert "filtered SQL imports" test "$import_code" -eq 0
  kept=$(docker exec "$DB_CNAME" mariadb -N -uroot -pwordpress-root wordpress \
    -e "SELECT COUNT(*) FROM sandbox_notes WHERE body LIKE '%enable the sandbox mode%'" | tr -d '[:space:]')
  assert "restored rows keep the sandbox phrase" test "$kept" = "5"
  docker rm -f -v "$DB_CNAME" >/dev/null
fi

say "readme paths work from wp-devkit"
DOC="$ROOT/doclayout"
mkdir -p "$DOC/project-x" "$DOC/project-x-baseline/wp-devkit/bin" "$DOC/project-x-candidate" "$DOC/project-x-snapshots"
cp -a "$REPO/wp-devkit/." "$DOC/project-x/wp-devkit/"
cp "$REPO/wp-devkit/compose.yaml" "$DOC/project-x-baseline/wp-devkit/compose.yaml"
printf 'COMPOSE_PROJECT_NAME=rd%s\n' "$TAG" > "$DOC/project-x-baseline/wp-devkit/.env"
touch "$DOC/project-x-baseline/wp-devkit/bin/wp-devkit-adapt-urls.sh"
touch "$DOC/project-x-snapshots/initial.sql" "$DOC/project-x-snapshots/smoke.md"
if ! python3 - "$REPO/wp-devkit/README.md" "$DOC/project-x/wp-devkit" >"$ROOT/readme-paths.txt" <<'PY'
import os, re, sys
readme, cwd = sys.argv[1:]
text = open(readme, encoding="utf-8").read()
if re.search(r"(?<!/)\.\./project-x", text):
    sys.exit("README still has a one-level ../project-x path")
rels = re.findall(r"(?:\.\./)+project-x[A-Za-z0-9_./-]*|bin/wp-devkit-[a-z-]+\.sh", text)
missing = []
for rel in rels:
    path = os.path.normpath(os.path.join(cwd, rel))
    if not os.path.exists(path):
        missing.append(f"{rel} -> {path}")
if not rels or missing:
    sys.exit("missing documented paths:\n" + "\n".join(missing))
print(f"checked {len(rels)} paths")
PY
then
  bad "readme paths resolve from wp-devkit"
  cat "$ROOT/readme-paths.txt" >&2 || true
else
  ok "readme paths resolve from wp-devkit"
fi
( cd "$DOC/project-x/wp-devkit" && ./bin/wp-devkit-check-db.sh ../../project-x-baseline ) >"$ROOT/readme-check-db.txt" 2>&1
( cd "$DOC/project-x/wp-devkit" && ./bin/wp-devkit-preflight.sh ../../project-x-baseline ) >"$ROOT/readme-preflight.txt" 2>&1
assert "documented check-db runs from wp-devkit" grep -q 'no wp-config.php yet' "$ROOT/readme-check-db.txt"
assert "documented preflight runs from wp-devkit" grep -q 'belongs only to' "$ROOT/readme-preflight.txt"
snap_out=$(cd "$DOC/project-x/wp-devkit" && realpath -m ../../project-x-snapshots/smoke.md)
site_root=$(cd "$DOC/project-x" && pwd)
assert "documented smoke output stays outside the site" test "${snap_out#"$site_root"/}" = "$snap_out"

say "git archive contains only wp-devkit"
ARCHIVE="$ROOT/archive.txt"
git -C "$REPO" archive --format=tar "$(git -C "$REPO" write-tree)" | tar -t > "$ARCHIVE"
assert "archive has the skill" grep -qx 'wp-devkit/skills/wp-devkit/SKILL.md' "$ARCHIVE"
assert "archive has START_HERE" grep -qx 'wp-devkit/START_HERE.md' "$ARCHIVE"
assert "archive has the public README" grep -qx 'wp-devkit/README.md' "$ARCHIVE"
assert "archive omits docs" test -z "$(grep -E '^docs/' "$ARCHIVE" || true)"
assert "archive omits tests" test -z "$(grep -E '^tests/' "$ARCHIVE" || true)"
assert "archive omits AGENTS.md" test -z "$(grep -x 'AGENTS.md' "$ARCHIVE" || true)"
other=$(grep -v '^wp-devkit/' "$ARCHIVE" || true)
assert "archive has no other root entries" test -z "$other"

say "summary pass=$PASS fail=$FAIL skipped=$SKIP"
[[ "$FAIL" -eq 0 ]]
