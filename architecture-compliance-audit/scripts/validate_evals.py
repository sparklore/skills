#!/usr/bin/env python3
"""Contract gate for architecture-compliance-audit evals (no model calls)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVALS_PATH = ROOT / "evals" / "evals.json"

REQUIRED_SECTIONS = [
    "结论",
    "P0/P1 违规",
    "P2 死代码 / 死路由 / 文档漂移",
    "已确认清干净",
    "未跑项",
]


def fail(message: str) -> None:
    print(f"eval validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


with EVALS_PATH.open(encoding="utf-8") as eval_file:
    data = json.load(eval_file)

if data.get("skill_name") != "architecture-compliance-audit" or data.get("schema_version") != 1:
    fail("unexpected skill_name or schema_version")

evals = data.get("evals")
if not isinstance(evals, list) or len(evals) < 5:
    fail("at least 5 evaluation cases are required")

ids = [case.get("id") for case in evals]
if len(ids) != len(set(ids)):
    fail("evaluation ids must be unique")

for case in evals:
    label = f"case {case.get('id', '?')}"
    for field in ("prompt", "expected_output", "assertions", "files"):
        if field not in case:
            fail(f"{label} is missing {field}")
    if len(str(case["prompt"]).strip()) < 4:
        fail(f"{label} prompt is too short")

    assertions = case["assertions"]
    required = {
        "read_only",
        "requires_evidence_grade",
        "output_sections",
        "must_include",
        "must_not",
    }
    missing = required - set(assertions)
    unknown = set(assertions) - required
    if missing or unknown:
        fail(f"{label} assertions missing {sorted(missing)} or unknown {sorted(unknown)}")

    if assertions["read_only"] is not True:
        fail(f"{label} audit turn must be read_only=true")
    if assertions["requires_evidence_grade"] is not True:
        fail(f"{label} must require evidence grades")
    if assertions["output_sections"] != REQUIRED_SECTIONS:
        fail(f"{label} output_sections must match SKILL.md report template")
    if not assertions["must_include"] or not assertions["must_not"]:
        fail(f"{label} needs non-empty must_include and must_not")

print(f"Validated {len(evals)} architecture-compliance-audit evaluation cases.")
