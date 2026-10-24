# WordPress Docker devkit — agent prompt

Read `START_HERE.md`, then `skills/wp-devkit/SKILL.md`, then `README.md`. Use the same commands a person uses. Do not install Git, GNU Make, or a project-specific CLI. Do not add Compose override files. The skill file works by path; do not copy it into an agent home directory.

1. Discover the WordPress root (the parent of `wp-devkit/`), the size of that root and of `wp-content/uploads/`, and free space where the sibling copies would go. Separate observed facts from gaps. Ask only for the missing PHP, database, WordPress, port, and test details.
2. Show the file-space estimate for two copies with and without uploads. Ask whether both copies should include uploads. Then confirm the baseline sibling `<site>-baseline/` before choosing the candidate dimension and exact version. The candidate is `<site>-candidate/`. Use the same `--uploads include` or `--uploads exclude` for both. Do not overwrite an existing directory.
3. Work only inside the selected copy. The original site, the baseline, and the candidate are separate directories, Compose projects, networks, and database volumes. Do not use worktrees, symlinks, or a shared database.
4. Do not edit the source files or the source database while the snapshot and the two restores are in progress. Nothing locks the source, and later source edits do not flow into the copies.
5. Keep SQL snapshots in `<site>-snapshots/` outside every HTTP-served WordPress root.
6. Before the first start of a copy, run `wp-devkit/bin/wp-devkit-preflight.sh` and `wp-devkit/bin/wp-devkit-check-db.sh`. Refuse to continue if the Compose project belongs to another directory or `DB_HOST` is not this copy's `db` service.
7. Change one comparison dimension at a time (PHP image, WordPress core, database engine/version, or one plugin). Record any extra difference that could not be avoided.
8. Do not let a normal startup or a PHP image change replace WordPress core. Updating core is only `wp core update` (and `wp core update-db` when needed), run on the candidate.
9. Run `wp-devkit/bin/wp-devkit-smoke.sh` and any project check that is actually configured. Missing project tests are NOT CONFIGURED, never PASS.
10. Write a Markdown report with the goal, the one comparison dimension, baseline and candidate parameters, the uploads mode, the disk estimate, the snapshot path, actual versions, commands and exit codes, the five statuses (PASS, FAIL, SKIPPED, NOT CONFIGURED, ERROR), differences, limitations, and whether cleanup has been done. Excluded uploads leave attachment rows without files; record that as a testing limitation, not as a product regression. The file estimate is not a guaranteed upper bound.
11. Restore a snapshot only with `wp-devkit/bin/wp-devkit-restore.sh --target COPY SNAPSHOT.sql`. Clean up with `wp-devkit/bin/wp-devkit-cleanup.sh` on that same copy. Do not run either command against the original project. Do not run `docker system prune` or delete unrelated containers, volumes, or images.
12. Docker does not block outbound mail, webhooks, or payments. Do not claim that it does. Do not add a mandatory MU-plugin, egress firewall, `WP_HTTP_BLOCK_EXTERNAL`, or a forced cron change.

PHP 7.4 is qualified only for the combinations recorded in the README. A PHP 8.4 result does not by itself qualify another PHP version. Only database engine/version pairs that this run actually imported may be called tested.
