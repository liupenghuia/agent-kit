# 既有产品仓接入

把已有仓库接到 agent-delivery-kit：**不覆盖**业务文档与代码。

适用版本：**0.2.1+**

## 原则

| 留在产品仓 | 来自 kit |
| --- | --- |
| requirements / architecture / openapi / database / 代码 | 流程文档（仅当缺失时补齐） |
| 已有 ideas / tasks / issues | validate / deliver / doctor |
| 业务专属脚本（如 `check_web.rb`） | 可在 `product.yaml` 的 checks 里引用 |

## 步骤

```bash
cd /path/to/agent-delivery-kit

ruby scripts/adopt_product.rb \
  --path /path/to/your-product \
  --name my-product \
  --display-name "My Product" \
  --preset api-web \
  --mode link \
  --kit-path "$(pwd)" \
  --dry-run

# 确认后去掉 --dry-run
```

常用 preset：`api-web` | `api-miniprogram` | `api-web-miniprogram` | `docs-only`。

## 验收

```bash
cd /path/to/your-product
ruby scripts/doctor.rb
ruby scripts/validate_workflow.rb
# 有 task 时再：
# ruby scripts/deliver.rb <task>
```

## 行为摘要

- 无 `product.yaml` 时按 preset 生成；已有则默认保留（可用 `--force-product-yaml`）
- 默认**不**覆盖根 `AGENTS.md`（可用 `--force-agents`）
- 旧 `scripts/{deliver,validate_workflow,doctor}.rb` → `scripts/legacy/`
- 写入 `VERSION_KIT`

## 回滚

1. 从 `scripts/legacy/` 移回脚本  
2. 删除或停用 `product.yaml`  
3. 可选删除 `VERSION_KIT` 与 adapters  

## checks 声明式示例

```yaml
delivery:
  checks:
    - id: workflow
      cmd: ["ruby", "scripts/validate_workflow.rb"]
    - id: backend-syntax
      when: "scopes.backend"
      cwd: backend
      cmd: ["node", "--check"]
      glob: "src/**/*.js"
    - id: backend-health
      when: "scopes.backend"
      type: service_http
      cwd: backend
      start: ["node", "src/server.js"]
      env: { PORT: "{{port}}" }
      health_url: "http://127.0.0.1:{{port}}/health"
```

完整字段见 `templates/product/product.yaml.example` 与 `docs/USAGE.md`。
