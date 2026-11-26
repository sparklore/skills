# 跨工具安装（Cursor / Claude / 其他 Agent）

**SSoT = 本目录 `rules/*.md`（纯 Markdown，无 Cursor 专用 frontmatter）。**  
各工具项目内文件都是镜像；改规则只改 `rules/`，再同步到目标仓库。

仓库：`github.com/sparklore/skills`，路径 `sparklore-architecture-gates/`。  
在 forge 工作区里通常是子模块：`sparklore-forge/skills/sparklore-architecture-gates/`。

## 一键同步镜像（仅项目根，不写用户全局）

**优先：** 本地控制台 →「Agent 工具」→「安装 Agent 规则与 Skills」（可勾选，默认全选）→ 执行。  
终端仅排障时用：

```bash
./sync-adapters.sh
# 写入「项目根」下的 Claude / Cursor 规则与 skill（省略选择 = 全部）
./sync-adapters.sh --install-local
# 装到任意仓库（clients / 其他仓）
./sync-adapters.sh --install-local --project-root=/path/to/repo
# 可选子集（显式空值 = 该项不装）
./sync-adapters.sh --install-local \
  --project-root=/path/to/repo \
  --rules=audit-evidence,data-driven,no-silent-orchestration,no-zombie-dual-track \
  --skills=sparklore-architecture-gates,architecture-compliance-audit,intent-compile,session-charter,acceptance-gate \
  --targets=cursor-rules,claude-rules,cursor-skills,agents-skills
```

`--install-local` 按勾选写入（**只写 `--project-root`，默认 = `skills/` 的父目录**；**永不写** `~/.claude` / `~/.cursor`）：

| 目标 id | 路径 |
|---|---|
| `cursor-rules` | `<project>/.cursor/rules/{name}.mdc` |
| `claude-rules` | `<project>/.claude/rules/{name}.md` |
| `cursor-skills` | `<project>/.cursor/skills/<skill>/` **与** `<project>/.claude/skills/<skill>/` |
| `agents-skills` | `<project>/.agents/skills/<skill>/` |

全量规则（含非闸）请用上一级 [`../install-local.sh`](../install-local.sh)（控制台「安装 Agent 规则与 Skills」已指向它）：

```bash
../install-local.sh --project-root=/path/to/sparklore-clients
```

## 各工具怎么吃到「always」（团队不全用 Cursor）

同一仓库内，**Cursor / Claude / 其他 Agent 各自读项目根下的目录**；安装必须两边（或多边）都写齐，禁止只装 Cursor、也禁止写 `~`。

| 工具 | 机制 | 项目内路径 |
|---|---|---|
| **Cursor** | `.cursor/rules/*.mdc` + `alwaysApply` | `<project>/.cursor/{rules,skills}` |
| **Claude Code** | 项目 rules + skills | `<project>/.claude/{rules,skills}` |
| **Codex / 读 AGENTS.md** | 入口文档 | 宿主仓 `AGENTS.md` §3/§5 |
| **Gemini / Antigravity** | 当前上游仍偏全局 `~/.gemini` | **未**再写 home；项目内路径待定（勿假装已装） |
| **其他（Windsurf / Continue / …）** | 项目 rules 或 system prompt | 拷 `rules/*.md` 或指向本 skill |

`cursor-skills` 目标会同时写入 `.cursor/skills` **与** `.claude/skills`，避免 Claude 用户打开同仓时缺 skill。

## 团队约定

1. **改闸只改** `skills/sparklore-architecture-gates/rules/*.md`，提 PR 到 `sparklore/skills` 的 `dev-merge`（或团队主分支）。
2. 合入后各人更新子模块指针，再对**每个要打开的仓库**跑一次安装（forge / clients 各自 `--project-root`）。
3. **不要**把 `~/.claude` / `~/.cursor` 当真相；活镜像 = 各仓库项目根下的 `.cursor` / `.claude` / `.agents`。
4. 审计类按需 skill：`../architecture-compliance-audit/`（不是 always）。
5. `audit-evidence` 是**写报告时**的闸（审计 / 台账 / 复查结论），不是改代码时的闸；它与审计 skill 配对使用——skill 管跑什么命令，规则管一条结论凭什么敢写。

## Claude 专项说明

Cursor 的 `alwaysApply: true` **不会**作用到 Claude。Claude 要靠：

- 项目 `.claude/rules/*.md`（与 `--install-local` 写入处一致），或  
- 本 skill 被 Claude 的 skill 发现路径加载（description 已写成「任何 forge/clients 改动都用」）。

两者都装最稳：rules 管每轮硬闸，skill 管长文与审计入口。
