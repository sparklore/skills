# Frontend pages

1. Follow the repo’s established page patterns (script style, lists, dialogs, state). No `any`. New pages use existing route registration — do not invent a parallel menu or permission system inside the page.
2. Requests go only through the existing API layer. Pages must not import each other; extract a shared component only when reused in two or more places.
3. Clear timers, subscriptions, and in-flight requests on unmount.
4. Colors and type sizes use design tokens. Missing token → add the token first; never hardcode colors in the page.
5. Do not reshape request/response contracts to make a page easier. Do not inject unsanitized HTML for rich text.

How to click and what the page must show → `delivery-gate`. Visual specs (contrast, spacing, breakpoints) → `ui-designer`; do not duplicate here.

Chinese reference (not installed): `zh/frontend.md`
