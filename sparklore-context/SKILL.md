---
name: sparklore-context
description: |
  Use this skill whenever working on the Sparklore project — a Go monorepo with NATS-based microservices, event-driven architecture, and a thin-client web frontend. This skill provides the authoritative mental model, behavioral rules (hard gate), architecture reference, decision trees, and detailed step-by-step workflows.

  Use this skill for ANY task in this workspace — reading code, adding features, fixing bugs, or answering questions. Even if the user doesn't mention "Sparklore," if you're working in this repository, load this skill. Also trigger when the user types `/sparklore` to refresh context.

  This skill is the SINGLE SOURCE OF TRUTH for how to work in this project. CLAUDE.md files are quick-reference only — this skill overrides them when they conflict.
---

# Sparklore — Project Context & Behavioral Rules

## ⛔ THE HARD GATE (Non-Negotiable)

You must follow this sequence for EVERY code change. No exceptions, no shortcuts, no matter how "simple" the task seems.

```
1. IDENTIFY — what's the actual problem? Root cause, not symptom.
   - State your assumptions explicitly. If uncertain, ASK.

2. EXPLORE — before proposing ANY solution:
   a. Use GitNexus to trace relevant code paths (gitnexus_query, gitnexus_context)
   b. Scan the mistake registry for this domain (mistakes/*.md)
   c. Check architecture docs for constraints on the affected area
   d. Search codebase for existing patterns that solve this (GitNexus, not grep)
   e. Read ONLY files in the traced path — don't wander

3. PLAN — present a concise plan:
   - What changes, why, which files
   - Why this approach fits the architecture
   - Verification checkpoints: "Step 1 → verify: [check]. Step 2 → verify: [check]."

4. CROSS-CHECK — does this plan conflict with any documented architecture?
   - If yes → flag the conflict: "This conflicts with [document] section [X] which says [Y].
     Should I: (a) adjust the approach, or (b) update the docs?"
   - Let the user decide. Never silently violate documented architecture.

5. WAIT — for explicit approval.
   - Keywords: "yes", "go ahead", "approved", "proceed"
   - NO PERMISSION = NO ACTION. Do not begin until clearly confirmed.

6. EXECUTE — follow the approved plan exactly.
   - No deviations, no "while I'm here" improvements, no shortcuts.
   - Touch only what's needed. But: if you spot an architectural violation
     (e.g., domain service publishing to ui.event.*), FLAG IT — don't silently pass.

7. VERIFY — evidence before claims.
   - Tests pass. gitnexus_detect_changes() is clean.
   - Never claim "done" or "fixed" without showing verification output.
```

**Red flags — if you catch yourself thinking any of these, STOP:**
- "This is simple, I can just do it" → You're skipping the gate. Don't.
- "Let me read a few more files first" → You're wandering. Trace with GitNexus instead.
- "I'll just fix this one other thing too" → Not in the plan. Flag it, don't do it.
- "The pattern is probably..." → Don't guess. Check the codebase.

---

## Mental Model — The Big Picture

### Why This Architecture Exists

The Sparklore architecture exists to solve one core problem: **decoupling business logic from presentation so that new client platforms (iOS, Android, CLI) can be added without touching any domain service.**

Every rule in this project traces back to that goal. When you understand *why* a rule exists, you won't be tempted to violate it.

### The Three Layers

```
Domain Services ──<domain>.event.*──→ Bridge ──ui.event.<userID>.*──→ Web/Client
Domain Services ←──<domain>.cmd.*──── Bridge ←──ui.action.<userID>.*── Web/Client
```

| Layer | What it owns | What it must NEVER do | Why |
|-------|-------------|----------------------|-----|
| **Domain Services** (quest, agent, messaging, cms, forge) | Business logic, state, domain events | UI knowledge (HTML, templates, user sessions, SSE, Datastar) | If a domain service knows about UI, adding iOS means rewriting every service |
| **Bridge** (stateless NATS-to-NATS translator) | Event routing, KV registry, userID resolution | HTTP, HTML, business logic, DB, data enrichment | Bridge is the single translation point. Everything flows through here so routing can change at runtime |
| **Web/Client** (dumb thin client) | Render ClientEvent via SSE, serve pages, publish ui.action.* | Subscribe to domain events, call domain commands, construct signal trees | Web is one of many future clients. It must know nothing that an iOS app wouldn't also know |

