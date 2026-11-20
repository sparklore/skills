#!/usr/bin/env bash
# Regenerate skills/claude + skills/cursor rule packs from SSoT.
# SSoT:
#   - 四闸: sparklore-architecture-gates/rules/*.md
#   - 其余共享规则: claude/rules/*.md（不含四闸；无 Cursor frontmatter）
#   - Cursor 专用: overlays/graphify.md
#   - Claude 专用: claude/rules/worktree.md（不生成到 cursor）
# Usage:
#   ./sync-tool-rules.sh
#   ./sync-tool-rules.sh --check
#   ./sync-tool-rules.sh --install-local
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export SYNC_TOOL_RULES_ROOT="$ROOT"
export SYNC_TOOL_RULES_FORGE="$(cd "$ROOT/.." && pwd)"
exec python3 - "$@" <<'PY'
import os, sys, pathlib, shutil

ROOT = pathlib.Path(os.environ["SYNC_TOOL_RULES_ROOT"])
FORGE = pathlib.Path(os.environ["SYNC_TOOL_RULES_FORGE"])
GATES_DIR = ROOT / "sparklore-architecture-gates" / "rules"
CLAUDE_DIR = ROOT / "claude" / "rules"
CURSOR_DIR = ROOT / "cursor" / "rules"
OVERLAYS = ROOT / "overlays"

GATES = {
    "audit-evidence",
    "data-driven",
    "no-silent-orchestration",
    "no-zombie-dual-track",
}

DESC = {
    "audit-evidence": "审计证据分级：每条发现标 G1 已确认 / G2 读过链 / G3 推断；G3 不得带预估或波次；差集不是结论",
    "data-driven": "数据驱动铁律：禁止业务硬编码、专用路由/capability、往冻结段加行；缺能力先改数据再加通用构件",
    "no-silent-orchestration": "禁止在 Go/JS 里静默加编排、重试、兜底；动手前必须如实说明为什么、好处、为何不进 QuestFlow",
    "no-zombie-dual-track": "禁止僵尸代码与双轨：生产零调用却靠测试/迁移/开关续命；删旧不搬家；单真相源",
    "architecture": "涉及数据所有权、事务、鉴权、跨服务、事件、定时、缓存时先短设计，不留无期限的过渡实现",
    "change-record": "改了代码、配置或脚本后：步骤注释、CHANGELOG、回复末尾可复制的中文 commit message。纯问答跳过",
    "codegraph": "项目装了 CodeGraph 时，结构问题先用 codegraph_explore，再对具体行读文件",
    "db-change": "改了迁移或表结构后，Agent 自己跑项目的迁移命令并同步结构快照，禁止只甩给人",
    "delivery-gate": "验收回复格式与人闸。阶段未 PASS 不进下一步；整单 PASS 后等用户「验收通过」",
    "dont-read-junk": "禁止读取依赖目录、构建产物、日志、大批量测试数据",
    "engineering": "日常编码：短计划、最小 diff、复用优先、相关测试实跑、不臆造不谎报",
    "engineering-guardrails": "核心工程约束、任务执行与自动验证规范",
    "frontend": "改前端页面时跟现有页面结构、设计令牌和请求层。禁止改接口形状来迁就界面",
    "graphify": "graphify knowledge graph context",
    "legacy-align": "对齐旧系统时按真实读路径实现。可以优化，但必须写下结构差异",
    "no-fake-data": "接口和联调禁止编造业务数据。没有记录时返回空；形状对齐真实样例",
    "session-plan": "复杂任务先 Charter；执行 plan 先签字；同一会话最多跑 1 波；换会话时给填好的开工指令",
    "test-data": "集成测试造数用短名、跑完删干净、删除失败要报出来。测试行不能留在联调库当种子",
    "ui-designer": "做界面规格时：设计系统优先、WCAG AA、用可核对的数字。页面代码不在本文件",
    "visible-entry": "做接口前先确认有未注释的可见入口在调用。没有入口的遗留接口默认不做",
}

CLAUDE_README = """# Claude 规则包（远程仓备份里的源）

- **四闸**：SSoT 在 `../../sparklore-architecture-gates/rules/`；本目录同名文件由 `sync-tool-rules.sh` 生成，禁止手改。
- **其余 `.md`**：非闸 SSoT（纯 Markdown，不要加 Cursor frontmatter）。
- **`worktree.md`**：仅 Claude。
- 活镜像在 `~/.claude/rules`（与 `~/.cursor/rules`、项目 `.cursor/rules` 必须一致）。安装：`../../install-local.sh`。
"""

