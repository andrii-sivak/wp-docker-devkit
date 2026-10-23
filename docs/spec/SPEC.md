# WordPress Docker Dev/Test MVP

Project: `wp-docker-devkit`. Date: 24 October 2026. 
**Status:** APPROVED FOR IMPLEMENTATION
**Approved on:** 2026-10-24
**Version:** 1.0
Requirements language: English.

The requirements and MVP scope are approved.
Technical assumptions marked UNVERIFIED remain subject to validation
during implementation. Any material scope changes require explicit approval.

This document is self-contained; no chat history is required to understand the requirements. It was prepared using the installed `to-spec` skill. The companion document, `IMPLEMENTATION_HANDOFF.md`, defines the receiving agent's workflow; this specification defines the requirements.

Statuses: **ACCEPTED** — an agreed requirement or decision; **RECOMMENDED** — a recommendation, not a commitment; **PROPOSED** — an option proposed but not yet approved; **UNVERIFIED** — a technical assumption or unverified compatibility; **BACKLOG** — excluded from the MVP and deferred. A requirement's presence does not mean it has been implemented or verified.

## Problem Statement

Team developers need a simple local WordPress Docker template that can be downloaded as a ZIP and placed in the root of a new or existing WordPress installation. It must work independently of Git, repository structure, GNU Make, and the AI product being used.

When evaluating PHP, WordPress, database, or plugin upgrades, developers need parallel baseline and candidate environments: separate copies of the same site with identical initial test data. Testing must not modify the original local site or mix the instances' code and databases. Results must identify actual differences and the limits of the checks performed.

This is a local development and testing tool for gradual team adoption. It does not standardize server infrastructure or require every developer to move to Docker immediately.

## Solution

### User Workflow [ACCEPTED]

1. Download the template using GitHub's standard **Code → Download ZIP** action, extract the archive, and copy its contents into the WordPress root. For a new site, the directory may initially be empty; for an existing site, it contains the complete WordPress tree.
2. Configure versions, local ports, and resources. Confirm that the copy connects to its own database, and prepare the project's integrations for a test run.
3. Start Nginx, PHP-FPM, and the selected MariaDB/MySQL database engine using ordinary Docker Compose commands. MariaDB is the initial engine for the first prototype and pilot; MySQL remains an agreed configurable-engine requirement. Each environment runs one selected database engine, not both simultaneously. Composer, WP-CLI, PHP CLI, and a SQL client are available; Node.js and phpMyAdmin are optional.
4. For Greenfield, install WordPress manually or use optional automation. Normal Brownfield startup does not replace core, plugins, or custom code.
5. For comparison, create two complete, independent WordPress copies outside the source WordPress root and one consistent logical snapshot of permitted test data. Copying must not recursively include previously created test environments. Keep temporary SQL snapshots outside every HTTP-served WordPress root. Restore the snapshot into two separate databases, and assign different Compose project names and HTTP ports.
6. Validate the baseline, change the selected comparison dimension in the candidate, and run available checks. Produce a compact Markdown report, then explicitly clean up only the selected temporary resources.

A person can perform every step without AI. An agent uses the same ordinary commands. A custom environment manager or complex CLI is not required.

### Future Implementation Deliverables [ACCEPTED]

A standard GitHub **Code → Download ZIP** distribution containing only files required to install and use the Docker environment: the base Compose template and a Dockerfile built on the selected WordPress FPM base, Nginx/PHP configuration, the public README covering configuration and lifecycle, user-facing comparison workflows, a short portable AI prompt, and an example Markdown report. Development-only documentation and AI tooling remain in Git and are excluded from this archive as specified below. Implementation filenames and layout remain unspecified except for the agreed distribution paths below.

The AI prompt itself will be written during implementation, after specification approval. This package records only its purpose, invariants, and reporting contract.

## User Stories

