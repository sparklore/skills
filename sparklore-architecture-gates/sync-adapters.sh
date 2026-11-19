#!/usr/bin/env bash
# Generate Cursor .mdc adapters from plain rules/*.md; optionally install local mirrors.
# Usage:
#   ./sync-adapters.sh
#   ./sync-adapters.sh --install-local
#   ./sync-adapters.sh --install-local \
#     --rules=data-driven,no-silent-orchestration,no-zombie-dual-track \
#     --skills=sparklore-architecture-gates,architecture-compliance-audit \
#     --targets=cursor-rules,claude-rules,cursor-skills,agents-skills
# Omitted --rules/--skills/--targets mean "all". Explicit empty (--rules=) means none.
# Compatible with macOS /bin/bash 3.2 (no namerefs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
RULES="$ROOT/rules"
OUT_CURSOR="$ROOT/adapters/cursor"
SKILLS_ROOT="$(cd "$ROOT/.." && pwd)"

ALL_RULES="data-driven no-silent-orchestration no-zombie-dual-track"
ALL_SKILLS="sparklore-architecture-gates architecture-compliance-audit"
ALL_TARGETS="cursor-rules claude-rules cursor-skills agents-skills"

DESC_data_driven='数据驱动铁律：禁止业务硬编码、专用路由/capability、往冻结段加行；缺能力先改数据再加通用构件'
DESC_no_silent_orchestration='禁止在 Go/JS 里静默加编排、重试、兜底；动手前必须如实说明为什么、好处、为何不进 QuestFlow'
DESC_no_zombie_dual_track='禁止僵尸代码与双轨：生产零调用却靠测试/迁移/开关续命；删旧不搬家；单真相源'

INSTALL=0
RULES_SEL=""
SKILLS_SEL=""
TARGETS_SEL=""
RULES_SET=0
SKILLS_SET=0
TARGETS_SET=0

csv_to_space() {
  echo "$1" | tr ',' ' ' | sed 's/  */ /g;s/^ //;s/ $//'
}

in_list() {
  local needle="$1"
  local hay="$2"
  local x
  for x in $hay; do
    [ "$x" = "$needle" ] && return 0
  done
  return 1
}

validate_subset() {
  local kind="$1"
  local sel="$2"
  local allowed="$3"
  local item
  for item in $sel; do
    if ! in_list "$item" "$allowed"; then
      echo "unknown $kind: $item (allowed: $allowed)" >&2
      exit 1
    fi
  done
}

count_words() {
  local s="$1"
  if [ -z "$s" ]; then
    echo 0
  else
    echo "$s" | wc -w | tr -d ' '
  fi
}

for arg in "$@"; do
  case "$arg" in
    --install-local) INSTALL=1 ;;
    --rules=*)
      RULES_SET=1
      RULES_SEL="$(csv_to_space "${arg#--rules=}")"
      ;;
    --skills=*)
      SKILLS_SET=1
      SKILLS_SEL="$(csv_to_space "${arg#--skills=}")"
      ;;
    --targets=*)
      TARGETS_SET=1
      TARGETS_SEL="$(csv_to_space "${arg#--targets=}")"
      ;;
    *)
      echo "unknown arg: $arg" >&2
      echo "usage: $0 [--install-local] [--rules=a,b] [--skills=a,b] [--targets=a,b]" >&2
      exit 1
      ;;
  esac
done

if [ "$RULES_SET" -eq 0 ]; then RULES_SEL="$ALL_RULES"; fi
if [ "$SKILLS_SET" -eq 0 ]; then SKILLS_SEL="$ALL_SKILLS"; fi
if [ "$TARGETS_SET" -eq 0 ]; then TARGETS_SEL="$ALL_TARGETS"; fi

validate_subset rule "$RULES_SEL" "$ALL_RULES"
validate_subset skill "$SKILLS_SEL" "$ALL_SKILLS"
validate_subset target "$TARGETS_SEL" "$ALL_TARGETS"

if [ "$INSTALL" -eq 1 ] && [ "$(count_words "$RULES_SEL")" -eq 0 ] && [ "$(count_words "$SKILLS_SEL")" -eq 0 ]; then
  echo "nothing to install: pick at least one rule or skill" >&2
  exit 1
fi
if [ "$INSTALL" -eq 1 ] && [ "$(count_words "$TARGETS_SEL")" -eq 0 ]; then
  echo "nothing to install: pick at least one target" >&2
  exit 1
fi

mkdir -p "$OUT_CURSOR"
for name in $RULES_SEL; do
  src="$RULES/$name.md"
  [ -f "$src" ] || { echo "missing $src" >&2; exit 1; }
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

if [ "$INSTALL" -ne 1 ]; then
  exit 0
fi

# Resolve forge root: .../sparklore-forge/skills/sparklore-architecture-gates -> ../..
FORGE="$(cd "$ROOT/../.." && pwd)"
CURSOR_RULES="$FORGE/.cursor/rules"
CLAUDE_RULES="${HOME}/.claude/rules"
CURSOR_SKILLS_ROOT="$FORGE/.cursor/skills"
AGENTS_SKILLS_ROOT="$FORGE/.agents/skills"

want_target() { in_list "$1" "$TARGETS_SEL"; }

if want_target cursor-rules || want_target claude-rules; then
  mkdir -p "$CURSOR_RULES" "$CLAUDE_RULES"
  for name in $RULES_SEL; do
    if want_target cursor-rules; then
      cp "$OUT_CURSOR/$name.mdc" "$CURSOR_RULES/$name.mdc"
      echo "installed Cursor .mdc: $name"
    fi
    if want_target claude-rules; then
      cp "$RULES/$name.md" "$CLAUDE_RULES/$name.md"
      echo "installed Claude rules: $name"
    fi
  done
fi

mirror_skill() {
  local skill_id="$1"
  local src="$SKILLS_ROOT/$skill_id"
  [ -d "$src" ] || { echo "missing skill dir: $src" >&2; exit 1; }
  if want_target cursor-skills; then
    local dest="$CURSOR_SKILLS_ROOT/$skill_id"
    mkdir -p "$dest"
    cp "$src/SKILL.md" "$dest/"
    [ -f "$src/INSTALL.md" ] && cp "$src/INSTALL.md" "$dest/"
    [ -f "$src/checklist.md" ] && cp "$src/checklist.md" "$dest/"
    if [ -d "$src/rules" ]; then
      mkdir -p "$dest/rules"
      cp "$src/rules"/*.md "$dest/rules/" 2>/dev/null || true
    fi
    echo "mirrored skill -> $dest"
  fi
  if want_target agents-skills; then
    local dest="$AGENTS_SKILLS_ROOT/$skill_id"
    mkdir -p "$dest"
    cp "$src/SKILL.md" "$dest/"
    [ -f "$src/INSTALL.md" ] && cp "$src/INSTALL.md" "$dest/"
    [ -f "$src/checklist.md" ] && cp "$src/checklist.md" "$dest/"
    if [ -d "$src/rules" ]; then
      mkdir -p "$dest/rules"
      cp "$src/rules"/*.md "$dest/rules/" 2>/dev/null || true
    fi
    echo "mirrored skill -> $dest"
  fi
}

for skill_id in $SKILLS_SEL; do
  mirror_skill "$skill_id"
done

echo "done. rules=$RULES_SEL skills=$SKILLS_SEL targets=$TARGETS_SEL"
