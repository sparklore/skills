# SOURCE — hyperframes / captions-overlay

- 上游：https://github.com/heygen-com/hyperframes
- 取自：`.agents/skills/captions-overlay/`（仅这一个 skill，整仓是个 AI 视频编辑器，其余未取）
- commit：`8c31cb3f400b20710ff76fda53354d7abfd6faca`（2026-11-23）
- 许可：Apache-2.0（`LICENSE` 为上游原文）
- 本地改动：无，逐字副本

## 为什么在这里

`cinematic-storytelling/skills/silent-web-cinema/SKILL.md:31` 写「Adapted from `captions-overlay`」，
但那个 skill 属于打包者的另一个包，本仓没有。这里直接从原作者仓取回，补上该引用。

## 两点注意

- 它自己的 frontmatter 带 `metadata.internal: true`——HeyGen 把它当内部补充件，不是对外发布的独立 skill。
- 它声明「supplements the upstream `/hyperframes` skill's `references/captions.md`；applies ON TOP of it」。
  那个 `hyperframes` 主 skill 本仓没装（是 HyperFrames 视频渲染专用），所以这一层引用仍然悬空。
  对本仓用途无妨：要用的 drop / rail / embed 字幕模型在本文件里是完整的。
