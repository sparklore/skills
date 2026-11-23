# SOURCE — blader/humanizer

- 上游：https://github.com/blader/humanizer（作者 Siqi Chen，GitHub `blader`）
- 取自：**整仓即 skill**（`package.json` 与 `.claude-plugin/plugin.json` 都写 `"skills": ["./"]`，`SKILL.md` 在仓根）
- commit：`a32f24407364c74c812b43c15926d638bee1e072`（2026-11-23 取；上游最后推送 2026-11-19）
- 版本：`plugin.json` 写 `4.0.0`，但本 commit 是 **`v4.0.0` 标签之后的未发布状态**（`CHANGELOG.md` 顶部有 `## Unreleased`）
- 许可：MIT（`LICENSE` 为上游原文，Copyright (c) 2025 Siqi Chen）
- 本地改动：无，逐字副本（`diff -r` 对上游解包目录无差异）

## 为什么不取标签而取 HEAD

`v4.0.0` 之后的未发布改动不是实验性的，是修订与一个校验器缺陷修复：

- `scripts/validate-package.py` 原先在 `SKILL.md` 或 README 表格里**同一个 pattern 编号出现两次时不报错**（后者静默覆盖前者），该 commit 修掉（上游 #340）。
- §22 之外，非正式人类文本（聊天、吐槽、怒评）不再被过度改写：小写、缩写、残句、生硬开头都保留，单条 tell 不足以触发重写（上游 #318）。
- §4 补 "the part" 这类替身说法；§2 补 "Overall" / "Ultimately" 收尾判词；§6/§13/§15/§25 四处 After 例子重写。

拿标签会少掉这些，而它们正是这个 skill 的本体内容，所以钉 HEAD 并在此记明。

## 为什么不取打包者那份副本

`pedronauck/skills` 的 `skills/marketing/humanizer/` 是 `blader/humanizer` 的 vendor 副本，
且**落后于上游**：`SKILL.md` 差 74 行（498 vs 504），`CHANGELOG.md` 没有 `## Unreleased` 段，
`README.md` 与 `scripts/validate-package.py` 也不同。本仓既有规矩是「从各自原作者仓逐字取回」，
故直接取 `blader/humanizer`。

## 它不是来补断引用的

`silent-web-cinema/SKILL.md:10` 的协作 skill 列表里**没有** `humanizer`。它只出现在打包者
`cinematic-storytelling/README.md:18` 的跨包提示 `writing-and-agent-ops → copywriting, humanizer`。
这是单独要装的，不在「补断引用」那条线上。它与 `copywriting` 的分工：`copywriting` 写新文案，
`humanizer` 改掉已有文案里的 AI 腔。

## 一个代价：仓库基建跟着进了镜像

因为整仓即 skill，逐字副本把这些也带进了六处镜像：

```
.claude-plugin/plugin.json   .cursor-plugin/plugin.json
.github/workflows/validate.yml   package.json   scripts/validate-package.py
```

**实测没有造成重复注册**——Claude Code 的 skill 清单里 `humanizer` 只出现一次，
`~/.gemini/config/skills/` 与 `~/.gemini/config/plugins/` 之间也无同名冲突。
所以没有为此在 `install-vendor-skills.sh` 里加排除逻辑：`vendor/` 保持逐字副本这条更重要，
真出问题再在安装层处理（和 `blender-modeling` 路径本地化同一层次）。

`scripts/validate-package.py` 是上游自带的包自检脚本，**本仓没有运行过它**（第三方脚本）。
副本忠实度是用 `diff -r` 对上游解包目录证明的，不依赖它。
