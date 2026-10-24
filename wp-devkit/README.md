# wp-docker-devkit

Local WordPress development and comparison environment. Place this single `wp-devkit/` directory inside a WordPress root, then use ordinary Docker Compose commands from that directory. Git, GNU Make, and an AI assistant are not required.

`wp-devkit/` is not a WordPress site by itself. The parent directory is the site. Do not merge these files into the WordPress root, and do not start Compose with the development repository (the tree that contains `docs/` and `.git`) as the parent: the PHP entrypoint treats that as an incomplete site and refuses to overwrite it. An assistant can read `START_HERE.md` and `skills/wp-devkit/SKILL.md` by path. Those files are optional.

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

1. On GitHub, use **Code → Download ZIP**. Extract the archive, find the single `wp-devkit/` directory inside GitHub's wrapper directory, and place that directory inside the WordPress root. Do not replace an existing `wp-devkit/` without reviewing it. Leave the site's own Compose file, Dockerfile, `.env`, README, and scripts where they are.
2. A root whose only top-level entry is `wp-devkit/` is a new site. An existing site must already be a complete tree (`index.php`, `wp-includes/version.php` with `$wp_version`, `wp-settings.php`, `wp-load.php`, `wp-login.php`, `wp-admin/admin.php`, `wp-includes/functions.php`, `wp-includes/load.php`, `wp-includes/plugin.php`, `wp-admin/includes/admin.php`, a `wp-content/` directory, and the rest of a real core). A handful of those files is not enough.
3. `cp .env.example .env` inside `wp-devkit/` and edit ports, resource limits, and `WP_HOME` / `WP_SITEURL`. `.env.example` is a DevKit example. It is not the version or credential source for an existing site. Constants already set in `wp-config.php` stay in force; `WP_HOME` and `WP_SITEURL` in `.env` do not replace them or the `home` and `siteurl` values stored in the database. DevKit does not edit the original `wp-config.php` or the source database.
4. Set `COMPOSE_PROJECT_NAME` to a name that is unique on this machine, for example the site directory name (`project-x`). Do not use `wp-devkit`. Set a distinct `PHP_IMAGE` when more than one copy will run.
5. From `wp-devkit/`, check the project name, then build and start:

```bash
cd /path/to/wordpress/wp-devkit
bin/wp-devkit-preflight.sh
docker compose build
docker compose up -d
```

6. Open `http://127.0.0.1:8080` (or the port in `.env`) and finish the browser installer. Infrastructure can be healthy before that installer is done: `http://127.0.0.1:8080/healthz` returns `ok` from Nginx alone.

The development database password in `.env.example` is `wordpress`. It is a local default, not a secret to reuse anywhere else.

If this WordPress root is already published by another web server, that server can still expose `wp-devkit/` (including `.env`). DevKit's Nginx rules apply only to the DevKit stack. Check the other server and do not assume this folder is hidden. This toolkit does not edit that server's configuration.

## Lifecycle

Run these from `wp-devkit/`:

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

`docker compose down` keeps the database volume. Rebuilding or changing `PHP_BASE_IMAGE` does not replace an existing WordPress core. Core changes only when you run `wp core update` yourself, or when the parent directory is a new root that contains only `wp-devkit/` and the upstream entrypoint copies core once.

An incomplete tree (some site files, but not a complete core) is refused before that copy. Move the extra files or complete the tree, then start again. `bin/wp-devkit-preflight.sh` refuses to start when this `COMPOSE_PROJECT_NAME` already belongs to a different `wp-devkit/` directory.

Uploads and cache are chowned to `www-data` (uid 33, gid 33) when `WP_DEVKIT_FIX_UPLOAD_PERMS=1`. Other directories are left alone. PHP-FPM workers run as uid 33; the entrypoint process is root because the upstream image requires it.

## HTTP

Published HTTP ports bind to `127.0.0.1`. The database port is not published. Nginx denies the whole `/wp-devkit/` tree, `.env`, `.git`, SQL dumps, `compose.yaml`, `Dockerfile`, `wp-config.php`, and backup or dotfile names even under `/.well-known/`. A real challenge file such as `/.well-known/acme-challenge/<token>` is still served. PHP files under `wp-content/uploads/` are denied. These rules do not cover a different web server that is already serving this directory.

## Comparisons

`<site>` below is the name of the WordPress root directory, not a wider project name. For a root named `project-x`, the siblings are:

- `project-x/` — the original site
- `project-x-baseline/` — the baseline copy
- `project-x-candidate/` — the candidate copy
- `project-x-snapshots/` — SQL snapshots and any report you choose to write there

