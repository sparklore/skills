# Session and Plan

## Charter (before complex work starts)

When the task spans many files, architecture, data models, cross-service work, large docs, or the user did not give writable / forbidden paths, write first:

1. Single goal (one sentence)
2. Writable / read-only / forbidden paths
3. Deliverables list
4. Acceptance commands
5. Mode: Plan only or Agent execute

If the user says 「用默认 charter」 / "use the default charter", or already pasted a full charter: confirm in one sentence, then start. When the user invokes the acceptance gate, use Charter together with `delivery-gate`.

## Verifiable slices（可验收切片）

Split complex Plans into independently verifiable slices (one call chain / one ledger debt / one green acceptance command). At most 8 todos per wave. Do not default to horizontal mega-packs (「后端 → 前端 → 测试」 / "backend → frontend → tests"). Pure contract / zombie deletion / collection-data work may be a single-layer slice but must still carry its own acceptance. Over the limit → split waves or open a new chat before executing.

## Sign-off gate (before editing files)

When the message contains `Implement the plan`, 「按计划执行」, 「执行 plan」, or attaches a `.plan.md` asking to start:

First output a scope table (will change | will not change | top 3 risks), conflicts with existing architecture decisions, rollback commands, and A 范围对吗 / B 验收够吗 / C 可以执行吗 (A scope OK? / B acceptance enough? / C OK to execute?).

Until the user writes **C=是** (or 「可以执行」 / 「开干」 / 「直接执行无需再问」), do not edit files, commit, or run environment-changing commands. Read-only is OK. After approval, do not edit the plan file itself unless the user asks.

## One wave per conversation

For a plan that says `Don't stop until you have completed all the to-dos`: run it at most once in the same chat. From the second wave onward, pass the sign-off gate above, or ask the user to open a new chat. Do not chain three or more `Implement the plan` runs without **C=是**.

## Handoff block for a new chat

When the user says 「下一步」 / 「新开 chat」 / 「执行指令」 / 「给我指令」, or a wave finishes and needs a new session: give a **fully filled** block — no `<占位符>` / `<placeholder>` left.

Fill from the current repo: goal, writable/forbidden paths, deliverables, acceptance commands, ≤10 lines of state (from CHANGELOG and that task’s progress docs). End with `C=是；直接执行无需再问。` and remind them to paste it in the new chat. Do not copy another project’s DB names, doc numbers, or start commands.

Chinese reference (not installed): `zh/session-plan.md`
