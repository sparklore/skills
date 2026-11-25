---
name: ux-proof-workflow
description: >-
  4-stage verification workflow preventing assumption-driven plans, dropped swarm
  promises, and mock-only "done" claims. Use before pitching any user-facing plan,
  before launching /swarm or subagents, and before reporting completion.
---

# UX Proof Workflow (`ux-proof-workflow`)

Use this 4-stage workflow on every user-facing feature, bugfix, UX overhaul, or `/swarm` delegation across `sparklore-clients` and `sparklore-forge`.

## Stage 1 — End-to-End Runtime Trace (Read-Only, Before Planning)

Do not propose fixes, latencies, or UX promises until you have read and cited the real code path end-to-end:

1. **Click / Entry (`assets/*.js`, `extensions/**/*.js`):** Locate the exact DOM element, tooltip/title, click handler, and state toggles (`file:line`).
2. **Client Transport & Routing (`assets/orb-*.js`):** Trace where input actually goes (e.g., `/api/gen/ask` vs `/api/quest/start`, `SpeechRecognition` vs `MediaRecorder`, VAD thresholds, error handling).
3. **Server Handler & Model Slot (`internal/server/*.go`, `internal/assistant/*.go`):** Trace route registration, handler implementation, streaming vs blocking HTTP calls, and exact `CognitiveSlots` / `LLMConfig` resolution.
4. **Quest / Engine / Storage (`internal/quest/*.go`, `extensions/*.json`):** Trace `QuestFlow` steps, tier selection (`decision` / `fast` / `deep`), SSE delta events, and record persistence.

Rule: Never guess any link. If a segment was not read yet, mark it `UNREAD` and read it before pitching the plan.

## Stage 2 — Requirement Parity Matrix (`R1..Rn`, Before Coding or `/swarm`)

Before editing or spawning workers, build a parity matrix mapping every promise made to the user:

| Req | User Promise | Target Files (`file:line`) | Single Owner (incl. Cross-Layer Seams) | Planned Live Proof |
|---|---|---|---|---|

Guardrails when delegating:
- Paste every `R#` **verbatim** into its owner's brief.
- Never split an end-to-end behavior (e.g., tooltip copy in `orb.js` + click behavior in `orb-gen.js`, or slot lookup in `admin_llm.go` + caller in `voice.go`) across two uncoordinated briefs without an explicit owner responsible for the seam.
- Check parity before spawning: confirm 100% of `R1..Rn` have an owner AND a live-proof check.

## Stage 3 — Honest Execution (Zero Fake Shims)

While implementing (coordinator or worker):
- Never simulate a missing backend capability on the client (e.g., streaming a complete `r.json()` response locally and calling it "streaming TTS").
- Never suppress HTTP non-2xx / upstream errors into empty strings or fake success states.
- Never change UI labels/tooltips unless the underlying click/runtime behavior matches the label.
- If a plan assumption turns out false in real code, **stop and escalate / re-plan** instead of shipping a hollow substitute.

## Stage 4 — Live User-Journey Verification & Mandatory Proof Table

Before reporting completion:
1. Run static & unit checks (`go build`, `go vet`, targeted `go test`, `make lint-js`, Node tests).
2. Run at least one **live runtime verification** exercising the real compiled binary with real config structure (not `-data-dir :memory:` with empty models unless testing the empty state specifically), real SSE/HTTP calls, real UI click path, and real measured timing if latency is part of the promise.
3. Deliver the **Requirement Proof Table** in your final message:

| Req | Plan Promise | Actual Diff (`file:line`) | Verification Kind (`LIVE RUNTIME` / `UNIT-MOCK` / `NOT RUN`) | Exact Command + Observed Output | Status (`VERIFIED` / `UNVERIFIED`) |
|---|---|---|---|---|---|

4. Include copy-pasteable verification commands/steps immediately after the table.
5. Never write `"all done"` or `"fixed"` if any `R#` row is `UNVERIFIED` or tested only with mocks.
