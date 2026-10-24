# Comparison report

Example from the Linux pilot on 24 October 2026. It is a record of that run, not a promise that the next run will match these versions.

- Goal: install a new site, then compare a plugin update and a WordPress core update on separate candidates.
- Initial snapshot: `../wp-devkit-work/snapshots/initial.sql`, outside the HTTP roots.
- Baseline: project `wpdevkitbase`, `http://127.0.0.1:18082`, same snapshot in its own database volume.
- Plugin candidate: project `wpdevkitcand`, `http://127.0.0.1:18083`.
- Core candidate: project `wpdevkitcore`, `http://127.0.0.1:18084`.
- PHP image: `wordpress:php8.4-fpm` index `sha256:41fcfa8617e811e41516783bda46046f0945d94d547f346617bbea5e189b30bc` (PHP 8.4.27).
- Database: MariaDB 11.8.9 (`mariadb:11.8` index `sha256:f16d7a344413e519dff518f27bdb221388f84b0d274c97c4fb5f2cb0dc1b34fa`).

## Plugin dimension

Only `hello-dolly` was updated on `wpdevkitcand`. Core stayed 7.1.3 on both sides.

| Item | Baseline | Candidate |
| --- | --- | --- |
| hello-dolly | 1.6 | 1.7.2 |
| WordPress | 7.1.3 | 7.1.3 |

| Command | Exit | Status | Detail |
| --- | --- | --- | --- |
| `wp plugin install hello-dolly --version=1.6 --force` on the source, before the snapshot | 0 | PASS | Installed the older release |
| `wp plugin update hello-dolly` on the candidate | 0 | PASS | Updated only that plugin |
| Baseline `wp plugin get hello-dolly --field=version` after the candidate update | 0 | PASS | Still 1.6 |

## Core dimension

`wpdevkitcore` was restored from the same snapshot, then updated on its own. The baseline stayed on the image core.

| Command | Exit | Status | Detail |
| --- | --- | --- | --- |
| `wp core version` before the change | 0 | PASS | 7.1.3 on the candidate and the baseline |
| `wp core download --version=6.8.3 --force` | 0 | PASS | Candidate files moved to 6.8.3 |
| `wp core update` | 0 | PASS | Resolved to 7.1.3. Baseline stayed 7.1.3. `wp core update --version=latest` is not a version and does not do this |
| `wp core update-db` | 0 | PASS | Ran after the update |

## Smoke

`bin/wp-devkit-smoke.sh` on the installed source exited 0.

| Check | Status | Detail |
| --- | --- | --- |
| `/healthz`, homepage, `/wp-login.php` | PASS | HTTP 200 |
| `PROJECT_CHECK_COMMAND` | NOT CONFIGURED | The variable was unset. This is not a passing test suite |
| External integrations | SKIPPED | The template does not intercept SMTP, webhooks, or payments |

Smoke checks do not prove that every feature works.

## Limits

- PHP 7.4.33 ran a WordPress site. Its SQL client is MariaDB 10.5.23 from Debian 11 main, because the security-archive packages 404.
- MySQL 8.4.13 installed WordPress and restored that snapshot into a second MySQL volume. A MariaDB dump was not imported into MySQL.
- phpMyAdmin 5.2.2 started and logged in.
- macOS and Windows were not run.
- Cleanup removed only `wpdevkitcand` and its database volume. The source still answered HTTP. `docker system prune` was not used.

## Cleanup

- Plugin candidate: removed with `bin/wp-devkit-cleanup.sh`.
- Baseline, core candidate, and source: removed at the end of the pilot.
- Global image cache: not pruned.
