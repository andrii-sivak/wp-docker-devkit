# wp-docker-devkit

Local WordPress development and comparison environment. Copy these files into a WordPress root, then use ordinary Docker Compose commands. Git, GNU Make, and an AI assistant are not required.

This tree is the template. It is not a WordPress site by itself. Do not start Compose in a checkout that also contains `docs/`, `.git`, or other project files: the PHP entrypoint treats that as an incomplete site and refuses to overwrite it.

## What was verified

Verified on Linux x86_64 with Docker Engine 29.5 and Compose v5.1, on 24 October 2026:

| Piece | Identity | Result |
| --- | --- | --- |
| PHP / WordPress base | `wordpress:php8.4-fpm` index `sha256:41fcfa8617e811e41516783bda46046f0945d94d547f346617bbea5e189b30bc` | PHP 8.4.27, image core 7.1.3, Debian 13, `mysqli` present, `pdo_mysql` absent |
| Database default | `mariadb:11.8` index `sha256:f16d7a344413e519dff518f27bdb221388f84b0d274c97c4fb5f2cb0dc1b34fa` | MariaDB 11.8.9. A logical dump was restored into two new volumes of this same version |
| HTTP | `nginx:1.30-alpine` index `sha256:47928bf67eb62a1863cb08d9ecb52d3e704304ba614eaee17884204677702951` | Nginx 1.30.6. `/healthz` is ready before WordPress is installed |
| Composer / WP-CLI | 2.10.3 and 2.12.0 | Run inside the PHP 8.4 image. WP-CLI runs as `www-data` |
| SQL client | MariaDB client 11.8.6 from Debian 13 | Talks to MariaDB 11.8.9. With `skip-ssl`, it also imported a one-row table into MySQL 8.4.13 |
| Optional Node.js | `node:22-alpine` index `sha256:fe4f6d74e20370acb04ad889077d14d0f64a9c8ea6a42bc60cddf1e844699914` | `node --version` printed v22.23.4. The profile does not start with the site |
| Optional phpMyAdmin | `phpmyadmin/phpmyadmin:5.2.2` digest `sha256:95e01f723b5e55fabf16d0473f1df2354c4c6352b35902b51d6a6245e074aee4` | Started with `--profile pma` and logged in to MySQL 8.4 |

PHP 7.4 is qualified on this Linux host as `wordpress:php7.4-fpm` index `sha256:0b4b629f3f1389cb4e42570c452188d6f1ebe74d31aee6395bbb010450a0640e`: PHP 7.4.33, Debian 11, image core 6.1.1, `mysqli` present, `pdo_mysql` absent, Composer 2.10.3, WP-CLI 2.12.0, and MariaDB client 10.5.23. A site on that image answered HTTP, and an existing PHP 8.4 site kept the same core hashes after its runtime was switched to this image. Debian 11's security index lists newer client packages whose files return HTTP 404, so the image installs the main-archive versions. That client is older than the Debian 13 client used with PHP 8.4.

MySQL 8.4.13 (`sha256:76f0358884cb92d9a086d24e5671c38048d3fef40f2588703d73eb55392d6b69`) installed WordPress and restored that logical snapshot into a second MySQL 8.4 volume. A MariaDB dump was not imported into MySQL. macOS and Windows were not run. The GitHub **Code → Download ZIP** archive was not downloaded, because this repository has no GitHub remote.

`pdo_mysql` is not installed. Rebuild with `INSTALL_PDO_MYSQL=1` in `.env` when a project needs it.

## Install

1. On GitHub, use **Code → Download ZIP**. Extract the archive and copy its contents into the WordPress root. An empty directory is a new site. An existing site must already be a complete tree (`index.php`, `wp-includes/version.php`, `wp-settings.php`, `wp-load.php`, `wp-login.php`, `wp-admin/admin.php`, and `wp-includes/functions.php`).
2. `cp .env.example .env` and edit ports, resource limits, and `WP_HOME` / `WP_SITEURL`.
3. Give the project its own `COMPOSE_PROJECT_NAME` and `PHP_IMAGE` when more than one copy will run.
4. Build and start:

```bash
docker compose build
docker compose up -d
```

5. Open `http://127.0.0.1:8080` (or the port in `.env`) and finish the browser installer. Infrastructure can be healthy before that installer is done: `http://127.0.0.1:8080/healthz` returns `ok` from Nginx alone.

The development database password in `.env.example` is `wordpress`. It is a local default, not a secret to reuse anywhere else.

## Lifecycle

```bash
docker compose ps
docker compose logs -f php
docker compose exec php php -v
docker compose exec php composer --version
docker compose exec php wp cli version
docker compose exec php wp db query "SELECT VERSION();"
docker compose stop
docker compose down
```

`docker compose down` keeps the database volume. Rebuilding or changing `PHP_BASE_IMAGE` does not replace an existing WordPress core. Core changes only when you run `wp core update` yourself, or when the directory is a new empty template and the upstream entrypoint copies core once.

An incomplete tree (some site files, but not the core set above) is refused before that copy. Move the extra files or complete the tree, then start again.

Uploads and cache are chowned to `www-data` (uid 33, gid 33) when `WP_DEVKIT_FIX_UPLOAD_PERMS=1`. Other directories are left alone. PHP-FPM workers run as uid 33; the entrypoint process is root because the upstream image requires it.

## HTTP