1. As a developer, I want to run the template from a ZIP without Git or GNU Make, so that I can use it with projects regardless of how their source code is organized.
2. As a developer starting a new site, I want to install WordPress manually, so that automated bootstrap is not a prerequisite.
3. As a developer maintaining an existing site, I want to use its complete WordPress tree and change the PHP runtime without silently replacing site files.
4. As a developer, I want to select PHP and database versions, local ports, and resource limits, so that I can adapt the environment to the project and machine.
5. As a developer, I want access to PHP CLI, Composer, WP-CLI, and a SQL client, with Node.js and phpMyAdmin available when needed.
6. As a developer, I want to run baseline and candidate environments simultaneously with independent code, networks, and databases, so that I can compare versions without modifying the original site.
7. As a developer, I want to change one selected comparison dimension and see actual versions and before/after results, so that I can assess the effects of an upgrade.
8. As a developer or agent operator, I want to distinguish a product failure, a check execution error, and missing tests, so that I do not receive a false success result.
9. As a developer, I want cleanup to target a specific test instance, so that the original site and unrelated Docker resources remain intact.
10. As a team member, I want clear platform and integration limitations, so that I know what has been verified and what remains my project's responsibility.

## Implementation Decisions

### 1. Distribution and Placement [ACCEPTED]

- The template is developed in a separate Git repository; users download GitHub's standard **Code → Download ZIP** archive, extract it, and copy its contents into the WordPress root. Cloning the repository is not required.
- Keep development documentation (`docs/spec/`, `docs/agents/`) and AI tooling (`AGENTS.md`, `.agents/`, `.claude/`, `skills-lock.json`) tracked in Git. Use `.gitattributes` with `export-ignore` to exclude these and other development-only files from the standard GitHub ZIP.
- The downloaded ZIP contains only files required to install and use the Docker environment, including its public README. Verify the actual GitHub ZIP contents for acceptance; local archive inspection alone does not satisfy that requirement. Do not introduce a custom ZIP builder, release pipeline, or installer.
- Shared Docker files reside directly in the WordPress root. A mandatory parent directory containing an `html/` subdirectory is not introduced.
- Do not impose a monorepository. A project's Git repository may contain only a theme, several plugins, the whole WordPress installation, or nothing at all.
- Every necessary operation — configuration, startup, rebuild, diagnostics, checks, shutdown, and cleanup — is documented using ordinary Compose commands or portable commands/scripts without requiring GNU Make.
- Shared files contain no personal absolute paths, names of personal integrations, or mandatory external networks. Individual settings are provided without editing shared files; the specific configuration mechanism remains to be selected. Compose overrides are not part of the standard MVP.

### 2. Services, Versions, and Tools [ACCEPTED]

| Area | Contract |
| --- | --- |
| HTTP/PHP/database | Nginx + PHP-FPM + one selected MariaDB/MySQL engine per environment; versions are configurable per project. MariaDB is used for the first prototype and pilot. MySQL remains within the agreed configurable database-engine requirements and is not removed or deferred by that implementation sequence. |
| Initial PHP base | The official Debian `wordpress:php8.4-fpm` image is the agreed starting candidate for the prototype, not a fully qualified image. |
| Minimum PHP target | PHP 7.4 remains the agreed minimum target version. Runtime compatibility has not yet been verified. Do not claim support until runtime, tooling, and required extensions have been validated. |
| CLI | PHP CLI, Composer, WP-CLI, and an ordinary mysql/mariadb client are available. |
| Additional tools | Node.js is available for projects with a frontend workflow; phpMyAdmin is optional. Neither is required to start a site. |
| Reporting | PHP, database, Composer, and WP-CLI versions are clear and overridable; actual versions are recorded, not only configured tags. |

The PHP 8.4 / MariaDB 11.8 and Composer 2.9.5 / WP-CLI 2.12.0 versions in the Mitgavrim example do not become mandatory team versions. Specific Nginx, Node.js, and phpMyAdmin versions have not been agreed.

