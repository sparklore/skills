#!/usr/bin/env python3
"""Contract gate for session-charter evals (no model calls)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVALS_PATH = ROOT / "evals" / "evals.json"

REQUIRED_SECTIONS = [
    "唯一目标（一句话）",
    "仓库",
    "交付物",
    "验收",
    "模式",
]


def fail(message: str) -> None:
    print(f"eval validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


with EVALS_PATH.open(encoding="utf-8") as eval_file:
    data = json.load(eval_file)

if data.get("skill_name") != "session-charter" or data.get("schema_version") != 1:
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
        "sections_in_order",
        "writes_files_before_confirm",
        "max_clarifying_questions",
        "must_include",
        "must_not",
    }
    missing = required - set(assertions)
    unknown = set(assertions) - required
    if missing or unknown:
        fail(f"{label} assertions missing {sorted(missing)} or unknown {sorted(unknown)}")

    if assertions["sections_in_order"] != REQUIRED_SECTIONS:
        fail(f"{label} sections_in_order must match SKILL.md charter template")
    if assertions["writes_files_before_confirm"] is not False:
        fail(f"{label} must set writes_files_before_confirm=false")
    if not 0 <= assertions["max_clarifying_questions"] <= 3:
        fail(f"{label} max_clarifying_questions must be 0..3")
    if not assertions["must_include"] or not assertions["must_not"]:
        fail(f"{label} needs non-empty must_include and must_not")

print(f"Validated {len(evals)} session-charter evaluation cases.")
