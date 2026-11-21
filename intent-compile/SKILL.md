---
name: intent-compile
description: >-
  Compiles vague user intent into explicit requirements, hidden constraints, and
  an executable prompt. Use when the user says 整理我说的 / 完善我说的 / 补充隐性 /
  给提示词 / 意图编译, or sends a short vague request expecting a full prompt back.
---

# 意图编译（7.6）

## 触发

用户消息包含或等价于：

- 整理我说的 / 完善我说的 / 补充隐性 / 补充我没说到的
- 给提示词 / 生成完整 markdown 提示词
- 意图编译

## 输出顺序（固定，不得跳步）

1. **整理你说的（显式）** — 表格列出显式需求
2. **补充隐性约束** — 边界、非目标、风险、验收、Ask/Agent 模式
3. **缺信息处理** — 最多 3 个 targeted 问题；否则写清假设
4. **完整可执行 prompt** — markdown 代码块，可直接复制给 Agent
5. **不要做什么** — ≥5 条

## 上下文块（从用户消息或仓库推断）

```markdown
## 上下文
- 仓库：{path}
- 相关 ADR/文档：{@file}
- 模式：{Plan only | 先 prompt 后执行 | 只分析}
```

## 与 Plan 门的关系

- 若输出 prompt 含「按计划执行」，提醒用户须走规则 `session-plan`「Sign-off gate」（C=是）
- 用户只要 prompt、未要执行 → 默认不调用写文件工具

## 质量要求

- 隐性约束要**可执行**（路径、禁止项），不要空话
- prompt 内写清交付物与验收
- 不擅自扩大 scope

## 反例

- ❌ 只复述用户原话
- ❌ 隐性部分只写「注意安全」「注意性能」
- ❌ 未给「不要做什么」
