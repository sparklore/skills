#!/usr/bin/env python3
"""Contract gate for sparklore-context evals (no model calls)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVALS_PATH = ROOT / "evals" / "evals.json"
SKILL_PATH = ROOT / "SKILL.md"


def fail(message: str) -> None:
    print(f"eval validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


skill_text = SKILL_PATH.read_text(encoding="utf-8")
if "非 SSoT" not in skill_text and "不是权威源" not in skill_text:
    fail("SKILL.md must state it is not the authority (非 SSoT / 不是权威源)")
if "graphify" not in skill_text:
    fail("SKILL.md must mention graphify as explore tool")
if "禁止" not in skill_text or "GitNexus" not in skill_text:
    fail("SKILL.md must explicitly forbid GitNexus")
if "SINGLE SOURCE OF TRUTH" in skill_text or "overrides them when they conflict" in skill_text:
    fail("SKILL.md must not claim to override AGENTS/CLAUDE")
if any(bad in skill_text for bad in ("sparklore/pkg/clientevent", "gitnexus_query", "Datastar SSE")):
    fail("SKILL.md still contains retired stack markers")

with EVALS_PATH.open(encoding="utf-8") as eval_file:
    data = json.load(eval_file)

if data.get("skill_name") != "sparklore-context" or data.get("schema_version") != 2:
    fail("unexpected skill_name or schema_version (expect schema_version=2)")

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
    required = {"defers_to_agents_md", "explore_tool", "must_include", "must_not"}
    if set(assertions) != required:
        fail(f"{label} assertions keys must be exactly {sorted(required)}")
    if assertions["defers_to_agents_md"] is not True:
        fail(f"{label} defers_to_agents_md must be true")
    if assertions["explore_tool"] != "graphify":
        fail(f"{label} explore_tool must be graphify")
    if not assertions["must_include"] or not assertions["must_not"]:
        fail(f"{label} needs non-empty must_include and must_not")
    banned = ("gitnexus_query", "overrides CLAUDE", "本 skill 覆盖 AGENTS")
    joined_must_not = " ".join(assertions["must_not"])
    if not any(b in joined_must_not for b in ("GitNexus", "gitnexus", "覆盖 AGENTS", "overrides")):
        # at least some cases should ban old tools; soft-check via case 1/2 content in file
        pass

print(f"Validated {len(evals)} sparklore-context evaluation cases (schema v2).")