CURSOR_README = """# Cursor 规则包（生成物）

本目录由 `../../sync-tool-rules.sh` 生成，禁止手改。`skills/` 整仓是远程备份；Agent 读的是活镜像：

- `~/.cursor/rules`
- `<forge>/.cursor/rules`

与 `~/.claude/rules` 条文一致。安装：`../../install-local.sh`。
"""


def body_of(text: str) -> str:
    if text.startswith("---"):
        parts = text.split("---", 2)
        if len(parts) >= 3:
            text = parts[2].lstrip("\n")
    if text and not text.endswith("\n"):
        text += "\n"
    return text


def mdc(desc: str, body: str) -> str:
    if body and not body.endswith("\n"):
        body += "\n"
    return f"---\ndescription: {desc}\nalwaysApply: true\n---\n\n{body}"


def write_or_check(path: pathlib.Path, content: str, check: bool) -> bool:
    if check:
        if not path.is_file() or path.read_text() != content:
            print(f"DRIFT {path}", file=sys.stderr)
            return False
        return True
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    print(f"wrote {path}")
    return True


def main() -> int:
    check = "--check" in sys.argv[1:]
    install = "--install-local" in sys.argv[1:]
    unknown = [a for a in sys.argv[1:] if a not in ("--check", "--install-local")]
    if unknown:
        print(f"unknown arg: {unknown[0]}", file=sys.stderr)
        print("usage: sync-tool-rules.sh [--check] [--install-local]", file=sys.stderr)
        return 1

    ok = True

    # 1) 四闸全文进两包（不省略条文）
    for name in sorted(GATES):
        src = GATES_DIR / f"{name}.md"
        if not src.is_file():
            print(f"missing gate SSoT: {src}", file=sys.stderr)
            return 1
        body = body_of(src.read_text())
        ok &= write_or_check(CLAUDE_DIR / f"{name}.md", body, check)
        ok &= write_or_check(CURSOR_DIR / f"{name}.mdc", mdc(DESC[name], body), check)

    # 2) 共享非闸：claude SSoT → 去 frontmatter；生成 cursor
    for src in sorted(CLAUDE_DIR.glob("*.md")):
        name = src.stem
        if name in ("README",) or name in GATES or name == "worktree":
            continue
        body = body_of(src.read_text())
        if name not in DESC:
            print(f"missing DESC for {name}", file=sys.stderr)
            return 1
        if check:
            if src.read_text() != body:
                print(f"DRIFT {src} (frontmatter/body)", file=sys.stderr)
                ok = False
        else:
            if src.read_text() != body:
                src.write_text(body)
                print(f"normalized {src}")
        ok &= write_or_check(CURSOR_DIR / f"{name}.mdc", mdc(DESC[name], body), check)

    # 3) Cursor overlay
    gsrc = OVERLAYS / "graphify.md"
    if not gsrc.is_file():
        print(f"missing {gsrc}", file=sys.stderr)
        return 1
    ok &= write_or_check(CURSOR_DIR / "graphify.mdc", mdc(DESC["graphify"], body_of(gsrc.read_text())), check)

    # 4) 不应有 worktree.mdc
    worktree_mdc = CURSOR_DIR / "worktree.mdc"
    if worktree_mdc.exists():
        if check:
            print(f"DRIFT unexpected {worktree_mdc}", file=sys.stderr)
            ok = False
        else:
            worktree_mdc.unlink()
            print(f"removed {worktree_mdc}")

    ok &= write_or_check(CLAUDE_DIR / "README.md", CLAUDE_README if CLAUDE_README.endswith("\n") else CLAUDE_README + "\n", check)
    ok &= write_or_check(CURSOR_DIR / "README.md", CURSOR_README if CURSOR_README.endswith("\n") else CURSOR_README + "\n", check)

    if check:
        if not ok:
            print("sync-tool-rules --check FAILED", file=sys.stderr)
            return 1
        print("sync-tool-rules --check OK")
        return 0

    if install:
        # 活镜像三处必须一致；skills/ 仓内文件只是远程备份检出，不是运行时真相
        rule_targets = [
            ("claude-rules", pathlib.Path.home() / ".claude" / "rules", "md"),
            ("cursor-rules-home", pathlib.Path.home() / ".cursor" / "rules", "mdc"),
            ("cursor-rules-project", FORGE / ".cursor" / "rules", "mdc"),
        ]
        for label, dest, kind in rule_targets:
            dest.mkdir(parents=True, exist_ok=True)
            if kind == "md":
                for p in CLAUDE_DIR.glob("*.md"):
                    if p.name == "README.md":
                        continue
                    shutil.copy2(p, dest / p.name)
            else:
                for p in CURSOR_DIR.glob("*.mdc"):
                    shutil.copy2(p, dest / p.name)
                shutil.copy2(CURSOR_DIR / "README.md", dest / "README.md")
            print(f"installed {label} -> {dest}")

    print("done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY
