# Changelog

## 0.2.0 — 2026-07-16

### Added

- **Main-business readiness:** `scripts/adopt_product.rb` for non-destructive adoption into existing product repos.
- Delivery check types beyond simple commands:
  - `glob` multi-file expansion (e.g. `node --check` over `src/**/*.js`)
  - `type: service_http` local process + HTTP health (`{{port}}` substitution)
  - `allow_empty` for optional glob matches
- `scripts/check_static_web.rb` generic static web presence check.
- Stack default checks aligned with main business deliver loop (node-api / static-admin-web / wechat-miniprogram).
- Real AI adapters (Claude / Cursor / Grok), installed by `init_product` and `adopt_product`.
- Migration guide: `docs/MIGRATION.md`.
- Example product config: `templates/product/product.api-web-miniprogram.example.yaml`.
- GitHub Actions CI template at `docs/github-actions-ci.yml` (copy into `.github/workflows/` when the token has `workflow` scope).
- Expanded self-tests: adopt, delivery glob/health, product config validation.

### Changed

- `ProductConfig#owners` merges `product.yaml` owners with defaults.
- `ProductConfig` validates `service_http` check shape.
- `doctor.rb` checks wrapper scripts, `VERSION_KIT`, and check types.
- Version bump to **0.2.0** (minor: new capabilities, schema extensions are additive).

## 0.1.0 — 2026-07-16

### Added

- Initial extract of multi-agent delivery kit from the host product monorepo.
- L0 core rules, generic workflow docs, role briefs, and idea/task/issue templates.
- `product.yaml` schema and front-matter schemas.
- Scripts: `init_product.rb`, `validate_workflow.rb`, `deliver.rb`, `doctor.rb` with shared `scripts/lib`.
- Stack plugins: `node-api`, `static-admin-web`, `wechat-miniprogram`, plus stubs for react/ios/android.
- Example product scaffold target: `examples/minimal-api-web`.
- User guide: `docs/USAGE.md`.
