# Universal Experience Runtime Architecture

## Overview

The Universal Experience Runtime (Stage 11) enables Anything to render any Experience as a rich, interactive application without domain-specific screens, templates, or code. The runtime interprets declarative interface definitions and executes behavior graphs using only trusted, generic components.

## Core Principles

1. **Zero Domain Hardcoding** — No app-specific screens, templates, or logic in production code
2. **Local-First** — All data persists via SQLite; no required backend
3. **Security Budgets** — Enforced limits on depth, children, total nodes, query results
4. **Trusted Interpreter** — Declarative nodes executed by generic components; no arbitrary code execution
5. **Play Store Compliant** — No downloaded executable code

## Architecture Layers

```
┌─────────────────────────────────────────────────┐
│              ExperienceHostScreen                │
│  (Router + Navigation + RuntimeContext)          │
├─────────────────────────────────────────────────┤
│              ExperienceRenderer                  │
│  (InterfaceNode → Widget via ComponentRegistry)  │
├─────────────────────────────────────────────────┤
│         RuntimeComponentContext                  │
│  (CRUD + Query + Navigation + Form Binding)      │
├─────────────────────────────────────────────────┤
│         ComponentRegistry (25+ types)            │
│  (Trusted generic widgets with security limits)  │
├─────────────────────────────────────────────────┤
│         DataQueryEngine + StateEngine            │
│  (Filter/Sort/Search/Aggregate + Reactive State) │
├─────────────────────────────────────────────────┤
│         ExperienceDatabase (SQLite)              │
│  (Per-experience isolated storage)               │
└─────────────────────────────────────────────────┘
```

## Key Components

### ExperienceRenderer (`lib/runtime/experience_renderer.dart`)
- Converts `InterfaceDefinition` → Flutter widgets
- Multi-screen navigation via `ExperienceRouter`
- Data-driven views: entityList, entityGrid, entityDetail, entityForm, dashboardMetrics, referenceSelector, chart
- State binding via `StateEngine` (reactive streams)
- Action binding via `ActionBinding` → event dispatch
- Form field types: string, multiline, integer, decimal, boolean, date, enum, select, reference

### ComponentRegistry (`lib/runtime/component_registry.dart`)
- 25+ trusted component types
- Security: maxDepth=20, maxChildren=50, maxTotal=500
- Components: text, heading, button, iconButton, card, column, row, stack, input, dropdown, switch, searchField, entityList, entityGrid, entityDetail, entityForm, dashboardMetrics, referenceSelector, chart, divider, spacer, progressIndicator, chip, sectionHeader, emptyState, listTile
- State binding: `_stateValue` prop for reading, `_onStateChanged` for writing
- Action binding: `_onPressed` prop for button callbacks

### RuntimeComponentContext (`lib/runtime/runtime_context.dart`)
- Bounded event dispatch via `dispatch(eventId, data)`
- CRUD: `createRecord`, `updateRecord`, `deleteRecord` (with delete safety)
- Query: `queryRecords`, `countRecords`
- Form binding: `getFormController`, `getOrCreateFormController`
- Navigation: `pushScreen`, `pop`, `replaceScreen`, `switchTab`
- Record labels: human-readable display names

### ExperienceRouter (`lib/runtime/experience_router.dart`)
- 10 navigation actions: push, pop, replace, switchTab, popToRoot, pushAndRemoveAll, pushReplacement, canPop, isValidScreen, currentScreen
- Screen validation against interface definition
- Navigation history tracking
- Reactive stream for navigation events

### DataQueryEngine (`lib/runtime/data_query.dart`)
- 13 filter operators: equals, notEquals, greaterThan, lessThan, greaterThanOrEqual, lessThanOrEqual, contains, notContains, startsWith, endsWith, isTrue, isFalse, isEmpty
- 5 aggregate operations: count, sum, average, min, max
- Sort: ascending/descending by field
- Search: multi-field text search
- Security: maxResults=10000, maxFilters=20, maxSorts=10

### ExperienceFormController (`lib/runtime/form_controller.dart`)
- Create/Edit modes
- Validation rules: required, minLength, maxLength, min, max, pattern, allowedValues
- Dirty state tracking
- Reactive state stream
- Reset/setValue/getValues

### BehaviorInterpreter (`lib/runtime/behavior_interpreter.dart`)
- Executes `BehaviorGraph` with event-driven nodes
- Node types: event, action, condition, stateUpdate, derivedCalculation
- Security: maxNodes=100 per execution, maxExecutions=10 per event
- Action node types: create, update, delete, toggle, increment, decrement

## Creation Pipeline

```
User Intent
    ↓
AppBlueprint (entities, fields, actions, views, derivedValues)
    ↓
CreationEngine._buildInterfaceFromBlueprint()
    ↓
InterfaceDefinition (screens with InterfaceNodes)
    ↓
ExperienceRenderer (InterfaceNode → Widget tree)
    ↓
ExperienceHostScreen (full interactive Experience)
```

### Action Wiring
- `BlueprintAction` with `actionId` → `InterfaceNode.actionBinding`
- List views: create action → "Add" button
- Form views: create action → "Save" button
- Detail views: delete action → "Delete" button (danger)
- Actions dispatched via `RuntimeComponentContext.dispatch()`

## Security Model

### Component Security
- Max depth: 20 levels
- Max children per node: 50
- Max total nodes: 500
- Unknown components: null (not rendered)
- Forbidden component types: none (all types allowed)

### Query Security
- Max results: 10,000
- Max filters per query: 20
- Max sorts per query: 10
- Input validation: type checking, range validation

### Form Security
- Validation rules enforced before submit
- Required field checks
- Type validation (integer, decimal, date)
- Allowed values enforcement

### Navigation Security
- Screen IDs validated against interface definition
- Unknown screen IDs rejected
- History tracking for back navigation

## Domain Hardcoding Audit

**Zero domain-specific production code found:**
- No `InventoryScreen`, `HabitScreen`, etc. in `lib/`
- No domain templates in production code
- No domain-specific component types
- Only doc comment examples in `app_archetype.dart` and `app_blueprint.dart`

## Test Coverage

- 445 tests ALL PASS
- Stage 11 core tests: 48 (DataQuery, FormController, Router, Registry, Security)
- Stage 11 widget tests: 22 (ExperienceRenderer rendering)
- Full regression: all prior stages (81-84, 94, 10) pass
- Zero analyzer errors in production code
