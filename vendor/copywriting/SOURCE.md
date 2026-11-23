# SOURCE — pedronauck/skills / copywriting

- 上游：https://github.com/pedronauck/skills
- 取自：`skills/marketing/copywriting/`（仅这一个 skill，整仓 100+ 个，其余未取）
- commit：`71a96003910d1e222c49f9bfa3830127f46b240f`（2026-11-23）
- 版本：`metadata.version: 2.3.5`
- 许可：MIT（`LICENSE` 为上游原文，Copyright (c) 2026 Pedro Nauck）
- 本地改动：无，逐字副本（`diff -r` 对上游解包目录无差异）

## 为什么在这里

`cinematic-storytelling/skills/silent-web-cinema/SKILL.md` 两处引用它：

- `:10` 列为协作 skill 之一
- `:40` 引用它的「Three-Question Gate」裁字幕文案

打包者把它归到另一个包 `writing-and-agent-ops`（`cinematic-storytelling/README.md:18`），
那个包不存在于任何公开源。本仓同一个打包包里的 `brand-storytelling` 已署名 `pedronauck/skills`，
该仓 `skills/marketing/` 下正好同时有 `copywriting` 与 `humanizer`——与打包者列的那一对一致，
故判定来源为此仓，并以三问门原文比对确认（见下）。

## 打包者的转述与原文有一处不一致

`silent-web-cinema/SKILL.md:40` 把三问门写成：

> Can the reader picture it? **Is it specific?** Could a generic competitor write it?

上游 `SKILL.md:66-69` 原文是：

> 1. Can the reader picture it?
> 2. **Can it be proven true or false?**（可证伪）
> 3. Could a competitor write this exact sentence?（swap test）

第 2 问被转述成「是否具体」，丢掉了**可证伪**这个判据——「best-in-class 是装饰而非主张」正是靠它拦下的。
`vendor/` 保持逐字副本不改上游文本，此处不动 `silent-web-cinema`，只在这里记下差异：
要按三问门裁文案时以本 skill 原文为准。

## 两点注意

- **它自己带 3 条悬空引用**：frontmatter description 里写 `For editing, see copy-editing. For emails,
  see emails. For the offer, see offers.`——这三个 skill 在上游仓里**不存在**（已核 `skills/` 全量清单）。
  那是软指针（给 skill 选择用），不是硬依赖；本 skill 正文自洽，三问门与 ai-tells 都是完整的。
- **三问门本身是二手转述**：上游 `SKILL.md:77` 自己注明，diagnosis / 三问门 / decompose-and-lock
  改写自 Profound 的 `improved-copywriting`（https://github.com/retieedra-profound/skills-marketing-library，MIT）。
  链条是 Profound → pedronauck → 打包者 → 本仓。

## 顺带

这是 `vendor/` 里**第一个自带 `evals/` 的 skill**（`skills/copywriting/evals/evals.json`）。
