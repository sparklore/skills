# Architecture Mistakes (Layer Violations, Import Rules)

> **Pre-flight check:** Before touching code that crosses service boundaries, scan this list.

---

## Import Violations

### MISTAKE: Web importing service internal packages
**Severity:** Critical architectural violation
**Near-miss count:** 0

**Wrong:**
```go
import "github.com/sparklore/quest/internal/something"
import "github.com/sparklore/agent/internal/orchestrator"
```

**Right:** Web may only import stateless DTO/contract packages from `sparklore/pkg/<domain>/` (e.g., `pkg/quest` for `QuestDTO`, `pkg/clientevent` for `ClientEvent`). Never import any `internal/` package.

---

### MISTAKE: Importing `pkg/events` (legacy helpers)
**Severity:** Architectural violation

`pkg/events` contains legacy `PublishUserUIEvent` helpers. These predate the Bridge. Do not use them. Use `ui.action.*` publishing contract instead.

---

## Layer Confusion

### MISTAKE: Adding business logic to the Bridge
**Severity:** Architectural violation

Bridge is a pure translator — match, resolve, route. No validation (beyond schema), no state transitions, no business rules. If you need logic, it belongs in a domain service.

---

### MISTAKE: Adding HTML or UI knowledge to a domain service
**Severity:** Critical architectural violation

Domain services publish pure domain facts. No HTML, no template slugs, no CSS selectors, no Datastar, no SSE. If you find yourself importing `templ`, `datastar`, or writing HTML in a domain service, stop.

---

### MISTAKE: Enriching events in Bridge instead of Web Client
**Severity:** Architectural violation

Template rendering is the Web Client's job. Bridge publishes raw `ClientEvent` envelopes. Web calls Template Service for enrichment. If you add enrichment to Bridge, you're coupling the translation layer to presentation concerns.

---

## Contract/Implementation Confusion

### MISTAKE: Putting converter functions in `dto.go`
**Severity:** Structural violation

`dto.go` in `pkg/<domain>/` is shapes only — struct definitions, no functions. Converters go in `<service>/internal/converter/`.

---

### MISTAKE: Defining new types in `model_type.go`
**Severity:** Structural violation

`model_type.go` must contain only `=` type aliases (e.g., `type QuestRun = pkg.QuestRun`). Never define new types there.

---

### MISTAKE: Adding external imports to `pkg/<domain>/` contract files
**Severity:** Structural violation

Contract files (`types.go`, `dto.go`, `events.go`, etc.) may only import stdlib + `github.com/samber/lo`. If you need NATS, Echo, or any other import, the code belongs in `<service>/internal/`.

---

## Signal Construction

### MISTAKE: Web constructing domain signal trees
**Severity:** Architectural violation

Signals arrive pre-built in `ClientEvent.Payload`. The dispatcher calls `s.Signal(event.Payload)` for signal-only events. Never construct `signals.QuestRunsSignals` or similar in web/.

**Permitted web-only signals:** CSRF token, session user metadata, layout toggles (sidebar). These are web-local UI state, not domain-derived.

---

## userID Handling

### MISTAKE: Extracting userID from request body or query params
**Severity:** Security violation

userID must come exclusively from the authenticated session middleware:
```go
userID := c.Get("user_id").(string) // CORRECT
```
Never from `c.FormValue("user_id")`, `c.QueryParam("user_id")`, or request body.

---

## File Size

### MISTAKE: Letting files grow beyond 800 lines
**Severity:** Maintainability

| Lines | Action |
|-------|--------|
| > 400 | Consider splitting |
| > 600 | Plan split by concern |
| > 800 | Mandatory split (god file) |

Split by **business concern** — `run_ops.go` is better than `helpers.go`.
