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
    "audit-evidence": "Evidence grades G1 已确认 / G2 读过链 / G3 推断; no estimates on G3; set-diff is not causation",
    "data-driven": "Data-driven 数据驱动: no business hardcoding, dedicated routes/capabilities, or freeze-section growth; data first",
    "no-silent-orchestration": "No silent orchestration/retry/fallback in Go/JS; disclose why before edit; wait for 「可以改」",
    "no-zombie-dual-track": "No zombies/dual-track: prod-zero calls kept alive by tests; relocate≠delete; single SSoT",
    "architecture": "Short design first for ownership/txn/auth/cross-service/events/schedulers/cache; no open-ended bridges",
    "change-record": "After code/config/script changes: comments (default none), CHANGELOG, copy-pasteable commit message. Skip for pure Q&A",
    "communication": "Default reply/doc style (internal STE): one point per sentence, one term per concept, active voice, risks before action, label 事实/推测/建议/待核验",
    "codegraph": "When .codegraph/ exists, use codegraph_explore for structure before reading files",
    "db-change": "After migrations, Agent runs this repo's migrate command and syncs schema snapshot; do not only ask the user",
    "delivery-gate": "Acceptance reply format and human gates; wait for 「验收通过」; Chinese reply headings",
    "dont-read-junk": "Do not read vendor/build/logs/bulk test dumps",
    "engineering": "Daily coding: short plan, minimal diff, reuse first, run related tests, no fake verified claims",
    "engineering-guardrails": "Align before code; type-safe; mandatory local verification before ending the turn",
    "frontend": "Follow existing page patterns, tokens, API layer; do not reshape APIs for UI convenience",
    "graphify": "graphify knowledge graph context",
    "legacy-align": "When aligning to legacy, preserve cache-key semantics; document behavior diffs",
    "no-fake-data": "No invented business data; empty is valid; shapes match real samples",
    "session-plan": "Charter first; verifiable slices; sign-off with C=是; one wave per chat; filled handoff block",
    "test-data": "Short unique test names; delete before close; fail on delete errors; no seed litter",
    "ui-designer": "Tokens/components first; WCAG AA; checkable numbers; page code is frontend",
    "visible-entry": "Require uncommented visible entry before API work unless 「强制做这条、不管有没有入口」",
}

CLAUDE_README = """# Claude 规则包（远程仓备份里的源）

- **四闸**：SSoT 在 `../../sparklore-architecture-gates/rules/`；本目录同名文件由 `sync-tool-rules.sh` 生成，禁止手改。
- **其余 `.md`**：非闸 SSoT（纯 Markdown，不要加 Cursor frontmatter）。**执行正文为英文**；用户触发词保留中文（如「验收通过」「可以改」「C=是」「豁免」）。
- **`zh/`**：中文参考备份，**不**安装到活镜像；Agent 只读顶层英文 `.md`。
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
