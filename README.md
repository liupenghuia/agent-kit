# agent-delivery-kit

与业务无关的**多 Agent 交付框架**（流程约定 + 校验 + 本地交付 runner）。

产品是什么由你在**产品仓**里定；本仓库不包含业务需求、示例产品或领域代码。

| | |
| --- | --- |
| 版本 | `0.2.1`（见 `VERSION`） |
| 运行时 | Ruby 2.6+（推荐 3+）；Node 仅在启用对应 stack 检查时需要 |
| 使用说明 | [docs/USAGE.md](./docs/USAGE.md) |
| 既有仓接入 | [docs/MIGRATION.md](./docs/MIGRATION.md) |

## 快速开始

```bash
cd agent-delivery-kit

ruby scripts/init_product.rb \
  --path ~/work/my-product \
  --name my-product \
  --display-name "My Product" \
  --preset api-web \
  --mode link \
  --kit-path "$(pwd)"

cd ~/work/my-product
ruby scripts/doctor.rb
```

既有仓库（不覆盖业务文档/代码）：

```bash
ruby scripts/adopt_product.rb \
  --path ~/work/existing-app \
  --name my-product \
  --preset api-web \
  --mode link \
  --kit-path "$(pwd)"
```

## 目录

```text
core/        根 AGENTS 模板、读序、命令
docs/        通用流程文档（非业务）
roles/       角色简报
schema/      product / front matter 形状
templates/   idea/task/issue 与文档 stub
stacks/      技术栈插件（AGENTS + checks + stubs）
scripts/     init / adopt / doctor / validate / deliver
adapters/    Claude / Cursor / Grok 入口
tests/       仅测 kit 引擎本身（不是业务测试）
```

## 脚本

| 脚本 | 作用 |
| --- | --- |
| `init_product.rb` | 新建空产品仓骨架 |
| `adopt_product.rb` | 既有仓接入（备份旧 scripts，不覆盖真相文档） |
| `doctor.rb` | 接线检查 |
| `validate_workflow.rb` | idea/task/issue front matter |
| `deliver.rb` | 按 `product.yaml` 的 checks 跑验证 |

## 三层模型

```text
L0  kit（本仓库）
L1  产品仓 product.yaml + 选用的 stacks
L2  产品真相与代码（只在产品仓）
```

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
