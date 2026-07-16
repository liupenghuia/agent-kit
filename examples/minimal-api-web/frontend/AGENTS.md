# Frontend Agent Coordinator

## Load Before Work

- Read root `AGENTS.md`, `docs/client-architecture.md`, requirements, OpenAPI, the task, and linked frontend issues.
- Read the target-specific `AGENTS.md` under each selected frontend target directory.

## Scope Routing

- Aggregate `scope_status.frontend` is owned by the Frontend coordinator.
- Each `frontend_targets.<name>` has an independent `frontend_target_status.<name>` owned by the target agent.
- Coordinate shared API client, error taxonomy, design decisions, and cross-target changes.
- Do not let one target silently change another target's behavior.

## Exit

- Complete the client architecture pre-coding check for every affected target before coding.
- Aggregate frontend is `Done` only when every required target is `Done` with evidence (delivery mode).
- Record handoffs with changed files, exact commands/results, issues, and next action.
