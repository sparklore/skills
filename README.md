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
| [`claude/rules/`](claude/rules/) | 非闸共享规则 SSoT（**英文执行正文**）+ 四闸生成镜像；Claude 专用 `worktree.md`；[`zh/`](claude/rules/zh/) 中文参考（不装活镜像；触发词仍含中文） |
| [`sparklore-architecture-gates/rules/`](sparklore-architecture-gates/rules/) | **四闸英文 SSoT**；中文参考在 `claude/rules/zh/` |
| [`cursor/rules/`](cursor/rules/) | **生成物**（勿手改） |
| [`overlays/`](overlays/) | 工具专用正文（现仅 `graphify.md`） |
| [`architecture-compliance-audit/`](architecture-compliance-audit/) | 只读合规审计（按需）；含 `evals/` |
| [`intent-compile/`](intent-compile/) · [`session-charter/`](session-charter/) · [`acceptance-gate/`](acceptance-gate/) | 会话流程 skills；含 `evals/` |
| [`design-first-feature/`](design-first-feature/) · [`quality-guardrails/`](quality-guardrails/) · [`code-review-audit/`](code-review-audit/) · [`simplify-codebase/`](simplify-codebase/) | 设计/质量/审查/简化；含 `evals/` |
| [`sparklore-context/`](sparklore-context/) | **薄入口指针**（非 SSoT）：指向 AGENTS/docs/四闸 + graphify；含 `evals/` v2 |
| [`event-storming/`](event-storming/) | 既有 skill（尚无 eval） |
| [`vendor/`](vendor/) | **三方 plugin 包原样存放**（不改正文）；装法见下节 |

改 skill 后跑契约闸：`python3 <skill>/scripts/validate_evals.py`（不调模型）。

`architecture-compliance-audit` 另有本地打分器（读回答目录 `<id>.md`，按 `must_include`/`must_not` 逐条 PASS/FAIL）：

```bash
python3 skills/architecture-compliance-audit/scripts/score_evals.py skills/architecture-compliance-audit/evals/answers-pass
python3 skills/architecture-compliance-audit/scripts/score_evals.py skills/architecture-compliance-audit/evals/answers-fail
```

详见该 skill 的 `SKILL.md`「Eval 跑法」。

## `vendor/` 三方 plugin 包

`vendor/<包>/` 是外部 plugin 包的**原样副本**，本仓只做分发，不改其正文。每包形如：

```
vendor/<包>/
  plugin.json          # Antigravity 的 standalone plugin 清单（Claude Code / Cursor 不读）
  README.md            # 上游出处与跨包协作表
  skills/<name>/        # 每个 skill 一个目录，内含 SKILL.md
```

一份真相，两种安装产物（跑 `./install-local.sh`，或直接 `./install-vendor-skills.sh`）：

| 工具 | 目标 | 形态 |
|---|---|---|
| Claude Code | `~/.claude/skills/` · `<forge>/.claude/skills/` | 打散（一 skill 一目录） |
| Cursor | `~/.cursor/skills/` · `<forge>/.cursor/skills/` | 打散 |
| Antigravity（工作区） | `<forge>/.agents/skills/` | 打散 |
| Antigravity（全局） | `~/.gemini/config/plugins/<包>/` | **整包**，保住 `plugin.json` 的 `suggestedPrompts` 与 logo |

Antigravity 全局只走整包形态：它同时发现 `config/skills/` 和 `config/plugins/*/skills/`，两处都写会让同一个 skill 注册两次。

目标父目录不存在就跳过并打印（没装 Antigravity 的机器不会凭空造 `~/.gemini`），装好后重跑一次即可。`~/.agents/skills/` 归另一个 skill 管理器（`.skill-lock.json`）管，脚本不碰。

打散产物是生成物：手改会被下次安装覆盖，要改请改 `vendor/` 下的源。

### 已装的两个包（19 个 skill）

**`cinematic-storytelling`**（7）：`silent-web-cinema`（orchestrator）、`storytelling`、`brand-storytelling`、`filmmaker`、`scroll-world-storytelling`、`cinematic-scroll-storytelling`、`motion-and-storytelling`

**`threejs-3d-gamedev`**（12）：`threejs-fundamentals`、`threejs-geometry`、`threejs-lighting`、`threejs-materials`、`threejs-shaders`、`threejs-postprocessing`、`threejs-performance`、`ghibli-environment-art`、`camera-systems`、`game-development`（orchestrator，下辖 10 个子 skill 由它路由读取，不单独注册）、`img2threejs`、`blender-modeling`

只有 5 个会被模型自动触发：`silent-web-cinema`、`scroll-world-storytelling`、`threejs-fundamentals`、`ghibli-environment-art`、`blender-modeling`。其余 14 个带 `disable-model-invocation: true`，需显式调用。

### 启用前置（装了 skill 不等于能跑）

| skill | 还需要 |
|---|---|
| `blender-modeling` | 本机 Blender + Node ≥ 20；`BLENDER_SKILL_DIR` |
| `img2threejs` | Python 3.10+；可选视觉适配器 `uv sync --project integrations/vision --python 3.11`（SAM2 / Depth Anything V2 / MediaPipe）；`IMG2THREEJS_SHOWCASE_ROOT` |
| `scroll-world-storytelling` | ffmpeg |

### 已知缺口

- `threejs-3d-gamedev/README.md` 列了 `godot-gdscript-patterns`，**包内无此目录**，装不了。
- `silent-web-cinema` 等引用了 `copywriting`、`captions-overlay`、`impeccable` —— 它们属于上游另三个包（`writing-and-agent-ops`、`hyperframes-video-studio`、`frontend-ui-ux`），本仓没有，引用会断。
- 19 个 skill 均无 `evals/`，不在本仓契约闸覆盖范围内，也不在 `ALL_SKILLS` 白名单里。
- `scroll-world-storytelling/demo/video/assets/contract-flight.mp4`（3.7M）**已从本仓删除**，这是 `vendor/` 唯一偏离上游原样副本之处。同目录的 `contract-flight-source.svg` 与海报 `contract-flight.webp` 保留，demo 退化为静态海报而非报错；需要样片时按该目录 `README.md` 的参数用 ffmpeg 从源 SVG 重生成，文件名保持不变。

### 升级方式

`img2threejs` 原带的 `.git` 已剥除（子模块内不能套 git 仓），所以没有 `git pull` 升级路径。升级 = 重新取上游整包，覆盖 `vendor/<包>/`，再跑 `./install-local.sh`。

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
