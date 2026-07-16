# 主业务 / 既有产品仓迁移指南

目标：让已有 monorepo（例如寻职 `agents-project`）**渐进接入** agent-delivery-kit，  
**不覆盖**业务真相（requirements / architecture / openapi / database / 代码 / 已有 tasks）。

适用 kit 版本：**0.2.0+**

---

## 1. 迁移原则

| 保留在产品仓 | 迁到 kit |
| --- | --- |
| `docs/requirements.md`、ADR、OpenAPI、database | 通用流程文档（可缺则补、不覆盖） |
| `backend/` `frontend/` `mobile/` 代码 | 状态机校验、deliver runner、doctor |
| 现有 `tasks/` `ideas/` `issues/` | 角色简报与 stack 默认 checks |
| 业务专属 `scripts/check_web.rb` 等 | 可保留并在 `product.yaml` 引用 |

**不要**把业务 media、sqlite、领域 ADR 放进 kit。

---

## 2. 推荐路径：`adopt_product.rb`

在 kit 根目录执行：

```bash
cd /path/to/agent-delivery-kit

# 先 dry-run
ruby scripts/adopt_product.rb \
  --path /path/to/agents-project \
  --name recruitment \
  --display-name "寻职" \
  --preset api-web-miniprogram \
  --mode link \
  --kit-path "$(pwd)" \
  --evidence-root /tmp/agent-delivery/recruitment \
  --dry-run

# 确认后正式接入
ruby scripts/adopt_product.rb \
  --path /path/to/agents-project \
  --name recruitment \
  --display-name "寻职" \
  --preset api-web-miniprogram \
  --mode link \
  --kit-path "$(pwd)" \
  --evidence-root /tmp/agent-delivery/recruitment
```

### 会做什么

1. 若不存在则生成 `product.yaml`（含 stack 合并后的 checks：语法 glob、测试、service_http 健康检查）
2. 安装薄包装：`scripts/{doctor,validate_workflow,deliver}.rb` → load kit
3. 将旧脚本移到 `scripts/legacy/`（可用 `--no-backup-scripts` 关闭）
4. 缺失的流程 docs / idea·task·issue 模板补齐（**不覆盖**已有文件）
5. 默认不覆盖根 `AGENTS.md`（需要时 `--force-agents`）
6. 写入 `VERSION_KIT`，可选安装 Claude / Cursor / Grok adapter

### 不会做什么

- 不改业务代码
- 不重写已有 requirements / openapi / 已有 task 内容
- 不删除 `scripts/legacy/`

---

## 3. 验收清单

在产品仓根目录：

```bash
ruby scripts/doctor.rb
ruby scripts/validate_workflow.rb
ruby scripts/deliver.rb <一个真实 task 名>
```

期望：

| 步骤 | 期望 |
| --- | --- |
| doctor | 输出 `OK`（允许 WARN：truth 路径或 VERSION_KIT 小版本差） |
| validate | 对现有 ideas/tasks/issues 通过，或给出可修的 front matter 错误 |
| deliver | 按 task 的 `required_scopes` / `frontend_targets` 过滤 checks，写 evidence 报告 |

证据目录默认：`product.yaml` → `delivery.evidence_root`。

---

## 4. 主业务 checks 映射（硬编码 → 声明式）

旧版产品 `scripts/deliver.rb` 常见逻辑与 kit 对应关系：

| 旧逻辑 | product.yaml / stack |
| --- | --- |
| `validate_workflow.rb` | `id: workflow` |
| `npm test`（backend） | `backend-test` |
| 遍历 `backend/src/**/*.js` + `node --check` | `backend-syntax` + `glob` |
| 启动 server + `/health` | `type: service_http` + `health_url` |
| 小程序 `node --check` / `tests/*.test.js` | `miniprogram-syntax` / `miniprogram-test` |
| web `node --check` + `check_web.rb` | `web-syntax` + `web-static`（优先本地 `check_web.rb`） |
| 静态 HTTP 起 web | `web-health` service_http |
| 微信 DevTools / 生产部署 | `human_gates`（永不自动通过） |

完整示例：`templates/product/product.api-web-miniprogram.example.yaml`。

### `glob` 与 `service_http`

```yaml
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
  env:
    PORT: "{{port}}"
    NODE_ENV: test
  health_url: "http://127.0.0.1:{{port}}/health"
```

- `{{port}}` 由 runner 分配空闲端口，可出现在 `start`/`cmd`/`env`/`health_url` 中。
- `allow_empty: true` 允许 glob 0 文件时仍通过（适合尚无测试目录的阶段）。

---

## 5. AGENTS.md 策略

| 策略 | 何时 |
| --- | --- |
| **保留**现有产品 `AGENTS.md`（默认） | 主业务已有成熟 code-first 约定 |
| `--force-agents` | 希望与 kit `core/AGENTS.root.md` 完全对齐 |

建议：迁移初期保留主业务 AGENTS，仅接 scripts + product.yaml；稳定后再考虑统一模板。

---

## 6. link vs copy

| 模式 | 适用 |
| --- | --- |
| `link` + 绝对 `kit.path` | monorepo 旁挂 kit / 本机统一升级（主业务推荐） |
| `copy` / vendored | 离线、单仓自包含 |

升级 kit 后：

```bash
cd product
# 视需要重跑 adopt 或手工改 kit_version / VERSION_KIT
ruby scripts/doctor.rb
```

major 不一致时 doctor **FAIL**。

---

## 7. 回滚

1. 从 `scripts/legacy/` 移回 `deliver.rb` / `validate_workflow.rb`
2. 删除或改名 `product.yaml`（若不再需要）
3. 可选删除 `VERSION_KIT` 与 adapters

业务代码与 docs 真相不受影响。

---

## 8. 迁移后的日常

```text
# 默认：只写代码
按 docs/code-quality-prerequisites.md 实现

# 明确交付时
交付 <task>
→ ruby scripts/deliver.rb <task>
```

新产品请继续用 `init_product.rb`，不要用 adopt。
