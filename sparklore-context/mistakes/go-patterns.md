# Go Patterns Mistakes (Package Structure, Idioms)

> **Pre-flight check:** Before writing Go code in this project, scan this list.

---

## Package Structure

### MISTAKE: Putting behavior in `pkg/<domain>/` contract layer
**Severity:** Structural violation

`sparklore/pkg/<domain>/` is for struct definitions and pure value methods only (stdlib + `lo` imports only). If a function needs any external import beyond that, it goes in `<service>/internal/`.

**Valid pure value method:**
```go
// sparklore/pkg/quest/types.go
func (q Quest) IsPublished() bool { return q.Status == "published" }
```

**Invalid — belongs in internal/:**
```go
// This uses NATS — belongs in quest/internal/
func (q Quest) Publish(nc *nats.Conn) error { ... }
```

---

## Reinventing Wheels

### MISTAKE: Writing a new solution when the codebase already has one
**Severity:** Duplication, inconsistency

Before creating any new pattern or helper, search the codebase. Common things that already exist:
- NATS subject building → `pkg/subjects/` (use helpers.go wrappers)
- UI selectors → `pkg/ui/` (`ui.From()`, `ui.Inspect()`, `ui.Slot()`)
- SSE streaming → `web/internal/platform/sse/`
- Layout registration → `web/internal/platform/layout/`
- Entity hydration → `web/internal/platform/hydrate/`
- UDL CRUD → `pkg/nats/udl/`
- Datastar signals → `pkg/signals/`

---

## `pkg/utils/` Import Restriction

### MISTAKE: Importing Echo, NATS clients, or domain packages in `pkg/utils/`
**Severity:** Structural violation

`pkg/utils/` is a pure utility package. No Echo, no NATS clients, no `pkg/<domain>` packages. Standard library and well-known utility packages (zerolog, decimal, ulid, lo) are fine.

---

## Type Aliases

### MISTAKE: Defining new types in `model_type.go`
**Severity:** Structural violation

**Wrong:**
```go
// quest/internal/model_type.go
type MyNewType struct { ... }  // NO — new type definition
```

**Right:**
```go
// quest/internal/model_type.go
type QuestRun = pkg.QuestRun  // YES — type alias
type Quest = pkg.Quest        // YES — type alias
```

New types are defined in `sparklore/pkg/<domain>/types.go`. The `model_type.go` file only aliases them.

---

### MISTAKE: Using type aliases for function aliases incorrectly
**Severity:** Won't compile

Function aliases use `var`, not `type`:
```go
var ConvertToDTO = converter.ToDTO  // YES
```
Not:
```go
type ConvertToDTO = converter.ToDTO  // NO — this aliases the type, not the value
```

---

## UDL Patterns

### **CRITICAL: Creating custom endpoints that already exist as defaults**
**Severity:** Duplication, reinventing the wheel
**Near-miss count:** 0

Every domain service using `RegisterEndpoints()` from `sparklore/pkg/nats/udl/endpoints.go` automatically gets these endpoints. **You do NOT need to create handlers for these — they already work.**

**Default COMMAND endpoints** (auto-registered on `<namespace>.cmd.<name>`):

| Endpoint | What it does | NATS subject example |
|----------|-------------|---------------------|
| `create` | Create a new entity | `quest.cmd.create` |
| `update` | Full update by ID | `quest.cmd.update` |
| `patch` | Partial update by ID | `quest.cmd.patch` |
| `delete` | Delete by ID | `quest.cmd.delete` |
| `bulk_delete` | Delete by field/value or IDs | `quest.cmd.bulk_delete` |
| `upsert` | Create or update | `quest.cmd.upsert` |
| `merge` | Merge data into existing entity | `quest.cmd.merge` |
| `restore_revision` | Restore to a previous revision | `quest.cmd.restore_revision` |

**Default QUERY endpoints** (auto-registered on `<namespace>.query.<name>`):

| Endpoint | What it does | NATS subject example |
|----------|-------------|---------------------|
| `get` | Get entity by ID | `quest.query.get` |
| `get_by` | Get entity by field/value | `quest.query.get_by` |
| `find` | Search with FindOptions | `quest.query.find` |
| `get_history` | Get revision history for an entity | `quest.query.get_history` |

**Before creating ANY new endpoint, check the list above.** You almost never need to — the defaults cover create, read, update, patch, delete, upsert, merge, bulk delete, find, get-by-field, history, and restore for every entity type.

**ALWAYS use `SetEndpoint` with a subject constant from `pkg/subjects/`.** When the subject matches a default endpoint (e.g., `quest.cmd.create`), `SetEndpoint` automatically detects it and overrides the default handler. When the subject is new, it registers a custom endpoint. Either way, the pattern is the same — `SetEndpoint` + subject constant. Never use `AddCMD`/`AddQuery` — they take bare strings, which violates the no-hardcoded-subjects rule.

**Wrong (using AddCMD/AddQuery with hardcoded strings):**
```go
// ❌ Hardcoded strings violate the subject rules
svc.AddCMD("create", customCreateHandler)
svc.AddQuery("get", customGetHandler)
```

**Wrong (reinventing defaults — these operations already exist):**
```go
// ❌ create, get, find are already default endpoints. Just use them.
svc.SetEndpoint("quest.cmd.insert", customCreateHandler)
svc.SetEndpoint("quest.query.lookup", customGetHandler)
```

**Right (using defaults — no code needed, they already work):**
```go
// ✅ Default handlers exist. Just publish/request to the subject.
nc.Publish(subjects.QuestCmdCreate, questJSON)
nc.Request(subjects.QuestQueryGet, idJSON, ...)
nc.Request(subjects.QuestQueryFind, findOpts, ...)
```

**Right (overriding a default — same SetEndpoint pattern, auto-detected):**
```go
// ✅ SetEndpoint detects that quest.cmd.create matches a default, overrides it
svc.SetEndpoint(subjects.QuestCmdCreate, customCreateHandler)
```

**Right (genuinely new operation — same SetEndpoint pattern):**
```go
// ✅ Only for operations NOT in the defaults list. SetEndpoint + subject constant.
svc.SetEndpoint(subjects.QuestRunCmdExecuteActionWild, customHandler)
```

The rule is simple: **always `SetEndpoint` with a constant from `pkg/subjects/`. Never `AddCMD`/`AddQuery` for new code. Never hardcode a subject string.**

> **Note:** `forge/internal/kb/endpoint.go` has legacy `AddCMD`/`AddQuery` calls for UDL type/world operations. These predate the `SetEndpoint` SSoT convention and should be migrated. New code must not follow this pattern.

### MISTAKE: Constructing a writable UDL service in web/
**Severity:** Architectural violation

Web is stateless. Use `udl.NewServiceMirror[...]` for reads only. All writes go through NATS command subjects → domain services → UDL.

### MISTAKE: Using `AddCMD`/`AddQuery` instead of `SetEndpoint`
**Severity:** Structural violation (hardcoded strings)

`AddCMD`/`AddQuery` accept bare string names like `"create"` or `"get"`, which embeds hardcoded subject knowledge. `SetEndpoint` takes a full subject constant from `pkg/subjects/` — the single source of truth. Even for overriding a default handler, use `SetEndpoint` with the subject constant. The UDL automatically detects when the subject matches a default endpoint and overrides it.

---

## Idioms

### MISTAKE: Not checking errors from `AddEndpoint`/`RegisterEndpoints`
**Severity:** Silent failure at runtime

```go
// Always check:
if err := service.AddEndpoint(...); err != nil {
    log.Fatal("failed to register endpoint", "error", err)
}
```
