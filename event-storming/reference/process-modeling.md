# Process Modeling — Facilitation Guide

Process Modeling zooms into specific flows from Big Picture and adds the full causal chain: commands trigger events, policies react to events, read models inform decisions. This is where the "why" and "how" behind each domain event becomes visible — and where business rules start to emerge as concrete, nameable things.

## What You're Adding

On top of the existing domain events:

| Sticky | Color | What It Means |
|--------|-------|---------------|
| Command | 🔵 Blue | An imperative action that triggers an event: "Place Order", "Approve Refund" |
| Actor | 🟡 Yellow (small) | The person or role issuing a command: "Customer", "Warehouse Staff" |
| Policy | 🟣 Purple | An automatic reaction: "When [Event], then [Command]" |
| Read Model | 🟢 Green | Information an actor needs to see before making a decision |
| Aggregate | 🟡 Yellow (large) | The business entity that receives commands and emits events — the "decision-maker" |
| External System | 🩷 Pink | A system that either triggers commands or reacts to events |

---

## The Fundamental Pattern

Every process follows this causal chain:

```
[Actor] reads [Read Model]
    → issues [Command]
    → processed by [Aggregate]
    → produces [Domain Event]
    → triggers [Policy]
    → issues [Command]
    → ...
```

You won't have all elements everywhere, and that's fine. But when something feels missing, ask: "What does the actor need to *see* to make this decision? Who or what is processing this command? What automatically happens next?"

The chain reveals the hidden structure of the domain — business rules, dependencies, and automation that often exists only in people's heads.

---

## Which Flows to Model

Don't try to model everything from Big Picture in this phase. Select 2-4 flows that are:
- High-value (core to the business)
- High-uncertainty (lots of hotspots)
- High-complexity (many actors, rules, or edge cases)

Ask the user: "Which flows are most important to get right? Which ones keep you up at night?"

---

## Facilitation Steps (Per Flow)

### Step 1 — Identify the trigger
"What kicks this flow off — is it a human action, an external event, an automatic scheduled process, or a reaction to something else in the system?"

### Step 2 — Add commands
Work backward from each event: "What was the action that caused this event?" Place a blue command sticky to the *left* of each orange event sticky.

### Step 3 — Add actors
"Who issues this command — a specific user role, or is it automated?" Small yellow stickies above or next to commands.

### Step 4 — Add policies
"After this event fires, does anything happen automatically?" Look for chain reactions — these are often where the most important business rules live. A good prompt: "Does anything automatically kick off when this happens, without a human deciding to do it?"

### Step 5 — Add read models
"What does the actor need to *see* before they can issue this command?" Green stickies go *before* the commands they inform. These often correspond to pages, screens, dashboards, or reports in the final software.

### Step 6 — Identify aggregates
"What's the business entity that receives this command and decides whether to accept or reject it?" Group related commands and events inside a large yellow aggregate shape.

---

## Questions for Eliciting Process Details

These uncover business rules, edge cases, and design signals:

- "What has to be true *before* this command can succeed?" → preconditions and business rules
- "Who is allowed to issue this command?" → authorization rules
- "What happens if this command is rejected?" → error events and failure flows
- "Does anything happen automatically after this event?" → policies
- "What does the user need to *see* to know they can do this?" → read models
- "Is there a time component — does this trigger something later, not immediately?" → async policies, scheduled events
- "Could two people issue this same command at the same time?" → concurrency signal → aggregate design implication
- "How does this command fail? What are the different ways it could go wrong?" → rich error modeling
- "Does this event update anything that other parts of the system need to know about?" → cross-context integration signals

---

## Identifying Aggregates

An aggregate is the "decision-making unit" of the domain. Every command is handled by exactly one aggregate. Every event is emitted by exactly one aggregate.

**An aggregate is NOT a database table.** It's a cluster of related state and behavior that enforces business rules — it decides whether a command is valid given its current state.

Signs you've found an aggregate:
- A cluster of commands and events that all revolve around one "thing" (an Order, a Subscription, a User Account)
- Business rules that protect consistency: "you can't ship an order that hasn't been paid" → that rule lives in the Order aggregate
- A natural life cycle — the thing has states it transitions through (created → confirmed → shipped → delivered → returned)

Aggregate names are always domain nouns: **Order**, **Payment**, **Subscription**, **Cart**, **ShipmentTracking**, **UserAccount**.

When in doubt about aggregate boundaries, ask: "What's the minimal unit of state that the system needs to protect as consistent?" If two things always need to change together, they're in the same aggregate. If they can change independently, they might be separate.

---

## Identifying Policies

Policies are the automation of the domain — they're the business rules that say "when X happens, Y automatically follows." They're often invisible to developers because no one has ever written them down.

To surface policies, ask after every event: "Does anything automatically happen because of this event, without a human deciding?"

Common policy patterns:
- **Notification policies**: "When Order Shipped → send confirmation email to customer"
- **State transition policies**: "When Payment Failed → mark subscription as suspended"
- **Integration policies**: "When Inventory Level Drops Below Threshold → trigger purchase order to supplier"
- **Compensation policies**: "When Order Cancelled → initiate refund if payment was captured"

Policies often span multiple aggregates or bounded contexts — this is a signal that the system has some cross-domain coordination happening, which becomes important in Software Design.

---

## Miro Layout for Process Modeling

Use vertical swimlanes — one per distinct flow:

```
┌─────────────────────────────────────────────────────────────┐
│ Flow: Customer Checkout                                      │
│                                                              │
│ [Read Model]→[Actor]→[Command]→[Aggregate]→[Event]→[Policy] │
│                                               ↓              │
│                                          [Ext System]        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Flow: Fulfillment                                            │
│                                                              │
│ [Policy]→[Command]→[Aggregate]→[Event]→[Policy]→[Command]   │
└─────────────────────────────────────────────────────────────┘
```

Group each aggregate's commands and events inside a large yellow container shape. This makes the aggregate boundaries visible and prepares for Software Design.

---

## Common Issues

**"What's the difference between a command and an event?"**
→ "A command is an *intention* — something someone wants to happen. It can be accepted or rejected. An event is a *fact* — something that definitely happened. Commands are in the present tense ('Place Order'), events are in the past tense ('Order Placed')."

**User can't identify aggregates**
→ Ask: "For this command — what piece of data in the system is being changed? Who 'owns' that data and enforces the rules about when it can change? That's your aggregate."

**Model gets very complex**
→ This is expected and valuable. Complexity in the model reveals complexity that already exists in the business — it's not something you're adding. A complex model tells you: "this domain is hard, and building it without this map would be even harder."

**User keeps adding new events during process modeling**
→ Good! Add them. Process Modeling often reveals events that were missing from Big Picture. Enrich the model freely.

---

## When to Move On

Process Modeling is done when:
- You have full command-event chains for the most important 2-4 flows
- Aggregates are clearly identified with their commands and events grouped
- Policies are documented (the automation and business rules are visible on the board)
- Each actor has clear read models (what they need to see before acting)
- The user can walk through a complete scenario step-by-step using the board

Carry forward into Software Design:
1. Named aggregates with their commands and events
2. Named bounded contexts (from the domain boundaries discovered earlier)
3. Policies that cross contexts (these become integration points in the software design)
4. The top remaining hotspots