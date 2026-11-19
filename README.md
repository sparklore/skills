# sparklore/skills

团队共享的 Agent Skills 与跨工具架构闸。分支以仓库当前默认 / `dev-merge` 为准。

| 目录 | 用途 |
|---|---|
| [`sparklore-architecture-gates/`](sparklore-architecture-gates/) | **数据驱动 / 禁静默编排 / 禁僵尸双轨** — 跨 Cursor、Claude、其他 Agent 的 SSoT |
| [`architecture-compliance-audit/`](architecture-compliance-audit/) | 只读合规审计（按需） |
| [`sparklore-context/`](sparklore-context/) | 项目上下文与硬闸（既有） |
| [`event-storming/`](event-storming/) | Event Storming 引导（既有） |

## 架构三闸（新人）

```bash
cd sparklore-architecture-gates
./sync-adapters.sh --install-local   # Cursor .mdc + ~/.claude/rules + 本地 skill 镜像
```

说明见 [`sparklore-architecture-gates/INSTALL.md`](sparklore-architecture-gates/INSTALL.md)。
