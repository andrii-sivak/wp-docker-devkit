# WordPress Docker Dev/Test MVP

Project: `wp-docker-devkit`. Date: 24 October 2026. 
**Status:** APPROVED FOR IMPLEMENTATION
**Approved on:** 2026-10-24
**Version:** 1.2
Requirements language: English.

The requirements and MVP scope are approved.
Technical assumptions marked UNVERIFIED remain subject to validation
during implementation. Any material scope changes require explicit approval.

This document is self-contained; no chat history is required to understand the requirements. It was prepared using the installed `to-spec` skill. The companion document, `IMPLEMENTATION_HANDOFF.md`, defines the receiving agent's workflow; this specification defines the requirements.

Statuses: **ACCEPTED** — an agreed requirement or decision; **RECOMMENDED** — a recommendation, not a commitment; **PROPOSED** — an option proposed but not yet approved; **UNVERIFIED** — a technical assumption or unverified compatibility; **BACKLOG** — excluded from the MVP and deferred. A requirement's presence does not mean it has been implemented or verified.

## Problem Statement

Team developers need a simple local WordPress Docker template downloaded as a ZIP and placed as one self-contained `wp-devkit/` directory **inside the WordPress root** of a new or existing site, without merging files into or overwriting the site root. It must work independently of Git, repository structure, GNU Make, and the AI product being used.

When evaluating PHP, WordPress, database, or plugin upgrades, developers need parallel baseline and candidate environments: separate copies of the same site with identical initial test data. Testing must not modify the original local site or mix the instances' code and databases. Results must identify actual differences and the limits of the checks performed.

This is a local development and testing tool for gradual team adoption. It does not standardize server infrastructure or require every developer to move to Docker immediately.

## Solution

### User Workflow [ACCEPTED]

1. Download the template using GitHub's standard **Code → Download ZIP** action. Extract it, find the single distributable `wp-devkit/` directory inside GitHub's archive wrapper, and place that directory inside the actual WordPress root. Do not merge its contents into the WordPress root or overwrite an existing `wp-devkit/` directory without explicit review.
2. For an AI-assisted comparison, the agent first inspects available site and runtime evidence (actual PHP/FPM, WordPress and database versions, extensions, limits, ports, Node.js/frontend requirements, and relevant optional services). It distinguishes observed values from assumptions and asks only for missing or ambiguous information. The user confirms the baseline configuration before the agent asks which component and target version to test in the single candidate. One change is preferred. Several changes stay in that same candidate only when the user asks for one combined test. No environment creation or upgrade starts before the relevant configuration is confirmed. The same information can be configured manually from the README without AI.
3. Configure approved versions, local ports, resources, and optional services. Confirm each copy uses its own database and prepare project integrations for a test run. Start Nginx, PHP-FPM, and one selected MariaDB/MySQL engine using ordinary Compose commands from `wp-devkit/`; MariaDB is the initial pilot engine and MySQL remains in scope. Composer, WP-CLI, PHP CLI, and an SQL client are available; Node.js and phpMyAdmin remain optional and off unless needed.
4. For Greenfield, a WordPress root containing only the new `wp-devkit/` toolkit (and no WordPress core) must still be recognized as a safe fresh site for manual installation or optional bootstrap. Normal Brownfield startup does not replace core, plugins, or custom code.
5. For comparisons, run a disk-space preflight and choose whether to copy `wp-content/uploads/` before creating the two independent test roots. Place those roots alongside the source directory by default: `../project-x-baseline/` and `../project-x-candidate/` for source `project-x/`. Each contains its own `wp-devkit/`, files, Compose project, network, and DB volume; neither is the original. Reject existing destinations instead of overwriting them. Use one logical snapshot of permitted test data, stored outside all HTTP-served WordPress roots, and restore it independently into the two test databases. Use distinct Compose project names and HTTP ports. Apply the same `uploads` choice to both copies, and report omitted media as a testing limitation.
6. Tell the developer not to change the source files or database during preparation and comparison: changes made after copying are not propagated to baseline/candidate, and edits during copying may make the initial states incomparable. Do not introduce source locking, change monitoring, or automated synchronization; the developer is responsible for observing this instruction.
7. Validate the baseline, change the selected comparison dimension only in the candidate, run available checks, and produce a compact Markdown report. Leave both copies available for inspection until their specific cleanup is requested; cleanup removes only the selected temporary resources.

