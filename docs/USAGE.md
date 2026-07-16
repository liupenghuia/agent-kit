# agent-delivery-kit 使用说明

> 版本：见仓库根目录 `VERSION`（当前 **0.1.0**）  
> 读者：想在新产品仓使用多 Agent 闭环交付的人，以及在本 monorepo 内维护 kit 的人。

---

## 1. 这是什么

`agent-delivery-kit` 是一套**与业务无关**的多 Agent 交付套件。它提供：

| 能力 | 说明 |
| --- | --- |
| 角色与读序 | Product / Architect / Backend / Frontend / Test / Orchestrator 等约定 |
| 状态机与门禁 | Idea / Task / Issue 状态、优先级、handoff 规则 |
| 脚手架 | `init_product.rb` 一键生成产品仓骨架 |
| 校验 | `validate_workflow.rb` 校验 front matter 与双向链接 |
| 交付 runner | `deliver.rb` 按 `product.yaml` 的 checks 跑本地验证并写报告 |
| 栈插件 | `node-api`、`static-admin-web`、`wechat-miniprogram` 等默认检查与 AGENTS |

**它不包含**：业务 OpenAPI、表结构、领域 ADR、业务代码。这些永远属于产品仓。

### 三层模型

```text
L0  meta rules     → 本 kit：core / roles / docs / scripts
L1  product shape  → 产品仓 product.yaml + 选用的 stacks/*
L2  product truth  → 产品仓 requirements / architecture / openapi / database / 代码
```

---

## 2. 在当前主工程中的位置

本 kit 已作为子目录抽离在：

```text
agents-project/
├── agent-delivery-kit/     ← 本套件（通用、可迁独立仓）
├── backend/                ← 寻职业务（L2）
├── frontend/
├── docs/                   ← 寻职业务真相 + 历史流程文档
├── tasks/ ideas/ issues/
└── scripts/                ← 寻职仓仍在用的交付脚本（尚未强制切到 kit）
```

设计蓝图：主仓 `docs/agent-delivery-kit-design.md`。  
**主寻职工程尚未强制依赖本 kit**；新产品建议直接用 kit init，老仓可渐进迁移。

---

## 3. 环境要求

| 依赖 | 要求 |
| --- | --- |
| Ruby | **2.6+**（推荐 3+） |
| Node.js | 使用 `node-api` / 静态 Web 检查时需要 **18+** |
| 可选 | `npm`（后端测试）、各端平台工具（小程序 DevTools 等，属 human gates） |

检查 Ruby：

```bash
ruby -v
```

---

## 4. 五分钟上手：初始化一个产品

在 kit 根目录执行：

```bash
cd /path/to/agent-delivery-kit

ruby scripts/init_product.rb \
  --path ~/work/my-product \
  --name my-product \
  --display-name "我的产品" \
  --preset api-web \
  --mode link \
  --kit-path "$(pwd)"
```

进入产品仓：

```bash
cd ~/work/my-product
ruby scripts/doctor.rb          # 期望输出 OK
ruby scripts/validate_workflow.rb
```

### 4.1 CLI 参数一览

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `--path DIR` | 必填 | 新产品根目录 |
| `--name SLUG` | 必填 | 产品 slug（证据目录、标识） |
| `--display-name NAME` | = name | 人类可读名称 |
| `--preset NAME` | `api-web` | 见下表 |
| `--mode link\|copy` | `link` | link：脚本转调外部 kit；copy：vendor 整份 kit |
| `--kit-path DIR` | 当前 kit | kit 绝对路径（link 模式写入 `product.yaml`） |
| `--backend STACK` | preset | 覆盖后端栈 id |
| `--web STACK` | preset | 覆盖 web 栈 id |
| `--miniprogram STACK` | — | 启用小程序栈 |
| `--no-miniprogram` | — | 强制关闭小程序 |
| `--force` | false | 允许非空目标目录覆盖写入 |
| `--decision-owner NAME` | `User` | 想法决策人 |

### 4.2 Preset

| preset | backend | web | miniprogram |
| --- | --- | --- | --- |
| `api-web` | node-api | static-admin-web | 关 |
| `api-miniprogram` | node-api | — | wechat-miniprogram |
| `api-web-miniprogram` | node-api | static-admin-web | wechat-miniprogram |
| `docs-only` | 无代码栈 | — | — |

### 4.3 link vs copy

