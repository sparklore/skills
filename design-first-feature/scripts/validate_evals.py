#!/usr/bin/env python3
"""Contract gate for design-first-feature evals (no model calls)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVALS_PATH = ROOT / "evals" / "evals.json"
REQUIRED_SECTIONS = [
    "Problem & Goal",
    "Scope",
    "Interfaces & Contracts",
    "Data Flow",
    "Edge Cases / Invariants",
    "Implementation Plan",
    "Verification Plan",
]


def fail(message: str) -> None:
    print(f"eval validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


with EVALS_PATH.open(encoding="utf-8") as eval_file:
    data = json.load(eval_file)

if data.get("skill_name") != "design-first-feature" or data.get("schema_version") != 1:
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
        "sections_in_order",
        "min_edge_cases",
        "codes_before_design",
        "must_include",
        "must_not",
    }
    if set(assertions) != required:
        fail(f"{label} assertions keys must be exactly {sorted(required)}")
    if assertions["sections_in_order"] != REQUIRED_SECTIONS:
        fail(f"{label} sections_in_order must match SKILL.md")
    if assertions["min_edge_cases"] < 5:
        fail(f"{label} min_edge_cases must be >= 5")
    if assertions["codes_before_design"] is not False:
        fail(f"{label} codes_before_design must be false")
    if not assertions["must_include"] or not assertions["must_not"]:
        fail(f"{label} needs non-empty must_include and must_not")

print(f"Validated {len(evals)} design-first-feature evaluation cases.")
