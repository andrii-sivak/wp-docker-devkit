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

MariaDB 11.8 dumps start with `/*M!999999\- enable the sandbox mode */`. The PHP 7.4 client 10.5.23 reports `Unknown command '\-'`. Snapshot and restore now drop that line.

MySQL 8.4.13 (`sha256:76f0358884cb92d9a086d24e5671c38048d3fef40f2588703d73eb55392d6b69`) was selected with `DB_IMAGE` only. The stack became healthy, `wp core install` succeeded, and `SELECT VERSION()` contained `8.4.`. A logical snapshot restored into a second MySQL 8.4 project kept `blogdescription=mysql-marker`, and that copy's homepage returned 200. WP-CLI calls the client with `--no-defaults`, which ignored `skip-ssl` in `my.cnf` and failed against MySQL 8.4's self-signed certificate. The image now wraps `mysql`, `mariadb`, `mysqldump`, and `mariadb-dump` so `--skip-ssl` is passed on the command line, with `--no-defaults` kept first. A MariaDB dump was not imported into MySQL.

## OQ-05 Node.js and phpMyAdmin

`docker compose --profile node run --rm --entrypoint node node --version` printed `v22.23.4`. Plain `docker compose config --services` lists `db`, `php`, and `nginx`.

phpMyAdmin 5.2.2 (`sha256:95e01f723b5e55fabf16d0473f1df2354c4c6352b35902b51d6a6245e074aee4`) was started with `--profile pma` on the MySQL project. `http://127.0.0.1:18131/` returned 200 and the body contained `phpMyAdmin`. A login as the WordPress database user reached the server without a connection error.

## OQ-08 Readiness

Nginx `/healthz`, PHP-FPM `/ping`, and the database healthcheck became healthy before installation on both the PHP 8.4/MariaDB pilot and the PHP 7.4 project. Compose applied PHP limits of 384m, 0.50 CPU, and 222 PIDs on the acceptance container.

## Not verified

- GitHub **Code → Download ZIP**. `git remote -v` is empty. `git archive HEAD` omits `docs/`, `AGENTS.md`, `.agents/`, `tests/`, and `skills-lock.json`, and includes `README.md`. That is not the GitHub archive.
- macOS and Windows.
- `pdo_mysql` (still off unless `INSTALL_PDO_MYSQL=1`).
- Importing a MariaDB dump into MySQL, or the reverse.
- Every historical PHP version other than 7.4.33 and 8.4.27.
