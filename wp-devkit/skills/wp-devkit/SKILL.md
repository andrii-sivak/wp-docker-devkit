---
name: wp-devkit
description: Prepare and compare a local WordPress site with the wp-devkit folder. Use when the user adds wp-devkit to a WordPress root, asks for a baseline and candidate, or wants to compare PHP, WordPress core, the database, or one plugin. Read this file by its path when skill discovery is unavailable.
---

# wp-devkit

Use the commands in `wp-devkit/README.md`. Do not invent a CLI, Compose override, or installer. Manual use of that README is enough when no assistant is available.

Discovered facts, inferred settings, and missing data stay separate. The host `php -v` is not the site's PHP-FPM version.

## Discover

Inspect only what is already on disk and in Docker:

- WordPress root (parent of `wp-devkit/`) and whether it is greenfield or a complete tree
- `wp-devkit/.env`, Compose project name, HTTP port, `WP_HOME`
- running containers for this kit's project name and their `com.docker.compose.project.working_dir`
- `wp core version`, PHP, database engine, and `SELECT VERSION()` when the stack is already up

## Clarify

Ask only for items that are missing or ambiguous: PHP/FPM image, database engine and version, WordPress version, extensions, memory/CPU/PID limits, Node.js, phpMyAdmin, ports, and the project's own test command. Do not start a comparison yet.

## Confirm baseline

The baseline is a sibling directory, `<site>-baseline/`, with its own `wp-devkit/`, Compose project, network, and database volume. Show the source path, the baseline path, the project name, and the port. Stop if that directory exists. Do not edit the source site or its database after this confirmation until both copies are restored.

## Select the candidate

Ask for one dimension and the exact target version: PHP image, WordPress release, database image, or one plugin. Show what changes and what stays. The candidate is the sibling `<site>-candidate/`. Do not pick an unsupported version or start the copy until the user confirms.

## Execute

Follow README for the snapshot, copy, preflight, start, restore, and URL commands. The snapshot file stays in `<site>-snapshots/`, outside the source, baseline, and candidate. Restore and URL adaptation take the copy as the target. Refuse the source. Run `wp-devkit/bin/wp-devkit-smoke.sh` and `PROJECT_CHECK_COMMAND` when it is set. A missing project check is NOT CONFIGURED.

## Report

Write Markdown with the goal, the one dimension, both roots and their parameters, the snapshot path, versions, commands, exit codes, and only these statuses: PASS, FAIL, SKIPPED, NOT CONFIGURED, ERROR. State cleanup only after it has run.

Before either copy starts, repeat the README integration warning: Docker does not block outbound mail, webhooks, or payments. Do not claim that it does.
