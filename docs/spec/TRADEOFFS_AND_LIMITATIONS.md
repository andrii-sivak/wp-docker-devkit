# Trade-offs and limitations — wp-docker-devkit

*Why it is bad (on purpose).* 

**Status:** MVP decision record, not a defect list or an implementation backlog.  
**Scope:** Local WordPress development and upgrade comparisons; not production deployment.  
**Related:** [SPEC.md](SPEC.md), [IMPLEMENTATION_HANDOFF.md](IMPLEMENTATION_HANDOFF.md), [qualification.md](../validation/qualification.md), and [BOUNDARIES.mmd](BOUNDARIES.mmd).

## Purpose and decision rule

The MVP deliberately optimizes for a small, auditable workflow: create one isolated **baseline** and one isolated **candidate** from the same initial site/data; change an approved dimension; run available checks; retain evidence; clean up only the selected copies. It is not a general-purpose WordPress orchestration system.

Entries below distinguish:

- **Limitation:** a guarantee the tool does *not* provide. The operator must account for it on every applicable run.
- **Trade-off:** a deliberate design choice with benefits and costs, not automatically technical debt.
- **Deferred:** a possible improvement that needs a repeated use case or concrete failure before implementation.

**Do not automatically turn every entry into a GitHub issue.** Revisit a choice only when its trigger occurs; a failed test or a documented limitation is not necessarily a DevKit defect. If this document and the accepted requirements disagree, `SPEC.md` takes precedence until an explicit decision changes it.

## Safety and trust boundaries

| ID | Boundary or trade-off | Operator responsibility / remaining risk | Revisit when |
| --- | --- | --- | --- |
| S-01 | **No outbound network sandbox.** Docker networks isolate local projects, not external destinations; the tool does not automatically block SMTP, SMS, webhooks, payment/CRM APIs, or cron. | Inspect integrations before either copy starts. Use test credentials, suitable data, disabled jobs or approved stubs as appropriate; `SKIPPED` does not mean safe. | Teams need repeatable guardrails for sites with live integrations. |
| S-02 | **No automatic data anonymization or encryption-at-rest policy.** A logical SQL dump and copied site can contain personal data and active secrets. Restrictive file permissions help, but are not encryption. | Use only data approved for local testing; protect and eventually remove retained snapshots/reports under the team's data policy. | Client data is routinely used, or policy requires sanitization/retention controls. |
| S-03 | **Docker is not a hostile-code sandbox.** The AI agent and host user may have broad Docker daemon/filesystem privileges. Container CPU/RAM/PID limits are resource controls, not security guarantees. | Run only trusted code and review high-impact commands. The skill cannot constrain an agent that executes unrelated shell commands. | Running untrusted plugins or multi-tenant workloads becomes a goal (a different threat model). |
| S-04 | **DevKit Nginx rules do not secure the original web server.** Its HTTP-deny rules protect only traffic served by the DevKit Nginx instance. | Independently ensure any Apache/Nginx serving the original WordPress root cannot expose `wp-devkit/`, `.env`, or operational files. | Distribution/installation model changes or a repeatable exposure is found. |
| S-05 | **AI skill is advisory, not a permission boundary.** Discovery, confirmations, and path checks reduce mistakes; they cannot guarantee agent behavior. | Respect client permission prompts; inspect commands affecting the source, Docker daemon, secrets, or deletions. The scripts' own checks apply only when those scripts are used. | Repeated unsafe proposals occur despite clear skill instructions. |
| S-06 | **Project checks are user-provided host commands.** `PROJECT_CHECK_COMMAND` is run via `bash -lc` in the copy's root on the host, not inside a restricted test container by default. | Only configure commands whose effects and required credentials are understood. | A shared project-check runner or stricter execution boundary becomes necessary. |

## Reproducibility and data fidelity

| ID | Boundary or trade-off | Consequence | Revisit when |
| --- | --- | --- | --- |
| R-01 | **Comparable copies, not production parity.** An original Alpine stack may be compared using two matching Debian PHP images. PHP patch versions, extensions, native libraries, web-server configuration, and other services can still differ. | A result applies to the **recorded** environment, not all production stacks. Differences unrelated to the selected change must be disclosed. | A defect depends on OS image, native libraries, an extension, or production-only configuration. |
| R-02 | **Nginx + PHP-FPM + one MariaDB/MySQL database are the default stack.** Node.js and phpMyAdmin are opt-in; Redis, queues, search engines, CDN, external cron, etc. are not reproduced automatically. | External/service-dependent behavior may be missing or misleading. Do not infer full-stack compatibility. | A required dependency repeatedly blocks useful comparisons. |
| R-03 | **One logical SQL snapshot restored into fresh independent databases.** This is *not* an in-place MariaDB/MySQL upgrade of an existing `/var/lib/mysql` directory, nor a production migration/rollback rehearsal. | Successful import and WordPress startup do not validate physical data-directory upgrades, all user/grant metadata, replication, or production rollback steps. | Planning a real production database migration or an engine switch. |
| R-04 | **No source locking or automatic synchronization.** File copies and SQL export are separate operations, and later source edits do not propagate. | Concurrent source writes can make the initial states inconsistent. Freeze source changes during preparation, and record the provenance/timing of the dump. | Active/high-write sites need reproducible point-in-time capture. |
| R-05 | **Uploads are all-in or excluded for both copies.** With `--uploads exclude`, attachment records remain in SQL but the corresponding files are missing. | Media-dependent failures are limitations of the test fixture, not automatically upgrade regressions. | Large media libraries routinely make full copies impractical. |
| R-06 | **Existing configuration can override `.env`.** A hardcoded `DB_HOST`, credentials, `WP_HOME` or `WP_SITEURL` in copied `wp-config.php` can supersede DevKit environment values. WordPress-aware URL replacement also cannot promise to fix every project-specific link. | Verify *effective* DB connection points to each copy's own DB before restore/start; never assume changing `.env` is sufficient. Review custom URL/storage settings separately. | A common project convention permits safe automated configuration validation. |
| R-07 | **A database snapshot is not a full-site backup.** SQL lives separately from copied files; uploads and external object storage may not be included. | Do not use DevKit as a production backup/restore solution. | Backup/disaster recovery becomes an explicit, separately scoped product goal. |