### Two NATS Namespaces — Never Mix

| Namespace | Pattern | Who publishes | Contains |
|-----------|---------|---------------|----------|
| Domain events | `<domain>.event.<entityID>.<eventType>` | Domain services only | Pure domain facts. No user identity. No HTML. No rendering hints. |
| UI events | `ui.event.<userID>.<domain>.<entityID>.<eventType>` | Bridge only | ClientEvent envelopes. User-routed, entity-scoped. |
| UI actions | `ui.action.<userID>.<domain>.<entityID>.<actionType>` | Web only | User interactions from browser. Bridge translates to domain commands. |

**Why two namespaces?** Domain events are facts ("quest run X reached waiting_input"). UI events are instructions ("tell user Y to render an input form"). If these were the same namespace, every domain service would need user routing — coupling business logic to session management.

### The Universal Envelope: ClientEvent

Every UI update flows through `ClientEvent` from `sparklore/pkg/clientevent/`. This is the contract between Bridge and all clients. Domain services never construct it. Bridge never adds HTML to it. Web renders it blindly.

### The Two-Layer Code Structure

```
sparklore/pkg/<domain>/     ← CONTRACT LAYER: types, DTOs, events, signals (importable by all)
<service>/internal/         ← IMPLEMENTATION LAYER: behavior, converters, service logic (private)
```

**Why?** Contracts are shared across services for compile-time safety. Implementations are private — no service can import another service's internal logic. NATS is the only real boundary between services.

### Event Journey Story

Here's what happens when a quest run needs user input:

```
1. Quest engine detects: run_abc needs input on node_5
2. Quest publishes: quest_run.event.run_abc.waiting_for_input
   Payload: { user_id: "usr_99", node: {...}, run_state: {...} }
   ← Pure domain facts. Zero UI knowledge.

3. Bridge receives the event (queue group "bridge" ensures exactly-once)
4. Bridge matches against registry: pattern "quest_run.event.*.waiting_for_input"
5. Bridge extracts user_id from payload → "usr_99"
6. Bridge publishes: ui.event.usr_99.quest_run.run_abc.waiting_for_input
   ClientEvent: { domain: "quest_run", entity_id: "run_abc", interaction_type: "input_form", payload: {...} }

7. Web SSE handler receives ClientEvent on ui.event.usr_99.>
8. Web renders skeleton HTML → requests Template Service enrichment → patches DOM
9. User fills form, clicks submit
10. Web publishes: ui.action.usr_99.quest_run.run_abc.submit_input
    Payload: { values: {...} }

11. Bridge receives action → validates → translates
12. Bridge publishes: quest_run.cmd.submit_inputs
    Payload: { run_id: "run_abc", user_id: "usr_99", inputs: {...} }

13. Quest engine receives command, validates, advances state machine
```

Every rule in this project exists to keep this flow clean.

---

## Behavioral Rules

These are ranked by priority. Follow them always.

### 1. Hard Gate Before Any Code
See the gate above. Plan → cross-check → confirm → execute → verify. No exceptions.

### 2. Pattern-First Exploration
- Use GitNexus (`gitnexus_query`, `gitnexus_context`) to trace code paths before reading files
- Search for existing patterns that solve similar problems
- Existing patterns win over new inventions. If the codebase already has a way to do X, use it.

### 3. Relevance Filter
- Before reading a file, ask: does this participate in the code path I'm investigating?
- Use GitNexus to trace first, then read only the files in the traced path
- Do not wander into unrelated files and get lost

### 4. Systematic Debugging (Never Guess)
- Reproduce the bug first
- Trace the code path to root cause
- Cite file paths and line numbers for every assertion about code behavior
- Use `superpowers:systematic-debugging` skill for any bug or test failure