Published HTTP ports bind to `127.0.0.1`. The database port is not published. Nginx does not serve `.env`, `.git`, `.wp-devkit-*`, SQL dumps, `compose.yaml`, `Dockerfile`, `wp-config.php`, or the `nginx/`, `php/`, `bin/`, `prompt/`, and `examples/` directories. PHP files under `wp-content/uploads/` are denied.

## Comparisons

Create the work directory outside the site. The default is a sibling named `wp-devkit-work`. Override it with `WP_DEVKIT_WORKDIR`. Snapshots go in `$WP_DEVKIT_WORKDIR/snapshots`. Copies go in `$WP_DEVKIT_WORKDIR/instances/<name>` and must stay there.

```bash
export WP_DEVKIT_WORKDIR="$PWD/../wp-devkit-work"
bin/wp-devkit-snapshot.sh initial
bin/wp-devkit-copy.sh \
  --source "$PWD" \
  --dest "$WP_DEVKIT_WORKDIR/instances/baseline" \
  --project wpbaseline \
  --port 8081 \
  --old-url "http://127.0.0.1:8080" \
  --new-url "http://127.0.0.1:8081"
bin/wp-devkit-copy.sh \
  --source "$PWD" \
  --dest "$WP_DEVKIT_WORKDIR/instances/candidate" \
  --project wpcandidate \
  --port 8082 \
  --old-url "http://127.0.0.1:8080" \
  --new-url "http://127.0.0.1:8082"
```

The copy skips directories that already contain `.wp-devkit-instance`, and it refuses a symlink that points outside the source. It keeps WordPress files owned by uid 33 and sets mode 1777 on the copy's top directory so the host can add the marker and `.env`. Each copy receives its own `.env`, project name, HTTP port, and PHP image tag.

Check the copy, then start it and import the same snapshot into its own database:

```bash
bin/wp-devkit-check-db.sh "$WP_DEVKIT_WORKDIR/instances/baseline"
docker compose --project-directory "$WP_DEVKIT_WORKDIR/instances/baseline" build
docker compose --project-directory "$WP_DEVKIT_WORKDIR/instances/baseline" up -d
bin/wp-devkit-restore.sh "$WP_DEVKIT_WORKDIR/snapshots/initial.sql"
bin/wp-devkit-adapt-urls.sh
```

Run the adapt command from the copy (`cd` there, or call its `bin/wp-devkit-adapt-urls.sh`). It uses `wp search-replace`, which updates serialized values, then sets the `home` and `siteurl` options. Constants already saved in `wp-config.php` are not rewritten.

Change one dimension on the candidate:

| Dimension | Command | Leave unchanged |
| --- | --- | --- |
| PHP | Set `PHP_BASE_IMAGE` in the candidate `.env`, set a distinct `PHP_IMAGE`, then `docker compose build && docker compose up -d` | Core files |
| WordPress | `docker compose exec php wp core check-update`, then `docker compose exec php wp core update` for the offer WP-CLI selects, or `wp core update --version=7.1.3` for one exact release. Then `wp core update-db` when WordPress asks. Record `wp core version`. `wp core update --version=latest` is not a version number and leaves the site unchanged | Plugins, PHP image, database volume |
| Database | New empty volume, new `DB_IMAGE`, `bin/wp-devkit-restore.sh` the logical snapshot. Do not copy `/var/lib/mysql` | Files |
| Plugin | `docker compose exec php wp plugin update <slug>` | Other plugins |

Record actual versions with `bin/wp-devkit-versions.sh`. `latest` must be written down as the version number WP-CLI prints afterward.

## Checks and report

```bash
bin/wp-devkit-smoke.sh --output "$WP_DEVKIT_WORKDIR/smoke.md"
```

`PROJECT_CHECK_COMMAND`, when set, is run on the host. If it is unset, the report says NOT CONFIGURED. Statuses are PASS, FAIL, SKIPPED, NOT CONFIGURED, and ERROR. A skipped integration check is not a success. Smoke checks do not prove that payment, mail, or other integrations work.

`prompt/AGENT_PROMPT.md` tells an assistant to use these commands. `examples/comparison-report.md` shows the report shape.

## Optional tools

```bash
docker compose --profile node run --rm --entrypoint node node --version
docker compose --profile pma up -d
```

Plain `docker compose up -d` does not start either service.

## Cleanup

This removes the instance directory, its containers, its network, and its named database volume:

```bash
bin/wp-devkit-cleanup.sh "$WP_DEVKIT_WORKDIR/instances/candidate"
```

It refuses a path that is not inside the work directory or that lacks `.wp-devkit-instance`. It does not run `docker system prune` and it does not delete other projects.

## Integration warning

Before starting a copy, review SMTP, SMS, webhook, payment/CRM/API integrations, and background jobs. Running Docker locally does not block outbound traffic. Use test credentials/stubs and data suitable for testing. The template isolates containers and local databases but does not guarantee prevention of external side effects.

The template does not set `WP_ENVIRONMENT_TYPE`, `DISABLE_WP_CRON`, or `WP_HTTP_BLOCK_EXTERNAL`, and it does not install an email interceptor.

## Updating pins

`docker buildx imagetools inspect <name>:<tag>` prints the index digest. Put that digest in `.env` as `PHP_BASE_IMAGE`, `DB_IMAGE`, or `NGINX_IMAGE`, rebuild, and record `php -v`, `wp core version`, and `SELECT VERSION()`. A new digest is not a compatibility promise for an existing database.

## Host tools

The copy, database check, and cleanup scripts use Bash, GNU `tar` / `find`, Docker Compose, and Python 3. PHP, Composer, WP-CLI, and the SQL client run inside the PHP container.
