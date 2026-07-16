# AGENTS — Minimal API + Web

Kit: agent-delivery-kit@0.1.0  
Kit path: `/Users/Penguin/Documents/PPFiles_Learn/agents-project/agent-delivery-kit`  
Quality mode: code-first

## Instruction Order

1. This file (product overlay)
2. `product.yaml`
3. Kit / product docs: `docs/delivery-workflow.md`, `docs/code-quality-prerequisites.md`
4. Nearest role `AGENTS.md` under `backend/`, `frontend/`, `mobile/`, `tests/`
5. Active task acceptance criteria and linked issues

Role instructions may tighten, but never weaken, this contract.  
Preserve unrelated user changes; never discard work to resolve a conflict silently.

## Code-First Contract

Users primarily want **high-quality code**, not gate ceremony.

1. Do **not** drive task/issue state machines unless the user explicitly asks for delivery, status, blockers, or gates (`交付`, `顺序完成`, release, etc.).
2. Before coding, complete `docs/code-quality-prerequisites.md` (intent, short baseline, ownership, robustness, minimal diff).
3. Prefer correctness, maintainability, extensibility, and robustness; do not swallow errors; keep auth on the server.
4. Prove behavior with local runnable checks; never report an assumed pass.
5. Report engineering outcomes: what changed, key trade-offs, how it was verified.

When the user requests closed-loop delivery, also follow `docs/delivery-workflow.md`.

## Iteration Contract

- Treat the latest explicit user intent and task acceptance criteria as the current source of truth.
- Establish a short baseline before editing; avoid reloading unrelated modules.
- Make the smallest change that produces observable acceptance evidence.
- Record adjacent improvements as follow-up work instead of expanding scope silently.

## Product Owner Entry Point

- Prefer `docs/product-request-template.md` for non-technical requests.
- Product owns scope and acceptance; Architect owns technical boundaries; implementation agents own code; Test owns independent evidence.
- `顺序完成` continues through reversible repository phases without confirmation between steps.
- Pause only for product tradeoffs, production release, real user data, secrets, paid external actions, irreversible changes, or unavailable required platform access.

## Sources of Truth

| Concern | Source |
| --- | --- |
| Product shape | `product.yaml` |
| Pre-coding quality bar | `docs/code-quality-prerequisites.md` |
| Idea / MVP decision | `ideas/*.md`, `docs/product-discovery.md` |
| Product behavior | `docs/requirements.md`, task acceptance criteria |
| System boundaries | `docs/architecture.md` |
| Client structure | `docs/client-architecture.md` |
| HTTP contract | `docs/openapi.yaml` |
| Data model | `docs/database.md` |
| Delivery state | YAML front matter in `tasks/*.md` and `issues/*.md` |
| Gates and transitions | `docs/delivery-workflow.md` |
| Test policy | `docs/testing.md` |

## Role Commands

See `COMMANDS.md`. Command aliases may be customized in `product.yaml` under `commands`.

## Operating Contract (delivery mode)

When the user **explicitly** requests delivery:

- Run preflight, entry gate, work, verification, and exit gate from `docs/delivery-workflow.md`.
- Client implementation roles complete and record the client-architecture pre-coding check before code edits.
- Update task/issue front matter and append a handoff row on each transition.
- Use `P0`–`P3` priority; retests outrank new feature work at equal priority.
- Implementation owners may mark issues `Ready for Retest`; only Test Agent marks them `Closed`.
- Do not mark a task `Done` unless the validator and applicable quality gates pass.
- Record exact commands and results. If a required check cannot run, use `Blocked`; never report an assumed pass.

## Closed-Loop Delivery Rules

- Prefer `ruby scripts/deliver.rb <task>` after implementation and after every fix round.
- A failed runner check is actionable failure evidence; route to the owning scope.
- A runner pass is necessary but not sufficient; Test Agent still owns acceptance evidence and final test status.
- Preserve runner reports under the product's `delivery.evidence_root`.
- Never bypass production deployment approval, secret access, destructive changes, or unavailable platform-specific checks through the runner.

## Commit Attribution

When `quality.commit_coauthor` is true, AI commits must include:

```text
Co-Authored-By: <agent model and attribution byline>
```

Commit only when the user requests it.
