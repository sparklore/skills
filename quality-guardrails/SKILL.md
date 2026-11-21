---
name: quality-guardrails
description: >-
  Full quality workflow templates: plan/changes/tests format, stage test gate
  details, anti-fake-tests, failure modes, anti-patterns. Use on any coding,
  refactor, or multi-step implementation after the short Always rule fires.
---

# Quality Guardrails（细则）

短铁律在 `.cursor/rules/quality-guardrails.mdc`（Always）。本 skill 展开模板与边界。

## Hard Requirements（展开）

1. **Plan before code** — 短计划含：intended change scope；data flow；edge cases；what will NOT be changed。
2. **Minimal, localized diffs** — 小步可组合；只 refactor 触及处，除非正确性要求。
3. **Follow existing project patterns** — 目录、命名、错误处理、日志/遥测、类型校验、依赖边界。
4. **Refactor for readability** — 避免 >2 层嵌套；复杂分支抽小函数；重复逻辑抽共享（有第二调用方时）。
5. **Add verification（阶段测试门）**
   - 非 trivial：单测 / 集成测 / 可运行验证片段 + 期望结果；不可自动化则给可勾选手动清单（禁空话）。
   - **汇报**：Tests/verification 须含 Agent 已执行的 PASS/FAIL；并按规则 `delivery-gate` 输出「验收步骤（可复制）」。
   - **每阶段门禁**：阶段结束必须新增/更新有效测试（或 Charter/plan 等价命令）并实跑；未 PASS 禁止进下一阶段；FAIL → 定位 → 同命令重跑 → 通过再继续。
   - **禁止造假过测**：删测、空断言、弱化断言、`skip` / `t.Skip` / `Only`、改期望迁就实现、口头「应该过」。
   - **收尾全量**：全部阶段完成后跑 Charter/plan 全量套件，写入最终验收证据。
   - 整单人闸：规则 `delivery-gate`「下一步动作」/ skill `acceptance-gate`。
6. **Self-check** — 编译/lint；无死代码；错误路径；无意外 N+1 / 无界循环。
7. **Tradeoffs** — 非显然方案 1～3 行说明 why。

## Output Format

1) Plan（bullet）  
2) Changes（file-by-file）  
3) Tests/verification（how to run + **已执行结果**）  
4) Notes（仅必要时）

## Failure Mode

- 需求不足：编码前最多 3 个针对性问题。
- 现有代码不清：先读相关文件；禁止猜着实现。

## Examples of what to avoid

- 复制粘贴大块
- 占位注释代替真实处理
- 无理由新依赖
- 大 refactor 无测试
- 关注点混杂（如 UI 直调 DB）