A person can perform every step without AI. An agent uses the same ordinary commands. A custom environment manager or complex CLI is not required.

### Future Implementation Deliverables [ACCEPTED]

A standard GitHub **Code → Download ZIP** distribution containing a single `wp-devkit/` folder within GitHub's normal archive wrapper. That folder contains only installation and usage files: its Compose template and Dockerfile, Nginx/PHP configuration, public `README.md`, `START_HERE.md`, `skills/wp-devkit/SKILL.md`, user-facing comparison workflows, the existing portable AI prompt (adapted to the new layout), and an example Markdown report. Development-only documentation and AI tooling remain in Git but outside the distributed folder and are excluded from the archive as specified below.

The README is a complete, standalone manual guide. `START_HERE.md` provides a short vendor-neutral instruction to explicitly read the bundled skill; the skill guides discovery, clarification, baseline/candidate configuration, execution, and reporting without duplicating the README or making AI mandatory. Claude Code, Codex, and Grok are priority validation targets; Gemini CLI and Antigravity are additional targets. Native skill discovery or registration is tool-specific and must be tested rather than presumed.

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
11. As a developer, I want the entire toolkit in one `wp-devkit/` folder, so that I can add it to a site without colliding with existing Compose, Dockerfile, README, or environment files.
12. As an agent user, I want a staged, evidence-based configuration dialogue and a portable skill, so that unknown settings are clarified and the baseline is approved before I select the candidate change.
13. As a developer, I want to estimate disk use and choose whether to copy `wp-content/uploads/` into both test instances, so that very large media libraries do not unexpectedly exhaust local storage.

## Implementation Decisions

### 1. Distribution and Placement [ACCEPTED]