| 模式 | `product.yaml` → `kit.path` | 适用 |
| --- | --- | --- |
| `link` | kit 的**绝对路径** | 本 monorepo 内多产品、统一升级 kit |
| `copy` | `vendored`（内容在 `vendor/agent-delivery-kit`） | 离线分发、单仓自包含 |

产品仓 `scripts/*.rb` 是薄包装：设置 `PRODUCT_ROOT` / `KIT_ROOT` 后 `load` kit 内实现。

---

## 5. 初始化后的产品目录

以 `api-web` 为例：

```text
my-product/
├── product.yaml                 # L1 唯一配置入口
├── AGENTS.md                    # 自 core/AGENTS.root.md 渲染
├── COMMANDS.md
├── README.md
├── VERSION_KIT                  # 记录生成时的 kit 版本
├── docs/
│   ├── delivery-workflow.md     # 自 kit 拷贝（流程）
│   ├── code-quality-prerequisites.md
│   ├── product-discovery.md
│   ├── testing.md
│   ├── client-architecture.md
│   ├── requirements.md          # stub，Product 填写
│   ├── architecture.md          # stub，Architect 填写
│   ├── database.md              # stub
│   └── openapi.yaml             # stub
├── ideas/template.md
├── tasks/template.md
├── issues/template.md
├── backend/                     # node-api 栈
├── frontend/web/                # static-admin-web 栈
├── scripts/
│   ├── doctor.rb
│   ├── validate_workflow.rb
│   └── deliver.rb
└── tests/AGENTS.md
```

---

## 6. `product.yaml` 详解

完整示例见 `templates/product/product.yaml.example`。

### 6.1 必填与常用字段

```yaml
kit_version: "0.1.0"
name: my-product
display_name: "我的产品"

scopes:
  backend: true
  frontend: true
  mobile: false
  ios: false
  android: false

frontend_targets:
  web: true
  miniprogram: false

stacks:
  backend: node-api
  web: static-admin-web

delivery:
  max_rounds: 3
  evidence_root: /tmp/agent-delivery/my-product
  command_timeout_sec: 180
  checks:
    - id: workflow
      cmd: ["ruby", "scripts/validate_workflow.rb"]
    - id: backend-test
      when: "scopes.backend"
      cwd: backend
      cmd: ["npm", "test"]
  human_gates:
    - id: production-deploy
      description: "生产部署需人工批准"

kit:
  mode: link
  path: /absolute/path/to/agent-delivery-kit
```

### 6.2 `when` 表达式

交付 runner 与 checks 过滤支持：

| 表达式 | 含义 |
| --- | --- |
| 省略或 `true` | 始终执行 |
| `scopes.<name>` | 任务 `required_scopes` 优先，否则产品 `scopes` 为 true |
| `frontend_targets.<name>` | 任务 `frontend_targets` 优先，否则产品配置 |

> 跑 `deliver.rb <task>` 时，**以任务 front matter 为准**过滤 checks，这样同一产品可对「仅后端」任务跳过前端检查。

### 6.3 `truths`

映射文档路径，默认指向 `docs/*`。`doctor` 会在缺失时 **WARN**（不强制 FAIL，便于 stub 阶段）。

---

## 7. 日常脚本

均在**产品仓根目录**执行（包装脚本已设置环境变量）。

### 7.1 `doctor.rb`

```bash
ruby scripts/doctor.rb
```

检查：

- Ruby 版本
- `product.yaml` 结构
- kit 路径与 major 版本兼容
- 必备目录 `ideas/ tasks/ issues/ docs/ scripts/`
- stack 是否存在于 kit
- truths 路径是否存在（缺失仅警告）

退出码：`0` = OK，`1` = FAIL。

### 7.2 `validate_workflow.rb`

```bash
ruby scripts/validate_workflow.rb
```

校验：

- idea / task / issue YAML front matter
- id 格式与唯一性
- 状态枚举、优先级、owner
- idea ↔ task、task ↔ issue 双向链接
- `required_scopes` / `frontend_targets` 与 `scope_status` 一致性
- **frontend_targets 键集合来自 `product.yaml`**（不再写死仅 miniprogram/web，但默认模板仍使用这两者）

忽略 `ideas|tasks|issues/template.md`。

### 7.3 `deliver.rb`

