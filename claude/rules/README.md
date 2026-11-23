# Claude 规则包（远程仓备份里的源）

- **四闸**：SSoT 在 `../../sparklore-architecture-gates/rules/`；本目录同名文件由 `sync-tool-rules.sh` 生成，禁止手改。
- **其余 `.md`**：非闸 SSoT（纯 Markdown，不要加 Cursor frontmatter）。**执行正文为英文**；用户触发词保留中文（如「验收通过」「可以改」「C=是」「豁免」）。
- **`zh/`**：中文参考备份，**不**安装到活镜像；Agent 只读顶层英文 `.md`。
- **`worktree.md`**：仅 Claude。
- 活镜像在 `~/.claude/rules`（与 `~/.cursor/rules`、项目 `.cursor/rules` 必须一致）。安装：`../../install-local.sh`。
