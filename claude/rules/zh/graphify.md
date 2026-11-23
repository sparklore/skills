# graphify（中文参考）

> **非执行正文。** 活镜像加载英文版 `overlays/graphify.md` → Cursor `graphify.mdc`。

本项目在 `graphify-out/` 有 graphify 知识图谱。

**强制：** 用 Read / Grep / Glob / Bash 探索代码库之前，必须先跑 graphify：
- `graphify query "<question>"` — 任意代码/架构问题的范围子图
- `graphify path "<A>" "<B>"` — 两符号间依赖路径
- `graphify explain "<concept>"` — 与概念相关的全部节点

适用于你以及你拉起的每个子代理。凡涉及代码探索的子代理提示词须显式写入本规则。不得因「文件已知」或「在执行 plan」而跳过——图谱会给出 grep/Read 找不到的跨文件依赖与推断边。

仅在下列情况直接用 Read/Grep/Glob：
1. graphify 已定向，你只需改或调试具体行
2. 尚不存在 `graphify-out/graph.json`

- 若存在 `graphify-out/wiki/index.md`，优先用 wiki 导航，勿裸读源文件
- 仅当 query/path/explain 不够时，才为广域架构评审读 `graphify-out/GRAPH_REPORT.md`
- 改代码文件后跑 `graphify update .` 保持图谱更新（仅 AST，无 API 费用）