There is one baseline and one candidate. Each has its own `wp-devkit/`, Compose project, network, and database volume. `bin/wp-devkit-snapshot.sh initial` writes `project-x-snapshots/initial.sql`, outside all three WordPress roots.

That export needs the source database running and reachable. If it is not, the export stops. Start or repair that database yourself, then run the snapshot command again. DevKit does not start, repair, or reconfigure the original database. If you already have a suitable `.sql` dump, put it in `project-x-snapshots/` and skip another export. `bin/wp-devkit-snapshot.sh` uses WP-CLI inside the DevKit PHP container. On a source that is not running under DevKit, an existing client such as `mariadb-dump` is enough. Do not copy raw database files, and do not install tools only to obtain WP-CLI.

Do not edit the source files or the source database while you take the snapshot and restore it into both copies. The toolkit does not lock or watch the source. A later edit of the source is not copied into the siblings. A copy keeps the database name, user, and password it found in `wp-config.php` when those values are hardcoded. Before the first start or restore, `bin/wp-devkit-check-db.sh` must show that `DB_HOST` is this copy's `db` service. If the check prints another host, change only that copy's `wp-config.php`, never the original. `.env` does not override a hardcoded `DB_HOST`.

From the source `wp-devkit/` directory:

```bash
bin/wp-devkit-snapshot.sh initial
bin/wp-devkit-copy.sh \
  --role baseline \
  --project projectxbase \
  --port 8081 \
  --old-url "http://127.0.0.1:8080" \
  --new-url "http://127.0.0.1:8081"
bin/wp-devkit-copy.sh \
  --role candidate \
  --project projectxcand \
  --port 8082 \
  --old-url "http://127.0.0.1:8080" \
  --new-url "http://127.0.0.1:8082"
```

Before either copy, the script prints approximate file sizes for the source and for `wp-content/uploads/`, the file space for two copies with uploads included and excluded, and the free space on the destination filesystem. It refuses that copy before writing if the destination clearly cannot hold the selected copy. Run the same `--uploads` value for baseline and candidate. The default is `include`, which copies media. `--uploads exclude` leaves an empty writable `wp-content/uploads/` in each copy and does not change the original uploads directory.

```bash
bin/wp-devkit-copy.sh \
  --role baseline \
  --uploads exclude \
  --project projectxbase \
  --port 8081 \
  --old-url "http://127.0.0.1:8080" \
  --new-url "http://127.0.0.1:8081"
```

The numbers are an estimate, not a guaranteed upper bound. SQL snapshots, database volumes, Docker images, filesystem quotas, and caches can need more space and may sit on another disk. When uploads are excluded, restored databases still contain attachment records, but the files are absent. Missing media in that mode is a testing limitation, not by itself a PHP, WordPress, or plugin regression.

If a sibling already exists or the parent directory is not writable, the command stops. Pass `--dest /another/path` only when that path is outside the source and is empty. The copy skips nested trees that already contain `.wp-devkit-instance`, and it skips top-level `*-baseline`, `*-candidate`, and `*-snapshots` directories. It refuses a symlink that points outside the source. Each copied file keeps the uid, gid, and mode it had in the source, including mixed ownership. The original tree is not chowned. The copy root is not made world-writable. Marker files and `.env` are written inside the copy's `wp-devkit/` and are readable by the user who ran the copy. PHP-FPM and WP-CLI run as uid 33 (`www-data`). Core and plugin updates on a copy succeed when those files are writable by uid 33; otherwise adjust the copy, not the original. Each copy receives its own `.env`, project name, HTTP port, and PHP image tag.

Check the copy, then start it and import the same snapshot into its own database. Run these from `project-x/wp-devkit/`. A sibling of `project-x/` is two levels up (`../../`), because `../` is `project-x/` itself. These commands name the baseline copy, not the source:

```bash
bin/wp-devkit-check-db.sh ../../project-x-baseline
bin/wp-devkit-preflight.sh ../../project-x-baseline
docker compose --project-directory ../../project-x-baseline/wp-devkit build
docker compose --project-directory ../../project-x-baseline/wp-devkit up -d
bin/wp-devkit-restore.sh --target ../../project-x-baseline ../../project-x-snapshots/initial.sql
../../project-x-baseline/wp-devkit/bin/wp-devkit-adapt-urls.sh
```

Run the adapt command from the copy, as shown. It reads `.wp-devkit-meta` as data, uses `wp search-replace` (which updates serialized values), then sets the `home` and `siteurl` options. Constants already saved in `wp-config.php` are not rewritten. Repeat restore and adapt for `../../project-x-candidate`.

