#!/usr/bin/env bash
# 把 vendor/ 下的三方 plugin 包装到各 agent 工具的活镜像。
#
#   打散形态（一 skill 一目录）→ Claude Code / Cursor / Antigravity 工作区
#   整包形态（保留 plugin.json）→ Antigravity 全局 plugin 目录
#
# vendor/<pkg>/skills/<name> 是唯一真相；手改任一镜像会被下次安装覆盖。
# 目标父目录不存在就跳过并打印，不自动创建（本机未装 Antigravity 时无 ~/.gemini）。
# 不碰 ~/.agents/skills —— 那是另一个 skill 管理器（.skill-lock.json）的地盘。
#
# Usage（在 skills/ 下，或由 install-local.sh 调用）:
#   ./install-vendor-skills.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VENDOR="$ROOT/vendor"
FORGE="$(cd "$ROOT/.." && pwd)"

[ -d "$VENDOR" ] || { echo "missing vendor dir: $VENDOR" >&2; exit 1; }

# 每行 <探测父目录>:<写入根目录>
FLAT_TARGETS="
${HOME}/.claude:${HOME}/.claude/skills
${FORGE}/.claude:${FORGE}/.claude/skills
${HOME}/.cursor:${HOME}/.cursor/skills
${FORGE}/.cursor:${FORGE}/.cursor/skills
${FORGE}/.agents:${FORGE}/.agents/skills
"

# Antigravity 全局只走整包形态：它同时发现 config/skills/ 与 config/plugins/*/skills/，
# 两处都写会让同一个 skill 注册两次；整包还多带 plugin.json 的 suggestedPrompts 和 logo。
PKG_TARGETS="
${HOME}/.gemini/config:${HOME}/.gemini/config/plugins
"

sync_tree() {
  mkdir -p "$2"
  rsync -a --delete --exclude '.DS_Store' --exclude '.git/' "$1/" "$2/"
}

written=0
skipped=0

for entry in $FLAT_TARGETS; do
  parent="${entry%%:*}"
  dest_root="${entry#*:}"
  if [ ! -d "$parent" ]; then
    echo "skipped: not present -> $dest_root"
    skipped=$((skipped + 1))
    continue
  fi
  n=0
  for pkg_dir in "$VENDOR"/*/; do
    for skill_dir in "$pkg_dir"skills/*/; do
      [ -f "${skill_dir}SKILL.md" ] || continue
      sync_tree "${skill_dir%/}" "$dest_root/$(basename "$skill_dir")"
      n=$((n + 1))
    done
  done
  echo "installed $n vendor skills -> $dest_root"
  written=$((written + 1))
done

for entry in $PKG_TARGETS; do
  parent="${entry%%:*}"
  dest_root="${entry#*:}"
  if [ ! -d "$parent" ]; then
    echo "skipped: not present -> $dest_root"
    skipped=$((skipped + 1))
    continue
  fi
  n=0
  for pkg_dir in "$VENDOR"/*/; do
    [ -f "${pkg_dir}plugin.json" ] || continue
    sync_tree "${pkg_dir%/}" "$dest_root/$(basename "$pkg_dir")"
    n=$((n + 1))
  done
  echo "installed $n vendor packages -> $dest_root"
  written=$((written + 1))
done

echo "done. vendor targets written=$written skipped=$skipped"