```bash
ruby scripts/deliver.rb <task-name>
ruby scripts/deliver.rb <task-name> --max-rounds 3
DELIVERY_REPAIR_COMMAND='echo repair' ruby scripts/deliver.rb <task-name>
```

行为：

1. 读取任务 front matter  
2. 按 `when` 过滤 `delivery.checks`  
3. 在 `evidence_root/<task-id>/<run-id>/` 写每项 log 与 `report.md`  
4. 失败时可多轮；若设置 `DELIVERY_REPAIR_COMMAND` 则在轮次间执行  
5. **不会**自动把 `human_gates` 标为通过  

查找任务：优先 `tasks/<name>.md`，否则按 front matter `title` 匹配。

### 7.4 环境变量

| 变量 | 含义 |
| --- | --- |
| `PRODUCT_ROOT` | 产品仓根（包装脚本自动设置） |
| `KIT_ROOT` | kit 根（包装脚本根据 product.yaml 设置） |
| `DELIVERY_REPAIR_COMMAND` | 交付失败轮次间的修复命令 |

---

## 8. Agent 工作方式

### 8.1 默认：Code-First

用户优先要的是**高质量代码**，不是门禁运营。

1. 先完成 `docs/code-quality-prerequisites.md`  
2. **不**主动推进 task/issue 状态机（除非用户明确要求交付/状态/门禁）  
3. 用本地可运行验证证明行为  
4. 最小 diff，不扩大范围  

### 8.2 明确要求交付时

用户说 `交付 <task>` / `顺序完成` / 要求门禁时：

1. 遵循 `docs/delivery-workflow.md`  
2. 更新 front matter 与 handoff  
3. 实现后跑 `ruby scripts/deliver.rb <task>`  
4. 失败建 issue，修复后 `Ready for Retest`，仅 Test Agent 可 `Closed`  

### 8.3 短命令

见产品仓 `COMMANDS.md`（自 kit `core/COMMANDS.md` 拷贝）。常用：

```text
想法 <idea>      / idea <idea>
产品 <task>      / product <task>
架构 <task>      / architect <task>
后端 <task>      / backend <task>
前端 <task>      / frontend <task>
小程序 <task>    / miniprogram <task>
Web <task>       / web <task>
测试 <task>      / test <task>
交付 <task>      / deliver <task>
下一个 <role>    / next <role>
```

### 8.4 读序

见 `core/INSTRUCTION_ORDER.md`：

1. 产品 `AGENTS.md`  
2. `product.yaml`  
3. 流程与质量文档  
4. 最近角色 `AGENTS.md`  
5. 当前 task / issues  

---

## 9. Idea / Task / Issue

### 9.1 创建

```bash
cp ideas/template.md ideas/my-idea.md
# 编辑 front matter：id 形如 IDEA-20260716-001，status 从 Captured 起
```

任务与缺陷同理，使用 `tasks/template.md`、`issues/template.md`。

### 9.2 ID 格式

| 类型 | 格式 |
| --- | --- |
| Idea | `IDEA-YYYYMMDD-NNN` |
| Task | `TASK-YYYYMMDD-NNN` |
| Issue | `ISSUE-YYYYMMDD-NNN` |

### 9.3 状态机摘要

**Idea：** Captured → Discovering → Ready for Review → Approved → Promoted（或 Parked / Rejected）

**Task：** Draft → Ready for Architecture → Ready for Implementation → In Progress → Ready for Test → … → Done

**Issue：** Open → Assigned → Fixing → Ready for Retest → Closed（或 Retest Failed）

完整表见 `docs/delivery-workflow.md`。

### 9.4 优先级

`P0` > `P1` > `P2` > `P3`；同优先级时 `Ready for Retest` 优先于新功能。

---

## 10. 栈插件（stacks）

路径：`stacks/<id>/`

| 文件 | 作用 |
| --- | --- |
| `AGENTS.md` | 拷贝到对应产品目录 |
| `checks.yaml` | init 时合并进 `product.yaml` delivery.checks |
| `*.stub` | 拷贝并去掉 `.stub` 后缀 |

### 内置栈

| id | 产品目录 | 默认检查 |
| --- | --- | --- |
| `node-api` | `backend/` | `npm test`、`node --check src/app.js` |
| `static-admin-web` | `frontend/web/` | `node --check frontend/web/app.js` |
| `wechat-miniprogram` | `frontend/miniprogram/` | `node --check frontend/miniprogram/app.js` |
| `react-web` / `ios` / `android` | 预留 | 空 checks，可自行扩展 |

