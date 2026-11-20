#!/usr/bin/env python3
"""Score architecture-compliance-audit eval answers (no model calls).

Usage:
  python3 scripts/score_evals.py <answers_dir>

answers_dir must contain one <id>.md per eval in evals/evals.json.
Scoring uses assertions.must_include / must_not only (criteria live in data).
Missing answer file → FAIL. Any FAIL → exit 1.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVALS_PATH = ROOT / "evals" / "evals.json"


def usage() -> None:
    print(
        "usage: score_evals.py <answers_dir>\n"
        "  answers_dir: directory with <id>.md per eval (e.g. evals/answers-pass/)",
        file=sys.stderr,
    )


def score_case(case: dict, text: str | None) -> tuple[bool, list[str]]:
    """Return (passed, detail lines). text=None means missing file."""
    case_id = case["id"]
    assertions = case["assertions"]
    must_include = list(assertions["must_include"])
    must_not = list(assertions["must_not"])
    details: list[str] = []

    if text is None:
        details.append("missing answer file")
        details.append(f"  must_include (unchecked): {must_include}")
        details.append(f"  must_not (unchecked): {must_not}")
        return False, details

    hit_include: list[str] = []
    missing_include: list[str] = []
    for phrase in must_include:
        if phrase in text:
            hit_include.append(phrase)
        else:
            missing_include.append(phrase)

    hit_forbidden: list[str] = []
    clear_forbidden: list[str] = []
    for phrase in must_not:
        if phrase in text:
            hit_forbidden.append(phrase)
        else:
            clear_forbidden.append(phrase)

    details.append(f"must_include hit: {hit_include}")
    details.append(f"must_include missing: {missing_include}")
    details.append(f"must_not clear: {clear_forbidden}")
    details.append(f"must_not hit (fail): {hit_forbidden}")

    passed = not missing_include and not hit_forbidden
    return passed, details


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] in ("-h", "--help"):
        usage()
        return 2 if len(argv) != 2 else 0

    answers_dir = Path(argv[1]).expanduser()
    if not answers_dir.is_dir():
        print(f"score failed: answers_dir is not a directory: {answers_dir}", file=sys.stderr)
        return 2

    with EVALS_PATH.open(encoding="utf-8") as eval_file:
        data = json.load(eval_file)

    evals = data.get("evals")
    if not isinstance(evals, list) or not evals:
        print("score failed: evals.json has no evals", file=sys.stderr)
        return 2

    failures = 0
    for case in sorted(evals, key=lambda c: int(c["id"])):
        case_id = case["id"]
        answer_path = answers_dir / f"{case_id}.md"
        text = answer_path.read_text(encoding="utf-8") if answer_path.is_file() else None
        passed, details = score_case(case, text)
        status = "PASS" if passed else "FAIL"
        if not passed:
            failures += 1
        print(f"[{status}] eval {case_id}: {answer_path.name}")
        for line in details:
            print(f"  {line}")

    total = len(evals)
    passed_n = total - failures
    print(f"\nSummary: {passed_n}/{total} PASS, {failures} FAIL")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
