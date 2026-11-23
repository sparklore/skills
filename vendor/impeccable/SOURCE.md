# SOURCE — impeccable

- 上游：https://github.com/pbakaus/impeccable（作者 Paul Bakaus）
- 取自：`.agents/skills/impeccable/`
- commit：`b49177d32788f2dc585c42831d845dacf1ebed2c`（2026-11-23），skill 自标 `metadata.version: 4.10.0`
- 许可：Apache-2.0（`LICENSE`、`NOTICE.md` 均为上游原文；`NOTICE.md` 记录其 iOS/Android 参考页派生自 MIT 的 `ehmo/platform-design-skills`）
- 本地改动：无，逐字副本

## 为什么在这里

`silent-web-cinema/SKILL.md:10` 把 `impeccable` 列为协同 skill，而它属于打包者的
`frontend-ui-ux` 包，本仓没有。这里从原作者仓取回。它本身也直接对得上
`sparklore-clients/sites/company` 的前端质感评审需求。

## 运行前置

- 体积 2.4M，其中 `scripts/` 1.7M、`reference/` 576K。
- `scripts/impeccable` 启动器跑的是一个自带二进制，**首次运行时若本地没有会联网下载一次**；
  上游说明不需要 Node 或其他运行时。首次使用前请知悉这次下载。
- 它用 `<skill-base-dir>` 在运行时自解析路径（SKILL.md 所在目录），**不需要路径本地化**，
  也不需要设环境变量。