Development and testing of the PHP 8.4 baseline may proceed independently of PHP 7.4 qualification. If PHP 7.4 qualification fails or remains blocked, record the unresolved requirement and request an explicit decision before claiming that the relevant acceptance criteria are satisfied. Do not silently raise the minimum PHP version or treat a successful PHP 8.4 pilot as evidence of PHP 7.4 support.

**RECOMMENDED:** pin images by multiarch index digest and document how pins are updated. Exact digests and the final pinning policy remain subject to validation; do not insert unverified values. Mutable tags and `latest` must be resolved to the actual versions obtained; record the identity of the image/digest used when available.

**RECOMMENDED / UNVERIFIED:** provide PHP 7.4 as a separate opt-in legacy option after validating compatible FPM, Composer, WP-CLI, and required extensions. Historical image availability does not imply current security maintenance.

### 3. Files and Bootstrap [ACCEPTED]

- Bind-mount the complete site tree into the PHP container. Nginx reads the same tree; read-only access for Nginx is the recommended default.
- PHP must be able to write to uploads/cache and any other directories required by the project with appropriate permissions. Exact UID/GID values and writable directories are validated during the pilot.
- Brownfield uses existing files. Normal startup and changing the PHP image must not automatically update or replace WordPress core, plugins, themes, or custom code.
- Explicitly distinguish fresh and existing site states before the first startup. An incomplete or ambiguous Brownfield copy must not enter potentially destructive automatic preparation; diagnose it before writing to the site.
- Greenfield permits manual installation. Automatic core retrieval and WP-CLI bootstrap are optional additional paths. Pinning a WordPress version in configuration is not a mandatory prerequisite for the first startup.
- Create complete, separate baseline and candidate directory copies, including the themes, plugins, uploads, and configuration actually needed. Both directories must be outside the source WordPress root. The copy operation must not recursively include previously created test environments. Do not introduce shared mutable files or directories, Git worktrees, or symlinks as the basis of the workflow.

**Known risk:** according to the 23 October 2026 audit, the official entrypoint may copy core into a nonempty directory when both `index.php` and `wp-includes/version.php` are absent. Checking only that a directory is nonempty is insufficient. The presence of those two files also does not prove that the entire WordPress tree is complete. The specific fresh/existing validation mechanism remains to be validated.

### 4. Isolation, Networking, and Resources [ACCEPTED]

- Multiple instances run from different directories with different Compose project names, for example using `docker compose -p ...`. Fixed global `container_name` values are prohibited.
- Each project has its own network and database volume. The original site, baseline, and candidate must not share a database volume or mutable code.
- Separate projects may use identical internal DNS names and test database credentials, such as `db:3306` and `wordpress`/`wordpress`. What matters is that each copy actually connects to its own database.
- Before a copy's first startup, check the database connection settings in its `wp-config.php` and effective configuration: they must not reference the original or a remote database. Changing environment variables alone does not guarantee that an existing `wp-config.php` has been reconfigured.
- HTTP ports are predictably configurable and bind to `127.0.0.1` by default; parallel projects receive different ports. If a database UI is enabled, its port is also configurable. Do not publish the database port without a need.
- RAM, CPU, and PID limits are configurable. Verify that Compose actually applies the configured limits on the pilot platform.
- Healthchecks verify readiness of the main services. Nginx/PHP/database readiness is distinct from a completed WordPress installation: the Greenfield setup wizard may not yet have been completed.
- Shutdown and deletion of temporary resources target a specific project. Do not delete original or unrelated containers, volumes, images, or the global Docker cache. `docker system prune` is not part of cleanup.

### 5. Data, URLs, and Upgrades [ACCEPTED]

The original local site remains unchanged. Exporting a permitted test snapshot is a separate operation: copying files does not copy a database. Create one consistent logical snapshot and restore it independently into baseline and candidate. Do not share a database or transfer a physical data directory between different database versions.

