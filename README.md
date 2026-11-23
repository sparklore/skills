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
| Antigravity（全局，单 skill 来源） | `~/.gemini/config/skills/` | 打散 |

Antigravity 同时发现 `config/skills/` 和 `config/plugins/*/skills/`，同一个 skill 进两处就注册两次。
所以按**有无 `plugin.json`** 分流：有的走整包，没有的（从原作者仓直接取回的单 skill）走打散。
两者天然不重叠。

目标父目录不存在就跳过并打印（没装 Antigravity 的机器不会凭空造 `~/.gemini`），装好后重跑一次即可。`~/.agents/skills/` 归另一个 skill 管理器（`.skill-lock.json`）管，脚本不碰。

打散产物是生成物：手改会被下次安装覆盖，要改请改 `vendor/` 下的源。

**路径本地化（组员零配置的关键）**：上游 `blender-modeling` 的文档把 `SKILL_DIR` 默认写成
`$HOME/.agents/skills/blender-modeling`——那是上游自己的安装约定，本仓不往那里装，所以默认值必然落空。
安装脚本在每次 `rsync` 之后把该 skill 的 `.md` 里这个路径改写为**该镜像自身的绝对路径**，
于是任何工具、任何 shell 都不必设 `BLENDER_SKILL_DIR`。改写覆盖三种上游写法：`$HOME/...`、`~/...`，
以及 `references/cli-reference.md` 可复制 Python 片段里泄漏的上游作者本机路径 `/Users/<他的用户名>/...`。
`vendor/` 保持上游原样，改写只发生在产物上，升级覆盖 `vendor/` 后重跑安装即自动重新改写。
要覆盖仍可自行 `export BLENDER_SKILL_DIR=...`（`${VAR:-默认}` 形式，env 优先）。

改写用 `find` + `perl`（每台 macOS 无条件自带），本脚本因此不需要 `python3`。
注意别据此以为整条安装链不要 `python3`：入口 `install-local.sh` 第一步的 `sync-tool-rules.sh:16`
是 `exec python3`，生成规则包必须有它。所以这里换 perl 只是少了一处依赖，不是清零。

**新成员**：`git submodule update --init --recursive && ./skills/install-local.sh`，没有第二步。详见 forge [`README.md`](../README.md) §新成员。

### 已装来源（6 个，23 个 skill）

**`cinematic-storytelling`**（7）：`silent-web-cinema`（orchestrator）、`storytelling`、`brand-storytelling`、`filmmaker`、`scroll-world-storytelling`、`cinematic-scroll-storytelling`、`motion-and-storytelling`

**`threejs-3d-gamedev`**（12）：`threejs-fundamentals`、`threejs-geometry`、`threejs-lighting`、`threejs-materials`、`threejs-shaders`、`threejs-postprocessing`、`threejs-performance`、`ghibli-environment-art`、`camera-systems`、`game-development`（orchestrator，下辖 10 个子 skill 由它路由读取，不单独注册）、`img2threejs`、`blender-modeling`

**单 skill 来源**（4，无 `plugin.json`，从各自原作者仓逐字取回，溯源见各目录 `SOURCE.md`）：

