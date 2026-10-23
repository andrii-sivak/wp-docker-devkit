# Coding Agent Handoff — WordPress Docker Dev/Test MVP

Project: `wp-docker-devkit`. Date: 24 October 2026. 
**Status:** APPROVED — READY FOR IMPLEMENTATION
**Specification:** SPEC.md v1.0 
This document provides instructions to the receiving agent; requirements, acceptance criteria, and exclusions are defined in `SPEC.md`.

## First Task: Review and Validate Assumptions

Read `SPEC.md` in full. First review the contract for consistency and produce a concise map of unverified assumptions OQ-01–OQ-10 and their implementation implications. Do not start by writing Compose files or repeat discovery for settled decisions.

The current user task authorizes specification preparation and revision only. During independent review, provide findings and document refinements without implementation. Once a separate implementation task is given, the first technical action is to validate current images and their dependent assumptions in an isolated test environment before building the main solution.

Prioritize validation of the selected Debian WordPress FPM image/digest and entrypoint; prevention of incomplete Brownfield overwrites; CLI tools, extensions, and SQL clients; compatible PHP 7.4 options; readiness; and write permissions. Do not cite a network timeout as evidence of incompatibility. Do not claim runtime support based on a registry manifest or a single PHAR startup.

PHP 7.4 remains the agreed minimum target version, but runtime compatibility is unverified. Validate its runtime, tooling, and required extensions before claiming support. If qualification fails or remains blocked, document the unresolved requirement and request an explicit decision before claiming the relevant acceptance criteria, including their PHP 7.4 portions in AC-04 and AC-08, are satisfied. Do not silently raise the minimum. Development and testing of the PHP 8.4 baseline may proceed independently; success there does not qualify PHP 7.4.

MariaDB is the initial database engine for the first prototype and pilot. MySQL remains within the agreed configurable database-engine requirements; do not silently remove or defer it. Each environment runs one selected engine, not both simultaneously. Do not promise arbitrary MariaDB/MySQL version compatibility or universal migrations. Describe only verified engine/version combinations as tested or supported.

Confirmed requirements are final unless a material technical contradiction is found. If one is found, present the evidence, affected requirement, and smallest necessary adjustment. Do not silently raise the PHP minimum, bring BACKLOG features into the MVP, or turn PROPOSED/RECOMMENDED options into user decisions. Preserve ACCEPTED, RECOMMENDED, PROPOSED, UNVERIFIED, and BACKLOG distinctions from `SPEC.md`.

## Implementation Sequence After a Separate Task Is Given

| Stage | Receiving Agent's Work | Completion Evidence |
| --- | --- | --- |
| 1. Base Compose | Minimal Nginx/PHP-FPM/database, Dockerfile on the validated base, configurable versions/ports/RAM/CPU/PID limits, CLI tools, healthchecks, and HTTP hygiene. Work from the WordPress root; no test orchestration yet. Start with MariaDB; retain MySQL as an agreed configurable-engine requirement. | Reproducible Linux startup; actual versions and limits; tools available. AC-01, AC-04, AC-05. PHP 8.4 progress does not close the unresolved PHP 7.4 qualification requirement. |
| 2. Greenfield/Brownfield | Test manual installation of a new WordPress site, a complete existing-site copy, and protection of an incomplete tree before the potentially destructive entrypoint. | Installed Greenfield responds; complete Brownfield is not replaced; incomplete copy is not overwritten. AC-02, AC-03. |
| 3. Parallel instances | Complete independent file copies outside the source WordPress root; copying does not recursively include previously created test environments. One logical snapshot is restored into two separate database volumes; configure project names, ports, networks, and URLs. Keep temporary SQL snapshots outside every HTTP-served WordPress root. | Two simultaneously running instances with no shared mutable files or database volumes; changes in one affect neither the other nor the original. AC-06, AC-07. |
| 4. Upgrade workflows | Establish the baseline first; then separately test PHP, a specific/latest WordPress version, a compatible database transition, and a targeted plugin update. Preserve MySQL within the configurable-engine scope while using MariaDB for the initial prototype/pilot; one selected engine per environment. | Comparisons with actual versions and explicit migration limits. AC-08–AC-10. Only verified engine/version combinations are called tested or supported. Failed/blocked PHP 7.4 qualification requires an explicit decision before relevant acceptance claims. |
| 5. QA and prompt | Minimal smoke checks and available deterministic project checks; after specification approval, a short vendor-neutral AI prompt and example Markdown report. | Missing tests are not reported as PASS; five distinct statuses, commands, and exit codes are recorded. AC-11, AC-14. |
| 6. ZIP and README | Keep development documentation (`docs/spec/`, `docs/agents/`) and AI tooling (`AGENTS.md`, `.agents/`, `.claude/`, `skills-lock.json`) tracked in Git; exclude them and other development-only files from GitHub's standard **Code → Download ZIP** archive using `.gitattributes` `export-ignore`. Include only files required to install and use the environment, including its public README. Document extraction and copying the contents into the WordPress root, installation, configuration, lifecycle/rebuild/diagnostics/cleanup without Git or Make, the integration warning, and support limitations. Do not introduce a custom ZIP builder, release pipeline, or installer. | Inspect the actual GitHub ZIP contents and perform an independent pilot using that ZIP; a local archive check alone is insufficient. Targeted cleanup preserves original and unrelated resources. AC-01, AC-12, AC-13. |

