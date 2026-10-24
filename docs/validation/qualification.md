# Image qualification — 24 October 2026

Linux x86_64, Docker Engine 29.5, Compose v5.1. Development evidence, excluded from the GitHub ZIP by `export-ignore`.

Commands below were run from the repository with `DOCKER_CONFIG` pointed at an empty client config, because this machine's Docker config asks for `docker-credential-desktop`, which is not installed. That does not change the images under test.

## OQ-01 PHP 8.4 base

`wordpress:php8.4-fpm` index `sha256:41fcfa8617e811e41516783bda46046f0945d94d547f346617bbea5e189b30bc`.

Runtime: PHP 8.4.27, Debian 13, WordPress 7.1.3 in `/usr/src/wordpress`. `mysqli` is present. `pdo_mysql` is absent. Composer 2.10.3 and WP-CLI 2.12.0 run. The SQL client is MariaDB 11.8.6. Debian 13's security archive installed those packages on the first attempt; the Bullseye fallback did not run.

The upstream entrypoint still copies core when both `index.php` and `wp-includes/version.php` are missing. The devkit entrypoint refuses an incomplete tree first. A complete core hash was unchanged after a second start.

`tests/acceptance.sh`: 61 PASS, 0 FAIL, including manual install, HTTP hygiene, two isolated projects, `hello-dolly` 1.6 to 1.7.2, and cleanup of only the candidate project.

## OQ-02 PHP 7.4

Index `sha256:0b4b629f3f1389cb4e42570c452188d6f1ebe74d31aee6395bbb010450a0640e`. PHP 7.4.33 on Debian 11. Image core is WordPress 6.1.1. `mysqli`, `curl`, `gd`, `intl`, `mbstring`, and `zip` are present. `pdo_mysql` is absent.

APT is not a network failure and not a PHP incompatibility. `apt-get update` succeeds. The security index still names `mariadb-client` `1:10.5.29-0+deb11u1`, `libfcgi-bin` `2.4.2-2+deb11u1`, and `ca-certificates` `20250419~deb12u1~deb11u1`, and those pool URLs return HTTP 404 from `deb.debian.org`. The same filenames exist for the older main-archive builds (`mariadb-client` `1:10.5.23-0+deb11u1`, `libfcgi-bin` `2.4.2-2`) and return HTTP 200. The Dockerfile installs the security set first and, only after that 404, pins `Debian-Security` to priority -1, installs the main-archive set, and deletes the pin. The built image has no leftover pin file.

Verified on the built image and a running project (`tests/qualify-followup.sh`):

- `php -v` → 7.4.33
- `composer --version` → 2.10.3
- `wp cli version` → 2.12.0
- `mariadb --version` → 10.5.23
- `cgi-fcgi` is installed and the stack's PHP healthcheck became healthy
- `/healthz` returned 200 before installation
- `wp core install` succeeded and the homepage returned 200
- `wp db query "SELECT 1"` returned 1
- `www-data` wrote `wp-content/uploads/php74.txt`

## PHP image switch

An installed PHP 8.4 site was copied. The copy's `PHP_IMAGE` was `wp-devkit-php:7.4`. After startup, `php -r 'echo PHP_VERSION;'` was `7.4.33`. SHA-256 of `index.php`, `wp-settings.php`, `wp-includes/version.php`, and `wp-includes/functions.php` matched the PHP 8.4 source before and after restoring that source's SQL snapshot. The switched homepage returned 200.

## WordPress update

`wp core check-update` on a fresh 6.8.3 site listed `6.8.11` (minor) and `7.1.3` (major). `wp core update --version=latest` does not select either offer: WP-CLI only treats `--version` as a version number or `nightly`, so the command prints "WordPress is up to date" and leaves the files alone. That was the earlier anomaly.

`wp core update` with no version, on a fresh 6.8.3 install, resolved to 7.1.3 (`before=6.8.3 installed=6.8.3 default=7.1.3`). `wp core update --version=7.1.3` then stayed on 7.1.3. `wp core update-db` ran. The acceptance suite saw the same resolution on a candidate whose files had been set to 6.8.3: `downloaded=6.8.3 after=7.1.3`, while the baseline stayed 7.1.3.

## OQ-04 Databases

MariaDB 11.8.9 remains the default. One snapshot restored into two new MariaDB volumes in the acceptance suite.

MariaDB 11.8 dumps start with the directive line `/*M!999999\- enable the sandbox mode */`. The PHP 7.4 client 10.5.23 reports `Unknown command '\-'`. Snapshot and restore delete only that directive line. SQL that merely contains the same words is kept.

MySQL 8.4.13 (`sha256:76f0358884cb92d9a086d24e5671c38048d3fef40f2588703d73eb55392d6b69`) was selected with `DB_IMAGE` only. The stack became healthy, `wp core install` succeeded, and `SELECT VERSION()` contained `8.4.`. A logical snapshot restored into a second MySQL 8.4 project kept `blogdescription=mysql-marker`, and that copy's homepage returned 200. WP-CLI calls the client with `--no-defaults`, which ignored `skip-ssl` in `my.cnf` and failed against MySQL 8.4's self-signed certificate. The image now wraps `mysql`, `mariadb`, `mysqldump`, and `mariadb-dump` so `--skip-ssl` is passed on the command line, with `--no-defaults` kept first. A MariaDB dump was not imported into MySQL.

