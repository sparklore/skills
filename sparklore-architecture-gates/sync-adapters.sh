#!/usr/bin/env bash
# Generate Cursor .mdc adapters from plain rules/*.md; optionally install project mirrors.
# Usage:
#   ./sync-adapters.sh
#   ./sync-adapters.sh --install-local
#   ./sync-adapters.sh --install-local --project-root=/path/to/any-repo
#   ./sync-adapters.sh --install-local \
#     --rules=data-driven,no-silent-orchestration,no-zombie-dual-track \
#     --skills=sparklore-architecture-gates,architecture-compliance-audit,intent-compile,session-charter,acceptance-gate \
#     --targets=cursor-rules,claude-rules,cursor-skills,agents-skills
# Omitted --rules/--skills/--targets mean "all". Explicit empty (--rules=) means none.
# 永不写入 ~/.claude / ~/.cursor；只写 --project-root（默认 = skills 父目录）。
# Compatible with macOS /bin/bash 3.2 (no namerefs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
RULES="$ROOT/rules"
OUT_CURSOR="$ROOT/adapters/cursor"
SKILLS_ROOT="$(cd "$ROOT/.." && pwd)"
PROJECT_ROOT="$(cd "$SKILLS_ROOT/.." && pwd)"

ALL_RULES="audit-evidence data-driven no-silent-orchestration no-zombie-dual-track"
ALL_SKILLS="sparklore-architecture-gates architecture-compliance-audit intent-compile session-charter acceptance-gate design-first-feature quality-guardrails code-review-audit simplify-codebase sparklore-context ux-proof-workflow"
ALL_TARGETS="cursor-rules claude-rules cursor-skills agents-skills"

DESC_audit_evidence='审计证据分级：每条发现标 G1 已确认 / G2 读过链 / G3 推断；G3 不得带预估或波次；差集不是结论'
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
    --project-root=*)
      raw="${arg#--project-root=}"
      if [ -z "$raw" ] || [ ! -d "$raw" ]; then
        echo "invalid --project-root: $raw" >&2
        exit 1
      fi
      PROJECT_ROOT="$(cd "$raw" && pwd)"
      ;;
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
      echo "usage: $0 [--install-local] [--project-root=PATH] [--rules=a,b] [--skills=a,b] [--targets=a,b]" >&2
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

want_target() { in_list "$1" "$TARGETS_SEL"; }

# 有效动作 = 选了规则且选了规则目标，或选了 skill 且选了 skill 目标。
# 一个动作都没有时必须失败：否则控制台会把「什么都没装」显示成「完成」。
if [ "$INSTALL" -eq 1 ]; then
  ACTIONS=0
  if [ "$(count_words "$RULES_SEL")" -gt 0 ]; then
    if want_target cursor-rules || want_target claude-rules; then ACTIONS=$((ACTIONS + 1)); else echo "skip rules: no rule target (cursor-rules / claude-rules) selected"; fi
  fi
  if [ "$(count_words "$SKILLS_SEL")" -gt 0 ]; then
    if want_target cursor-skills || want_target agents-skills; then ACTIONS=$((ACTIONS + 1)); else echo "skip skills: no skill target (cursor-skills / agents-skills) selected"; fi
  fi
  if [ "$ACTIONS" -eq 0 ]; then
    echo "nothing to install: pick rules with a rule target, or skills with a skill target" >&2
    exit 1
  fi
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

# skills/ 只是远程仓备份；活镜像只写项目根，不写用户 home。
CURSOR_RULES_PROJECT="$PROJECT_ROOT/.cursor/rules"
CLAUDE_RULES_PROJECT="$PROJECT_ROOT/.claude/rules"
CURSOR_SKILLS_PROJECT="$PROJECT_ROOT/.cursor/skills"
CLAUDE_SKILLS_PROJECT="$PROJECT_ROOT/.claude/skills"
AGENTS_SKILLS_ROOT="$PROJECT_ROOT/.agents/skills"

echo "sync-adapters project-root=$PROJECT_ROOT"

copy_rule_mdc() {
  local name="$1"
  local dest_dir="$2"
  mkdir -p "$dest_dir"
  cp "$OUT_CURSOR/$name.mdc" "$dest_dir/$name.mdc"
  echo "installed Cursor .mdc: $dest_dir/$name.mdc"
}

if want_target cursor-rules || want_target claude-rules; then
  for name in $RULES_SEL; do
    if want_target cursor-rules; then
      copy_rule_mdc "$name" "$CURSOR_RULES_PROJECT"
    fi
    if want_target claude-rules; then
      mkdir -p "$CLAUDE_RULES_PROJECT"
      cp "$RULES/$name.md" "$CLAUDE_RULES_PROJECT/$name.md"
      echo "installed Claude rules: $CLAUDE_RULES_PROJECT/$name.md"
    fi
  done
fi

copy_skill_tree() {
  local src="$1"
  local dest="$2"
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.DS_Store' \
      --exclude '.git/' \
      "$src/" "$dest/"
  else
    cp "$src/SKILL.md" "$dest/"
    [ -f "$src/INSTALL.md" ] && cp "$src/INSTALL.md" "$dest/"
    [ -f "$src/checklist.md" ] && cp "$src/checklist.md" "$dest/"
    for sub in rules evals scripts references agents assets docs; do
      if [ -d "$src/$sub" ]; then
        mkdir -p "$dest/$sub"
        cp -R "$src/$sub/." "$dest/$sub/" 2>/dev/null || true
      fi
    done
  fi
  chmod +x "$dest/scripts/"*.py 2>/dev/null || true
  echo "mirrored skill -> $dest"
}

mirror_skill() {
  local skill_id="$1"
  local src="$SKILLS_ROOT/$skill_id"
  [ -d "$src" ] || { echo "missing skill dir: $src" >&2; exit 1; }
  if want_target cursor-skills; then
    copy_skill_tree "$src" "$CURSOR_SKILLS_PROJECT/$skill_id"
    copy_skill_tree "$src" "$CLAUDE_SKILLS_PROJECT/$skill_id"
  fi
  if want_target agents-skills; then
    copy_skill_tree "$src" "$AGENTS_SKILLS_ROOT/$skill_id"
  fi
}

for skill_id in $SKILLS_SEL; do
  mirror_skill "$skill_id"
done

echo "done. rules=$RULES_SEL skills=$SKILLS_SEL targets=$TARGETS_SEL project-root=$PROJECT_ROOT"
