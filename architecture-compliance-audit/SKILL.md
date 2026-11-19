---
name: architecture-compliance-audit
description: >-
  Audits sparklore-forge / sparklore-clients for data-driven violations, silent
  orchestration, hardcoding, zombie dual-track, and dead routes. Use when the
  user asks to 审核架构合规、查硬编码、查静默编排、查僵尸双轨、复查 purge、
  对照 docs/02 或 AGENTS.md §5, or after a large cleanup commit.
---

# 架构合规审计（Sparklore）

只读审计。先出问题清单，**不改代码**；用户说「可以改」后再按严重度动手。

权威条文（跨工具 SSoT）：

- [`../sparklore-architecture-gates/rules/`](../sparklore-architecture-gates/rules/)
- 宿主仓 `docs/02-rules-data-driven.md`、`AGENTS.md` §5

## 流程

0. 先跑 [checklist.md](checklist.md) §0 **仪器自检**（在 forge 仓根、clients 在位）。不过就停——`rg` 在路径不在位时同样退出 0，「没扫」与「干净」输出同形。
1. `graphify query` 定向（SQLite / graph / foundry / genPrompt / SyncStore）——勿先全仓瞎扫。
2. 按 checklist 跑命令；每条按 `audit-evidence` 标 **`G1` 已确认 / `G2` 读过链 / `G3` 推断**；跑不了的标「未能核验」并写为什么。
3. **集合差集命中必须反向走链**（见下节），否则「正解方向 / 建议」列只能写「待核验」。
4. 分级输出（见下）；区分「台账已登记的旧债」与「声称已清但仍在的新债」。
5. 给下一步：小修复 vs 须先写 `docs/design/` 的架构迁出。触及编排/硬编码时，改前仍走 `no-silent-orchestration` 五问闸。

## 反向走链（填「正解方向 / 建议」列的前置）

路由差集、零调用、死文件这类**集合差集**只说明「少了什么」，不说明「删掉即可」。下结论前从可见入口正向走一遍，每跳记 `file:line`：

1. 可见入口在哪（按钮 / 菜单 / 页面；按 `visible-entry`，入口在注释里不算）
2. 它**实际**打哪条路由——很可能是另一条还活着的路由
3. 那条后端 handler 现在还做不做事（起 run？写库？发事件？）
4. 两端响应字段是否同形（前端读的 `res.<field>` vs 后端实际返回的键）
5. 按建议删掉之后，第 3 步那件事还会不会继续发生、谁还能观察到

任何一步没走，这条只能是 `G3`。

## 输出格式

```markdown
## 结论（1～2 句）

## P0/P1 违规（数据驱动 / 静默编排 / 双轨）
| # | 档 | 类别 | 位置 | 证据（命令 / `file:line`） | 为何违规 | 正解方向 | 待核验 |
|---|---|---|---|---|---|---|---|
（`正解方向` 只许 `G1`/`G2` 行填；`G3` 行该格留空，内容写进「待核验」）

## P2 死代码 / 死路由 / 文档漂移
| # | 档 | 位置 | 反向链（谁触发 → 实际打哪条活路由 → 后端还做不做事） | 证据 | 建议 |
|---|---|---|---|---|---|

## 已确认清干净
- …

## 未跑项
- （没跑的测试/E2E 明确写「未验证」）
```

## 类别速查

| 类别 | 抓什么 |
|---|---|
| 数据驱动 | 业务名进 Go/JS；`/api/<feature>/*`；业务 capability；Go 内业务 prompt；freeze 加行 |
| 静默编排 | 私有重试/修复环；确定性假成功；前端串多 API；`normalize*` 静默改写；失败变成功 |
| 僵尸双轨 | 生产 0 调用 + 测试续命；`graph`+`flow`；搬家冒充删除；nil 防护吞失败 |
| 死代码 | 前端调已删路由；文案承诺已无能力；docs/台账与代码不符 |

## 硬约束

- 遵守 `dont-read-junk`（不扫 `vendor/`、`node_modules/`、`bin/`、`assets/living/`）。
- 台账 §4 已登记项标「已知债」，**禁止当模板扩写**。
- 未跑检查禁止写「已验证 / 全绿」。
- 每条发现按 `audit-evidence` 标档。**`G3` 行禁止带预估、波次、工期、方案选择。**
- 一行只记一个声明。「位置」是 `G1` 而「正解方向」是 `G3` 时拆两行，禁止共用一个档。
- 写了前置却没跑，**禁止**让它影响任何数字（预估 / 波次）。
- 豁免按**调用链**写，点名豁免哪条链。禁止整文件或整子系统一次性豁免——同一个 `app.js` 里既有良性 SSE 汇聚，也有业务轮询 + 前端重试编排。
- 引规则时连它指向文件的**段头与作用域**一起读（`freeze.txt` 的「引擎段可以增加」≠「冻结段只能删」）。