| skill | 上游 | 许可 |
|---|---|---|
| `captions-overlay` | [`heygen-com/hyperframes`](https://github.com/heygen-com/hyperframes) `.agents/skills/captions-overlay` @ `8c31cb3` | Apache-2.0 |
| `impeccable` | [`pbakaus/impeccable`](https://github.com/pbakaus/impeccable) `.agents/skills/impeccable` @ `b49177d`（自标 v4.10.0） | Apache-2.0 |
| `copywriting` | [`pedronauck/skills`](https://github.com/pedronauck/skills) `skills/marketing/copywriting` @ `71a9600`（自标 v2.3.5） | MIT |
| `humanizer` | [`blader/humanizer`](https://github.com/blader/humanizer) 整仓即 skill @ `a32f244`（`v4.0.0` 之后的未发布状态） | MIT |

前三个是为补 `silent-web-cinema` 的断引用而取的——打包者把它们放在另外两个包里（`hyperframes-video-studio`、`frontend-ui-ux`、`writing-and-agent-ops`），那几个包不存在于任何公开源。`copywriting` 的归属是这么定下的：同一打包包里的 `brand-storytelling` 已署名 `pedronauck/skills`，该仓 `skills/marketing/` 下正好同时有 `copywriting` 与 `humanizer`（与打包者列的那一对一致），再用三问门原文逐条比对确认。`humanizer` 不是补断引用，是单独要的：`silent-web-cinema` 没引用它，它只出现在打包者的跨包提示里。取的是原作者仓 `blader/humanizer`，不是打包者那份副本——后者落后于上游（`SKILL.md` 差 74 行，缺 `v4.0.0` 之后那批修订）。

10 个会被模型自动触发：`silent-web-cinema`、`scroll-world-storytelling`、`motion-and-storytelling`、`copywriting`、`humanizer`、`captions-overlay`、`impeccable`、`threejs-fundamentals`、`ghibli-environment-art`、`blender-modeling`。其余 13 个带 `disable-model-invocation: true`，需显式调用。（此处原写「5 个 / 14 个」，是 19 个 skill 时期的旧数，且漏算了没有该标记的 `motion-and-storytelling`；现数按 frontmatter 实测。）

### 启用前置（装了 skill 不等于能跑）

| skill | 还需要 |
|---|---|
| `blender-modeling` | 本机 Blender + Node ≥ 20。**无需设环境变量**，路径已本地化 |
| `img2threejs` | Python 3.10+；可选视觉适配器 `uv sync --project integrations/vision --python 3.11`（SAM2 / Depth Anything V2 / MediaPipe）。`IMG2THREEJS_SHOWCASE_ROOT` / `IMG2THREEJS_REQUIRE_SHOWCASE` 只影响该 skill 自带的 runtime 测试，日常使用不需要 |
| `scroll-world-storytelling` | ffmpeg |
| `impeccable` | 无需配置（运行时按 SKILL.md 所在目录自解析路径）。但 `scripts/impeccable` 启动器跑的是自带二进制，**本地没有时首次运行会联网下载一次** |

组员自检（不需要先配任何东西，路径已本地化）：

```bash
node ~/.claude/skills/blender-modeling/scripts/blender-rt.mjs viewport doctor
```

`ok: true` 即通。缺 Blender 时装：`brew install --cask blender`（约 1 GB，装完 `blenderExe` 自动发现，
`blenderFrom: auto:install`，不必设 `BLENDER_RT_EXE`）。首次要连上 GUI 跑 `viewport launch` 一键拉起并自动 Connect。

### 已知缺口

- `threejs-3d-gamedev/README.md` 列了 `godot-gdscript-patterns`，**包内无此目录**，装不了。
- `silent-web-cinema` 正文引用的 3 个外包 skill **已全部补齐**（`captions-overlay`、`impeccable`、`copywriting`，见上文「单 skill 来源」）。`SKILL.md:10` 列的 9 个协作 skill 现在 9/9 可解析。但 `copywriting` 带进来两条新事实：① 打包者在 `SKILL.md:40` 把三问门第 2 问转述成「Is it specific?」，上游原文是「Can it be proven true or false?」（可证伪），判据不同——裁文案时以 `copywriting` 原文为准，`vendor/` 不改上游文本；② 它自己 frontmatter 的 description 指向 `copy-editing` / `emails` / `offers` 三个 skill，上游仓里并不存在（已核全量清单），属软指针不是硬依赖，正文自洽。详见 `vendor/copywriting/SOURCE.md`。
- `captions-overlay` 自己声明「applies ON TOP of the `/hyperframes` skill's `references/captions.md`」，那个主 skill 本仓没装（HyperFrames 视频渲染专用），所以它这一层引用仍悬空。要用的 drop / rail / embed 字幕模型在它本文件里是完整的。
- 23 个 skill 里只有 `copywriting` 自带 `evals/`（上游原样带来），其余 22 个没有，不在本仓契约闸覆盖范围内；23 个都不在 `ALL_SKILLS` 白名单里。
- `humanizer` 的上游**整仓即 skill**（`plugin.json` 写 `"skills": ["./"]`），所以逐字副本把仓库基建一起带进了六处镜像：`.claude-plugin/plugin.json`、`.cursor-plugin/plugin.json`、`.github/workflows/validate.yml`、`package.json`、`scripts/validate-package.py`。**实测没有造成重复注册**（Claude Code 的 skill 清单里 `humanizer` 只出现一次），`~/.gemini` 下也无同名冲突，所以没有为此在安装器里加排除逻辑——`vendor/` 保持逐字副本这条更重要。它自带的 `scripts/validate-package.py` 我**没有运行**（第三方脚本），副本忠实度是用 `diff -r` 对上游解包目录证明的。
- `blender-modeling` 装出来的 `.md` 里的 `SKILL_DIR` 默认路径与上游不同（见上文「路径本地化」）。这是产物层的改写，`vendor/` 源文件未改。
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
