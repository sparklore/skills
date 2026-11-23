# Workflow and quality guardrails

1. **Align before coding**
   - When a new requirement lacks clear Acceptance Criteria, ask 3–5 boundary questions first, update `SPEC.md`, and wait for confirmation before changing code.
   - Execute only the currently agreed sub-task; do not opportunistically refactor unrelated files.

2. **Code quality hard lines**
   - Honor existing type definitions; do not use `any` or type assertions to bypass the typechecker.
   - Prefer existing helpers and components in the repo; do not reinvent them.

3. **Mandatory automated verification (highest priority)**
   - After any code change, you must run the repo’s verification commands in the terminal (example shape: `npm run typecheck && npm run lint && npm test` — use what this repo actually documents).
   - On failure, read the logs and fix until every check is green before ending the turn.

Chinese reference (not installed): `zh/engineering-guardrails.md`
