# agent-delivery-kit 使用说明

> 版本：见仓库根 `VERSION`（当前 **0.2.1**）  
> 本 kit **不含业务产品**。需求与代码只存在于你 `init` / `adopt` 出的产品仓。

既有仓接入见 [MIGRATION.md](./MIGRATION.md)。

---

## 1. 是什么

| 能力 | 说明 |
| --- | --- |
| 角色与读序 | Product / Architect / Backend / Frontend / Test / Orchestrator |
| 状态机与门禁 | Idea / Task / Issue 约定 |
| 脚手架 | `init_product.rb` |
| 既有仓接入 | `adopt_product.rb` |
| 校验 | `validate_workflow.rb` |
| 交付 runner | `deliver.rb`（cmd / glob / service_http） |
| 栈插件 | `node-api`、`static-admin-web`、`wechat-miniprogram` |

**不包含**：业务 OpenAPI、表结构、领域 ADR、示例 App。

### 三层模型

```text
L0  kit        → 本仓库
L1  shape      → 产品仓 product.yaml + stacks
L2  truth      → 产品仓 docs 与代码
```

---

## 2. 环境

| 依赖 | 要求 |
| --- | --- |
| Ruby | 2.6+（推荐 3+） |
| Node.js | 使用 node-api / 静态 Web 检查时 18+ |

---

## 3. 新建产品仓

```bash
cd /path/to/agent-delivery-kit

ruby scripts/init_product.rb \
  --path ~/work/my-product \
  --name my-product \
  --display-name "My Product" \
  --preset api-web \
  --mode link \
  --kit-path "$(pwd)"

cd ~/work/my-product
ruby scripts/doctor.rb
ruby scripts/validate_workflow.rb
```

### CLI 要点

| 参数 | 说明 |
| --- | --- |
| `--path` | 产品根目录 |
| `--name` | slug |
| `--preset` | `api-web` / `api-miniprogram` / `api-web-miniprogram` / `docs-only` |
| `--mode link\|copy` | link 指向外部 kit；copy  vendored |
| `--force` | 允许写入非空目录 |

`link`：`product.yaml` → `kit.path` 为绝对路径。  
`copy`：内容进 `vendor/agent-delivery-kit`，`kit.path: vendored`。

产品仓 `scripts/*.rb` 是薄包装，真正实现在 kit。

---

## 4. 初始化后的产品目录（api-web）

```text
my-product/
├── product.yaml
├── AGENTS.md
├── COMMANDS.md
├── VERSION_KIT
├── docs/                 # 流程文档 + 待你填写的 stub
├── ideas/ tasks/ issues/ # 仅 template，无业务条目
├── backend/              # node-api stub（可选改）
├── frontend/web/         # static-admin-web stub
├── scripts/              # doctor / validate / deliver 包装
└── tests/AGENTS.md       # 测试角色说明，不是业务用例集
```

业务写什么、做不做后端/小程序，由你在产品仓决定。

---

## 5. `product.yaml`

示例：`templates/product/product.yaml.example`。

### `when`

| 表达式 | 含义 |
| --- | --- |
| 省略 / `true` | 总是跑 |
| `scopes.x` | 任务 `required_scopes` 优先，否则产品 scopes |
| `frontend_targets.y` | 任务 targets 优先 |

### check 字段

| 字段 | 说明 |
| --- | --- |
| `type` | `cmd`（默认）或 `service_http` |
| `cmd` / `start` | 命令数组 |
| `glob` | 对每个匹配文件追加路径执行 `cmd` |
| `allow_empty` | glob 0 文件时通过 |
| `health_url` / `env` | `service_http`；支持 `{{port}}` |

---

## 6. 日常脚本（在产品仓根）

```bash
ruby scripts/doctor.rb
ruby scripts/validate_workflow.rb
ruby scripts/deliver.rb <task>
```

- **doctor**：Ruby、product.yaml、kit 路径、目录、stack、checks  
- **validate**：front matter、双向链接、状态枚举  
- **deliver**：按 task 过滤 checks，写 `delivery.evidence_root` 报告  

环境变量：`PRODUCT_ROOT`、`KIT_ROOT`（包装脚本会设）、`DELIVERY_REPAIR_COMMAND`（可选）。

---

## 7. Agent 工作方式

### 默认：Code-First

1. 先过 `docs/code-quality-prerequisites.md`  
2. **不**主动推状态机，除非用户要交付/状态/门禁  
3. 本地可运行验证；不假设通过  

### 用户明确要求交付时

1. `docs/delivery-workflow.md`  
2. 更新 front matter / handoff  
3. `ruby scripts/deliver.rb <task>`  
4. 仅 Test 可将 issue `Closed`  

短命令见产品仓 `COMMANDS.md`。读序见 `core/INSTRUCTION_ORDER.md`。

---

## 8. Idea / Task / Issue

```bash
cp ideas/template.md ideas/my-idea.md
# id: IDEA-YYYYMMDD-NNN 等，见 template front matter
```

状态机全文：`docs/delivery-workflow.md`（init 时拷到产品仓）。

---

## 9. 栈插件

路径：`stacks/<id>/` → `AGENTS.md` + `checks.yaml` + 可选 `*.stub`。

| id | 目录 | 默认检查概要 |
| --- | --- | --- |
| `node-api` | `backend/` | test、syntax glob、health |
| `static-admin-web` | `frontend/web/` | syntax、static、health |
| `wechat-miniprogram` | `frontend/miniprogram/` | syntax、可选 tests |

新增栈：自建目录并在 init 用 `--backend` / `--web` / `--miniprogram` 引用。

---

## 10. AI 入口

| 工具 | 路径 |
| --- | --- |
| Claude | `adapters/claude/CLAUDE.md` |
| Cursor | `adapters/cursor/.cursor/rules/agent-delivery.mdc` |
| Grok | `adapters/grok/skills/agent-delivery/SKILL.md` |

只指向 `AGENTS.md` + 流程，不写业务规则。

---

## 11. kit 自测

`tests/` **只测本仓库引擎**，与任何业务产品无关。

```bash
ruby tests/test_product_config.rb
ruby tests/test_validate_workflow.rb
ruby tests/test_init_product.rb
ruby tests/test_adopt_product.rb
ruby tests/test_delivery_runner.rb
```

CI 模板：`docs/github-actions-ci.yml`（需要时复制到 `.github/workflows/`）。

---

## 12. 版本

| 变更 | 版本位 |
| --- | --- |
| 新 stack、文档、additive check 字段 | MINOR |
| front matter / 状态机破坏性变更 | MAJOR |
| bugfix / 精简清理 | PATCH |

`doctor`：`kit_version` 与 kit `VERSION` 的 **major 必须一致**。

---

## 13. 非目标

- 替你决定做什么产品  
- 内置示例 App / 领域模型  
- 云端看板或自动调 LLM 的编排服务  
- 自动通过 human_gates  

---

## 14. 常见问题

**kit not found** → 检查 `product.yaml` 的 `kit.path`。  
**deliver 找不到 task** → `tasks/<name>.md` 或 title 匹配。  
**service_http 超时** → 看 evidence 下 `*.service.log`，确认 `{{port}}` 与 health 路径。
