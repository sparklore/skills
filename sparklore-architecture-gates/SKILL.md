---
name: sparklore-architecture-gates
description: >-
  Sparklore architecture hard gates: data-driven (zero use-case hardcoding),
  no silent orchestration, no zombie dual-track. Use on EVERY code change in
  sparklore-forge or sparklore-clients — features, refactors, Foundry, Quest,
  WidgetDSL, admin APIs, freeze.txt, cleanup/purge. Also when the user mentions
  数据驱动、硬编码、静默编排、僵尸、双轨、freeze、QuestFlow, or types /sparklore-gates.
  Includes audit-evidence grading (G1/G2/G3) for any 审计报告 / 台账 / 复查结论.
  This skill is the shared SSoT for Cursor, Claude Code, and other agents;
  tool-local copies under .cursor/rules or ~/.claude/rules are mirrors only.
---

# Sparklore 架构三闸（跨工具 SSoT）

在 `sparklore-forge` / `sparklore-clients` 里改代码前，必须过这三道闸。完整条文在 `rules/`；本文件只留动手顺序。

| 闸 | 文件 | 一句话 |
|---|---|---|
| 数据驱动 | [rules/data-driven.md](rules/data-driven.md) | 业务进合集 / QuestFlow / Record / WidgetDSL；Go/JS 无业务名 |
| 禁止静默编排 | [rules/no-silent-orchestration.md](rules/no-silent-orchestration.md) | 重试/串并行/prompt/兜底先说明；能放 QuestFlow 默认否决 Go/JS |
| 禁止僵尸双轨 | [rules/no-zombie-dual-track.md](rules/no-zombie-dual-track.md) | 单真相；测产同构；搬家≠删除 |
| 审计证据分级 | [rules/audit-evidence.md](rules/audit-evidence.md) | **写报告时**（非每改必做）：每条发现标 `G1`/`G2`/`G3`；`G3` 不得带预估或波次 |

项目长文：宿主仓 `docs/02-rules-data-driven.md`、`AGENTS.md` §5、`docs/04` 台账。  
只读复查：兄弟 skill [`architecture-compliance-audit`](../architecture-compliance-audit/SKILL.md)。

## 每改必做

1. **两问**（`data-driven`）：删该应用要不要改 Go/JS？新应用要不要加 Go/JS？任一「要」→ 停手警告，给数据驱动替代方案。
2. **五问**（`no-silent-orchestration`，写进回复）：坏在哪 / 可观察好处 / 为何不进 QuestFlow / 失败对外长什么样 / 退场台账。未答完或用户未说「可以改」→ 禁止改代码。
3. **三问**（`no-zombie-dual-track`）：生产谁调用？删了谁红？有无第二真相？

## 写审计 / 台账 / 复查结论时

另过 [rules/audit-evidence.md](rules/audit-evidence.md)：每条发现标 `G1 已确认` / `G2 读过链` / `G3 推断`；`G3` 行只许写「待核验 + 下一步跑什么」，**禁止**带预估、波次、方案选择。集合差集（前端有 / 后端无）只支持「少了什么」，不支持「删掉即可」。

## 立即拦截（禁止静默照写）

- 新增业务 `capability`、`/api/<feature>/*`、`widgetdsl` 业务 `kind`
- Go/JS 硬编码业务 prompt、领域评分/术语当产品规则
- 往 `freeze.txt` 冻结段加行，或拆文件搬家冒充迁出
- 前端 `postMessage`/轮询串多条工作流；确定性假成功；写失败变成功

拦截话术：

> 该方案违反「Data-Driven Quest + Declarative WidgetDSL」铁律。应把流程放进 QuestFlow / 合集数据；Go 只留原子工具。需要豁免请明确说「豁免」并登记 `docs/04`。

## Eval 跑法（本地打分，不调模型）

契约闸只查字段；打分器对**已写好的回答文件**按 `assertions.must_include` / `must_not` 逐条判 PASS/FAIL。`disguised: true` 的用例模拟普通需求口吻（prompt 不得出现「审计 / 合规 / 规则 / 闸 / 闸名」等考试暗示词），看 Agent 是否仍主动拦截。

1. **生成回答文件**：对 `evals/evals.json` 里每条 `prompt`，让人或 Agent 按本 SKILL / `rules/` 作答，存成 `<answers_dir>/<id>.md`。缺文件算 FAIL。
2. **校验契约**（forge 仓根）：

```bash
python3 skills/sparklore-architecture-gates/scripts/validate_evals.py
```

3. **打分**（任一 FAIL → 退出码 1；合格样例期望 exit 0，违规样例期望 exit 1）：

```bash
python3 skills/sparklore-architecture-gates/scripts/score_evals.py skills/sparklore-architecture-gates/evals/answers-pass
python3 skills/sparklore-architecture-gates/scripts/score_evals.py skills/sparklore-architecture-gates/evals/answers-fail
```

打分器从 S2（`architecture-compliance-audit/scripts/score_evals.py`）**复制**而来（非跨 skill 参数化）：算法相同且刻意很小，各自 skill 自带 `ROOT`/`evals.json`，避免兄弟目录耦合。评分标准只在 eval 数据里。

## 装到本机各工具

见 [INSTALL.md](INSTALL.md)。改 `rules/*.md` 后跑 `./sync-adapters.sh`，再拷到 Cursor / Claude 本地目录。