**RECOMMENDED:** use `wp db export` / `wp db import`. Before use, validate the WordPress configuration, database connectivity, and required SQL binaries; availability of a WP-CLI command does not prove that its external dependencies are available. Temporary SQL snapshots must remain outside every HTTP-served WordPress root, including the source, baseline, and candidate roots. The exact location and portable commands remain to be selected within that constraint.

Assign correct test URLs to the copies. `WP_HOME`/`WP_SITEURL` or WordPress-aware `wp search-replace`, which accounts for serialized data, are acceptable. URL constants alone do not guarantee correction of all stored absolute links. Apply `wp config set` only when configuration values actually need changing. Choose and document the exact method for the project.

Confirm baseline functionality before modifying the candidate. Change exactly one comparison dimension where practical; report unavoidable additional changes.

| Dimension | Expected Change Method | Condition for a Valid Comparison |
| --- | --- | --- |
| PHP | Change the candidate's FPM image version. | Existing core is not replaced with image contents; actual PHP patch version and image identity are recorded. |
| WordPress | Run `wp core update` with a specific version or latest; run `wp core update-db` when needed. | Core changes are explicit; latest is resolved to an actual version number. |
| Database | Use a separate clean instance of the selected engine/version and a logical import. | Dump compatibility with the selected transition is verified; no shared data directory is used. |
| Plugin | Perform a targeted update of the selected plugin. | Record the plugin and actual versions; do not update all plugins unnecessarily. |

Arbitrary database upgrade/downgrade compatibility and universal migrations between MariaDB/MySQL versions or engines are not promised. Only verified engine/version combinations may be described as tested or supported. Different image platforms or native libraries may introduce additional differences; do not attribute those differences solely to a PHP minor version change.

### 6. Basic HTTP Hygiene and Integrations [ACCEPTED]

Nginx must not serve operational files from the webroot: `.env`, `.git`, SQL dumps, configuration files, and Docker files. PHP execution in upload directories is prohibited. The implementation must preserve normal site static-file and PHP functionality.

Before starting a copy, the project developer is responsible for SMTP, SMS, webhooks, payment/CRM/API integrations, and background jobs: use test credentials, disable them, or provide project-specific stubs. Use test or appropriately anonymized data where applicable. This is not automatic production database migration or mandatory agent-based secret analysis.

The future README must communicate the following warning:

> Before starting a copy, review SMTP, SMS, webhook, payment/CRM/API integrations, and background jobs. Running Docker locally does not block outbound traffic. Use test credentials/stubs and data suitable for testing. The template isolates containers and local databases but does not guarantee prevention of external side effects.

The template does not enforce `WP_ENVIRONMENT_TYPE=local`, `DISABLE_WP_CRON=true`, or `WP_HTTP_BLOCK_EXTERNAL=true`; it does not add a mandatory email-interception MU-plugin, egress firewall, or internal-only network. Such changes could distort the behavior under test and interfere with updates, Composer, or npm.

Do not disable cron globally. If cron is part of the functionality, test the project's corresponding mechanism, including its existing system cron schedule when used. Automatic cron reconfiguration is outside the MVP.

## Testing Decisions

### Testing Boundaries

The behavior and scenarios below are **ACCEPTED**. Grouping them into three testing seams is **PROPOSED** for review; that grouping has not been separately approved. It introduces no new services, frameworks, or test runner.

| Seam [PROPOSED] | Observable Boundary | Behavior Covered [ACCEPTED] |
| --- | --- | --- |
| User environment | Ordinary Compose/CLI commands and HTTP responses. | ZIP startup, manual installation, tools, health/readiness, resource configuration, and HTTP hygiene. |
| Independent lifecycle | File trees, database contents, and Docker resources before/after startup, modification, and cleanup. | Two projects, data independence, original-site preservation, no silent overwrites, and targeted cleanup. |
| Upgrade comparison | Externally observable baseline/candidate behavior and a Markdown report of command results. | Changing the selected dimension, smoke/project tests, actual versions, accurate statuses, and limitations. |

