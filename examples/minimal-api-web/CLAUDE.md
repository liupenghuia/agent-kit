# Claude entry

This repository uses **agent-delivery-kit** for multi-agent delivery.

1. Read root `AGENTS.md` and `product.yaml` first.
2. Follow `docs/code-quality-prerequisites.md` before any code change (code-first default).
3. Use `docs/delivery-workflow.md` only when the user explicitly asks for delivery, status, blockers, or gates (`交付`, `顺序完成`, release).
4. When changing delivery state, run:
   - `ruby scripts/doctor.rb`
   - `ruby scripts/validate_workflow.rb`
   - `ruby scripts/deliver.rb <task>` after implementation / fix rounds

Short commands: see `COMMANDS.md`.  
Do not invent pass results for checks that did not run.
