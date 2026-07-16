# agent-delivery-kit

可版本化的**多 Agent 闭环交付套件**。  
业务产品仓只保留产品事实（requirements / architecture / openapi / database / 代码）与 `product.yaml`；流程、角色、校验与交付 runner 由本 kit 提供。

| | |
| --- | --- |
| 版本 | `0.2.0`（见 `VERSION`） |
| 运行时 | Ruby 2.6+（推荐 3+）；Node 用于部分 stack 检查 |
| 完整使用说明 | **[docs/USAGE.md](./docs/USAGE.md)** |
| 主业务迁移 | **[docs/MIGRATION.md](./docs/MIGRATION.md)** |

## 快速开始

### 新产品

```bash
cd agent-delivery-kit

ruby scripts/init_product.rb \
  --path ~/work/my-product \
  --name my-product \
  --display-name "我的产品" \
  --preset api-web \
  --mode link \
  --kit-path "$(pwd)"

cd ~/work/my-product
ruby scripts/doctor.rb
ruby scripts/validate_workflow.rb
```

### 既有主业务仓（不覆盖业务真相）

```bash
ruby scripts/adopt_product.rb \
  --path ~/work/agents-project \
  --name recruitment \
  --display-name "寻职" \
  --preset api-web-miniprogram \
  --mode link \
  --kit-path "$(pwd)"
```

详见 [docs/MIGRATION.md](./docs/MIGRATION.md)。

## 目录结构（摘要）

```text
agent-delivery-kit/
├── core/           # 根 AGENTS 模板、读序、命令说明
├── docs/           # 通用流程文档 + USAGE + MIGRATION
├── roles/          # 角色简报
├── schema/         # product / front matter schema
├── templates/      # idea/task/issue 与文档 stub
├── stacks/         # 技术栈插件（AGENTS + checks + stubs）
├── scripts/        # init / adopt / validate / deliver / doctor + lib
├── adapters/       # Claude / Cursor / Grok 入口
├── examples/       # minimal-api-web
└── tests/          # kit 自测
```

## 核心脚本

| 脚本 | 作用 |
| --- | --- |
| `scripts/init_product.rb` | 脚手架生成**新产品**仓 |
| `scripts/adopt_product.rb` | **既有**产品仓非破坏性接入 |
| `scripts/doctor.rb` | 检查 product + kit 接线 |
| `scripts/validate_workflow.rb` | 校验 idea/task/issue |
| `scripts/deliver.rb` | 按 `product.yaml` checks 交付（支持 glob / service_http） |
| `scripts/check_static_web.rb` | 通用静态 Web 存在性检查 |

## 三层模型

```text
L0  kit 规则与引擎
L1  product.yaml + stacks
L2  产品真相与代码（产品仓）
```

## 0.2 对主业务的关键增强

- 声明式 checks：`glob` 批量语法检查、`type: service_http` 本地健康检查（`{{port}}`）
- 默认 stack checks 对齐「后端测试 + 语法 + health + 小程序 + Web」闭环
- `adopt_product` 备份旧 scripts 到 `scripts/legacy/`，业务 docs 不覆盖
- CI：`.github/workflows/ci.yml`

## 自测

```bash
ruby tests/test_product_config.rb
ruby tests/test_validate_workflow.rb
ruby tests/test_init_product.rb
ruby tests/test_adopt_product.rb
ruby tests/test_delivery_runner.rb
```

## 许可

MIT — 见 `LICENSE`。
