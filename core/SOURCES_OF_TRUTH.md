# Sources of Truth

Paths below are the defaults. A product may override them in `product.yaml` under `truths`.

| Concern | Default path | Owner |
| --- | --- | --- |
| Product shape (scopes, stacks, checks) | `product.yaml` | Product / Orchestrator |
| Idea discovery process | `docs/product-discovery.md` | Product Agent |
| Requirements / behavior | `docs/requirements.md` | Product Agent |
| System architecture | `docs/architecture.md` | Architect Agent |
| Client architecture standard | `docs/client-architecture.md` | Architect / Frontend |
| HTTP API contract | `docs/openapi.yaml` | Architect / Backend |
| Data model | `docs/database.md` | Architect / Backend |
| Delivery workflow | `docs/delivery-workflow.md` | Orchestrator |
| Testing policy | `docs/testing.md` | Test Agent |
| Code quality bar | `docs/code-quality-prerequisites.md` | All implementers |
| Idea records | `ideas/*.md` front matter + body | Product Agent |
| Task delivery state | `tasks/*.md` front matter + body | Role owners |
| Issue delivery state | `issues/*.md` front matter + body | Test + fix owners |

## Rules

1. Business domain facts live in the **product repo**, not in this kit.
2. Kit documents describe **process**, not product behavior.
3. If product docs and kit docs conflict on process, the product may tighten rules in root `AGENTS.md`, but must not weaken kit safety gates without an explicit decision.
4. Code must not invent a second contract source that contradicts OpenAPI or database design.