Confirm the baseline answers before you change the candidate. If the baseline fails, stop. Do not treat that failure as a candidate result. Prefer one change on the candidate. You can put several changes in that same candidate when you want one combined test. Do not create a second candidate for the combination.

| Dimension | Command | Leave unchanged |
| --- | --- | --- |
| PHP | Set `PHP_BASE_IMAGE` in the candidate `wp-devkit/.env`, set a distinct `PHP_IMAGE`, then `docker compose build && docker compose up -d` from that `wp-devkit/` | Core files |
| WordPress | `docker compose exec php wp core check-update`, then `docker compose exec php wp core update` for the offer WP-CLI selects, or `wp core update --version=7.1.3` for one exact release. Then `wp core update-db` when WordPress asks. Record `wp core version`. `wp core update --version=latest` is not a version number and leaves the site unchanged | Plugins, PHP image, database volume |
| Database | New empty volume, new `DB_IMAGE`, `bin/wp-devkit-restore.sh --target ../../project-x-candidate ../../project-x-snapshots/initial.sql`. Do not copy `/var/lib/mysql` | Files |
| Plugin | `docker compose exec php wp plugin update <slug>` | Other plugins |

Record actual versions with `bin/wp-devkit-versions.sh`. `latest` must be written down as the version number WP-CLI prints afterward.

## Checks and report

```bash
bin/wp-devkit-smoke.sh --output ../../project-x-snapshots/smoke.md
```

`PROJECT_CHECK_COMMAND`, when set, is run on the host. If it is unset, the report says NOT CONFIGURED. Statuses are PASS, FAIL, SKIPPED, NOT CONFIGURED, and ERROR. A skipped integration check is not a success. Smoke checks do not prove that payment, mail, or other integrations work. The command above is the smoke report. It is written only where `--output` points. With no `--output`, it is printed and not saved. `examples/comparison-report.md` shows a report shape. It is not generated for you. Keep or discard these files as you like. Nothing in this toolkit commits them.

`START_HERE.md` points at `skills/wp-devkit/SKILL.md` for an assistant. That skill is optional. This README is the manual. The skill's status check does not start containers. Discovery there does not change the site until you run the commands in this file.

## Optional tools

```bash
docker compose --profile node run --rm --entrypoint node node --version
docker compose --profile pma up -d
```

Plain `docker compose up -d` does not start either service.

## Cleanup

You can remove a copy at any time, whether or not the checks passed. From `project-x/wp-devkit/`:

```bash
bin/wp-devkit-cleanup.sh ../../project-x-baseline
bin/wp-devkit-cleanup.sh ../../project-x-candidate
```

Each command removes that copied WordPress root, its containers, its network, and its named database volume. It checks that every container for that Compose project name has this copy's `wp-devkit/` as its working directory. A name that belongs to another directory is refused, and nothing is deleted. The original site and its database stay. `project-x-snapshots/` and every file in it stay, including SQL dumps and reports. Deleting a snapshot file is a separate step you do yourself. Cleanup does not remove Docker images or the build cache, and it does not run `docker system prune`. There is no command that deletes every copy and the snapshots together.

Restore and cleanup require a directory created by `bin/wp-devkit-copy.sh`. They refuse the original project and a copy whose marker, `.wp-devkit-meta`, and `COMPOSE_PROJECT_NAME` disagree.

`bin/wp-devkit-restore.sh` does not import into the tree that contains the script. Pass the copy explicitly:

```bash
bin/wp-devkit-restore.sh --target ../../project-x-candidate ../../project-x-snapshots/initial.sql
```

## Integration warning

Before starting a copy, review SMTP, SMS, webhook, payment/CRM/API integrations, and background jobs. Running Docker locally does not block outbound traffic. Use test credentials/stubs and data suitable for testing. The template isolates containers and local databases but does not guarantee prevention of external side effects.

The template does not set `WP_ENVIRONMENT_TYPE`, `DISABLE_WP_CRON`, or `WP_HTTP_BLOCK_EXTERNAL`, and it does not install an email interceptor.

## Updating pins

`docker buildx imagetools inspect <name>:<tag>` prints the index digest. Put that digest in `.env` as `PHP_BASE_IMAGE`, `DB_IMAGE`, or `NGINX_IMAGE`, rebuild, and record `php -v`, `wp core version`, and `SELECT VERSION()`. A new digest is not a compatibility promise for an existing database.

## Host tools

The copy, database check, and cleanup scripts use Bash, GNU `tar` / `find`, Docker Compose, and Python 3. PHP, Composer, WP-CLI, and the SQL client run inside the PHP container.
