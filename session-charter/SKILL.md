---
name: session-charter
description: >-
  Opens a session with a Session Charter contract—goal, writable paths,
  deliverables, acceptance, and mode. Use when starting complex tasks, multi-file
  work, or when the user says 开会话 / session charter / 本会话合同.
disable-model-invocation: true
---

# Session Charter（7.2）

## 何时用

- 新复杂任务（多文件、架构、docs 大改）
- 用户说「开会话」「charter」「本会话只做什么」
- 规则 `session-charter-reminder` 触发后需完整模板

## 流程

1. 若用户已给 charter → 复述确认一句，再开始
2. 若信息不足 → 用模板填空（最多问 3 个 targeted 问题）
3. 用户确认后开始；模式为 Plan only 时禁止写文件

## 模板（复制给用户确认）

```markdown
# Session Charter（本会话合同）

## 唯一目标（一句话）
{例如：清洗 docs/architecture/xxx.md 并与代码对齐}

## 仓库
- 可写：{绝对路径列表}
- 只读：{例如 sparklore/docs/**}
- 禁止：{删文件、改 ADR 编号、动已发布 migration…}

## 交付物
- [ ] {审核报告}
- [ ] {diff ≤N 行}
- [ ] {CHANGELOG 一条}

## 验收
{make test / curl / 人工检查清单}

**须含：** Agent 执行的验收证据 + 「验收步骤（可复制）」小白向操作（见规则 `step-next-redo`）。

## 模式
- 当前：Plan only | Agent execute
- 超过 {N} 步须停下汇报「下一步动作」

确认后再开始。
```

## Agent 行为

- Charter 确认前：只读探索可接受，**不写仓**
- `Agent execute` 且涉及 plan 时，仍须遵守 `plan-execution-gate` 规则
