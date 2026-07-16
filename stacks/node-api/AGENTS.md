# Backend Agent (node-api stack)

## Load Before Work

- Read root `AGENTS.md`, product OpenAPI and database truths, the task, and linked backend issues.
- Complete `docs/code-quality-prerequisites.md` before coding.

## Ownership

- Own `backend/` API behavior, validation, authorization, persistence, and tests.
- Keep HTTP aligned with `docs/openapi.yaml` and storage with `docs/database.md`.
- Prefer small modules and explicit error mapping; do not invent a second contract.

## Suggested layout

```text
backend/
  package.json
  src/
    server.js
    app.js
  test/
```

## Exit

- Run stack checks (typically `npm test` and syntax checks).
- Record exact commands and results in the task when delivery mode is active.
