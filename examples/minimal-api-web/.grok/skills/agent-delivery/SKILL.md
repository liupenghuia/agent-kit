---
name: agent-delivery
description: Multi-agent closed-loop delivery using agent-delivery-kit (code-first by default; delivery mode on explicit request).
---

# agent-delivery

## When to use

- Implementing product work under this repository's agent delivery conventions.
- User mentions `交付`, task/issue status, gates, or `顺序完成`.

## Instructions

1. Load root `AGENTS.md` and `product.yaml`.
2. Default path: code-first via `docs/code-quality-prerequisites.md`.
3. Delivery path (only if user asked): `docs/delivery-workflow.md` + front matter updates + `ruby scripts/deliver.rb <task>`.
4. Validate with `ruby scripts/validate_workflow.rb` before changing delivery state.
5. Record exact commands and results; never invent pass results.

See `COMMANDS.md` for role short commands.