### Check Sequence [ACCEPTED]

Verify infrastructure readiness and baseline functionality before modifying the candidate. Then run applicable deterministic project checks and HTTP smoke checks of the homepage, administration area, and required routes; run integration/functional tests where available. Do not assume every site has PHPCS, PHPUnit, a Node build, or a particular test structure.

If a project uses Make targets, document direct invocation of the corresponding tools: GNU Make does not become a template dependency. Smoke checks do not prove that every feature or external integration works. Do not add load tests or QA tiers.

### Statuses and Reporting Contract [ACCEPTED]

Each check receives a distinct status; missing tests do not count as success.

| Status | Meaning in the Report |
| --- | --- |
| PASS | The check was actually executed and its criterion was met. |
| FAIL | An executed check detected a violation of the behavior being tested. |
| SKIPPED | The check was explicitly skipped; a reason is provided. |
| NOT CONFIGURED | The required project test suite or check command is not configured. |
| ERROR | Execution failed or a reliable result could not be obtained; a reason is provided. |

In compatibility reporting, separately mark untested versions/platforms as UNVERIFIED or NOT TESTED; this is not PASS or a sixth mandatory runner status.

The compact Markdown report contains:

- the goal, initial conditions, and selected comparison dimension;
- baseline/candidate identification, launch parameters, and information about the common initial snapshot;
- actual before/after versions, resolution of latest, and available image identities;
- relevant commands, exit codes, and check results, including reasons for skips/errors;
- baseline/candidate differences, issues, limitations, and everything not tested;
- information about targeted cleanup already performed or still outstanding.

This defines report content, not a new machine API format or report manager.

### Acceptance Criteria [ACCEPTED TARGETS — Not Results]

| ID | Criterion and Observable Evidence |
| --- | --- |
| AC-01 | Download the actual archive through GitHub's standard **Code → Download ZIP** action and inspect its contents: it contains only files required to install and use the Docker environment, including the public README; development-only documentation (`docs/spec/`, `docs/agents/`) and AI tooling (`AGENTS.md`, `.agents/`, `.claude/`, `skills-lock.json`) are absent while remaining tracked in Git, with exclusion controlled by `.gitattributes` `export-ignore`. Extract the ZIP and copy its contents into the WordPress root; documented startup and lifecycle operations work without Git, GNU Make, or AI. |
| AC-02 | A clean Greenfield installation completes manual setup and HTTP smoke checks; infrastructure readiness before installation does not require completion of the wizard. |
| AC-03 | A complete Brownfield copy preserves core/plugins/custom code during normal startup and PHP image changes. An incomplete copy is diagnosed before potentially destructive automatic writes. |
| AC-04 | PHP/database versions, local ports, and RAM/CPU/PID limits are configurable and actually applied. PHP CLI, Composer, WP-CLI, and the SQL client work for the combination under test. PHP 7.4 remains the agreed minimum target; its runtime, tooling, and required extensions must be validated before support is claimed. If qualification fails or remains blocked, document the unresolved requirement and request an explicit decision before claiming the PHP 7.4 portion of this criterion is satisfied; PHP 8.4 baseline development/testing may proceed independently. |
| AC-05 | Nginx/PHP/database have meaningful readiness checks; WordPress responds after installation. Operational files are not served, and PHP in uploads is not executed. |
| AC-06 | Two projects run simultaneously from separate complete directories outside the source WordPress root, with distinct project names/ports, networks, and database volumes. Copying does not recursively include previously created test environments. No mutable files or database volumes are shared; changes in one do not change the other or the original. |
| AC-07 | Both databases are independently restored from one consistent logical snapshot; configurations point to their own databases and test URLs are correct. Temporary SQL snapshots remain outside every HTTP-served WordPress root. |
| AC-08 | A PHP upgrade is tested and existing core is preserved. WordPress updates to a specific version and latest are tested, with update-db where needed; actual versions are recorded. Results for a verified PHP combination do not establish PHP 7.4 support. If PHP 7.4 qualification fails or remains blocked, record the unresolved requirement and request an explicit decision before claiming this criterion is satisfied for PHP 7.4. |
| AC-09 | A logical transfer into a new database instance is performed for an actually selected compatible transition, with transfer limitations documented. MariaDB is the initial prototype/pilot engine; MySQL remains an agreed configurable-engine requirement and must not be silently removed or deferred. Each environment uses one engine. Only verified engine/version combinations are described as tested or supported; arbitrary cross-engine/version compatibility and universal migrations are not claimed. |
| AC-10 | A targeted plugin update is demonstrated with an observable comparison. This is an agreed workflow; its absence as a separate checkbox in the original Definition of Done does not exclude it from the MVP. |
| AC-11 | Available project checks can be invoked; a missing suite is reported as NOT CONFIGURED. The report distinguishes the five statuses and states smoke-check limitations. |
| AC-12 | Setup, upgrade, and cleanup of copies preserve the original environment. Cleanup removes only selected temporary resources without affecting unrelated containers/volumes or the global cache. |
| AC-13 | The README covers installation, settings, lifecycle, limitations, and the integration warning; it does not promise to block real outbound actions. |
| AC-14 | A short vendor-neutral AI prompt and an example Markdown report allow the checks to be reproduced with ordinary CLI commands; AI itself is not required. |

