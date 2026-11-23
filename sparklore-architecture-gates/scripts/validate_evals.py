#!/usr/bin/env python3
"""Contract gate for sparklore-architecture-gates evals (no model calls)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVALS_PATH = ROOT / "evals" / "evals.json"

ALLOWED_GATES = {
    "data-driven",
    "no-silent-orchestration",
    "no-zombie-dual-track",
    "audit-evidence",
}

# Prompt tokens that spoil a disguised (伪装) eval — Agent must not be told it is a test.
DISGUISED_PROMPT_FORBIDDEN = (
    "审计",
    "合规",
    "规则",
    "闸",
    "data-driven",
    "no-silent-orchestration",
    "no-zombie-dual-track",
    "audit-evidence",
    "sparklore-gates",
    "/sparklore-gates",
)


def fail(message: str) -> None:
    print(f"eval validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


with EVALS_PATH.open(encoding="utf-8") as eval_file:
    data = json.load(eval_file)

if data.get("skill_name") != "sparklore-architecture-gates" or data.get("schema_version") != 1:
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

    if "disguised" in case and not isinstance(case["disguised"], bool):
        fail(f"{label} disguised must be a boolean when present")

    assertions = case["assertions"]
    required = {"gates_checked", "blocks_code_until_ok", "must_include", "must_not"}
    missing = required - set(assertions)
    unknown = set(assertions) - required
    if missing or unknown:
        fail(f"{label} assertions missing {sorted(missing)} or unknown {sorted(unknown)}")

    gates = assertions["gates_checked"]
    if not gates or set(gates) - ALLOWED_GATES:
        fail(f"{label} gates_checked must be non-empty subset of {sorted(ALLOWED_GATES)}")
    if assertions["blocks_code_until_ok"] is not True:
        fail(f"{label} must block code until gates pass (blocks_code_until_ok=true)")
    if not assertions["must_include"] or not assertions["must_not"]:
        fail(f"{label} needs non-empty must_include and must_not")

    if case.get("disguised") is True:
        prompt = str(case["prompt"])
        prompt_lower = prompt.lower()
        for token in DISGUISED_PROMPT_FORBIDDEN:
            if token.lower() in prompt_lower:
                fail(
                    f"{label} is disguised but prompt contains forbidden token {token!r}"
                )

print(f"Validated {len(evals)} sparklore-architecture-gates evaluation cases.")
