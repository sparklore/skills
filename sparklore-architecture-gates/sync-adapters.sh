#!/usr/bin/env bash
# Generate Cursor .mdc adapters from plain rules/*.md; optionally install local mirrors.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
RULES="$ROOT/rules"
OUT_CURSOR="$ROOT/adapters/cursor"

DESC_data_driven='数据驱动铁律：禁止业务硬编码、专用路由/capability、往冻结段加行；缺能力先改数据再加通用构件'
DESC_no_silent_orchestration='禁止在 Go/JS 里静默加编排、重试、兜底；动手前必须如实说明为什么、好处、为何不进 QuestFlow'
DESC_no_zombie_dual_track='禁止僵尸代码与双轨：生产零调用却靠测试/迁移/开关续命；删旧不搬家；单真相源'

mkdir -p "$OUT_CURSOR"
for name in data-driven no-silent-orchestration no-zombie-dual-track; do
  src="$RULES/$name.md"
  [[ -f "$src" ]] || { echo "missing $src" >&2; exit 1; }
  desc_var="DESC_${name//-/_}"
  desc="${!desc_var}"
  {
    printf '%s\n' '---'
    printf 'description: %s\n' "$desc"
    printf '%s\n' 'alwaysApply: true'
    printf '%s\n' '---'
    printf '\n'
    cat "$src"
  } >"$OUT_CURSOR/$name.mdc"
  echo "wrote adapters/cursor/$name.mdc"
done

if [[ "${1:-}" != "--install-local" ]]; then
  exit 0
fi

# Resolve forge root: .../sparklore-forge/skills/sparklore-architecture-gates -> ../..
FORGE="$(cd "$ROOT/../.." && pwd)"
CURSOR_RULES="$FORGE/.cursor/rules"
CLAUDE_RULES="${HOME}/.claude/rules"
CURSOR_SKILL="$FORGE/.cursor/skills/sparklore-architecture-gates"
AGENTS_SKILL="$FORGE/.agents/skills/sparklore-architecture-gates"

mkdir -p "$CURSOR_RULES" "$CLAUDE_RULES" "$CURSOR_SKILL" "$AGENTS_SKILL"
for name in data-driven no-silent-orchestration no-zombie-dual-track; do
  cp "$OUT_CURSOR/$name.mdc" "$CURSOR_RULES/$name.mdc"
  cp "$RULES/$name.md" "$CLAUDE_RULES/$name.md"
  echo "installed Cursor .mdc + Claude rules: $name"
done

# Skill tree mirror (SKILL + rules + INSTALL + audit pointer files stay by rsync-like cp)
cp "$ROOT/SKILL.md" "$ROOT/INSTALL.md" "$CURSOR_SKILL/"
cp "$ROOT/SKILL.md" "$ROOT/INSTALL.md" "$AGENTS_SKILL/"
mkdir -p "$CURSOR_SKILL/rules" "$AGENTS_SKILL/rules"
cp "$RULES"/*.md "$CURSOR_SKILL/rules/"
cp "$RULES"/*.md "$AGENTS_SKILL/rules/"
echo "mirrored skill -> $CURSOR_SKILL and $AGENTS_SKILL"
echo "done."
