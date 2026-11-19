# 跨工具安装（Cursor / Claude / 其他 Agent）

**SSoT = 本目录 `rules/*.md`（纯 Markdown，无 Cursor 专用 frontmatter）。**  
各工具本地文件都是镜像；改规则只改 `rules/`，再同步。

仓库：`github.com/sparklore/skills`，路径 `sparklore-architecture-gates/`。  
在 forge 工作区里通常是子模块：`sparklore-forge/skills/sparklore-architecture-gates/`。

## 一键同步镜像

**优先：** 本地控制台 →「Agent 工具」→「安装 Agent 规则与 Skills」（可勾选，默认全选）→ 执行。  
终端仅排障时用：

```bash
./sync-adapters.sh
# 写入本机 Claude / Cursor 规则与 skill 镜像（省略选择 = 全部）
./sync-adapters.sh --install-local
# 可选子集（显式空值 = 该项不装）
./sync-adapters.sh --install-local \
  --rules=data-driven,no-silent-orchestration,no-zombie-dual-track \
  --skills=sparklore-architecture-gates,architecture-compliance-audit \
  --targets=cursor-rules,claude-rules,cursor-skills,agents-skills
```

`--install-local` 按勾选写入：

| 目标 id | 路径 |
|---|---|
| `cursor-rules` | `<forge>/.cursor/rules/{name}.mdc` |
| `claude-rules` | `~/.claude/rules/{name}.md` |
| `cursor-skills` | `<forge>/.cursor/skills/<skill>/` |
| `agents-skills` | `<forge>/.agents/skills/<skill>/` |

## 各工具怎么吃到「always」

| 工具 | 机制 | 做法 |
|---|---|---|
| **Cursor** | `.cursor/rules/*.mdc` + `alwaysApply: true` | `sync-adapters.sh --install-local`；或 Skills 里启用本 skill |
| **Claude Code** | `~/.claude/rules/*.md` 或项目 `.claude/rules/` | `--install-local`；或 `/plugin` / 手工链到本 skill |
| **Codex / 读 AGENTS.md 的 Agent** | 入口文档 | 宿主仓 `AGENTS.md` §3/§5 已指针到本目录；保持摘要与 `rules/` 一致 |
| **任意支持 Agent Skills 的工具** | `SKILL.md` description 触发 | 把本目录（或整个 `sparklore/skills`）加入该工具的 skills 路径 |
| **Windsurf / Continue / 其他** | 项目规则或 system prompt | 把 `rules/*.md` 拷进其 rules 目录，或在 system 里写「必读 skills/.../rules/」 |

## 团队约定

1. **改闸只改** `skills/sparklore-architecture-gates/rules/*.md`，提 PR 到 `sparklore/skills` 的 `dev-merge`（或团队主分支）。
2. 合入后各人在 forge 根：`git submodule update --remote skills`（或按团队流程更新子模块指针），再在本地控制台点「安装 Agent 规则与 Skills」（或终端 `./sync-adapters.sh --install-local`）。
3. **不要**只改本机 `.cursor/rules` 或 `~/.claude/rules` 当真相——下次同步会被覆盖。
4. 审计类按需 skill：`../architecture-compliance-audit/`（不是 always）。

## Claude 专项说明

Cursor 的 `alwaysApply: true` **不会**作用到 Claude。Claude 要靠：

- `~/.claude/rules/*.md`（推荐，与 `--install-local` 一致），或  
- 本 skill 被 Claude 的 skill 发现路径加载（description 已写成「任何 forge/clients 改动都用」）。

两者都装最稳：rules 管每轮硬闸，skill 管长文与审计入口。
