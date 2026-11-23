---
name: silent-web-cinema
description: "Master orchestrator for muted-by-default (sound-off) interactive 3D and web brand films. Coordinates narrative arcs, beat-synced cinema subtitles (rail + climax card), metaphor-to-offer clarity, silent visual urgency cues, and camera sightline verification. Read first when building or fixing any web cutscene, Three.js short film, or autoplay brand story."
---

# Silent Web Cinema (Sound-Off Brand Film Protocol)

95%+ of web visitors watch interactive or autoplay films **with sound off** and **zero prior context** about the company. If a scene runs for 15–20 seconds before showing a vague 3-word tagline, the viewer has no idea *what is happening*, *why the metaphor matters*, or *what the company actually sells*.

Use this orchestrator together with the sibling skills in this plugin (`storytelling`, `brand-storytelling`, `filmmaker`, `scroll-world-storytelling`) and related craft skills (`copywriting`, `captions-overlay`, `camera-systems`, `ghibli-environment-art`, `impeccable`).

---

## 1. Narrative Architecture (Situation → Complication → Diagnosis → Retrofit → Payoff)

Map every multi-scene brand film to concrete, human beats (`storytelling` + `brand-storytelling`):

1. **Customer is Luke; Brand is Obi-Wan** (`brand-storytelling`): Never open with "We are an AI agency." Open inside the customer's craft, pride, and daily reality.
2. **Bridge the Metaphor Explicitly**: A visual metaphor (e.g., a woodworking cottage, a harbor, a kitchen) charms the eye, **but silent viewers cannot read your mind**. Your subtitle rail must gently bridge the concrete scene (*ledgers, couriers, ringing phone, roof cutaway*) to what the business actually does (*operations X-Ray, workflow retrofit, calm AI*).
3. **Earn Every Beat**:
   - **Act I — Foundation (Situation)**: What was built with care and still works.
   - **Act II — Friction (Complication)**: Growth outpaces manual handoffs; busywork crowds out the craft.
   - **Act III — X-Ray (Diagnosis)**: Pause and map how work really flows before changing a single tool (*Keep, Strengthen, Retrofit, Retire*).
   - **Act IV — Quiet Systems (Resolution)**: Fit modern tools beside the craft without breaking its soul.
   - **Act V — Breathing Room (Payoff + Invitation)**: Margin and calm restored; clear invitation to talk.

---

## 2. The Two-Tier Subtitle System (Rail + Earned Climax)

Adapted from `captions-overlay` for theatrical letterbox/web cinema:

1. **Tier 1 — Narrative Subtitle Rail (`cues: [{ t0, t1, en, zh }]`)**:
   - **First cue appears within `0.6s–1.4s`** of scene start — never leave a muted viewer staring at silent motion for >2 seconds without story orientation.
   - **Reading cadence**: 1–2 short lines (`8–16` words in English, `14–28` characters in Chinese), held for **`3.2s–5.2s`** with **`0.25s–0.45s` breathing room** between cues, aligned to shot cuts (`filmmaker` Principle #9: Timing).
   - **Typography**: Clean, warm cinema caption in the lower frame (`Source Serif 4` / `Songti SC` or editorial sans/italic), high contrast over a soft shadow gradient, **never** colliding with interactive UI pills or 3D callout pins.
2. **Tier 2 — Earned Climax Title Card (`titleAt`)**:
   - Appears **only once** in the final pullback/resolve shot of the chapter.
   - All Tier 1 rail cues **must finish before `titleAt - 0.35s`** so the rail and climax card **never overlap**.
   - Pairs a resonant chapter headline (`3–6` words) with a crystal-clear, zero-slop subtitle stating the real-world takeaway (`copywriting` Three-Question Gate: *Can the reader picture it? Is it specific? Could a generic competitor write it?*).

---

## 3. Silent Visual Storytelling Cues (No Audio Required)

When sound is off, every invisible audio cue in the screenplay **must have a visible physical counterpart** (`filmmaker` Principles #2 Anticipation, #3 Staging, #8 Secondary Action):

- **Unanswered phone / incoming demand** → Visible bell/handset vibration + subtle warm pulse ring or fluttering order slips so "overload" reads at a glance without hearing a ringtone.
- **Time passing / pressure** → Lighting shift (afternoon → dusk), growing physical stack of crates, faster walk stride, wiping brow, visible clock hands advancing.
- **Diagnostic X-Ray / system mapping** → Architectural cutaway + animated ink flow lines on the floor + non-overlapping semantic pins (*Keep / Strengthen / Retrofit / Retire*).
- **Calm resolution** → Unhurried movement, warm interior lamp glow, rising steam from mugs, settled posture.

---

## 4. Camera Sightline & Occlusion Verification (Never Stage Blind)

Hand-typed `[x, y, z]` coordinates routinely cause sills, flowerboxes, curtains, or props to block actors' faces:

1. **Check Sill & Foreground Heights Against Seated Eye Level**: A seated character's head is typically `1.15m–1.25m` above floor level. Any window sill + flowerbox taller than `1.0m` viewed from a high camera (`y > 1.6m`) will decapitate or hide the actors from outside. Keep exterior window cameras near seated eye-level (`y ≈ 1.15m–1.45m`) and keep curtains parted to the outer edges of the glass, never slabs blocking the center pane.
2. **Render & Inspect Keyframes**: For every scene, render actual browser frames at **each subtitle beat** AND the **climax title beat** (desktop + mobile + secondary locale) and visually inspect actor faces, silhouettes, props, and caption legibility before declaring done.
