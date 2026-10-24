# Start here

This folder is the WordPress DevKit. It lives inside the WordPress root. The manual is [README.md](README.md). You can do every step from that file without an assistant.

To use an assistant, tell it to read this file and then the skill, by path:

`wp-devkit/skills/wp-devkit/SKILL.md`

The assistant does not need the skill copied into its home directory or installed as a plugin. If it cannot discover skills on its own, the path above is enough. "wp-devkit status", or `/wp-devkit status` where that syntax exists, only checks that the skill, the WordPress root, and the DevKit files are present, that the `docker` CLI is on `PATH`, and that `docker compose version` succeeds.

Do not edit the source site while a baseline and a candidate are being prepared from one snapshot. The skill and the README use the same commands.
