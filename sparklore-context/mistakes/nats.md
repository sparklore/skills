# NATS Mistakes (Subjects, Bridge, Pub/Sub)

> **Pre-flight check:** Before writing ANY NATS code, scan this list.

---

## **CRITICAL: Subject String Rules**

### MISTAKE: Hardcoding NATS subject strings inline
**Severity:** Architectural violation
**Near-miss count:** 0

**Wrong:**
```go
nc.Publish("quest_run.cmd.start", data)
nc.Subscribe("quest_run.event.*.>", handler)
```

**Right:**
```go
// All subject constants live in sparklore/pkg/subjects/
nc.Publish(subjects.QuestRunCmdStart, data)
nc.Subscribe(subjects.QuestRunEventWildcardAll, handler)
```

**Why:** Subject strings are the API contract between services. Centralizing them in `pkg/subjects/` means you can change a subject once and have it propagate everywhere. Inline strings drift and break.

---

### MISTAKE: Defining subject constants outside `sparklore/pkg/subjects/`
**Severity:** Architectural violation

**Wrong:**
```go
// In quest/internal/some_file.go
const mySubject = "quest_run.cmd.my_action"
```

**Right:**
```go
// In sparklore/pkg/subjects/quest.go
const QuestRunCmdMyAction = "quest_run.cmd.my_action"
```

---

## Bridge & Pub/Sub Rules

### MISTAKE: Domain service publishing to `ui.event.*`
**Severity:** Critical architectural violation
**Near-miss count:** 0

**Wrong:**
```go
// In agent/internal/publisher.go
nc.Publish("ui.event."+userID+".agent.response", data)
```

**Right:** Domain services publish ONLY to `<domain>.event.*`. Only Bridge publishes to `ui.event.*`.

**Why:** If domain services publish directly to `ui.event.*`, adding a new client platform means touching every domain service. The Bridge is the single translation point — all UI events flow through it so routing can change at runtime without modifying domain code.

**If you see this in existing code:** FLAG IT. This is a known violation in the agent service that needs refactoring.

---

### MISTAKE: Web subscribing to `<domain>.event.*` directly
**Severity:** Critical architectural violation

**Wrong:**
```go
// In web/
nc.Subscribe("quest_run.event.*.>", handler)
```

**Right:**
```go
// Web subscribes only to UI events
nc.Subscribe(subjects.UIEventUserEventsAllSubject(userID), handler)
```

---

### MISTAKE: Web publishing directly to `<domain>.cmd.*`
**Severity:** Critical architectural violation

**Wrong:**
```go
// In web/ action handler
nc.Publish("quest_run.cmd.start", data)
nc.Request("quest_run.query.get", req, timeout)
```

**Right:**
```go
// Web publishes to ui.action.*, Bridge routes to domain.cmd.*
subject := subjects.UIActionSubject(userID, domain, entityID, actionType)
nc.Publish(subject, payload)
```

---

### MISTAKE: Using old subject format `ui.event.user.<userID>.<action>`
**Severity:** Deprecated format

The current format is `ui.event.<userID>.<domain>.<entityID>.<eventType>` (6 segments). The old 4-segment format is deprecated. Check `sparklore/pkg/subjects/helpers.go` for the canonical builder functions.

---

## Endpoint Registration

### MISTAKE: Using `AddCMD`/`AddQuery` or hardcoded subject strings
**Severity:** Architectural violation

Always use `SetEndpoint()` with full subject constants from `pkg/subjects/`. `AddCMD`/`AddQuery` take bare string names — this embeds hardcoded subject knowledge and violates the SSoT rule. When the subject passed to `SetEndpoint` matches a default endpoint, the UDL automatically detects and overrides it. Never use inline subject strings.

---

## KV Bucket Rules

### MISTAKE: Web writing directly to a NATS KV bucket
**Severity:** Architectural violation

Web is stateless. All writes go through NATS command subjects → domain services → UDL. Never construct a writable `udl.NewService` in web/.

### MISTAKE: Writing to KV bucket without writing `entityID → userID` mapping first
**Severity:** Race condition (Bridge may miss the event)

When creating an entity, write the `entityID → userID` mapping BEFORE publishing the domain event. Otherwise Bridge may receive the event before the mapping exists and drop it.
