---
name: sparklore-context
description: |
  Thin workspace pointer for Sparklore forge + clients. Use when working in this
  repo, when the user types /sparklore, or when an agent needs the current mental
  model. Does NOT override AGENTS.md or architecture gates — it only points to them.
---

# Sparklore — 工作区指针（非 SSoT）

> **本 skill 不是权威源。** 规则与禁止项以根目录 [`AGENTS.md`](../../AGENTS.md) 与四闸 [`sparklore-architecture-gates`](../sparklore-architecture-gates/SKILL.md) 为准；冲突时以它们为准，并报告本文件漂移。

## 1. 先读什么（每次任务）

按 [`AGENTS.md`](../../AGENTS.md) §1：

1. [`docs/README.md`](../../docs/README.md) → 前 4 篇：`01` 产品、`02` 数据驱动、`03` 架构、`04` 台账  
2. 动哪块再读对应专项（`docs/06` WidgetDSL、`08` 同步、`27` Quest v2 等）  
3. 术语：[`GLOSSARY.md`](../../GLOSSARY.md)

## 2. 两仓心智（摘自 docs/03）

| 仓 | 管什么 |
|---|---|
| **sparklore-forge** | 平台：Quest 运行、PG、合集发布、BFF、bridge、共享模块 `ud/` `widgetdsl/` `genspec/` `genloop/` `vecsearch/` |
| **sparklore-clients** | 本机优先用户端：`ud_sync`/`ud_local` KV、嵌入式 Quest Engine v2、widget 三档、hydrate/orb、设备能力 |

边界硬事实：

- clients → 平台只走 **HTTP（BFF）**；clients **不直连云端 NATS / PG**  
- 同步类数据经 **bridge HTTP**（`/v1/me/rev/*`）；本机类只经 clients 本地接口  
- 业务 UI / 流程必须 **QuestFlow + Record + WidgetDSL**，禁止业务 Go capability / `/api/<feature>/*`（见 AGENTS §5）

进程速查（细节与端口以 [`docs/03`](../../docs/03-tech-architecture.md) / [`docs/09`](../../docs/09-tech-run-and-verify.md) 为准）：

- forge：`quest` `:8080`、`bff` `:8081`、`bridge` `:8082`、`agent`（NATS）  
- clients：`sparklore` `:8090`、`desktop`  
- 日常启停优先 **`make panel`**（[`docs/agents/forge.md`](../../docs/agents/forge.md)）

## 3. 动手顺序（对齐 AGENTS，不是另套硬闸）

1. **识别**任务类型（问答 / 审计 / 文档 / 代码）  
2. **探路**：`graphify query|path|explain`（见 [`CLAUDE.md`](../../CLAUDE.md)）；有 `.codegraph/` 再用 codegraph。**禁止** GitNexus / `gitnexus_*`（本仓未部署）  
3. **过闸**：触及架构闸 → 读四闸；业务名进 Go/JS → **立即警告**并给数据驱动替代方案  
4. **复杂任务**：Session Charter / plan-execution-gate / acceptance-gate（按规则触发，非「每一行都等 yes」）  
5. **执行**：最小 diff；不静默编排、不搬家冒充删除  
6. **验证**：实跑相关测试/命令，贴 PASS/FAIL；未跑不得宣称完成  

## 4. 查代码与命令

| 要做什么 | 用什么 |
|---|---|
| 结构 / 调用关系 | `graphify query "…"` / `graphify path A B` |
| 改完更新图 | `graphify update .`（AST-only） |
| 日常启停 / 装 Skills | `make panel` → 控制台卡片 |
| forge / clients 命令地图 | [`docs/agents/forge.md`](../../docs/agents/forge.md)、[`docs/agents/clients.md`](../../docs/agents/clients.md) |
| NATS subject 常量（平台） | `internal/contract/subjects.go`（**不是**已删除的 `sparklore/pkg/subjects`） |

## 5. 近失登记（现网）

写代码前扫一眼 [`mistakes/`](mistakes/)：数据驱动、静默编排、僵尸双轨、探路工具。详细条文仍以四闸与 `docs/02` 为准。

## 6. 决策树

见 [`references/decision-tree.md`](references/decision-tree.md)。旧 Datastar/templ 速查已废弃，见同目录说明。
