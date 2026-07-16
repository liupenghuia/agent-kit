# Changelog

## 0.2.1 — 2026-07-16

### Changed

- **Lean kit:** remove `examples/` (no sample product in this repo).
- Neutral docs/templates: no product-domain or host-monorepo assumptions.
- Drop unused adapter `.stub` duplicates, empty stack placeholders (react/ios/android), and unused test fixtures.
- Shorten README / USAGE / MIGRATION to framework-only scope.

## 0.2.0 — 2026-07-16

### Added

- `scripts/adopt_product.rb` for non-destructive adoption into existing product repos.
- Delivery check extensions: `glob`, `type: service_http`, `allow_empty`, `{{port}}`.
- `scripts/check_static_web.rb`.
- Stack default checks for node-api / static-admin-web / wechat-miniprogram.
- Real AI adapters (Claude / Cursor / Grok).
- `docs/MIGRATION.md`, CI template, expanded self-tests.

### Changed

- `ProductConfig#owners` merges `product.yaml` owners with defaults.
- Stronger `doctor.rb` checks.

## 0.1.0 — 2026-07-16

### Added

- Initial multi-agent delivery kit extract: core, roles, schemas, scripts, stacks, templates.
