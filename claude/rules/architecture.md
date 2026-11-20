# Architecture first

When a change touches data ownership, transaction boundaries, process boundaries, auth, data models, cross-service contracts, async events, scheduled jobs, or cache projections: write a short design **before** code. If the project has `docs/design/`, put it there. Design must cover: scope, data flow, invariants, failure & concurrency, acceptance.

Small edits still follow `engineering` for minimal diff. 「改动很小」 / "the change is small" does **not** waive this rule.

## Forbidden

- 「先过渡」 / "ship a temporary bridge" with no deadline and no ledger entry.
- Dual-write, dual truth, silent fallback to an old data source. Putting orchestration / retry / prompts / bypass into Go/JS without prior disclosure → `no-silent-orchestration`.
- Copying known races, N+1, or full-key scans from the legacy impl. Recording legacy differences → `legacy-align` only.
- Multi-replica deployments using in-process locks or memory as mutex or truth.
- Using cache or a message channel as the entity’s only persistence. Records with monetary or ledger semantics must live in durable storage.
- Critical state triggered only by the client, with no server-side backstop.
- Events that need reliable delivery: publish after commit without an outbox, or push into a lossy channel.

Bounded transitions require all of: ledger entry, acceptance criteria, prohibitions, next action. Conflicts with prior architecture decisions go into the ledger with a deadline or trigger condition.

## Design must answer

| Dimension | Invariant |
|---|---|
| Data ownership | Entities only in durable store; cache is projection / lock / idempotency |
| Transactions | Monetary and state changes in one transaction; no half-applied failure |
| Idempotency | Write APIs and jobs must be safely replayable |
| Concurrency | Row locks or DB-level locks |
| Async | Follow the project’s existing tiers; reliable events must not downgrade to lossy channels |
| Scheduling | Where it runs, mutual exclusion, re-entrancy, crash recovery |
| Cache | Who writes/reads, invalidation, reconciliation; on cache failure fall back to durable store or fail closed |
| Contracts | External behavior differences must be ledgered |

Chinese reference (not installed): `zh/architecture.md`
