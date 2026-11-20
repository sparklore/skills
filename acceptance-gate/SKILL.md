---
name: acceptance-gate
description: >-
  Enforces charter → design-first → evidence per step → no "done"/topic switch
  until PASS and user says 验收通过. Use when user says /ship-gate, 验收门,
  ship-gate, 按 charter 先设计再改, or wants acceptance before next topic.
disable-model-invocation: true
---

# Acceptance Gate（验收门）

用户口令（须按字面遵守）：

> 按 charter：先设计再改；每步给验收证据；未 PASS 不宣称完成、不换题；PASS 后等我回复「验收通过」再继续。

## 何时用

- 用户输入 `/ship-gate` 或说「验收门」「按 charter…」
- 用户说「落地执行 / 开干」且本会话已确认走验收门
- 功能实现、修复、多步改造的关单前

## 流程（MUST 顺序）

1. **Charter**（若尚未确认）：输出轻量或完整 Session Charter，等用户确认；`Plan only` 时禁止写仓。
2. **先设计再改**：非 trivial → 按 `design-first-feature` 出短设计（含 Verification Plan）；用户批准或 trivial 声明后再改代码。
3. **落地执行**：按 plan / todo 小步改；遵守 `plan-execution-gate`（若触发签字门）。
4. **每步结束**用固定块（可与 `step-next-redo` 合并）：

```markdown
### 本步已完成
- <一句话>

### 验收证据
- 命令：`<exact command>`
- 结果：PASS | FAIL — <摘要>
- 需求对照：
  - [x] …
  - [ ] …（未过则说明）

### 下一步动作
- FAIL → 纠偏（不换题）
- PASS → 等待用户「验收通过」；禁止开启下一话题
```

5. **自动纠偏**：FAIL → 最小 diff 修复 → **同一命令**重跑 → 仍 FAIL 则停下汇报，不换题。
6. **关单**：全部交付物 PASS 后写「可最终验收」清单（1～3 条），**停住**直到用户「验收通过」。

## 禁止

- 无证据宣称完成
- PASS 前或用户确认前换新需求 / 新 charter
- 「应该能过」「逻辑上没问题」代替命令结果

## 与 rules 关系

硬约束见 alwaysApply 规则 `acceptance-before-next-topic`；本 skill 提供可 `/ship-gate` 显式拉起的完整流程。