- The template is developed in a separate Git repository. Users download GitHub's standard **Code → Download ZIP** archive and copy the **single included `wp-devkit/` folder** into the actual WordPress root, without distributing its files across that root. GitHub's generated outer archive directory is not the installable folder. Cloning the repository is not required. An existing `wp-devkit/` must not be silently overwritten.
- In Git, keep development documentation (`docs/spec/`, `docs/agents/`, `docs/validation/`) and development AI tooling (`AGENTS.md`, `.agents/`, `.claude/`, `skills-lock.json`) outside `wp-devkit/`. Use `.gitattributes` `export-ignore` to exclude them and all other root-level development-only entries from GitHub's standard ZIP. The **distributed** `wp-devkit/skills/wp-devkit/SKILL.md`, `START_HERE.md`, and its public `README.md` are user-facing runtime/help files and **must remain inside the ZIP**; do not confuse them with excluded development AI tooling.
- The downloaded ZIP must contain one installable `wp-devkit/` folder (inside GitHub's archive wrapper) and no other distributed repository files. Verify the actual GitHub ZIP after publishing as an acceptance criterion; local `git archive` inspection alone is insufficient. Until a GitHub remote exists, this check remains pending and must not be reported as PASS. Do not introduce a custom ZIP builder, release pipeline, installer, or obligatory Git.
- Compose, image-build context, scripts, examples, README, and skill live inside `wp-devkit/`. Run Compose from that directory; mount the **parent WordPress root** into the site containers while keeping image-build context limited to necessary DevKit files. A mandatory parent directory containing an `html/` subdirectory is not introduced. Existing root-level Compose, Dockerfile, `.env`, README, and scripts remain untouched.
- Do not impose a monorepository. A project's Git repository may contain only a theme, several plugins, the whole WordPress installation, or nothing at all. `wp-devkit/` is placed relative to the actual WordPress root, not assumed to be at the Git root.
- Every necessary operation — configuration, startup, rebuild, diagnostics, checks, shutdown, and cleanup — is documented using ordinary Compose commands or portable commands/scripts without requiring GNU Make. Users must be able to complete the same workflows manually without an agent or skill.
- Shared files contain no personal absolute paths, names of personal integrations, or mandatory external networks. Individual settings are provided without editing shared files; Compose overrides are not part of the standard MVP. The bundled skill requires no mandatory agent-specific installation or modification of the project's existing agent configuration.

### 2. Services, Versions, and Tools [ACCEPTED]

| Area | Contract |
| --- | --- |
| HTTP/PHP/database | Nginx + PHP-FPM + one selected MariaDB/MySQL engine per environment; versions are configurable per project. MariaDB is used for the first prototype and pilot. MySQL remains within the agreed configurable database-engine requirements and is not removed or deferred by that implementation sequence. |
| Initial PHP base | The official Debian `wordpress:php8.4-fpm` image is the agreed starting candidate for the prototype, not a fully qualified image. |
| Minimum PHP target | PHP 7.4 remains the agreed minimum target version. The 24 October Linux qualification records a working PHP 7.4.33 combination; broader runtime, platform, extension, and project compatibility must not be inferred from that single result. |
| CLI | PHP CLI, Composer, WP-CLI, and an ordinary mysql/mariadb client are available. |
| Additional tools | Node.js is available for projects with a frontend workflow; phpMyAdmin is optional. Neither is required to start a site. |
| Reporting | PHP, database, Composer, and WP-CLI versions are clear and overridable; actual versions are recorded, not only configured tags. |

The PHP 8.4 / MariaDB 11.8 and Composer 2.9.5 / WP-CLI 2.12.0 versions in the Mitgavrim example do not become mandatory team versions. Specific Nginx, Node.js, and phpMyAdmin versions have not been agreed.

Development and testing of the PHP 8.4 baseline may proceed independently of PHP 7.4 qualification. The PHP 7.4.33 Linux pilot recorded in `docs/validation/qualification.md` provides combination-specific evidence, not support for every site, image variant, or platform. If a required PHP 7.4 combination fails or remains blocked, record that limitation and request an explicit decision before claiming its acceptance criteria are satisfied. Do not silently raise the minimum or use PHP 8.4 results as PHP 7.4 evidence.

**RECOMMENDED:** pin images by multiarch index digest and document how pins are updated. Exact digests and the final pinning policy remain subject to validation; do not insert unverified values. Mutable tags and `latest` must be resolved to the actual versions obtained; record the identity of the image/digest used when available.

**RECOMMENDED / UNVERIFIED:** provide PHP 7.4 as a separate opt-in legacy option after validating compatible FPM, Composer, WP-CLI, and required extensions. Historical image availability does not imply current security maintenance.

### 3. Files and Bootstrap [ACCEPTED]

- Bind-mount the complete site tree into the PHP container. Nginx reads the same tree; read-only access for Nginx is the recommended default.
- PHP must be able to write to uploads/cache and any other directories required by the project with appropriate permissions. Exact UID/GID values and writable directories are validated during the pilot.
- Brownfield uses existing files. Normal startup and changing the PHP image must not automatically update or replace WordPress core, plugins, themes, or custom code.
- Explicitly distinguish fresh and existing site states before first startup. Treat a new WordPress root containing only `wp-devkit/` as Greenfield, while refusing incomplete or ambiguous Brownfield trees before potentially destructive automatic preparation.
- Greenfield permits manual installation. Automatic core retrieval and WP-CLI bootstrap are optional additional paths. Pinning a WordPress version in configuration is not a mandatory prerequisite for the first startup.
- Create independent baseline and candidate directory copies, including the themes, plugins, `wp-devkit/`, configuration, and all other required site files. **Exception:** the developer may explicitly omit the contents of `wp-content/uploads/` in both copies; keep the uploads directory itself present and writable. For source `.../project-x/`, use sibling directories `.../project-x-baseline/` and `.../project-x-candidate/` by default, **not** paths under the source and not an arbitrary nested `instances/` directory. If sibling placement is not writable or a destination exists, stop and ask for a safe alternative; never overwrite existing directories. The copy operation must not recursively include previously created test environments. Do not introduce shared mutable files or directories, Git worktrees, or symlinks as the basis of the workflow. Preserve source ownership/modes without changing the original; arrange only the minimal safe permissions needed on copies, not a world-writable (`1777`) top directory by default.

**Uploads and disk-space preflight [ACCEPTED]:** Before copying either test root, measure or estimate the source WordPress files and `wp-content/uploads/` separately, show the approximate file-space cost of **both** copies with and without uploads, and check free space on the destination filesystem. The copy workflow supports `--uploads include|exclude` for manual and agent use. The agent asks which mode to use before creating instances; both instances receive the same mode. Preserve the existing include behavior for legacy calls when no option is supplied, but still run the disk preflight. If space is clearly insufficient for the selected mode, refuse to start copying; if the estimate is unreliable (for example due to quotas or differing mounts), warn rather than claim guaranteed capacity. Treat SQL snapshots, database volumes, Docker images and caches as additional storage needs not fully measured by the file-copy estimate. Do not implement a complex capacity planner.

When `--uploads exclude` is selected, preserve an empty, writable `wp-content/uploads/` directory in each copy; do not remove it, bind-mount it from the source, or modify the original. WordPress attachment rows remain in the independently restored databases, but referenced media files are absent. Document this explicitly and record the chosen mode and the resulting limitations in the Markdown report. Missing original media in this deliberate mode must not automatically be classified as a PHP/WordPress/plugin regression. Preserve the existing safety checks on copy destinations, ownership, and data isolation.

**Known risk:** according to the 23 October 2026 audit, the official entrypoint may copy core into a nonempty directory when both `index.php` and `wp-includes/version.php` are absent. Checking only that a directory is nonempty is insufficient. The presence of those two files also does not prove that the entire WordPress tree is complete. The specific fresh/existing validation mechanism remains to be validated.

### 4. Isolation, Networking, and Resources [ACCEPTED]

- Multiple instances run from different sibling directories with different **globally nonconflicting** Compose project names, for example using `docker compose -p ...` from each instance's `wp-devkit/`. The repeated directory name `wp-devkit/` must not cause default Compose-name collisions. Before startup or cleanup, reject ambiguous names and verify ownership of any existing Compose resources; matching local `.env` and metadata alone is insufficient. Fixed global `container_name` values are prohibited.
- Each project has its own network and database volume. The original site, baseline, and candidate must not share a database volume or mutable code.
- Separate projects may use identical internal DNS names and test database credentials, such as `db:3306` and `wordpress`/`wordpress`. What matters is that each copy actually connects to its own database.
- Before a copy's first startup, check the database connection settings in its `wp-config.php` and effective configuration: they must not reference the original or a remote database. Changing environment variables alone does not guarantee that an existing `wp-config.php` has been reconfigured.
- HTTP ports are predictably configurable and bind to `127.0.0.1` by default; parallel projects receive different ports. If a database UI is enabled, its port is also configurable. Do not publish the database port without a need.
- RAM, CPU, and PID limits are configurable. Verify that Compose actually applies the configured limits on the pilot platform.
- Healthchecks verify readiness of the main services. Nginx/PHP/database readiness is distinct from a completed WordPress installation: the Greenfield setup wizard may not yet have been completed.
- Shutdown and deletion of temporary resources target a positively identified test instance and its own Compose resources. Reject a target pointing to the original or a different project, including Compose-name collisions; do not delete original or unrelated containers, volumes, images, or the global Docker cache. `docker system prune` is not part of cleanup. Normal cleanup also leaves the sibling `<site>-snapshots/` directory and its files in place. Deleting snapshot files is a separate explicit request. There is no cleanup-all command.

### 5. Data, URLs, and Upgrades [ACCEPTED]

The original local site remains unchanged. Exporting a permitted test snapshot is a separate operation: copying files does not copy a database. Create one logical snapshot while the developer refrains from editing source files/database, and restore **that same snapshot** independently into baseline and candidate. Source changes during preparation or comparison can invalidate the shared initial state; later source edits do not propagate to the copies. State this plainly in the README and agent workflow; do not implement locking, live synchronization, or snapshot coordination. Do not share a database or transfer a physical data directory between different database versions.

**RECOMMENDED:** use `wp db export` / `wp db import` when the site is already running under DevKit. Before use, validate the WordPress configuration, database connectivity, and required SQL binaries; availability of a WP-CLI command does not prove that its external dependencies are available. A source that is not running under DevKit may use an existing dump client such as `mariadb-dump`. The export needs a reachable source database. If that database is down, stop and let the developer make it reachable. Do not start, repair, or reconfigure the original database. An existing suitable SQL dump removes the need for another export. Do not substitute raw database files. The implemented snapshot directory is the sibling `<site>-snapshots/` of the WordPress root (`project-x-snapshots/initial.sql` for a root named `project-x`). Temporary SQL snapshots must remain outside every HTTP-served WordPress root, including the source, baseline, and candidate roots. Normal cleanup does not delete that directory or its files.

Assign correct test URLs to the copies. `WP_HOME`/`WP_SITEURL` or WordPress-aware `wp search-replace`, which accounts for serialized data, are acceptable. URL constants alone do not guarantee correction of all stored absolute links. Apply `wp config set` only when configuration values actually need changing. Adapt URLs **in the intended test copy**, not implicitly in the original; README commands must use the correct target/context. Treat instance metadata as data, not executable shell code (do not `source`/`eval` an instance metadata file). Choose and document the exact method for the project.

Confirm baseline functionality before modifying the candidate. If the baseline fails, stop and do not attribute that failure to the candidate. Change one comparison dimension where practical. A user who asks for several changes may put them in that same single candidate. Do not create extra candidates for the combination. Report unavoidable additional changes.

| Dimension | Expected Change Method | Condition for a Valid Comparison |
| --- | --- | --- |
| PHP | Change the candidate's FPM image version. | Existing core is not replaced with image contents; actual PHP patch version and image identity are recorded. |
| WordPress | Run `wp core update` with a specific version or latest; run `wp core update-db` when needed. | Core changes are explicit; latest is resolved to an actual version number. |
| Database | Use a separate clean instance of the selected engine/version and a logical import. | Dump compatibility with the selected transition is verified; no shared data directory is used. |
| Plugin | Perform a targeted update of the selected plugin. | Record the plugin and actual versions; do not update all plugins unnecessarily. |

Arbitrary database upgrade/downgrade compatibility and universal migrations between MariaDB/MySQL versions or engines are not promised. Only verified engine/version combinations may be described as tested or supported. Different image platforms or native libraries may introduce additional differences; do not attribute those differences solely to a PHP minor version change.

### 6. Basic HTTP Hygiene and Integrations [ACCEPTED]

Nginx must not serve operational files from the webroot: `.env`, `.git`, SQL dumps, configuration files, Docker files, **any files under `/wp-devkit/`**, and sensitive dotfiles/backup files, including those accidentally placed under `/.well-known/`. Legitimate `/.well-known/` challenges and normal static files must remain accessible. PHP execution in upload directories is prohibited. Because another, pre-existing web server may serve the source WordPress root independently, document and check that it also does not expose `wp-devkit/` (especially configurations and credentials); do not assume DevKit's own Nginx rules protect that external server. Do not require modifying unrelated server configuration automatically.

Before starting a copy, the project developer is responsible for SMTP, SMS, webhooks, payment/CRM/API integrations, and background jobs: use test credentials, disable them, or provide project-specific stubs. Use test or appropriately anonymized data where applicable. This is not automatic production database migration or mandatory agent-based secret analysis.

The public README and Agent Skill must communicate the following integration warning:

> Before starting a copy, review SMTP, SMS, webhook, payment/CRM/API integrations, and background jobs. Running Docker locally does not block outbound traffic. Use test credentials/stubs and data suitable for testing. The template isolates containers and local databases but does not guarantee prevention of external side effects.

The template does not enforce `WP_ENVIRONMENT_TYPE=local`, `DISABLE_WP_CRON=true`, or `WP_HTTP_BLOCK_EXTERNAL=true`; it does not add a mandatory email-interception MU-plugin, egress firewall, or internal-only network. Such changes could distort the behavior under test and interfere with updates, Composer, or npm.

Do not disable cron globally. If cron is part of the functionality, test the project's corresponding mechanism, including its existing system cron schedule when used. Automatic cron reconfiguration is outside the MVP.

### 7. Optional Agent Interface [ACCEPTED]

- Ship one portable Agent Skill at `wp-devkit/skills/wp-devkit/SKILL.md` (standard `SKILL.md` with YAML frontmatter), plus a short `wp-devkit/START_HERE.md` and the existing agent prompt adapted to the new layout. `START_HERE.md` must work by explicitly pointing an agent to the skill even when automatic discovery is unavailable; do not require installation into agent-specific home/project directories.
- The skill follows **Discover → Clarify → Confirm baseline → Select/confirm candidate → Execute → Report**. During Discover, inspect project/uploads size and destination free space; during Clarify, present estimates for two copies and explicitly ask whether to include or exclude uploads before copying. Inspect existing project/runtime evidence first; distinguish observed facts, inferred settings, and missing data. Ask targeted questions about unknown or ambiguous PHP/FPM, database engine/version, WordPress version, extensions, resources/limits, Node.js, phpMyAdmin, ports, and available tests. Do not conflate the host CLI PHP version with the site's FPM runtime.
- Confirm the intended baseline (the separate unchanged control copy) before collecting the candidate's upgrade dimension and exact target version. Show the user what will change and what will remain constant. Do not silently choose unsupported versions, start destructive operations, or run a comparison before necessary confirmation. If an agent is unavailable, the README provides equivalent manual instructions.
- Prioritize practical compatibility checks with **Claude Code, Codex, and Grok**; Gemini CLI and Antigravity are secondary. Test each tool's ability to follow the explicit skill path and, where possible, native skill discovery. Do not claim universal native discovery or duplicate separate implementations per vendor; document observed compatibility and limitations.
- Keep `SKILL.md` concise and vendor-neutral. Reference public README and portable scripts rather than copying lengthy operating instructions. This user-facing skill belongs **inside** the ZIP; development-only AI tooling remains excluded.

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
- baseline/candidate differences, issues, limitations, and everything not tested, including the uploads include/exclude mode, estimated disk requirements and omitted-media limitations;
- information about targeted cleanup already performed or still outstanding.

This defines report content, not a new machine API format or report manager.

### Acceptance Criteria [ACCEPTED TARGETS — Not Results]

| ID | Criterion and Observable Evidence |
| --- | --- |
| AC-01 | The actual GitHub **Code → Download ZIP** archive contains one installable `wp-devkit/` folder inside GitHub's generated wrapper, with its public README, `START_HERE.md`, bundled skill, and all runtime files; root-level development docs and AI tooling are excluded by `.gitattributes` `export-ignore` while remaining tracked in Git. Copy only `wp-devkit/` into the WordPress root without overwriting existing root files; lifecycle commands work without Git, GNU Make, or AI. Verify the downloaded GitHub ZIP **after publication**; until then this portion is PENDING/UNVERIFIED, not PASS. |
| AC-02 | A clean Greenfield root containing only `wp-devkit/` permits manual setup/optional bootstrap and passes HTTP smoke checks; infrastructure readiness before installation does not require completion of the wizard. |
| AC-03 | A complete Brownfield copy preserves core/plugins/custom code during normal startup and PHP image changes. An incomplete copy is diagnosed before potentially destructive automatic writes. |
| AC-04 | PHP/database versions, local ports, and RAM/CPU/PID limits are configurable and actually applied. PHP CLI, Composer, WP-CLI, and the SQL client work for the combination under test. PHP 7.4 remains the agreed minimum target; its runtime, tooling, and required extensions must be validated before support is claimed. If qualification fails or remains blocked, document the unresolved requirement and request an explicit decision before claiming the PHP 7.4 portion of this criterion is satisfied; PHP 8.4 baseline development/testing may proceed independently. |
| AC-05 | Nginx/PHP/database have meaningful readiness checks; WordPress responds after installation. `/wp-devkit/`, operational files (including risky files under `/.well-known/`) are not served, while legitimate challenges and static uploads still work; PHP in uploads is not executed. Document/check exposure by an independently running source-site web server as a separate concern. |
| AC-06 | Baseline and candidate are independent sibling directories next to the source WordPress root by default (`project-x-baseline/`, `project-x-candidate/`), each containing its own `wp-devkit/` and running simultaneously with distinct collision-checked Compose project names/ports, networks, and DB volumes. Their file copies match except for the explicitly permitted omission of uploads **in both instances**. No existing target is overwritten, no recursive copying or shared mutable data occurs, and changes in one do not affect the other or the original. |
| AC-07 | Both databases are independently restored from the same logical snapshot; instance identity and DB targets are verified before import, configuration points to each instance's own database, and URL adaptation executes only against the intended copy without evaluating untrusted metadata as shell. Temporary SQL snapshots remain outside every HTTP-served WordPress root. The developer is instructed not to edit the source during comparison; no locking/synchronization is required. |
| AC-08 | A PHP upgrade is tested and existing core is preserved. WordPress updates to a specific version and latest are tested, with update-db where needed; actual versions are recorded. Results for a verified PHP combination do not establish PHP 7.4 support. If PHP 7.4 qualification fails or remains blocked, record the unresolved requirement and request an explicit decision before claiming this criterion is satisfied for PHP 7.4. |
| AC-09 | A logical transfer into a new database instance is performed for an actually selected compatible transition, with transfer limitations documented. MariaDB is the initial prototype/pilot engine; MySQL remains an agreed configurable-engine requirement and must not be silently removed or deferred. Each environment uses one engine. Only verified engine/version combinations are described as tested or supported; arbitrary cross-engine/version compatibility and universal migrations are not claimed. |
| AC-10 | A targeted plugin update is demonstrated with an observable comparison. This is an agreed workflow; its absence as a separate checkbox in the original Definition of Done does not exclude it from the MVP. |
| AC-11 | Available project checks can be invoked; a missing suite is reported as NOT CONFIGURED. The report distinguishes the five statuses and states smoke-check limitations. A deliberate exclusion of uploads is recorded as a limitation, not automatically as a product regression. |
| AC-12 | Setup, upgrade, restore, and cleanup preserve the original. Cleanup verifies test-instance identity and actual Docker resource ownership before deletion; duplicate Compose project names and wrong/unsafe targets are rejected. Copy permissions are sufficient without default world-writable instance roots or changing original ownership; unrelated resources and global caches are untouched. |
| AC-13 | `wp-devkit/README.md` covers one-folder installation, manual configuration and lifecycle, sibling test copies, the `--uploads include|exclude` option, disk-space preflight and omitted-media limitations, correct-target restore/URL commands, optional services, copy permissions, source no-edit guidance, exposure through pre-existing HTTP servers, limitations, and the integration warning; it does not promise to block outbound actions. |
| AC-14 | A short vendor-neutral prompt, `START_HERE.md`, portable `skills/wp-devkit/SKILL.md`, and an example Markdown report guide evidence-based discovery, clarification, disk-space assessment and explicit uploads choice, baseline/candidate confirmation, and ordinary CLI checks; manual execution remains possible. Test skill use with Claude Code, Codex, and Grok first, then Gemini CLI/Antigravity as available, and report tool-specific limitations rather than claiming unverified support. |

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

No new technical tests were performed in preparing this specification revision. The later Linux qualification and acceptance evidence are recorded separately in `docs/validation/qualification.md`; historical audit facts do not guarantee a different platform or project combination.

## Out of Scope

The following are **ACCEPTED as excluded / BACKLOG**; do not reintroduce them into the MVP as best practices:

- SSH/remote agents, shared server-side AI, and server workflows.
- CI/CD, deployment, dev/stage/prod parity, and standardization of server infrastructure.
- A production → local/stage/dev migration tool and automatic processing of production databases.
- Mandatory agent methodologies/frameworks or dependence on a specific AI vendor.
- Automatic discovery/analysis of secrets and integrations, mandatory email interceptors, HTTP interception, MU-plugin stubs, egress firewalls, and a full network sandbox.
- Forced changes to environment type or cron, or forced blocking of external HTTP.
- Git worktrees, symlinks as the copying model, Compose overrides, and per-developer Compose extensions in the standard template.
- Automatic locking, continuous synchronization, change monitoring, or concurrent-write coordination of the original site.
- Agent-specific skill installers, mandatory global/project skill registration, or separate vendor-specific implementations.
- Submodules/subtrees, a custom ZIP builder, a release pipeline, an installer (including a CLI installer), centralized template updates, and a template version manager.
- Load testing, SQL/memory profiling, advanced monitoring, log rotation, automatic disk/cache growth management, granular media selection, incremental media syncing, hardlink/reflink deduplication, and multiple QA tiers.
- PHP below 7.4; extensive cross-platform qualification infrastructure before pilot feedback.

## Open Questions / Assumptions To Validate

Do not reopen confirmed requirements. Only genuine technical uncertainties follow. Proposals do not automatically become agreed decisions.

| ID | Uncertainty / Status | Implication and Next Step |
| --- | --- | --- |
| OQ-01 | Current Debian WordPress FPM image and pinning [UNVERIFIED]. | Before implementing dependent steps, verify availability of the selected digest, runtime/entrypoint, PHP patch version, extensions, and tools. RECOMMENDED: a multiarch index digest with documented updates. |
| OQ-02 | PHP 7.4 + Composer/WP-CLI/native libraries and required extensions [UNVERIFIED outside tested Linux combination]. | `docs/validation/qualification.md` records a working PHP 7.4.33 Linux combination. Qualify other required versions/platforms/extensions separately; failed or blocked qualification remains unresolved and must not silently raise the minimum. PHP 8.4 results do not qualify PHP 7.4. |
| OQ-03 | Fresh/existing handling and write permissions [UNVERIFIED for the revised layout]. | Retest the existing entrypoint guard with `wp-devkit/` as the only folder in a new root, a complete Brownfield, and incomplete trees; confirm UID/GID and necessary write access without default world-writable copy roots. Do not treat a single sentinel as full core validation. |
| OQ-04 | MariaDB/MySQL implementation model [not yet approved]. | ACCEPTED: MariaDB is the initial prototype/pilot engine; MySQL remains a configurable-engine requirement, not removed or deferred. Each environment uses one selected engine, not both simultaneously. PROPOSED: one selected database service per instance with explicit engine-specific configuration. Validate environment-variable differences, healthchecks, SQL clients, and dump compatibility. An image-tag change does not prove engine interchangeability; only verified engine/version combinations may be called tested or supported. |
| OQ-05 | Node.js/phpMyAdmin optionality [not yet approved]. | PROPOSED: simple opt-in Compose profiles if they do not complicate use; a documented external workflow is also acceptable. The absence of both options does not prevent base startup. |
| OQ-06 | Settings and test URLs [implementation details to validate]. | ACCEPTED: discover and confirm baseline settings before selecting candidate changes; use unambiguous instance-targeted URL adaptation and data-only metadata parsing. Select minimal external parameters without changing root project files or using Compose overrides; preserve serialization-safe URL handling. |
| OQ-07 | Snapshot placement, disk-capacity estimates and cleanup across operating systems [UNVERIFIED outside tested combinations]. | ACCEPTED: baseline and candidate are sibling WordPress roots by default; snapshot files remain outside every served root; copies have identical uploads modes; a basic pre-copy capacity check is required; copied resources are isolated and explicitly owned. Verify how destination free space and estimates behave with quotas, mounts, and macOS/Windows; do not promise exact database/Docker storage costs or add locks/synchronization. Linux is tested first. |
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

The approved v1.1 revision established the one-folder layout, sibling test roots, and portable agent workflow. **v1.2 adds only the optional uploads-copy mode and basic disk-space preflight.** Adapt the existing implementation rather than rebuilding it. Actual GitHub Download ZIP and agent-client qualification remain pending; do not represent them as completed.
