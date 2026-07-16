# Instruction Order

Agents and humans should load instructions in this order (later layers refine; they never silently discard safety rules):

1. **Product root `AGENTS.md`** — product overlay generated or customized at init
2. **`product.yaml`** — scopes, stacks, checks, truth paths, quality mode
3. **Kit L0 docs** (copied or linked into product `docs/`):
   - `delivery-workflow.md`
   - `code-quality-prerequisites.md`
   - `iterative-implementation-guidelines.md`
   - `product-discovery.md` / `testing.md` / `client-architecture.md` as needed
4. **Nearest role `AGENTS.md`** — e.g. `backend/AGENTS.md`, `frontend/web/AGENTS.md`
5. **Active work item** — `tasks/<name>.md` acceptance criteria, linked issues, ADRs

## Environment resolution

| Variable | Meaning |
| --- | --- |
| `PRODUCT_ROOT` | Product repository root (contains `product.yaml`) |
| `KIT_ROOT` | agent-delivery-kit root (contains `VERSION`, `scripts/`) |
| `DELIVERY_REPAIR_COMMAND` | Optional shell command run between failed delivery rounds |

When scripts run from product `scripts/*.rb` wrappers, they set `PRODUCT_ROOT` and resolve `KIT_ROOT` from `product.yaml` → `kit.path`.