The method for demonstrating file/data preservation is selected during implementation. Hashing unchanged files and making a controlled change in only one test database are possible **PROPOSED** methods; legitimate uploads/cache writes during site operation must be distinguished from silent core replacement.

### Matrix and Pilot

| Dimension | Target | Current Evidence |
| --- | --- | --- |
| Ubuntu/Linux | First development and acceptance platform. | The shared template and complete lifecycle have not yet been tested. The cached-image audit ran on Ubuntu AMD64. |
| macOS Intel/ARM64, Windows Docker Desktop/WSL2 | Later practical testing by a small team group. | Runtime is untested; this does not block the Linux prototype. |
| PHP 8.4, Debian WordPress FPM | Initial base candidate; development/testing may proceed independently of PHP 7.4 qualification. | Limited cached-image evidence exists; current digests were not downloaded. |
| PHP 7.4 | Agreed minimum target version; separate qualification of the legacy option. | Runtime, tooling, and required extensions are unverified. Do not claim support/verification. Failed or blocked qualification remains an unresolved requirement requiring an explicit decision before relevant acceptance criteria can be claimed as satisfied. |
| Database engines | MariaDB first for the prototype/pilot; MySQL remains an agreed configurable-engine requirement. One selected engine per environment. | Only verified engine/version combinations may be described as tested or supported. No universal migration compatibility is assumed. |
| Other PHP/database versions | Selected for the project and comparison dimension. | Claims apply only to combinations actually verified. |
| Greenfield | Pilot 1: clean WordPress. | A complete database-backed installation was not performed during the audit. |
| Brownfield | Pilot 2: independent Mitgavrim copy; pilot 3: one or more other local WordPress copies with different configurations. | Do not modify the live Mitgavrim environment. |

Completion boundary: a successful local pilot against the acceptance criteria and explicit documentation of limitations. Company-wide rollout, completed testing on every operating system, and support for every historical PHP version are not required. However, unverified PHP 7.4 must not be declared qualified merely to close the MVP. If PHP 7.4 qualification fails or remains blocked, document the unresolved requirement and request an explicit decision before claiming the relevant criteria or overall acceptance dependent on them are satisfied. Independent PHP 8.4 progress does not resolve that requirement. Starting with MariaDB does not remove or defer the agreed configurable MySQL requirement.

### Existing Evidence — Audit of 23 October 2026 Only