新增栈：在 `stacks/my-stack/` 增加 `AGENTS.md` + `checks.yaml` + 可选 stub，然后 init 时用 `--backend my-stack` 等参数引用。

---

## 11. 与 AI 工具对接

`adapters/` 提供薄封装模板（`.stub`，可按需拷到产品仓）：

| 工具 | 路径 |
| --- | --- |
| Claude | `adapters/claude/CLAUDE.md.stub` → 产品仓 `CLAUDE.md` |
| Cursor | `adapters/cursor/.cursor/rules/agent-delivery.mdc.stub` |
| Grok | `adapters/grok/skills/agent-delivery/SKILL.md.stub` |

原则：入口只指向 `AGENTS.md` + kit 流程，不把业务规则写进 adapter。

---

## 12. 示例工程

```bash
cd agent-delivery-kit
# examples/minimal-api-web 已用 init 生成（可 --force 重建）
cd examples/minimal-api-web
ruby scripts/doctor.rb
ruby scripts/validate_workflow.rb
cd backend && node --test test/app.test.js
```

说明见 `examples/README.md`。

---

## 13. kit 自测

在 kit 根目录：

```bash
ruby tests/test_product_config.rb
ruby tests/test_validate_workflow.rb
ruby tests/test_init_product.rb
```

全部应通过（exit 0）。

---

## 14. 从主寻职工程迁出 / 复用建议

| 步骤 | 动作 |
| --- | --- |
| 1 | 新产品直接 `init_product`（推荐） |
| 2 | 老仓：增加 `product.yaml`，scripts 改为薄包装指向本 kit |
| 3 | 业务 checks 从现有 `scripts/deliver.rb` 硬编码逻辑迁入 `product.yaml` / stack `checks.yaml` |
| 4 | 流程文档以 kit 为准升级；业务 ADR / openapi / database 留在老仓 |
| 5 | 将来可将 `agent-delivery-kit/` 拆成独立 Git 仓，产品用 submodule 或 `kit.path` 指向 |

**不要**把寻职业务 media、sqlite、招聘 ADR 放进 kit。

---

## 15. 版本与兼容

| 变更 | 版本位 |
| --- | --- |
| 新 stack、文档澄清 | MINOR |
| front matter 必填字段变更、状态机改名 | MAJOR |
| 纯 bugfix | PATCH |

`doctor`：产品 `kit_version` 与 kit `VERSION` 的 **major 必须一致**；minor/patch 不同仅警告。

---

## 16. 非目标（0.1 不做）

- 自动调用 LLM API 的编排服务  
- 云端任务看板  
- 替业务生成完整领域模型  
- 假装 human_gates 通过  
- 强制主寻职仓立刻切换到 kit scripts  

---

## 17. 常见问题

### doctor 报 kit not found

检查 `product.yaml` → `kit.path` 是否为存在的绝对路径，或 `vendored` 且 `vendor/agent-delivery-kit` 存在。

### validate 报 frontend_targets missing

任务 front matter 的 `frontend_targets` / `frontend_target_status` 键必须覆盖 `product.yaml` 声明的全部 target 键。

### deliver 找不到 task

确认 `tasks/<name>.md` 存在，或 front matter `title` 与参数一致；且不是仅有 `template.md`。

### Ruby 2.6 警告

可用；推荐升级到 Ruby 3+。kit 为兼容 macOS 系统 Ruby 2.6 做了最低版本放宽。

### 主工程 `scripts/deliver.rb` 与 kit 的关系

主寻职工程仍使用仓库根 `scripts/*`（业务 hardcode 检查）。kit 提供**通用化**实现；迁移时用产品仓包装 + `product.yaml.checks` 替代 hardcode。

---

## 18. 快速命令备忘

```bash
# 在 kit 内
ruby scripts/init_product.rb --path ../new-app --name new-app --preset api-web --kit-path "$(pwd)"
ruby tests/test_init_product.rb

# 在产品仓内
ruby scripts/doctor.rb
ruby scripts/validate_workflow.rb
ruby scripts/deliver.rb my-task
```

更细的状态机与门禁：产品仓 `docs/delivery-workflow.md`。  
设计全文：主仓 `docs/agent-delivery-kit-design.md`。
