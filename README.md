# sparklore/skills

远程仓库 [`github.com/sparklore/skills`](https://github.com/sparklore/skills) 的本地备份检出（forge 里通常是子模块）。**改完推远程后，必须再装到三处活镜像，保持一致——不要只改本目录当已生效。**

## 真相与镜像

| 角色 | 路径 |
|---|---|
| **远程备份 / 编辑入口** | 本目录（推到 `sparklore/skills`） |
| **活镜像（Agent 实际读）** | `~/.claude/{rules,skills}` · `~/.cursor/{rules,skills}` · `<forge>/.cursor/{rules,skills}` · `<forge>/.agents/skills` |

手改活镜像会被下次安装覆盖。三处不一致 = 双轨，禁止。

## 目录

| 目录 | 用途 |
|---|---|
| [`sparklore-architecture-gates/`](sparklore-architecture-gates/) | **四闸正文 SSoT** |
| [`claude/rules/`](claude/rules/) | 非闸共享规则 SSoT + 四闸生成镜像；Claude 专用 `worktree.md` |
| [`cursor/rules/`](cursor/rules/) | **生成物**（勿手改） |
| [`overlays/`](overlays/) | 工具专用正文（现仅 `graphify.md`） |
| [`architecture-compliance-audit/`](architecture-compliance-audit/) | 只读合规审计（按需） |
| [`sparklore-context/`](sparklore-context/) · [`event-storming/`](event-storming/) | 既有 skills |

## 改完怎么同步

**优先：** 本地控制台 →「Agent 工具」→「安装 Agent 规则与 Skills」。

终端：

```bash
# 在 skills/ 下：规则三处 + skills 树一并安装
./install-local.sh

# 或分步
./sync-tool-rules.sh --install-local   # 规则 → ~/.claude、~/.cursor、项目 .cursor
cd sparklore-architecture-gates && ./sync-adapters.sh --install-local  # 四闸 + skill 树
```

改规则正文：

1. **四闸** → `sparklore-architecture-gates/rules/*.md`
2. **其它共享规则** → `claude/rules/*.md`（纯 Markdown，无 Cursor frontmatter）
3. **graphify** → `overlays/graphify.md`
4. 跑 `./sync-tool-rules.sh`（生成 `cursor/rules`），再 `./install-local.sh`，最后提交并推远程。