### 5. Surgical Changes
- Touch only what's needed for the task
- Don't "improve" adjacent code, comments, or formatting
- Don't refactor things that aren't broken
- **But:** if you spot a real architectural violation (e.g., domain service publishing to ui.event.*), flag it. Don't silently pass.

### 6. Self-Correct + Log
- Before writing code in a domain (frontend, NATS, etc.), scan the mistake registry for that domain
- If a pattern matches → use the correct form silently, log a near-miss
- The mistake registry gets smarter every time you make a mistake

### 7. Verification Before Completion
- Tests pass, evidence shown — then claim "done"
- Use `superpowers:verification-before-completion` before any success claim
- Run `gitnexus_detect_changes()` after changes to verify scope is expected

### 8. Documentation Integrity
- If a proposed change conflicts with documented architecture → flag it
- Let the user decide: adjust approach or update docs
- Never silently violate documented rules

---

## Tech Stack Quick Reference

| Layer | Technology |
|-------|-----------|
| Language | Go 1.26.2 |
| Messaging | NATS JetStream (pub/sub + KV + request-reply) |
| Web Framework | Echo + a-h/templ |
| Real-time UI | Datastar SSE (server-sent events) |
| CSS | TailwindCSS 4 + DaisyUI 5 |
| JS Bundling | esbuild |
| AI Config | BAML |
| Logging | Zerolog |
| IDs | ULID |
| Data Layer | UDL (Universal Data Layer over NATS JetStream) |
| Dev Reload | air (Go hot-reload) |
| Code Intelligence | GitNexus |

---

## Service Map

| Directory | Module | Role |
|-----------|--------|------|
| `sparklore/` | `github.com/sparklore/sparklore` | Shared contracts, types, DTOs, subjects, ClientEvent |
| `web/` | `github.com/sparklore/web` | Echo + templ thin client (SSE, HTML rendering) |
| `bridge/` | `github.com/sparklore/bridge` | NATS-to-NATS event/action translator |
| `quest/` | `github.com/sparklore/quest` | Quest engine (state machine, runs) |
| `agent/` | `github.com/sparklore/agent` | LLM agent service (ReAct loops, BAML) |
| `auth/` | | Authentication service |
| `cms/` | | Content management service |
| `messaging/` | | Chat/messaging service |
| `template/` | | Template rendering service |
| `user/` | | User management service |
| `forge/` | | Knowledge base service |
| `editor/` | | Quest editor service |
| `scheduler/` | | Task scheduling service |

Each service has its own `go.mod`, `Makefile`, `air.toml`, `Dockerfile`, and `internal/` package layout.

---

## Commands

```bash
# In any service directory:
make dev     # Hot-reload
make build   # Production binary
make test    # Run all tests
make run     # Build and run
make clean   # Clean generated files and binary

# Web service has additional targets:
make templ   # Regenerate templ Go files (never edit *_templ.go manually)
make css     # Rebuild TailwindCSS
make js      # Rebuild esbuild JS bundle

# Sparklore shared lib:
make baml    # Regenerate BAML client after editing .baml files
```

**After editing specific file types:**
| File type | Action |
|-----------|--------|
| `.baml` | `make baml` — regenerate BAML client |
| `.templ` | `make templ` or let `make dev` pick it up — never edit `*_templ.go` manually |
| NATS subject constant in `pkg/subjects/` | Rebuild affected service(s); check Bridge mappings for coverage |

---

## Quick Decision Reference

| Question | Answer |
|----------|--------|
| Where do entity types live? | `sparklore/pkg/<domain>/types.go` |
| Where do DTOs live? | `sparklore/pkg/<domain>/dto.go` (shapes only, no converters) |
| Where do converters live? | `<service>/internal/converter/` |
| Can types have methods? | Yes — only if zero external imports beyond stdlib + `lo` |
| Where are NATS subjects defined? | `sparklore/pkg/subjects/` only — never hardcode inline |
| What can `pkg/utils/` import? | No Echo, no NATS clients, no `pkg/<domain>` — pure utilities |
| Where is `ClientEvent` defined? | `sparklore/pkg/clientevent/` |
| What publishes to `ui.event.*`? | Only Bridge |
| What publishes to `ui.action.*`? | Only Web (server-side session context) |
| Can Web subscribe to domain events? | No — only `ui.event.<userID>.>` |
| How does Bridge resolve userID? | Extracts from domain event payload (`user_id` field) |
| Who enriches via Template Service? | Web Client, not Bridge |
| Can Web write to KV buckets? | No — all writes via NATS command subjects |
| What triggers a mandatory file split? | File exceeds 800 lines (consider at 400, plan at 600) |

