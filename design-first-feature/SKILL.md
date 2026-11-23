---
description: Design-first requirement for feature/API changes and major refactors. Forces AI to produce a brief design doc (scope, interfaces, data flow, edge cases, verification plan) before coding.
alwaysApply: false
---

# Design-First Skill (Feature/API Change Guard)

Trigger this skill when the user request includes one or more:
- "add", "implement", "new", "feature", “添加”、“实现”、“新”、“功能”
- "API", "endpoint", "route", "contract"
- "refactor" (especially if touching multiple modules/files)
- "schema change", "data model change"
- "behavior change" (user-visible or breaking change)

## Required Output (MUST do in order)
1) Problem & Goal
- 1-3 lines describing what is being changed and why

2) Scope
- files/modules to touch (explicit list)
- files/modules to NOT touch

3) Interfaces & Contracts
- function/class signatures or API request/response shapes
- error cases + how they are represented (status/code/messages)

4) Data Flow
- step-by-step flow from input -> processing -> output
- where validation happens
- where side effects happen (DB/network/fs)

5) Edge Cases / Invariants
- list at least 5 key edge cases or invariants relevant to the change

6) Implementation Plan (small steps)
- numbered steps, each step small and testable

7) Verification Plan
- unit tests / integration tests to add or update
- how to run them (commands)
- expected results or assertions
- **编码后必须回填已执行结果**（PASS/FAIL）；未 PASS 不得宣称完成 — 见规则 `delivery-gate`「下一步动作」/ `/ship-gate`

## Coding Constraints (MUST)
- Do not write the full implementation until the required design output is provided.
- For non-trivial changes, include at least one test plan item before coding.
- If requirements are ambiguous or missing, ask up to 3 targeted questions instead of coding.
- After coding, run the Verification Plan and paste evidence; wait for user「验收通过」before next topic when acceptance gate is active.

## Allowed Exceptions
- If the change is purely trivial (e.g., rename a variable, fix a one-line bug, formatting only), the skill may be skipped and the AI should state: “Trivial change detected; design doc skipped.”
