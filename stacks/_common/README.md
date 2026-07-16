# Stack plugins

Each stack under `stacks/<id>/` may provide:

| File | Required | Purpose |
| --- | --- | --- |
| `AGENTS.md` | recommended | Role rules for that directory |
| `checks.yaml` | recommended | Default delivery checks merged into `product.yaml` |
| `*.stub` | optional | Scaffold files copied into the product (suffix `.stub` removed) |

## checks.yaml shape

```yaml
checks:
  - id: backend-test
    when: "scopes.backend"
    cwd: backend
    cmd: ["npm", "test"]
```

`when` supports `scopes.<name>`, `frontend_targets.<name>`, or omit/`true`.
