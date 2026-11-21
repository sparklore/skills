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

本 skill 只负责把下列规则按顺序拉起；条文以规则为准，本文件不另写一份。

## 何时用

- 用户输入 `/ship-gate` 或说「验收门」「按 charter…」
- 用户说「落地执行 / 开干」且本会话已确认走验收门
- 功能实现、修复、多步改造的关单前

## 顺序（MUST）

1. **Charter**：按规则 `session-plan`「Charter」；未确认前不写仓，`Plan only` 时禁止写仓。
2. **先设计再改**：非 trivial → skill `design-first-feature`；触及架构维度 → 规则 `architecture`。
3. **签字门**：触发时按规则 `session-plan`「Sign-off gate」，等 **C=是**。
4. **每步汇报**：用规则 `delivery-gate`「Per-step reply」块；「验收证据」下加一行「需求对照」，逐条 `[x]` / `[ ]`。
5. **失败熔断**：按 `delivery-gate`「下一步动作」：FAIL 只纠偏、同命令重跑，同症状 ≤3 次。
6. **关单**：全部 PASS 后写「可最终验收」清单（1～3 条），停住等用户「验收通过」。

## 禁止

- 无证据宣称完成
- PASS 前或用户确认前换新需求 / 新 charter
- 「应该能过」「逻辑上没问题」代替命令结果
