#!/usr/bin/env bash
# 把 vendor/ 下的三方 plugin 包装到各 agent 工具的活镜像。
#
#   打散形态（一 skill 一目录）→ Claude Code / Cursor / Antigravity 工作区
#   整包形态（保留 plugin.json）→ Antigravity 全局 plugin 目录
#
# vendor/<pkg>/skills/<name> 是唯一真相；手改任一镜像会被下次安装覆盖。
# 目标父目录不存在就跳过并打印，不自动创建（本机未装 Antigravity 时无 ~/.gemini）。
# 不碰 ~/.agents/skills —— 那是另一个 skill 管理器（.skill-lock.json）的地盘。
# 装完对 blender-modeling 做路径本地化：上游文档把 SKILL_DIR 默认写成
# $HOME/.agents/skills/blender-modeling（本机不存在），改写为该镜像自身的绝对路径，
# 使任何工具、任何 shell 都无需设 BLENDER_SKILL_DIR。vendor/ 保持上游原样。
# 只用 rsync / find / perl：三者在每台 macOS 都自带，组员无需先装什么。
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

# 把 blender-modeling 文档里的上游默认路径改成该镜像自身的绝对路径。
# 三条规则分别对应上游写法：$HOME/... 、~/... 、以及上游作者本机的
# /Users/<他的用户名>/...（cli-reference.md:287 的可复制 Python 片段里泄漏了一个）。
# 每次安装都在 rsync 之后跑，源始终是 vendor/ 的原样副本，所以天然幂等。
localize_blender() {
  local dest="$1"
  [ "$(basename "$dest")" = "blender-modeling" ] && [ -d "$dest" ] || return 0
  DEST="$dest" find "$dest" -name '*.md' -type f -exec perl -pi \
    -e 's!\$HOME/\.agents/skills/blender-modeling!$ENV{DEST}!g;' \
    -e 's!~/\.agents/skills/blender-modeling!$ENV{DEST}!g;' \
    -e 's!/Users/[^/ "]+/\.agents/skills/blender-modeling!$ENV{DEST}!g;' {} +
  echo "  localized blender-modeling paths -> $dest"
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
      localize_blender "$dest_root/$(basename "$skill_dir")"
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
    localize_blender "$dest_root/$(basename "$pkg_dir")/skills/blender-modeling"
    n=$((n + 1))
  done
  echo "installed $n vendor packages -> $dest_root"
  written=$((written + 1))
done

echo "done. vendor targets written=$written skipped=$skipped"
