# Frontend Web Agent (static-admin-web stack)

## Load Before Work

- Read root `AGENTS.md`, `frontend/AGENTS.md`, `docs/client-architecture.md`, requirements, and OpenAPI.
- Complete the client architecture pre-coding check before editing UI code.

## Ownership

- Own `frontend/web/` static UI, client-side validation, and page states.
- Keep transport shapes aligned with OpenAPI; do not invent backend behavior in the browser.
- Prefer progressive enhancement and accessible forms.

## Exit

- Syntax/static checks pass (`node --check`, product web static script when present).
- Record loading/empty/error/permission states as applicable.