## Test coverage and interpretation

| ID | Boundary or trade-off | Consequence | Revisit when |
| --- | --- | --- | --- |
| T-01 | **Minimal HTTP smoke tests.** `/healthz` and `/` expect 200; `/wp-login.php` accepts 200 or 302. These check responses, not page correctness, frontend JS, transactions, or business workflows. | **Smoke PASS does not mean regression-free.** Run project-specific checks and manual verification before any production decision. | A reported upgrade regression repeatedly passes smoke undetected. |
| T-02 | **Project-specific tests are optional, not invented.** When `PROJECT_CHECK_COMMAND` is absent, status is `NOT CONFIGURED`; external integrations are `SKIPPED`. | Never convert skipped/unconfigured coverage to PASS. Report exactly which commands ran and which capabilities were untested. | Several projects share an actually useful test suite or browser flow. |
| T-03 | **One candidate and preferably one changed dimension.** Plugin/core/database updates can have project-specific database migrations or activation/update hooks; a code-only change may not exercise the real operational upgrade path. | Verify the actual update method and state changes for the target project. Avoid attributing an unexplained side effect to one variable if others changed. | A specific upgrade procedure needs a dedicated repeatable test. |
| T-04 | **Human/agent-authored comparison narrative.** Scripts generate smoke output; the comparison is a concise Markdown assessment, not an exhaustive automated diff/benchmark. | Its quality depends on reported commands, actual versions, exit codes, and honest scope statements. | Reports become inconsistent or comparisons are run frequently enough to justify automation. |

## Operations, portability, and distribution

| ID | Boundary or trade-off | Consequence | Revisit when |
| --- | --- | --- | --- |
| O-01 | **Linux-first evidence.** Acceptance checks and three agent pilots cover specific Linux combinations; they do not certify Windows/WSL2, macOS, ARM64, every legacy PHP release, or arbitrary MariaDB ↔ MySQL transitions. | Qualify the host/platform, image, native libraries, and version combination actually being used. Historical PHP can run without being security-supported. | Developers need those platforms or combinations. |
| O-02 | **Disk preflight is an estimate.** Two file copies, SQL dump, DB volumes, image layers, logs, and cache compete for capacity; per-container CPU/RAM/PID limits do not impose an aggregate disk quota. | Reserve extra space and monitor disk growth. | Large sites or failed runs repeatedly exhaust local storage. |
| O-03 | **Conservative cleanup.** Only an identified copy and its owned Compose resources are removed; SQL snapshots/reports, images and build cache are kept. No `cleanup-all` and no global `docker system prune`. | Manually handle retained sensitive data and later image/cache housekeeping. A leftover temporary file created by an agent outside DevKit's scripts is the agent's responsibility. | Retention or disk use becomes a recurring problem. |
| O-04 | **No environment manager, CI/CD, installer, release builder or template auto-updater.** The developer uses GitHub's standard Download ZIP, ordinary shell/Compose commands, and the portable optional skill. Dev-only files stay in Git and are excluded from the distributed ZIP via `.gitattributes` `export-ignore`. | Less maintenance and vendor lock-in, but no centralized fleet rollout or version management. GitHub ZIP contents must be rechecked after distribution changes. | Real team adoption makes updates or repeatable release checks costly. |
| O-05 | **Host tools and permissions matter.** Copy/check/cleanup use Bash, GNU utilities, Python 3, Docker and Compose; Docker Desktop credential helpers, mounts and filesystem permissions differ by host. | A successful workflow on one host is not proof that another host is ready. Resolve host-specific blockers without editing the original project. | Cross-platform support becomes a validated requirement. |

## Evidence, not guarantees

As of the October 2026 pilots, the workflow was exercised on Linux with three distinct agents and changes: Claude Code (PHP 8.1 → 8.4), Codex CLI (WordPress 6.8.3 → 7.1.3), and Grok CLI (MariaDB 10.6 → 12.3). These show that the **tested** baseline/candidate workflows can succeed; they do not establish universal coverage or production safety. The qualification details and earlier limits are in `docs/validation/qualification.md`; per-pilot smoke/comparison reports are separate artifacts and should be retained with their corresponding runs.

## Decision checklist for future changes

Before implementing a new feature, document: **(1)** the observed failure or repeatable user need, **(2)** which entry above it addresses, **(3)** why the existing manual/project-specific workaround is insufficient, **(4)** the new security/maintenance cost, and **(5)** the smallest acceptance test. If none is concrete, keep the MVP behavior.

**Operational rule:** An isolated candidate passing smoke checks is evidence for *that limited test*, not authorization to apply an update to production.
