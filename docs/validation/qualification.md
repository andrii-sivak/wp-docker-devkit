# Image qualification — 24 October 2026

Linux x86_64, Docker Engine 29.5, Compose v5.1. This file is development evidence. It is excluded from the GitHub ZIP by `export-ignore`.

## OQ-01 PHP 8.4 base

`wordpress:php8.4-fpm` multi-arch index `sha256:41fcfa8617e811e41516783bda46046f0945d94d547f346617bbea5e189b30bc`.

Runtime: PHP 8.4.27, Debian 13, WordPress 7.1.3 in `/usr/src/wordpress`. Extensions include `mysqli`. `pdo_mysql` is absent. The upstream entrypoint still copies core when both `index.php` and `wp-includes/version.php` are missing, including into a nonempty incomplete directory. The devkit entrypoint refuses that case before the upstream script runs. A complete core's `wp-settings.php` hash was unchanged after a second start.

## OQ-02 PHP 7.4

Index `sha256:0b4b629f3f1389cb4e42570c452188d6f1ebe74d31aee6395bbb010450a0640e`. PHP 7.4.33 starts on Debian 11. `mysqli` is present. `pdo_mysql` is absent. Composer 2.10.3 and WP-CLI 2.12.0 both start.

`apt-get install mariadb-client libfcgi-bin` failed. Debian 11 security returned HTTP 404 for `mariadb-client` 10.5.29 and `libfcgi-bin`. The Dockerfile therefore does not build on this base. PHP 7.4 remains an unresolved minimum-target requirement. The PHP 8.4 pilot does not close it.

## OQ-03 Fresh and existing sites

Greenfield: an allowlisted template directory received core from the image, then the browser installer (`install.php?step=2`) returned HTTP 200 and `wp core is-installed` succeeded. `/healthz` was already 200. `www-data` wrote `wp-content/uploads/write-test.txt`.

Complete tree: custom `wp-settings.php` hash unchanged.

Incomplete tree: entrypoint exit non-zero, `index.php` absent, custom plugin hash unchanged.

## OQ-04 Databases

MariaDB 11.8.9 is the pilot engine. One snapshot was imported into two new volumes. Changes in one database did not appear in the other or in the source.

MySQL 8.4.13 (`sha256:76f0358884cb92d9a086d24e5671c38048d3fef40f2588703d73eb55392d6b69`) reached `mysqld is alive`. The MariaDB client failed with `TLS/SSL error: self-signed certificate in certificate chain` until `--skip-ssl`. With that flag it created and read a one-row table. The image now sets `[client] skip-ssl`. A WordPress dump was not imported into MySQL, so MariaDB 11.8 and MySQL 8.4 are not a tested migration pair.

## OQ-05 Node.js and phpMyAdmin

`docker compose --profile node run --rm --entrypoint node node --version` printed `v22.23.4`. Plain `docker compose config --services` lists only `db`, `php`, and `nginx`.

phpMyAdmin 5.2.2 is pinned and was not started. The host filesystem was at about 1.2G free after the MySQL pull.

## OQ-08 Readiness

Nginx `/healthz`, PHP-FPM `/ping`, and MariaDB `healthcheck.sh --connect --innodb_initialized` became healthy before the installer finished. Compose applied PHP limits of 384m, 0.50 CPU, and 222 pids on the pilot container.

## Core update observation

`wp core update --version=6.8.3` moved a candidate from 6.8.2 to 6.8.3 and left the baseline on 7.1.3. A following `wp core update --version=latest` printed "WordPress is up to date" and `wp core version` stayed 6.8.3.
