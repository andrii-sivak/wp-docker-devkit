# Agent Instructions

## Project

`wp-docker-devkit` — a reusable, local-first WordPress Docker development and compatibility-testing toolkit.

The delivered environment must work without Git, GNU Make, or any AI coding agent.

## Source of Truth

- `docs/spec/SPEC.md` defines requirements, scope, decisions, and acceptance criteria.
- `docs/spec/IMPLEMENTATION_HANDOFF.md` defines the receiving agent's workflow, implementation sequence, and invariants.
- Read both documents before planning implementation or making architectural decisions.
- Preserve the distinction between ACCEPTED, RECOMMENDED, PROPOSED, UNVERIFIED, and BACKLOG.
- Do not reinterpret proposals as approved requirements or silently expand MVP scope.
- Report material contradictions and unsupported assumptions instead of silently changing agreed decisions.

## Workflow

- Follow the current task's authorization. Do not start implementation during specification review.
- When implementation is authorized, follow the validation-first sequence in the handoff.
- Prefer deterministic verification and evidence over unverified compatibility claims.
- Keep implementation decisions traceable to requirements and acceptance criteria.
- Use installed project Skills when relevant; do not introduce them as runtime dependencies.

## Agent Skills

### Issue Tracker

Issues and specs live as Markdown files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Domain Docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
