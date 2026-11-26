#!/usr/bin/env bash
# 把 vendor/ 下的三方 plugin 包装到「项目根」下的活镜像（打散：一 skill 一目录）。
#
# vendor/<pkg>/skills/<name> 是唯一真相；手改任一镜像会被下次安装覆盖。
# 永不写入 ~/.claude / ~/.cursor / ~/.gemini / ~/.agents。
# 装完对 blender-modeling 做路径本地化：上游文档把 SKILL_DIR 默认写成
# $HOME/.agents/skills/blender-modeling（本机不存在），改写为该镜像自身的绝对路径。
#
# Usage（在 skills/ 下，或由 install-local.sh 调用）:
#   ./install-vendor-skills.sh
#   ./install-vendor-skills.sh --project-root=/path/to/any-repo
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VENDOR="$ROOT/vendor"
PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"

for a in "$@"; do
  case "$a" in
    --project-root=*)
      raw="${a#--project-root=}"
      if [ -z "$raw" ] || [ ! -d "$raw" ]; then
        echo "invalid --project-root: $raw" >&2
        exit 1
      fi
      PROJECT_ROOT="$(cd "$raw" && pwd)"
      ;;
    *)
      echo "unknown arg: $a" >&2
      echo "usage: $0 [--project-root=PATH]" >&2
      exit 1
      ;;
  esac
done

[ -d "$VENDOR" ] || { echo "missing vendor dir: $VENDOR" >&2; exit 1; }

# 项目内目标：这三处归该仓所有，**无条件创建**（.gitignore 下首次克隆不存在）。
PROJECT_SKILL_ROOTS="
${PROJECT_ROOT}/.claude/skills
${PROJECT_ROOT}/.cursor/skills
${PROJECT_ROOT}/.agents/skills
"

sync_tree() {
  mkdir -p "$2"
  rsync -a --delete --exclude '.DS_Store' --exclude '.git/' "$1/" "$2/"
}

localize_blender() {
  local dest="$1"
  [ "$(basename "$dest")" = "blender-modeling" ] && [ -d "$dest" ] || return 0
  DEST="$dest" find "$dest" -name '*.md' -type f -exec perl -pi \
    -e 's!\$HOME/\.agents/skills/blender-modeling!$ENV{DEST}!g;' \
    -e 's!~/\.agents/skills/blender-modeling!$ENV{DEST}!g;' \
    -e 's!/Users/[^/ "]+/\.agents/skills/blender-modeling!$ENV{DEST}!g;' {} +
  echo "  localized blender-modeling paths -> $dest"
}

install_flat() {
  local dest_root="$1"
  local n=0
  local pkg_dir skill_dir
  for pkg_dir in "$VENDOR"/*/; do
    for skill_dir in "$pkg_dir"skills/*/; do
      [ -f "${skill_dir}SKILL.md" ] || continue
      sync_tree "${skill_dir%/}" "$dest_root/$(basename "$skill_dir")"
      localize_blender "$dest_root/$(basename "$skill_dir")"
      n=$((n + 1))
    done
  done
  echo "installed $n vendor skills -> $dest_root"
}

written=0
echo "install-vendor project-root=$PROJECT_ROOT"

for dest_root in $PROJECT_SKILL_ROOTS; do
  install_flat "$dest_root"
  written=$((written + 1))
done

echo "done. vendor targets written=$written (project-only; no home globals)"