- At audit time, registry manifests for the selected WordPress PHP 7.4–8.5 FPM tags included `linux/amd64` and `linux/arm64`; this is not runtime qualification.
- Cached WordPress images with PHP 8.4.26 Debian 13 and PHP 8.1.34 Alpine ran on Ubuntu AMD64. Composer 2.9.5 and WP-CLI 2.12.0 PHAR files started; full dependency installation and a database-backed installation were not tested.
- Cached PHP 8.4 included `mysqli`, `curl`, `mbstring`, `gd`, `zip`, `intl`, `exif`, and OPcache; `pdo_mysql` was absent. Add `pdo_mysql` only if the project requires it.
- In a synthetic complete WordPress root, switching PHP 8.1 → 8.4 preserved all 3,352 files and their hashes; core remained unchanged. A separate test recorded the entrypoint overwriting a synthetic `wp-settings.php` in an incomplete tree.
- Pulling fresh digest-pinned images could not be completed. Current images, PHP 7.4, ARM64 runtime, Windows/macOS, complete HTTP/database lifecycles, and server parity were not tested.

No new technical tests or verification of registry/official web sources were performed for this specification. Historical facts do not guarantee the current state.

## Out of Scope

The following are **ACCEPTED as excluded / BACKLOG**; do not reintroduce them into the MVP as best practices:

- SSH/remote agents, shared server-side AI, and server workflows.
- CI/CD, deployment, dev/stage/prod parity, and standardization of server infrastructure.
- A production → local/stage/dev migration tool and automatic processing of production databases.
- Mandatory agent methodologies/frameworks or dependence on a specific AI vendor.
- Automatic discovery/analysis of secrets and integrations, mandatory email interceptors, HTTP interception, MU-plugin stubs, egress firewalls, and a full network sandbox.
- Forced changes to environment type or cron, or forced blocking of external HTTP.
- Git worktrees, symlinks as the copying model, Compose overrides, and per-developer Compose extensions in the standard template.
- Submodules/subtrees, a custom ZIP builder, a release pipeline, an installer (including a CLI installer), centralized template updates, and a template version manager.
- Load testing, SQL/memory profiling, advanced monitoring, log rotation, disk/cache growth management, and multiple QA tiers.
- PHP below 7.4; extensive cross-platform qualification infrastructure before pilot feedback.

## Open Questions / Assumptions To Validate

Do not reopen confirmed requirements. Only genuine technical uncertainties follow. Proposals do not automatically become agreed decisions.

