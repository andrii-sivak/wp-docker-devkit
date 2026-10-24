# WordPress Docker devkit — agent prompt

Use the same commands a person uses. Do not install Git, GNU Make, or a project-specific CLI. Do not add Compose override files.

1. Read `README.md` in this WordPress root. It is the operating manual.
2. Work only inside the selected copy. The original site, the baseline, and the candidate are separate directories and separate database volumes. Do not use worktrees, symlinks, or a shared database.
3. Keep SQL snapshots in the work directory outside every HTTP-served WordPress root.
4. Before the first start of a copy, run `bin/wp-devkit-check-db.sh` and refuse to continue if `DB_HOST` is not this copy's `db` service.
5. Change one comparison dimension at a time (PHP image, WordPress core, database engine/version, or one plugin). Record any extra difference that could not be avoided.
6. Do not let a normal startup or a PHP image change replace WordPress core. Updating core is only `wp core update` (and `wp core update-db` when needed), run on the candidate.
7. Run `bin/wp-devkit-smoke.sh` and any project check that is actually configured. Missing project tests are NOT CONFIGURED, never PASS.
8. Write a Markdown report with the goal, the one comparison dimension, baseline and candidate parameters, the snapshot path, actual versions, commands and exit codes, the five statuses (PASS, FAIL, SKIPPED, NOT CONFIGURED, ERROR), differences, limitations, and whether cleanup has been done.
9. Clean up with `bin/wp-devkit-cleanup.sh` on the selected instance only. Do not run `docker system prune` or delete unrelated containers, volumes, or images.
10. Docker does not block outbound mail, webhooks, or payments. Do not claim that it does. Do not add a mandatory MU-plugin, egress firewall, `WP_HTTP_BLOCK_EXTERNAL`, or a forced cron change.

PHP 7.4 is an unverified minimum target until a runtime qualification says otherwise. A PHP 8.4 result does not qualify PHP 7.4. Only database engine/version pairs that this run actually imported may be called tested.
