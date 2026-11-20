#!/usr/bin/env python3
"""Contract gate for acceptance-gate evals (no model calls)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVALS_PATH = ROOT / "evals" / "evals.json"

REQUIRED_BLOCKS = ["本步已完成", "验收证据", "下一步动作"]


def fail(message: str) -> None:
    print(f"eval validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


with EVALS_PATH.open(encoding="utf-8") as eval_file:
    data = json.load(eval_file)

if data.get("skill_name") != "acceptance-gate" or data.get("schema_version") != 1:
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
    required = {"step_report_blocks", "waits_for_user_pass", "must_include", "must_not"}
    missing = required - set(assertions)
    unknown = set(assertions) - required
    if missing or unknown:
        fail(f"{label} assertions missing {sorted(missing)} or unknown {sorted(unknown)}")

    if assertions["step_report_blocks"] != REQUIRED_BLOCKS:
        fail(f"{label} step_report_blocks must match SKILL.md report template")
    if assertions["waits_for_user_pass"] is not True:
        fail(f"{label} must wait for user 验收通过 (waits_for_user_pass=true)")
    if not assertions["must_include"] or not assertions["must_not"]:
        fail(f"{label} needs non-empty must_include and must_not")

print(f"Validated {len(evals)} acceptance-gate evaluation cases.")
