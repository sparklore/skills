#!/usr/bin/env python3
"""Contract gate for code-review-audit evals (no model calls)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVALS_PATH = ROOT / "evals" / "evals.json"
REQUIRED_SECTIONS = ["审查结论", "问题清单", "测试缺口"]


def fail(message: str) -> None:
    print(f"eval validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


with EVALS_PATH.open(encoding="utf-8") as eval_file:
    data = json.load(eval_file)

if data.get("skill_name") != "code-review-audit" or data.get("schema_version") != 1:
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
    assertions = case["assertions"]
    required = {
        "read_only_default",
        "requires_evidence",
        "output_sections",
        "must_include",
        "must_not",
    }
    if set(assertions) != required:
        fail(f"{label} assertions keys must be exactly {sorted(required)}")
    if assertions["read_only_default"] is not True:
        fail(f"{label} read_only_default must be true")
    if assertions["requires_evidence"] is not True:
        fail(f"{label} requires_evidence must be true")
    if assertions["output_sections"] != REQUIRED_SECTIONS:
        fail(f"{label} output_sections must match report skeleton")
    if not assertions["must_include"] or not assertions["must_not"]:
        fail(f"{label} needs non-empty must_include and must_not")

print(f"Validated {len(evals)} code-review-audit evaluation cases.")
