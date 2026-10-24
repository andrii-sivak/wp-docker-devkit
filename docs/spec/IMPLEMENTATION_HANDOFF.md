# Coding Agent Handoff — WordPress Docker Dev/Test MVP

Project: `wp-docker-devkit`. Date: 24 October 2026. 
**Status:** APPROVED — READY FOR IMPLEMENTATION
**Specification:** SPEC.md v1.1 
This document provides instructions to the receiving agent; requirements, acceptance criteria, and exclusions are defined in `SPEC.md`.

## First Task: Review and Validate Assumptions

Read `SPEC.md` in full. Do not repeat discovery for settled decisions. Image checks belong in an isolated environment. Do not treat a registry manifest or a single PHAR startup as runtime qualification.

Implementation of the revised specification is authorized by a separate task. **An MVP codebase already exists**: modify and regression-test it; do not start over. Qualification evidence lives in `docs/validation/qualification.md`. Do not claim a combination that file leaves unverified, including untested MariaDB/MySQL dump transitions and the actual GitHub Download ZIP while there is no GitHub remote.

Prioritize validation of the selected Debian WordPress FPM image/digest and entrypoint; prevention of incomplete Brownfield overwrites; CLI tools, extensions, and SQL clients; compatible PHP 7.4 options; readiness; and write permissions. Do not cite a network timeout as evidence of incompatibility. Do not claim runtime support based on a registry manifest or a single PHAR startup.

PHP 7.4 remains the agreed minimum target version. Do not silently raise the minimum. Record runtime, tooling, and extensions in `docs/validation/qualification.md` before calling a combination supported. A PHP 8.4 result does not by itself qualify PHP 7.4.

MariaDB is the initial database engine for the first prototype and pilot. MySQL remains within the agreed configurable database-engine requirements; do not silently remove or defer it. Each environment runs one selected engine, not both simultaneously. Do not promise arbitrary MariaDB/MySQL version compatibility or universal migrations. Describe only verified engine/version combinations as tested or supported.

Confirmed requirements are final unless a material technical contradiction is found. If one is found, present the evidence, affected requirement, and smallest necessary adjustment. Do not silently raise the PHP minimum, bring BACKLOG features into the MVP, or turn PROPOSED/RECOMMENDED options into user decisions. Preserve ACCEPTED, RECOMMENDED, PROPOSED, UNVERIFIED, and BACKLOG distinctions from `SPEC.md`.

## Approved v1.1 Change Scope

- **One-folder distribution:** move user-facing runtime files into repository `wp-devkit/` (Compose, Dockerfile/build files, configuration, `bin/`, examples, prompt, public README, and bundled skill). Keep `docs/`, development `AGENTS.md`, `.agents/`, `.claude/`, and `skills-lock.json` in Git outside that folder. GitHub's standard ZIP must ultimately contain only `wp-devkit/` inside its generated wrapper; use `.gitattributes` `export-ignore`, not a custom packager. Change relative mounts and every script's Compose `--project-directory` so Compose inside `wp-devkit/` serves its parent WordPress root while building only DevKit files. Do not overwrite existing project-root Compose, Dockerfile, `.env`, README, or scripts.
- **Sibling test roots:** default to source `project-x/` alongside `project-x-baseline/` and `project-x-candidate/`; copies include their own `wp-devkit/`, DB volumes, and isolated Compose projects. Reject existing destinations or name collisions. No default `instances/` nesting. SQL snapshots still stay outside all served roots. Prompt the developer not to edit the source during preparation/comparison; no locking or live synchronization.
- **Portable AI workflow:** ship `wp-devkit/START_HERE.md` and `wp-devkit/skills/wp-devkit/SKILL.md` with YAML frontmatter. Skill workflow: discover observable runtime/site settings → ask only for missing information → confirm baseline → ask for candidate dimension and exact target version → confirm → execute → report. Give priority to Claude Code, Codex, and Grok, then Gemini CLI and Antigravity. Explicit file-path invocation must work without native skill auto-discovery or agent-specific installation. README remains independently usable without AI.
- **Unclosed safety review:** remove executable `source`/`eval` of `.wp-devkit-meta` in URL adaptation; ensure README URL-adaptation examples target a copy; detect Compose-name collisions and verify resource ownership before cleanup; replace default mode `1777` on copy roots with appropriately scoped permissions; cover sensitive files even within `/.well-known/` without breaking legitimate challenges. Add focused negative regression tests and preserve prior 38 safety and 61 acceptance test behavior.
- **Pending, not waived:** verify the actual GitHub ZIP **after** publication; do not block local implementation on the missing GitHub remote or claim AC-01 fully PASS. Other unverified engine migrations and platforms remain explicitly unverified, not invented outcomes.

