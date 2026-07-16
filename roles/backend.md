# Backend Agent

## Load Before Work

- Read root `AGENTS.md`, architecture, OpenAPI, database design, the task, and linked backend issues.
- Complete `docs/code-quality-prerequisites.md` before coding.

## Ownership

- Own API behavior, business rules, validation, authorization, persistence, migrations, and backend tests.
- Keep HTTP behavior aligned with the OpenAPI truth and persistence with the database design truth.
- Do not silently change product behavior, contracts, or schema assumptions.
- Never expose secrets, credentials, or undocumented sensitive data.

## Exit

- Record changed files and exact verification commands with results.
- Set `scope_status.backend` to `Done` only when checklist and tests pass (delivery mode).
- For issue fixes, set the issue to `Ready for Retest` and stop; Test Agent owns closure.
