#!/usr/bin/env bash
# 把远程 skills 仓（本目录为备份检出）同步到「当前项目根」下的活镜像：
#   <project>/.claude/{rules,skills}
#   <project>/.cursor/{rules,skills}
#   <project>/.agents/skills
# 永不写入 ~/.claude / ~/.cursor / ~/.gemini 等用户全局目录。
#
# Usage（在 skills/ 下，或由本地控制台调用）:
#   ./install-local.sh
#   ./install-local.sh --project-root=/path/to/any-repo
#   ./install-local.sh --install-local --rules=... --skills=... --targets=...
# 无参时等价于全量 --install-local；默认 --project-root 为 skills 的父目录（forge）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"
PASSTHRU=()

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
      PASSTHRU+=("$a")
      ;;
  esac
done

echo "install-local project-root=$PROJECT_ROOT"

# 1) 全量规则包（含非闸 + 四闸生成镜像）→ 仅 <project>/.claude/rules + <project>/.cursor/rules
"$ROOT/sync-tool-rules.sh" --install-local --project-root="$PROJECT_ROOT"

# 1.5) 三方 vendor 包（仅项目内打散镜像；不写 ~/.gemini）
"$ROOT/install-vendor-skills.sh" --project-root="$PROJECT_ROOT"

# 2) 四闸 adapters 再写一遍（与上重合，保证只勾四闸时也走得通）+ skills 树
GATES="$ROOT/sparklore-architecture-gates/sync-adapters.sh"
if [ "${#PASSTHRU[@]}" -eq 0 ]; then
  exec "$GATES" --install-local --project-root="$PROJECT_ROOT"
fi
has_install=0
for a in "${PASSTHRU[@]}"; do
  [ "$a" = "--install-local" ] && has_install=1
done
# bash 3.2 + set -u：空数组展开前先分支，避免 unbound
if [ "$has_install" -eq 1 ]; then
  exec "$GATES" --project-root="$PROJECT_ROOT" "${PASSTHRU[@]}"
else
  exec "$GATES" --install-local --project-root="$PROJECT_ROOT" "${PASSTHRU[@]}"
fi