## Implementation Sequence After a Separate Task Is Given

| Stage | Receiving Agent's Work | Completion Evidence |
| --- | --- | --- |
| 1. Base Compose | Relocate the existing Nginx/PHP-FPM/database Compose and Docker build files under `wp-devkit/`, run Compose there, bind-mount the parent WordPress root, and retain configured versions/ports/limits, CLI tools, healthchecks, and HTTP hygiene. Do not rebuild unrelated functionality from scratch. | Reproducible Linux startup and Greenfield/Brownfield compatibility from the nested folder; existing project-root files intact. AC-01, AC-04, AC-05. |
| 2. Greenfield/Brownfield | Adapt and retest the existing guard: a new root containing only `wp-devkit/` is Greenfield, an existing complete site is preserved, and an ambiguous/incomplete tree is refused before upstream entrypoint writes. | The nested-kit Greenfield installs; complete Brownfield is not replaced; incomplete copy is not overwritten. AC-02, AC-03. |
| 3. Parallel instances | Adapt existing scripts to create `project-x-baseline/` and `project-x-candidate/` as siblings of `project-x/`; include their `wp-devkit/` folders, guard existing destinations and Compose-name collisions, and retain isolated project names, ports, networks, DB volumes and URL adaptation. Restore one snapshot into both while keeping it outside all served roots. | Both siblings work simultaneously and remain independent of each other and the source; wrong targets and duplicate Compose names are safely refused. AC-06, AC-07, AC-12. |
| 4. Upgrade workflows | Establish the baseline first; then separately test PHP, a specific/latest WordPress version, a compatible database transition, and a targeted plugin update. Preserve MySQL within the configurable-engine scope while using MariaDB for the initial prototype/pilot; one selected engine per environment. | Comparisons with actual versions and explicit migration limits. AC-08–AC-10. Only verified engine/version combinations are called tested or supported. Failed/blocked PHP 7.4 qualification requires an explicit decision before relevant acceptance claims. |
| 5. QA and skill | Preserve smoke/deterministic checks, report statuses, and example Markdown report. Adapt the existing portable prompt; add short `START_HERE.md` and `skills/wp-devkit/SKILL.md` guiding staged evidence-based discovery and confirmation. Check explicit usage on Claude Code, Codex, and Grok first and record any unavailable platforms. | Manual README workflow remains sufficient; missing checks are not PASS, five statuses are preserved, and agent compatibility claims match actual verification. AC-11, AC-14. |
| 6. ZIP and README | Update `.gitattributes` so `git archive` retains only the installable `wp-devkit/` folder (with its public README/skill) inside the normal archive wrapper; exclude root development docs and tooling. Update the manual README for one-folder placement, sibling copies, correct restore/URL commands, source no-edit guidance, safe cleanup and integration/exposure warnings. Do not introduce a ZIP builder, release pipeline, or installer. | Locally inspect archive contents and demonstrate manual installation. **Actual GitHub Download ZIP inspection is deferred until the repo is published** and does not count as PASS now. AC-01, AC-12, AC-13. |

At each stage, apply the criteria in `SPEC.md`, not just the summary table above. Pilots: clean WordPress → separate Mitgavrim copy → other local projects with different settings. A small group tests macOS/Windows later; do not present AMD64/ARM64 manifests as results of those tests.