| ID | Uncertainty / Status | Implication and Next Step |
| --- | --- | --- |
| OQ-01 | Current Debian WordPress FPM image and pinning [UNVERIFIED]. | Before implementing dependent steps, verify availability of the selected digest, runtime/entrypoint, PHP patch version, extensions, and tools. RECOMMENDED: a multiarch index digest with documented updates. |
| OQ-02 | PHP 7.4 + Composer/WP-CLI/native libraries and required extensions [UNVERIFIED]. | Validate compatible actual versions separately. PHP 7.4 remains the agreed minimum target; do not claim support before runtime, tooling, and required extensions pass qualification. If qualification fails or remains blocked, document the unresolved requirement and request an explicit decision before claiming relevant acceptance criteria are satisfied; do not silently raise the minimum. PHP 8.4 baseline development/testing may proceed independently. |
| OQ-03 | Fresh/existing handling and write permissions [UNVERIFIED]. | Define the simplest explicit check before the entrypoint and test Greenfield, complete Brownfield, and an incomplete tree. Confirm UID/GID and writable directories during the pilot. Do not treat a single sentinel as a complete site validation. |
| OQ-04 | MariaDB/MySQL implementation model [not yet approved]. | ACCEPTED: MariaDB is the initial prototype/pilot engine; MySQL remains a configurable-engine requirement, not removed or deferred. Each environment uses one selected engine, not both simultaneously. PROPOSED: one selected database service per instance with explicit engine-specific configuration. Validate environment-variable differences, healthchecks, SQL clients, and dump compatibility. An image-tag change does not prove engine interchangeability; only verified engine/version combinations may be called tested or supported. |
| OQ-05 | Node.js/phpMyAdmin optionality [not yet approved]. | PROPOSED: simple opt-in Compose profiles if they do not complicate use; a documented external workflow is also acceptable. The absence of both options does not prevent base startup. |
| OQ-06 | Settings and test URLs [details not yet approved]. | Select minimal external parameters without changing shared files or using Compose overrides; define safe adaptation of copied wp-config and URLs/serialized data. Do not present invented variable names as user decisions. |
| OQ-07 | Snapshot placement and cleanup across operating systems [UNVERIFIED]. | ACCEPTED: baseline/candidate directories are outside the source WordPress root; copying must not recursively include prior test environments; temporary SQL snapshots are outside every HTTP-served WordPress root; no mutable files or database volumes are shared. Provide portable instructions and verifiable ownership of resources being removed. PROPOSED: a user-selected sibling directory outside the WordPress root for snapshots and explicit project-targeted cleanup, without global cleanup. Linux is tested first. |
| OQ-08 | Readiness before/after installation [implementation not yet approved]. | Select Nginx/FPM/database probes separately from installed-WordPress checks and confirm the Greenfield wizard workflow. |
| OQ-09 | Server versions and environments [UNVERIFIED; does not block the Linux pilot]. | DevOps will later clarify images/digests/patches, databases, extensions/native libraries, FPM settings, UID/GID, writable directories, and projects using PHP 7.4. Do not claim server parity based on a PHP minor version alone. |
| OQ-10 | Testing seams [PROPOSED]. | During independent review, confirm or adjust the grouping into three boundaries without repeating discovery or expanding scope. The scenarios themselves are already agreed. |

No material contradictions requiring reconsideration of ACCEPTED decisions were identified during synthesis. Individual configuration outside shared files is not permission to introduce the deferred Compose override. The PHP 7.4 minimum target requirement and the lack of proven support are recorded separately.

## Further Notes

### Sources and Priority

This specification was synthesized from `wordpress-docker-spec-handoff(1).zip`, read starting with `00_READ_FIRST.md`, then `01`–`07` in the specified order. Priority: confirmed decisions in `01_SCOPE_AND_DECISIONS.md` and `05_SAFETY_AND_NON_GOALS.md` → `02_ENVIRONMENT_CONTRACT.md` → `03_TEST_WORKFLOWS.md` → `04_IMAGE_AUDIT.md` → `06_ACCEPTANCE_AND_PILOT.md` → `07_BACKLOG_AND_REFERENCES.md`.

The audit in the archive is an extract of the user's `wordpress-fpm-image-audit.md` report; original logs were not examined during this preparation. Old personal Docker configurations and `DOCKER-WP-AI-CONTEXT.md` are not used as a ready-made team template.

### Pilot Context

Mitgavrim is an example existing site, not a mandatory structural model. Do not inherit its former fixed container names, missing healthchecks/limits, serving of `/.git/HEAD`, or potential SQL export into the webroot. Its placement of Docker above `html/` and personal SSD paths are not carried into the shared template.

Mitgavrim's PHP lint, PHPCS, PHPUnit/theme tests, and Node build must not be assumed to exist in other projects or treated as proof of WordPress/database integration coverage.

### Official References for Future Validation

These links are carried forward from the source context for the receiving agent; they do not represent new verification of current documentation:

- [docker-library/wordpress](https://github.com/docker-library/wordpress)
- [WordPress image entrypoint](https://github.com/docker-library/wordpress/blob/master/docker-entrypoint.sh)
- [Official image manifests](https://github.com/docker-library/official-images/blob/master/library/wordpress)
- [PHP supported versions](https://www.php.net/supported-versions.php)
- [WP-CLI installation guide](https://make.wordpress.org/cli/handbook/guides/installing/)

The user's next step is independent specification review. Until a separate implementation task is given, do not create a working Docker template or modify existing environments.
