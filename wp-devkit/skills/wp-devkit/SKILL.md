---
name: wp-devkit
description: Prepare and compare a local WordPress site with the wp-devkit folder. Use when the user adds wp-devkit to a WordPress root, asks for a baseline and candidate, wants to compare PHP, WordPress core, the database, or a plugin, or asks for wp-devkit status. Read this file by its path when skill discovery is unavailable. A status request is only the short readiness check.
---

# wp-devkit

Use the commands in `wp-devkit/README.md`. Do not invent a CLI, Compose override, or installer. Manual use of that README is enough when no assistant is available.

Discovered facts, inferred settings, and missing data stay separate. The host `php -v` is not the site's PHP-FPM version. DevKit `.env` values do not override constants already defined in an existing `wp-config.php`.

## Status

`/wp-devkit status`, or the words "wp-devkit status", is only this check. Clients that have no slash commands use the same words. Report whether this skill is in use, whether the WordPress root (parent of `wp-devkit/`) is identifiable, whether `wp-devkit/compose.yaml`, `wp-devkit/bin/`, and `wp-devkit/README.md` exist, and whether the `docker` CLI is on `PATH` and `docker compose version` succeeds. Name one obvious blocker, such as a missing file or a missing `docker` CLI. Do not discover the site, start containers, pull or build images, create volumes or networks, or edit files.

## Discover

Read what is already on disk. Do not pull or build images, start containers, create Docker resources, start the source database, or edit files. If a check would do any of those, say so and wait for permission. After the user authorizes execution, use the README workflow.

Do not print `wp-config.php`, `.env`, Git remote URLs that embed credentials, passwords, salts, tokens, or API keys. Report whether a setting exists, whether it is a hardcoded constant or an environment lookup, and whether two sources agree. If a credential looks exposed, warn once. Do not rotate or rewrite it.

For an existing site, record without secret values:

- `DB_NAME`, `DB_USER`, `DB_PASSWORD`, and `DB_HOST`: present or absent, and hardcoded versus looked up. Any existing database name and user are valid. Each test copy must use its own database. Do not point a copy at the source database.
- `WP_HOME` and `WP_SITEURL`: constant, environment, or the `home` and `siteurl` options. Do not assume `.env` wins over a constant.
- `FS_METHOD` when filesystem work matters: whether the definition is reached before WordPress loads, and whether `wp-content`, plugins, themes, and upgrade paths are writable by the PHP user. Recommend a small correction. Do not `chown -R` or change permissions on the original. The same approved correction goes on both copies.

Also note source and uploads sizes, free space for the sibling copies, Compose project name, HTTP port, and, only if a stack is already running, `wp core version`, PHP, the database engine, and `SELECT VERSION()`. Label those as runtime-verified. Versions read from files or `.env` are configured, not verified. Baseline versions come from the project, not from DevKit example defaults. Mention real gaps such as Alpine versus Debian, missing extensions, or a service the copy will not run. Do not try to clone the whole original infrastructure.

A logical snapshot needs a reachable source database, or an existing SQL dump the user names. If the database is down, say that export is blocked, ask the user to make it reachable, and stop until they confirm. Do not start, repair, reconfigure, or replace the original database. A user-supplied dump is enough. Use WP-CLI or a dump tool already in the source environment. Do not install tools only to get WP-CLI. Do not copy raw database files.

## Clarify

Show the file-size estimate for two copies with uploads included and with uploads excluded, plus free space. Say that snapshots, database volumes, images, quotas, and caches are extra and the figure is not a guaranteed upper bound. Ask whether both copies should use `--uploads include` or `--uploads exclude`. Do not copy until the user answers. Ask only for other items that are missing or ambiguous: PHP/FPM image, database engine and version, WordPress version, extensions, memory/CPU/PID limits, Node.js, phpMyAdmin, ports, and the project's own test command. Do not start a comparison yet.

Name external side effects (mail, webhooks, payments, cron) and stop there. Do not set `DISABLE_WP_CRON`, `WP_HTTP_BLOCK_EXTERNAL`, or `WP_ENVIRONMENT_TYPE`, and do not disable plugins or jobs, unless the user explicitly allows that change on the test copies only.

## Confirm baseline

The baseline is a sibling directory, `<site>-baseline/`, with its own `wp-devkit/`, Compose project, network, and database volume. Show the source path, the baseline path, the project name, and the port. Stop if that directory exists. Do not edit the source site or its database after this confirmation until both copies are restored.

## Select the candidate

Use exactly one baseline and one candidate. Prefer one change (PHP image, WordPress release, database image, or one plugin) and its exact version. If the user wants several changes, recommend separate runs, or put the combination in that same single candidate when they say so. Do not add more candidates or a version matrix. Show what changes and what stays. Do not pick an unsupported version or start the copy until the user confirms.

## Execute

Follow README for the snapshot, copy, preflight, start, restore, and URL commands. Before the copy starts or a snapshot is restored, its effective `DB_NAME`, `DB_USER`, `DB_PASSWORD`, and `DB_HOST` must refer to that copy's own database service, including when those values are hardcoded in the copy's `wp-config.php`. Compare them without printing secrets. Pass the same `--uploads include` or `--uploads exclude` to both copies. Validate the baseline before any candidate change. If the baseline fails, stop. Do not continue, and do not treat that failure as a candidate result. The snapshot file stays in `<site>-snapshots/`, outside the source, baseline, and candidate. Restore and URL adaptation take the copy as the target. Refuse the source. Never edit the source tree or its `wp-config.php`. Database and URL edits belong only on a copy, and only after the user has authorized that step. Run `wp-devkit/bin/wp-devkit-smoke.sh` and `PROJECT_CHECK_COMMAND` when it is set. A missing project check is NOT CONFIGURED.

## Report

Write Markdown with the goal, the one dimension or the user-approved combination, both roots and their parameters, the uploads mode, the disk estimate, the snapshot path, configured versus runtime-verified versions, commands, exit codes, and only these statuses: PASS, FAIL, SKIPPED, NOT CONFIGURED, ERROR. If uploads were excluded, record missing media files as a testing limitation, not as a PHP, WordPress, or plugin regression. State cleanup only after it has run. Point at the smoke or comparison report that already exists. Do not add a migration plan, a commit, or another report.

Before either copy starts, repeat the README integration warning: Docker does not block outbound mail, webhooks, or payments. Do not claim that it does.

## Cleanup

When the user asks to remove a baseline or candidate, run `wp-devkit/bin/wp-devkit-cleanup.sh` on that copy only. That removes the copy and the Compose resources that belong to it. Leave `<site>-snapshots/` and every file in it, including SQL dumps and reports stored there, unless the user separately asks to delete those files. Do not delete images, build cache, the original site, its database, or unrelated Docker resources. There is no cleanup-all command.