## Fixed Invariants

- Use `wp-devkit/` within the actual WordPress root and complete sibling directories (`project-x-baseline/`, `project-x-candidate/`) for test copies, each with its own DevKit, Compose project, network, and DB volume. No shared mutable files, worktrees, or symlinks. Copy operations must not recursively include prior tests or overwrite existing destinations.
- Before a copy's first startup, its database configuration points to its own internal database. Identical test credentials are acceptable in separate networks.
- Independently import one consistent logical snapshot into two databases. Temporary SQL snapshots remain outside every HTTP-served WordPress root, including the source, baseline, and candidate roots. Do not transfer physical data directories between database versions.
- Normal startup and changing the PHP image do not silently update existing core. Updating WordPress is a separate, explicit action.
- Change one candidate comparison dimension at a time where practical. Report unavoidable additional differences.
- Do not perform global pruning, use fixed global container names, or mutate the original or live environment. Before cleanup, validate actual Compose resource ownership rather than trusting a matching name in editable files. Reject target identity/name conflicts.
- Do not add mandatory interceptors, secret scanning, cron disabling, external HTTP blocking, or environment-type changes. Docker isolation does not guarantee prevention of external outbound actions.
- Do not introduce dependencies on Git, GNU Make, a specific AI product, Compose overrides, personal paths/integrations, or agent frameworks. README procedures must work without the distributed Agent Skill; no mandatory agent registration. Do not lock, synchronize, or automatically coordinate changes to the original.

## Choices Still Required from the Agent

The existing code already implements image/tooling qualification, fresh/existing handling, database selection, optional Node.js/phpMyAdmin, parameters, snapshots, and cleanup. Preserve verified behavior; resolve only the integration details required by the new layout, sibling paths, and review follow-ups. `SPEC.md` contains acceptance constraints; avoid replacing tested commands with a new manager or changing unrelated public interfaces without need.

Use MariaDB first for the prototype and pilot, while preserving configurable MySQL as an agreed requirement. Engine-specific configuration and verified combinations still need validation; a simple image-tag change is not proof of interchangeability or migration compatibility. Snapshot-path and cleanup choices must obey the fixed placement and isolation invariants above.

DevOps information about server images, extensions, and UID/GID values is useful later but does not introduce server parity into the MVP. The 24 October Linux qualification records one working PHP 7.4.33 combination; do not extend that claim to untested platforms, versions, or projects. Record actual versions and evidence for each new verified combination and limitations for failed or blocked cases. Continue PHP 8.4 testing independently as appropriate.

## Expected Implementation Result

A working toolkit kept in one `wp-devkit/` folder, distributed using GitHub's standard **Code → Download ZIP** archive. This folder includes all runtime files, the standalone public README, portable `START_HERE.md` and `skills/wp-devkit/SKILL.md`, the adapted AI prompt, and an example compact Markdown report. Root development documentation and AI tooling remain tracked in Git but are excluded using `.gitattributes` `export-ignore`. Users copy **only the folder** into the actual WordPress root; baseline and candidate appear as independent sibling WordPress roots. The skill directs agents to the same Compose, WP-CLI, and project commands available to manual users, without a complex new CLI. Real GitHub ZIP acceptance remains pending publication.

The report states the goal and selected comparison dimension, baseline/candidate parameters, initial snapshot, actual before/after versions and resolution of latest, commands/exit codes, PASS/FAIL/SKIPPED/NOT CONFIGURED/ERROR, differences, limitations, and cleanup state. Its content matters more than the runner's internal implementation.

Completion is determined by the local pilot and AC-01–AC-14 with documented limitations. Failed or blocked PHP 7.4 qualification remains an unresolved minimum-target requirement and requires an explicit decision before relevant acceptance or overall completion dependent on it can be claimed. A successful PHP 8.4/MariaDB pilot does not qualify PHP 7.4 or remove/defer configurable MySQL. Do not expand the work into company-wide rollout, CI/CD, SSH, production migrations, every historical PHP version, or a full network sandbox.
