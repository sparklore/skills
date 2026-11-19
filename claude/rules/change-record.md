# 改动收尾

纯问答、只读、没产生 diff：下面三项都不用。本文件是注释、变更日志、commit 文案的唯一出处。

## 注释

新增或改动的函数、复杂分支写注释。函数外一行写业务意图；步骤写在对应代码旁边。写前置条件和边界，不复述代码字面意思。getter、纯透传、和周围完全同模式的片段可省略。

## CHANGELOG

仓库有 `CHANGELOG.md` 时，在 `[未发布]` 或 `[Unreleased]` 下追加。中文，写模块、做了什么、1～3 个关键路径。仅文档或规则放文档或维护小节。仓库没有该文件则跳过。

## Commit message（只给文案，不执行 commit / push）

```text
<type>(可选scope): <中文简述>
```

type：`feat` `fix` `docs` `style` `refactor` `perf` `chore` `test`。简述约 50 字，不加句号。多仓库分开写。和未提交的其他改动混在一起时，注明建议 stage 的文件。主题和本轮 CHANGELOG 一致。