---

## Hard Architecture Constraints

### Web Thin Client (Never Violate)
- **Forbidden imports:** service `internal/` packages, `pkg/events` (legacy helpers). Stateless DTOs from `pkg/quest`, `pkg/messaging`, `pkg/cms`, `pkg/agent`, `pkg/forge` are allowed for compile-time type safety (per blueprint §10.2).
- **Never** subscribe to `<domain>.event.*` directly — only `ui.event.<userID>.>`
- **Never** publish to `<domain>.cmd.*` directly — only `ui.action.<userID>.*`
- **Never** construct signal trees — signals arrive pre-built in `ClientEvent.Payload`
- **Never** extract `userID` from request body/query params — session middleware only
- **Never** hardcode `interaction_type` strings outside `internal/adapter/`

### NATS Subjects (Never Violate)
- **Never** hardcode a subject string inline — always use constants from `pkg/subjects/`
- **Never** define subject constants outside `sparklore/pkg/subjects/`
- All endpoint registration via `SetEndpoint` with full subject constants

### Bridge (Never Violate)
- **Never** expose HTTP endpoints
- **Never** contain business logic or database access
- **Never** enrich domain payloads or render HTML
- **Never** accept direct KV writes — all via `bridge.cmd.register_mapping`

### Domain Services (Never Violate)
- **Never** publish to `ui.event.*`
- **Never** include HTML, template refs, or user sessions in event payloads
- Every domain event must carry `user_id` at the top level of its JSON payload

---

## GitNexus Integration (Mandatory)

| When | Use |
|------|-----|
| Exploring unfamiliar code | `gitnexus_query` → find execution flows; `gitnexus_context` → full symbol context |
| Before editing any symbol | `gitnexus_impact` → blast radius, risk level. Report HIGH/CRITICAL risk to user. |
| After making changes | `gitnexus_detect_changes` → verify scope is expected |
| Renaming/refactoring | `gitnexus_rename` — never find-and-replace |
| Index stale warning | Run `npx gitnexus analyze` first |

---

## Key Documentation

| Document | Use for |
|----------|---------|
| `sparklore/docs/architecture/universal_event_driven_architecture.md` | System-wide EDA design, service boundaries, ClientEvent spec |
| `sparklore/docs/architecture/web_thin_client_blueprint.md` | Web compliance reference, forbidden patterns, SSE handler contract |
| `sparklore/docs/architecture/bridge_service_blueprint.md` | Bridge pipelines, registry, startup sequence, error policies |
| `sparklore/docs/architecture/CLAUDE_REFERENCE.md` | Anti-pattern checklists, pipeline stages, ui tag spec, element ID formats |
| `sparklore/pkg/subjects/` | All NATS subject constants (the true API specification) |
| `sparklore/pkg/clientevent/` | The canonical `ClientEvent` struct |

---

## Mistake Registry

Before writing code in any domain, scan the relevant mistake file. These files are dynamic — they grow as mistakes are caught and shrink as patterns are learned.

- [Frontend (Datastar, templ, TailwindCSS)](mistakes/frontend.md)
- [NATS (subjects, Bridge, pub/sub)](mistakes/nats.md)
- [Architecture (layer violations, import rules)](mistakes/architecture.md)
- [Go Patterns (package structure, idioms)](mistakes/go-patterns.md)

**How it works:**
- Each entry shows: wrong pattern → correct pattern → why it matters
- Near-miss counter tracks frequency; high-frequency items appear in bold
- 30-day cooldown: entries that stop occurring get archived
- When you self-correct before writing: silently use the correct pattern, log the near-miss