At each stage, apply the criteria in `SPEC.md`, not just the summary table above. Pilots: clean WordPress → separate Mitgavrim copy → other local projects with different settings. A small group tests macOS/Windows later; do not present AMD64/ARM64 manifests as results of those tests.

## Fixed Invariants

- Use complete separate directories and database volumes for the original, baseline, and candidate; no shared mutable files, worktrees, or symlinks. Baseline and candidate directories must be outside the source WordPress root. Copy operations must not recursively include previously created test environments.
- Before a copy's first startup, its database configuration points to its own internal database. Identical test credentials are acceptable in separate networks.
- Independently import one consistent logical snapshot into two databases. Temporary SQL snapshots remain outside every HTTP-served WordPress root, including the source, baseline, and candidate roots. Do not transfer physical data directories between database versions.
- Normal startup and changing the PHP image do not silently update existing core. Updating WordPress is a separate, explicit action.
- Change one candidate comparison dimension at a time where practical. Report unavoidable additional differences.
- Do not perform global pruning, use fixed global container names, or mutate the original or live environment.
- Do not add mandatory interceptors, secret scanning, cron disabling, external HTTP blocking, or environment-type changes. Docker isolation does not guarantee prevention of external outbound actions.
- Do not introduce dependencies on Git, GNU Make, a specific AI product, Compose overrides, personal paths/integrations, or agent frameworks.

## Choices Still Required from the Agent

Final digests/pinning, actual CLI versions for each PHP version being qualified, a minimal fresh/existing guard, engine-specific database configuration, opt-in Node.js/phpMyAdmin behavior, external parameters, URL adaptation, snapshot location, and portable cleanup. `SPEC.md` contains proposals and selection constraints; these are not approved filenames, variable names, or a command API.

Use MariaDB first for the prototype and pilot, while preserving configurable MySQL as an agreed requirement. Engine-specific configuration and verified combinations still need validation; a simple image-tag change is not proof of interchangeability or migration compatibility. Snapshot-path and cleanup choices must obey the fixed placement and isolation invariants above.

DevOps information about server images, extensions, and UID/GID values is useful later but does not block the Linux pilot or introduce server parity into the MVP. Record actual versions and evidence for each verified combination. PHP 7.4 is still UNVERIFIED; do not close it with a promise. If qualification fails or remains blocked, retain the unresolved requirement and request an explicit decision before claiming the relevant acceptance criteria are satisfied. Continue independent PHP 8.4 baseline development/testing as appropriate.

## Expected Implementation Result

A working template distributed through GitHub's standard **Code → Download ZIP** archive, containing only installation and usage files, including the public README, documented manual workflows, a short portable AI prompt, and an example compact Markdown report, with qualified versions/platforms and explicit limitations documented. Development-only documentation and AI tooling remain tracked in Git and are excluded using `.gitattributes` `export-ignore`; users extract the ZIP and copy its contents into the WordPress root. The prompt directs the agent to ordinary Compose, WP-CLI, and project commands and the invariants in `SPEC.md`; a new complex CLI is unnecessary.

The report states the goal and selected comparison dimension, baseline/candidate parameters, initial snapshot, actual before/after versions and resolution of latest, commands/exit codes, PASS/FAIL/SKIPPED/NOT CONFIGURED/ERROR, differences, limitations, and cleanup state. Its content matters more than the runner's internal implementation.

Completion is determined by the local pilot and AC-01–AC-14 with documented limitations. Failed or blocked PHP 7.4 qualification remains an unresolved minimum-target requirement and requires an explicit decision before relevant acceptance or overall completion dependent on it can be claimed. A successful PHP 8.4/MariaDB pilot does not qualify PHP 7.4 or remove/defer configurable MySQL. Do not expand the work into company-wide rollout, CI/CD, SSH, production migrations, every historical PHP version, or a full network sandbox.
