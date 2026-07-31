# Syntax Cheatsheet

Quick-lookup for correct syntax of commonly misused APIs in this project.

## Datastar

### Event Bindings
```html
<!-- ✅ CORRECT — colon syntax -->
data-on:click="@post('/api/...')"
data-on:submit="@post('/api/...', { contentType: 'form' })"
data-on:keydown_enter="@post('/api/...')"

<!-- ❌ WRONG — dash syntax (deprecated) -->
data-on-click="@post('/api/...')"
data-on-submit="@post('/api/...')"
```

### Page Load Initialization
```html
<!-- ✅ CORRECT -->
<div data-init="@get('/api/v1/hydrate/quest_run', {include: []})">

<!-- ❌ WRONG -->
<div data-on-load="@get('/api/v1/hydrate/quest_run')">
```

### UI State Bindings (data-bind)
```html
<!-- data-bind is for UI STATE only, never data transport -->
<input data-bind="ie_abc_title" />           <!-- Two-way binding for UI state -->
<span data-show="$updating">Saving...</span>  <!-- Show/hide based on signal -->
<button data-class="{ 'btn-loading': $saving }">Save</button>  <!-- Conditional class -->
```

### Form Submission (DOM as SSoT)
```html
<!-- ✅ CORRECT — form serialization -->
<form data-on:submit="@post('/api/v1/action/quest/abc/patch', { contentType: 'form' })">
  <input type="text" name="title" value="Current"/>
  <input type="hidden" name="id" value="abc"/>
  <button type="submit">Save</button>
</form>
```

### Actions with JSON payload (non-form data)
```html
<button data-on:click="@post('/api/...', { payload: { node_id: '123' } })">Delete</button>
```

### Indicators
```html
<form data-indicator="saving" data-on:submit="@post('/api/...', { contentType: 'form' })">
  <span data-show="$saving" class="loading-spinner">Saving...</span>
</form>
```

## Templ

### Template Files
```
*.templ  → Edit these (source)
*_templ.go → Generated (never edit manually)
```

### Common Patterns
```go
// Passing IDs to templ components
templ MyCard(id string) {
  <div id={ fmt.Sprintf("quest-panel-%s", id) }>...</div>
}

// Using ui.Slot() for container IDs
var slotOngoing = ui.Slot("quest_run", "", "ongoing")
// In templ: <div id={ slotOngoing.ID }>
```

## Go

### Type Aliases (model_type.go)
```go
type QuestRun = pkg.QuestRun    // ✅ type alias
// NOT: type QuestRun struct { ... }  // ❌ new type definition in model_type.go
```

### Function Aliases
```go
var ConvertToDTO = converter.ToDTO  // ✅
// NOT: type ConvertToDTO = converter.ToDTO  // ❌
```

### NATS Subject Usage
```go
// ✅ Always use constants from pkg/subjects/
nc.Publish(subjects.QuestRunCmdStart, data)

// For dynamic subjects, use helpers from pkg/subjects/helpers.go
subject := fmt.Sprintf(subjects.QuestRunEventFmt, entityID, eventType)
```

## File Organization

| File | Purpose | Restrictions |
|------|---------|-------------|
| `pkg/<domain>/types.go` | Entity structs + pure value methods | stdlib + lo imports only |
| `pkg/<domain>/dto.go` | DTO structs only | No converter functions |
| `pkg/<domain>/events.go` | NATS event payload structs | — |
| `<service>/internal/model_type.go` | Type aliases only (`=`) | No new type definitions |
| `<service>/internal/converter/` | Model ↔ DTO converters | — |
