# Architecture Decision Tree

Follow this decision tree before making ANY changes.

## 1. Where does this code belong?

```
Does it involve business rules or state?
  └─ YES → Domain Service (quest/agent/messaging/cms/forge)
       └─ Contract structs → sparklore/pkg/<domain>/
       └─ Behavior/implementation → <service>/internal/

Does it involve routing events between domain and UI?
  └─ YES → Bridge
       └─ Registry mappings ONLY
       └─ Zero business logic, zero HTML, zero HTTP

Does it involve rendering HTML, SSE, or handling HTTP requests?
  └─ YES → Web (thin client)
       └─ NEVER subscribe to <domain>.event.*
       └─ NEVER publish to <domain>.cmd.*
       └─ ONLY ui.event.<userID>.> and ui.action.<userID>.*

Is it a shared type/contract used by multiple services?
  └─ sparklore/pkg/<domain>/  (or pkg/clientevent/, pkg/subjects/)
```

## 2. Which NATS namespace?

```
Publishing a domain fact (e.g., "quest started")?
  └─ <domain>.event.<entityID>.<eventType>
  └─ Include user_id at top level of payload

Sending a UI update to a specific user?
  └─ ui.event.<userID>.<domain>.<entityID>.<eventType>
  └─ Only Bridge publishes here

Sending a user action from browser?
  └─ ui.action.<userID>.<domain>.<entityID>.<actionType>
  └─ Only Web publishes here
```

## 3. New NATS subject needed?

```
1. Open sparklore/pkg/subjects/<domain>.go
2. Add constant following existing naming convention
3. For dynamic subjects with %s placeholders, add a helper in helpers.go
4. If UI-related, register Bridge mapping
5. NEVER hardcode the subject string inline in a handler
```

## 4. Working on web/ frontend?

```
Am I writing an interaction_type string?
  └─ Only in internal/adapter/ — use constants from pkg/<domain>/

Am I subscribing to NATS?
  └─ Only ui.event.<userID>.> — never <domain>.event.*

Am I publishing an action?
  └─ Only ui.action.<userID>.<domain>.<entityID>.<actionType>

Am I handling signals?
  └─ Apply ClientEvent.Payload blindly — never construct domain signals

Am I extracting userID?
  └─ ONLY from session middleware: c.Get("user_id").(string)
  └─ NEVER from request body, query params, or headers
```

## 5. Before refactoring or renaming

```
1. gitnexus_impact({target: "symbolName", direction: "upstream"})
   └─ Report HIGH/CRITICAL risk to user before proceeding
2. Make changes
3. gitnexus_detect_changes() — verify scope is expected
```