## OQ-05 Node.js and phpMyAdmin

`docker compose --profile node run --rm --entrypoint node node --version` printed `v22.23.4`. Plain `docker compose config --services` lists `db`, `php`, and `nginx`.

phpMyAdmin 5.2.2 (`sha256:95e01f723b5e55fabf16d0473f1df2354c4c6352b35902b51d6a6245e074aee4`) was started with `--profile pma` on the MySQL project. `http://127.0.0.1:18131/` returned 200 and the body contained `phpMyAdmin`. A login as the WordPress database user reached the server without a connection error.

## OQ-08 Readiness

Nginx `/healthz`, PHP-FPM `/ping`, and the database healthcheck became healthy before installation on both the PHP 8.4/MariaDB pilot and the PHP 7.4 project. Compose applied PHP limits of 384m, 0.50 CPU, and 222 PIDs on the acceptance container.

## SPEC v1.1 layout — 24 October 2026

The runtime now lives in `wp-devkit/`. Compose bind-mounts the parent WordPress root. Baseline and candidate are siblings (`project-x-baseline/`, `project-x-candidate/`). Snapshots are `project-x-snapshots/*.sql`. Identity files are `wp-devkit/.wp-devkit-instance`, `.wp-devkit-meta`, and `.env`. URL adaptation reads metadata with the line parser and does not `source` it. Copy roots are not mode 1777. Cleanup and restore require container `com.docker.compose.project.working_dir` to be this copy's `wp-devkit/`. On Compose 5.1.3, volumes and networks do not carry that label; a project name that has only a volume or network is refused. Nginx denies `/wp-devkit/` and sensitive names under `/.well-known/`, and still serves `/.well-known/acme-challenge/token`.

`tests/safety.sh` after the snapshot-line and README-path fixes: 68 PASS, 0 FAIL, 0 SKIPPED. An earlier run of that file exited 1 because the disposable MariaDB accepted ping before the root password was ready; the re-run waited for `SELECT 1` and passed. `tests/acceptance.sh`: 67 PASS, 0 FAIL, using a unique directory under `/tmp` and unique Compose project names. The older counts below are the first v1.1 run.

`tests/safety.sh` on the first v1.1 run: 56 PASS, 0 FAIL, 0 SKIPPED. Includes foreign Compose-name refusal, metadata injection left as text, sibling copy permissions, and `git archive` of `git write-tree` (the index). That archive listed only `wp-devkit/` paths, including `START_HERE.md`, `skills/wp-devkit/SKILL.md`, and `README.md`, and omitted `docs/`, `tests/`, and `AGENTS.md`. After commit `a94c546`, `git archive --format=tar HEAD` also listed only `wp-devkit/` paths.

`tests/acceptance.sh` with `WP_DEVKIT_ACCEPTANCE` unset (work directory `/tmp/wp-devkit-mvp`): 63 PASS, 0 FAIL. Greenfield root containing only `wp-devkit/` installed WordPress. Sibling baseline and candidate ran together. `hello-dolly` moved from 1.6 to 1.7.2 on the candidate only. Core download 6.8.3 then `wp core update` returned to 7.1.3 on the core copy; the baseline stayed 7.1.3. Cleanup removed only the candidate. The suite's own trap then ran `docker compose down --volumes` for the disposable projects it created.

SPEC v1.2 uploads and disk preflight, 24 October 2026: `tests/safety.sh` 87 PASS, 0 FAIL, 0 SKIPPED. `tests/acceptance.sh` 69 PASS, 0 FAIL. Include mode kept a nested upload. Exclude mode left an empty writable `wp-content/uploads/` on both siblings and recorded `uploads=exclude`. A forced free-space value of 1 byte refused the copy before creating the destination. A non-empty `WP_DEVKIT_ACCEPTANCE` directory was refused and its file was left in place. `tests/qualify-followup.sh` was updated for the new paths and was not re-run. PHP 7.4, the PHP switch, MySQL 8.4, and phpMyAdmin evidence above is from the previous layout.

Claude Code, Codex, Grok, Gemini CLI, and Antigravity were not executed against the skill. Explicit path invocation is what `START_HERE.md` documents. Native discovery was not tested.

## Not verified

- GitHub **Code → Download ZIP**. `git remote -v` is empty. Local `git archive` is not that download. AC-01 stays PENDING.
- macOS and Windows.
- `pdo_mysql` (still off unless `INSTALL_PDO_MYSQL=1`).
- Importing a MariaDB dump into MySQL, or the reverse.
- Every historical PHP version other than 7.4.33 and 8.4.27.
- Re-running `tests/qualify-followup.sh` after the directory move.
- Skill behavior in Claude Code, Codex, Grok, Gemini CLI, and Antigravity.
