# sparklore/skills

远程仓库 [`github.com/sparklore/skills`](https://github.com/sparklore/skills) 的本地备份检出（forge 里通常是子模块）。**改完推远程后，必须再装到所有活镜像，保持一致——不要只改本目录当已生效。**

## 真相与镜像（必须统一）

| 角色 | 路径 |
|---|---|
| **远程备份 / 编辑入口（SSoT）** | 本目录 `skills/`（推到 `sparklore/skills`） |
| **活镜像（Agent 实际读）** | `~/.claude/skills` · `~/.cursor/skills` · `<forge>/.cursor/skills` · `<forge>/.claude/skills` · `<forge>/.agents/skills` |

**统一策略：** 凡是有 `skills` 的目录，同一 skill 树（`SKILL.md` + `evals/` + `scripts/` + 附属文件）内容应一致。  
手改任一活镜像会被下次安装覆盖。多处不一致 = 双轨，禁止。

**Agent 改 skill 时：** 改完一处后，必须向用户确认是否同步其余镜像；**默认 = 要同步全部**（跑 `./install-local.sh`）。用户说「只改这一处」才跳过。

## 目录

| 目录 | 用途 |
|---|---|
| [`sparklore-architecture-gates/`](sparklore-architecture-gates/) | **四闸正文 SSoT**；含 `evals/` |
| [`claude/rules/`](claude/rules/) | 非闸共享规则 SSoT + 四闸生成镜像；Claude 专用 `worktree.md` |
| [`cursor/rules/`](cursor/rules/) | **生成物**（勿手改） |
| [`overlays/`](overlays/) | 工具专用正文（现仅 `graphify.md`） |
| [`architecture-compliance-audit/`](architecture-compliance-audit/) | 只读合规审计（按需）；含 `evals/` |
| [`intent-compile/`](intent-compile/) · [`session-charter/`](session-charter/) · [`acceptance-gate/`](acceptance-gate/) | 会话流程 skills；含 `evals/` |
| [`design-first-feature/`](design-first-feature/) · [`quality-guardrails/`](quality-guardrails/) · [`code-review-audit/`](code-review-audit/) · [`simplify-codebase/`](simplify-codebase/) | 设计/质量/审查/简化；含 `evals/` |
| [`sparklore-context/`](sparklore-context/) | **薄入口指针**（非 SSoT）：指向 AGENTS/docs/四闸 + graphify；含 `evals/` v2 |
| [`event-storming/`](event-storming/) | 既有 skill（尚无 eval） |

改 skill 后跑契约闸：`python3 <skill>/scripts/validate_evals.py`（不调模型）。

`architecture-compliance-audit` 另有本地打分器（读回答目录 `<id>.md`，按 `must_include`/`must_not` 逐条 PASS/FAIL）：

```bash
python3 skills/architecture-compliance-audit/scripts/score_evals.py skills/architecture-compliance-audit/evals/answers-pass
python3 skills/architecture-compliance-audit/scripts/score_evals.py skills/architecture-compliance-audit/evals/answers-fail
```

详见该 skill 的 `SKILL.md`「Eval 跑法」。

## 改完怎么同步

**优先：** 本地控制台 →「Agent 工具」→「安装 Agent 规则与 Skills」。

终端：

```bash
# 在 skills/ 下：规则 + skills 树 → 全部活镜像
./install-local.sh

# 或分步
./sync-tool-rules.sh --install-local
cd sparklore-architecture-gates && ./sync-adapters.sh --install-local
```

改规则正文：

1. **四闸** → `sparklore-architecture-gates/rules/*.md`
2. **其它共享规则** → `claude/rules/*.md`（纯 Markdown，无 Cursor frontmatter）
3. **graphify** → `overlays/graphify.md`
4. 跑 `./sync-tool-rules.sh`（生成 `cursor/rules`），再 `./install-local.sh`，最后提交并推远程。
