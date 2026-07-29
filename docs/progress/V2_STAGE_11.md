# Stage 11 — Universal Experience Runtime

## Status: COMPLETE

## Summary

Stage 11 delivers the runtime infrastructure for universal Experience rendering. Built on Stage 10's synthesis layer, this stage provides the components needed to render any Experience as a real application — data querying, form management, navigation, trusted component registry, and widget-level rendering through ExperienceRenderer.

## What Was Built

### New Runtime Components (lib/runtime/)

| File | Purpose | Lines |
|------|---------|-------|
| `data_query.dart` | Typed filter/sort/search/pagination engine with security budgets | 325 |
| `form_controller.dart` | Form state management: validation, dirty state, field definitions, reset | 216 |
| `experience_router.dart` | In-experience navigation with screen ID validation | 160 |
| `component_registry.dart` | 25+ trusted component types mapped to Flutter widgets | 606 |
| `experience_renderer.dart` | Data-driven views, multi-screen, form fields, chart, registry-backed | ~1300 |
| `runtime_context.dart` | RuntimeComponentContext: bounded dispatch, CRUD, delete safety, navigation | ~300 |
| `query_controller.dart` | ExperienceQueryController: reactive search/filter/sort/pagination | ~200 |
| `experience_host_screen.dart` | Navigation shell: router integration, bottom tabs, RuntimeContext binding | ~300 |

### Creation Pipeline Enhancement

| File | Enhancement |
|------|-------------|
| `creation_engine.dart` | Data-driven InterfaceDefinition from BlueprintViewType; action wiring (create→Add button, create→Save button, delete→Delete button); reference field propagation |
| `experience_package.dart` | DataFieldSchema gains `referenceEntityId`, `allowedValues`, `hint` |

### Production Integration

| File | Integration |
|------|-------------|
| `experience_renderer.dart` | FutureBuilder for runtime context queries; entityList queries from runtimeContext.queryRecords(); form fields use ExperienceFormController; actionBinding wired to _onPressed |
| `anything_runtime.dart` | Creates router from interface; initializes per-entity query controllers; exposes router/runtimeContext; proper cleanup |
| `component_registry.dart` | Button uses `_onPressed` + ElevatedButton; iconButton uses `_onPressed`; switch reads `_stateValue` and writes `_onStateChanged` |
| `experience_host_screen.dart` | Router integration; NavigationBar with bottom tabs; RuntimeContext binding; screen switching |

### Tests (test/stage11/)

| File | Tests | Coverage |
|------|-------|----------|
| `stage11_core_test.dart` | 48 | DataQuery (18), FormController (9), Router (9), ComponentRegistry (4), Golden Path logic (3), Security (6) |
| `stage11_widget_runtime_test.dart` | 22 | ExperienceRenderer (13), StateEngine (4), Golden Path rendering (5) |
| `stage11_end_to_end_certification_test.dart` | 18 | Full lifecycle (People Tracker, Equipment Lending, Fossil Catalog, OrbitMetrics), Form, Cross-Experience Isolation, Reactivity, Synthesis Preservation, Widget Interaction |
| `stage11_security_certification_test.dart` | 25 | Component budgets, unknown/forbidden components, trusted types, navigation escape, query limits, malicious queries, form/package validation, behavior budget, registry |
| **Total** | **113** | **All passing** |

### Test Breakdown

#### DataQuery Engine (18 tests)
- Filter: equals, greaterThan, contains, isTrue
- Sort: ascending, descending
- Search: multi-field
- Pagination: limit + offset
- Combined: filter + sort + search
- Aggregates: count, sum, average, min, max
- Empty results, validation (too many filters, limit too high)

#### FormController (9 tests)
- Create/Edit mode, dirty state tracking
- Validation: required field, min length, allowed values
- Reset, setValues, form state stream

#### ExperienceRouter (9 tests)
- Push/pop, invalid screen rejection, popToRoot
- Replace, switchTab, history tracking
- Navigation events stream

#### ComponentRegistry (4 tests)
- Standard components registered, unknown type null
- Security budgets, all types list

#### Golden Path Logic (3 tests)
- People Tracker: full CRUD lifecycle, case-insensitive search
- Equipment Lending: relational CRUD with delete safety

#### Security (6 tests)
- DataQuery: maxResultLimit, maxFilters, maxSorts enforced
- ComponentRegistry: security budgets defined
- FormController: validation prevents invalid data
- Router: unknown screen IDs rejected

#### Widget Runtime (22 tests)
- ExperienceRenderer: text, button, input, column, card, divider/spacer, switch, state binding, unknown type, button tap, app bar, empty screens, row
- StateEngine: stream updates, read/write, initialize defaults
- Golden Path rendering: People Tracker list/form, Equipment Lending dashboard, Reading Collection, deeply nested layout

## Closure Audit

### Final Test Count
- **Total:** 488/488 passing, 0 failures
- **Analyzer:** 0 errors (only pre-existing infos/warnings)
- **Stage 11 new:** 113 tests all passing
- **Regression:** All prior stages (81-84, 94, 10) pass

### Domain Hardcoding Audit
- **Zero** app-specific production screens/classes in `lib/`
- **Zero** domain templates in production code
- **Zero** domain-specific component types
- Only doc comment examples in `app_archetype.dart` and `app_blueprint.dart`

### WebWeaveX Boundary
- Only `lib/knowledge/webweavex_adapter.dart` imports `package:webweavex`
- Version: v3.0.0 (correct)
- No runtime modules import WebWeaveX

### Action Wiring
- BlueprintAction → ActionBinding → InterfaceNode.actionBinding
- List views: create action → "Add" button
- Form views: create action → "Save" button
- Detail views: delete action → "Delete" button (danger)
- All actions dispatched via RuntimeComponentContext.dispatch()

### Security Model
- ComponentRegistry: maxDepth=20, maxChildren=50, maxTotal=500
- DataQuery: maxResults=1000, maxFilters=20, maxSorts=5
- FormController: validation enforced before submit
- Router: screen IDs validated against interface definition

## Commits
- `dbc52b8` — Stage 11.1: End-to-end certification (18 lifecycle + 25 security tests) + production bug fix (multilineText case label)
- `be581da` — Stage 11 closure: fix critical gaps, wire actions, architecture docs
- `076b57c` — Stage 11: Production integration (experience_renderer rewrite, runtime_context, query_controller, anything_runtime, experience_host_screen, creation_engine enhancements)
- `dd53908` — Phase 3 infrastructure (data_query, form_controller, experience_router, component_registry)
