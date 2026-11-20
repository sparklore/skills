# 禁止读噪声路径（中文参考）

> **非执行正文。** 活镜像只加载英文版 `../dont-read-junk.md`。

默认不扫：`vendor/`、`node_modules/`、`dist/`、`build/`、`coverage/`、`*.min.js`、`*.map`、`logs/`、`tmp/`、`*.log`、`**/testdata/**`、`**/fixtures/**`、大批量 CSV/JSON dump。

例外：用户点名的单个文件；改测试时只读对应测试源码；依赖清单（如 `go.mod`、`package.json`）可读，lockfile 只在查版本冲突时搜单行。

与 `.cursorignore` 冲突时以更严为准。
