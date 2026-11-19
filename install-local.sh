#!/usr/bin/env bash
# 把远程 skills 仓（本目录为备份检出）同步到三处活镜像，保持一致：
#   ~/.claude/{rules,skills}
#   ~/.cursor/{rules,skills}
#   <forge>/.cursor/{rules,skills} 与 <forge>/.agents/skills
#
# Usage（在 skills/ 下，或由本地控制台调用）:
#   ./install-local.sh
#   ./install-local.sh --install-local --rules=... --skills=... --targets=...
# 无参时等价于全量 --install-local。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

# 1) 全量规则包（含非闸 + 四闸生成镜像）→ ~/.claude/rules + ~/.cursor/rules + 项目 .cursor/rules
"$ROOT/sync-tool-rules.sh" --install-local

# 2) 四闸 adapters 再写一遍（与上重合，保证只勾四闸时也走得通）+ skills 树
GATES="$ROOT/sparklore-architecture-gates/sync-adapters.sh"
if [ "$#" -eq 0 ]; then
  exec "$GATES" --install-local
fi
# 控制台可能传入已含 --install-local 的参数
has_install=0
for a in "$@"; do
  [ "$a" = "--install-local" ] && has_install=1
done
if [ "$has_install" -eq 1 ]; then
  exec "$GATES" "$@"
fi
exec "$GATES" --install-local "$@"
