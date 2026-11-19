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

1. `graphify query` 定向（SQLite / graph / foundry / genPrompt / SyncStore）——勿先全仓瞎扫。
2. 按 [checklist.md](checklist.md) 跑命令；每条标 **已确认 / 部分确认 / 未能核验**。
3. 分级输出（见下）；区分「台账已登记的旧债」与「声称已清但仍在的新债」。
4. 给下一步：小修复 vs 须先写 `docs/design/` 的架构迁出。触及编排/硬编码时，改前仍走 `no-silent-orchestration` 五问闸。

## 输出格式

```markdown
## 结论（1～2 句）

## P0/P1 违规（数据驱动 / 静默编排 / 双轨）
| # | 类别 | 位置 | 证据 | 为何违规 | 正解方向 |
|---|---|---|---|---|---|

## P2 死代码 / 死路由 / 文档漂移
| # | 位置 | 证据 | 建议 |

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
