# Big Picture Event Storming — Facilitation Guide

The Big Picture phase casts the widest possible net across the entire domain. The goal is NOT to be correct — it's to get everything OUT. Speed and breadth matter more than precision here. You're building a shared timeline of what happens in this system, surfacing confusion, and finding natural domain boundaries.

## What You're Building

A horizontal timeline of domain events flowing left to right, enriched with:
- 🟠 **Orange**: Domain Events (the backbone — everything that happened)
- 🔴 **Red**: Hotspots (pain points, questions, unknowns — gold for later phases)
- 🟡 **Yellow (small)**: Actors (who triggers events)
- 🩷 **Pink**: External Systems (things outside your control)
- 🟢 **Green**: Opportunities (things that could be better)

---

## Opening Questions

These help the user start generating events. Follow the conversation — you don't need to ask them in order, but this sequence works well:

1. **"What kicks everything off in this domain?"**
   — "What's the first thing that has to happen before anything else can?"

2. **"What are the 5 most important things that happen in this system?"**
   — "If you had to explain what this system *does* in 5 events, what would they be?"

3. **"Walk me through the perfect, happy path from start to finish."**
   — Get the full success scenario out first. You'll add failures in the next pass.

4. **"Now what can go wrong?"**
   — "At each step — what could fail, get rejected, time out, or surprise you?"
   — "What's the most common failure mode? The most catastrophic?"

5. **"Who are the different people or roles involved?"**
   — "Are there any users with different goals or permissions?"

6. **"Where does money, data, or responsibility change hands?"**
   — These transitions are almost always the most important events in any domain.

7. **"What happens at the very end? What's the final outcome for the customer?"**
   — Working backward from outcomes often surfaces events people forget.

---

## Facilitation Rhythm: Five Passes

Work through the domain in passes rather than trying to do everything at once:

**Pass 1 — Brain dump**
Ask the user to throw out domain events as fast as possible. Don't evaluate, don't organize. If they're slow to start, ask "what's the thing you spend the most time thinking about in this domain?" The board should feel slightly chaotic at this point — that's right.

**Pass 2 — Timeline**
Ask the user to arrange events roughly chronologically, left to right. Don't aim for perfection — even a rough order helps the brain see gaps. "Does this feel right? Is anything clearly happening before or after something else?"

**Pass 3 — Hotspots**
Go through the timeline and ask "Is there anything here that feels uncertain, confusing, painful, or that the team disagrees about?" Place red hotspot stickies. Don't try to resolve them now — just mark them. Hotspots are valuable; a board full of red stickies is a success, not a failure.

**Pass 4 — Actors and External Systems**
Add who or what triggers each event. "Who made this happen? Was it a user action, an automatic process, or something from outside the system?" Place yellow actor stickies below events, pink external system stickies at the edges.

**Pass 5 — Pivotal events**
Ask "which 2-3 events are the most important? The ones where real business value is created, or where the biggest risks live?" These pivotal events often mark natural domain boundaries — they're the seams between different parts of the business.

---

## Discovering Domain Boundaries

Natural boundaries show up as signals — watch for them:

- **Different teams** responsible for different parts of the timeline
- **Vocabulary shifts** — the same "thing" gets called something different in two areas (this is huge: it usually means different bounded contexts)
- **Pivotal events** that feel like clear handoffs between business functions
- **Data that changes meaning** as it crosses from one area to another

When you spot a potential boundary, place a vertical dividing line on the Miro board and ask: "Does it feel like these two areas are owned by different teams or serve different business purposes?"

Don't force boundaries — let them emerge from the conversation. If the user isn't sure, mark it with a hotspot and move on.

---

## Miro Layout

```
← time flows left to right →

[External System] ──► [Event] ──► [Event] ──► [Event] ──► [Event] ──► [External System]
                            ▲              ▲       🔴 Hotspot
                         [Actor]        [Actor]

│─────── Boundary ──────│─────────────── Boundary ──────────────│
   Context: Checkout           Context: Fulfillment
```

Keep the layout clean as you go — it makes later phases much easier. Use Miro frames to group events that belong to the same part of the domain.

---

## Common Issues and How to Handle Them

**"I don't know where to start"**
→ "What's the thing your customers do most often? What's the first thing that creates value?" If still stuck: "Okay, let's start at the very end — what does success look like for your customer? What's the last event before they're happy?"

**User writes commands instead of events**
→ "That sounds like an action someone is taking, which is actually a *command* — and that's also important! But let's rephrase what *results* from that action. 'Submit Order' becomes 'Order Submitted'. Does that feel right?"

**User goes too deep too fast**
→ "That's a great detail — let me drop a hotspot here so we capture it. For now let's keep moving across the whole domain. We'll zoom into this specific flow during Process Modeling."

**User can't decide on an event name**
→ "Both names are fine — put them both down with a hotspot between them. Naming disagreements like this often reveal that two people see the domain differently, which is exactly what Event Storming is designed to surface."

**"Is this one event or two?"**
→ "If in doubt, split it. Events are cheap. You can always merge two events later, but you can't un-merge one that's hiding two different things."

**User is only describing the happy path**
→ "This is looking great — let's now look for the shadow of each event. For every step where things go right, what happens when they go wrong? What gets rejected, times out, or surprises people?"

---

## When to Move On

The Big Picture phase is done when:
- You have a timeline that covers the whole domain (not exhaustive, but representative)
- Both happy paths and major failure paths are represented
- Red hotspots mark the areas of uncertainty and pain
- You can see at least 2-3 natural domain boundaries
- The user can walk a stranger through the board and explain the whole domain

Don't aim for completeness — aim for coverage. Detail comes in Process Modeling. What matters here is that nothing big is missing.

---

## What to Carry Forward

Before moving to Process Modeling, summarize:
1. The 3-5 most pivotal events on the board
2. The domain boundaries you've identified (even tentatively)
3. The top 3 hotspots that most need resolution

These become the focus areas for Process Modeling.