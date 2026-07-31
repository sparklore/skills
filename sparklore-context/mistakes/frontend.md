# Frontend Mistakes (Datastar, templ, TailwindCSS)

> **Pre-flight check:** Before writing ANY frontend code, scan this list.
> Entries in **bold** are high-frequency — pay extra attention.

---

## **CRITICAL: Datastar Attribute Syntax**

### **MISTAKE: Using `data-on-click` instead of `data-on:click`**
**Severity:** Syntax error (silently fails at runtime)
**Near-miss count:** 0

**Wrong:**
```html
<button data-on-click="@post('/api/...')">
```

**Right:**
```html
<button data-on:click="@post('/api/...')">
```

**Why:** Datastar v0.20+ uses colon syntax `data-on:<event>` for all event bindings. The dash syntax `data-on-<event>` is deprecated and will NOT work.

---

### **MISTAKE: Using `data-on-load` instead of `data-init`**
**Severity:** Syntax error (silently fails at runtime)
**Near-miss count:** 0

**Wrong:**
```html
<div data-on-load="@get('/api/v1/hydrate/quest_run')">
```

**Right:**
```html
<div data-init="@get('/api/v1/hydrate/quest_run', {include: []})">
```

**Why:** Datastar replaced `data-on-load` with `data-init` for page-load initialization. The `data-init` attribute triggers when the element is inserted into the DOM.

---

## Datastar Patterns (Common Gotchas)

### MISTAKE: Building JSON payloads from signals for data transport
**Severity:** Architectural violation
**Near-miss count:** 0

**Wrong:**
```html
<input type="text" data-bind="ie_abc_title" value="Title"/>
<button data-on:click="@post('/api/...', { payload: { title: $ie_abc_title } })">Save</button>
```

**Right:**
```html
<form data-on:submit="@post('/api/v1/action/quest/abc/patch', { contentType: 'form' })">
  <input type="text" name="title" value="Current Title"/>
  <button type="submit">Save</button>
</form>
```

**Why:** DOM is the Single Source of Truth for form data. Use `contentType: 'form'` to serialize form elements. `data-bind` is for UI state only (edit mode, loading, error), never for data transportation.

---

### MISTAKE: Per-input keydown handler when form `data-on:submit` handles Enter natively
**Severity:** Unnecessary complexity
**Near-miss count:** 0

**Wrong:**
```html
<input data-on:keydown_enter="@post('/api/...')" />
```

**Right:**
```html
<form data-on:submit="@post('/api/...', { contentType: 'form' })">
  <input type="text" name="title" />
  <button type="submit">Save</button>
</form>
```

---

### MISTAKE: Go functions generating JavaScript strings
**Severity:** Architectural violation (last resort only)
**Near-miss count:** 0

**Wrong:**
```go
func choiceChangeJS(runID, nodeID string) string {
    return fmt.Sprintf("document.getElementById('%s').value = ...", runID)
}
```

**Right:** Use Datastar declarative attributes (`data-bind`, `data-class`, `data-show`, `data-on:click` with signal assignments) and standard HTML form behavior.

---

## Templ Gotchas

### MISTAKE: Editing `*_templ.go` files manually
**Severity:** Changes will be overwritten
**Near-miss count:** 0

Always edit `.templ` files, then run `make templ` (or let `make dev` pick it up). Never edit generated `*_templ.go` files.

---

## Component Type Strings

### MISTAKE: Hardcoding component type strings outside `adapter/`
**Severity:** Architectural violation

Component type strings must only appear in `web/internal/adapter/`. For layout registration, use constants from `pkg/<domain>/`. Never use magic strings.

---

## UI Slot Declaration

### MISTAKE: Raw string container IDs instead of `ui.Slot()`
**Severity:** Drift from LayoutRegistry

**Wrong:**
```html
<div id="quest-panel-ongoing">
```

**Right:**
```go
var slotOngoing = ui.Slot("quest_run", "", "ongoing")
```
```html
<div id={ slotOngoing.ID }>
```
