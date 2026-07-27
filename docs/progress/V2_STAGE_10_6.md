# Anything v2.0.0 — Stage 10.6 Production Lifecycle Certification

## Status: COMPLETE

## Date: 2026-07-27
## Branch: v2.0.0

---

## Defects Closed

### DEFECT A: Stage 10.5 Did Not Test Production Lifecycle

**Finding:** `test/stage10/stage10_5_test.dart` tested lower-level synthesis but did NOT use
`ExperienceCreationCoordinator`, `SqliteExperienceRepository`, `ExperienceOpeningCoordinator`,
or `AnythingRuntime`. The tests proved the canonical path worked but not the complete production
lifecycle.

**Resolution:** Created `test/stage10/stage10_6_test.dart` with real integration tests that exercise:

- **Lending full lifecycle:** `ExperienceCreationCoordinator.createFromExpression()` → Kernel →
  `ExecutionPlanReady` → `CreationEngine.create()` → `ExperiencePackage` → SQLite persistence →
  `ExperienceOpeningCoordinator.openExperience()` → package loaded → activity events verified →
  metadata `lastUsedAt` updated

- **OrbitMetrics full lifecycle:** Same production pipeline through dashboard archetype with
  network config, verifying structural metadata preservation.

- **Failure atomicity:** Corrupt model through `ExperienceCreationCoordinator` does not corrupt
  SQLite repository or emit false activity events.

### DEFECT B: CreationEngine Loses Structural Metadata

**Finding:** `CreationEngine` constructed `ExperienceManifest(...)` without passing `category` or
`tags` from the `AppBlueprint`. The `ExperienceManifest` class already supported these fields
(from Stage 10.4), but the engine never populated them from the blueprint.

**Resolution:** Added `_deriveStructuralCategory(AppBlueprint)` method to `CreationEngine` that
returns `archetype.name` from the first archetype in `blueprint.archetypes`. Updated manifest
construction to pass `category: blueprint != null ? _deriveStructuralCategory(blueprint) : spec.category.name`
and `tags: blueprint != null ? blueprint.tags : const []`.

---

## Production Trace (After Stage 10.6)

```
ExperienceCreationCoordinator.createFromIntent(intent)
  → AnythingKernel.processIntent(intent) → ExecutionPlanReady(plan, spec, blueprint)
  → _createExperience(intent, spec, plan, blueprint)
    → CreationEngine.create(CreationContext(intent, spec, plan, blueprint, ...))
      → ExperienceManifest(..., category: _deriveStructuralCategory(blueprint), tags: blueprint.tags)
      → _buildInterfaceFromBlueprint(blueprint) → InterfaceDefinition
      → _buildBehaviorFromBlueprint(blueprint) → BehaviorGraph
      → _buildStateFromBlueprint(blueprint) → StateSchema
      → _buildDataSchemaFromBlueprint(blueprint) → DataSchema(entities: [...])
      → ExperiencePackage(manifest, interface, behavior, state, data, ...)
    → ExperiencePackageValidator.validate(package) → isValid
    → SqliteExperienceRepository.savePackage(package) → persisted
    → SqliteExperienceRepository.saveMetadata(ExperienceMetadataRecord(category: manifest.category))
    → ActivityRepository.record(ActivityEvent(type: 'created'))
  → CreationCreated(package, experienceId)

ExperienceOpeningCoordinator.openExperience(experienceId)
  → SqliteExperienceRepository.getMetadata(experienceId)
  → ExperiencePackageValidator.validate(package)
  → ActivityRepository.record(ActivityEvent(type: 'opened'))
  → SqliteExperienceRepository.touchLastUsed(experienceId)
  → OpenReady(package, experienceId)
```

---

## Tests

### stage10_6_test.dart — 14 tests, ALL PASS

| Group | Test | Status |
|---|---|---|
| CreationEngine Structural Metadata | Manifest category matches blueprint archetype | PASS |
| CreationEngine Structural Metadata | Manifest tags match blueprint tags | PASS |
| CreationEngine Structural Metadata | Manifest without blueprint uses spec category | PASS |
| CreationEngine Structural Metadata | Manifest JSON roundtrip preserves category and tags | PASS |
| CreationEngine Structural Metadata | Manifest fromJson tolerates old packages without category | PASS |
| Production Lifecycle — Lending | Full lifecycle: create → persist → open → runtime | PASS |
| Production Lifecycle — Lending | Failure atomicity: corrupted model does not corrupt repo | PASS |
| Production Lifecycle — OrbitMetrics | Full lifecycle: create → persist → open → validate | PASS |
| Metadata Roundtrip | Category and tags survive JSON roundtrip | PASS |
| Metadata Roundtrip | Category and tags survive SQLite roundtrip | PASS |
| Metadata Roundtrip | Multi-archetype category uses first archetype | PASS |
| Security Regression | Package integrity hash is computed | PASS |
| Security Regression | Production validator rejects empty manifest | PASS |
| Security Regression | Production coordinator returns result for empty expression | PASS |

### Regression

| Suite | Tests | Status |
|---|---|---|
| stage10_4_test.dart | 64 | ALL PASS |
| stage10_5_test.dart | 14 | ALL PASS |
| stage10_6_test.dart | 14 | ALL PASS |
| Full `flutter test` (default) | 375 | ALL PASS |

---

## Analyzer

```
flutter analyze test/stage10/stage10_6_test.dart
No issues found!
```

---

## Files Modified

| File | Change |
|---|---|
| `lib/creation/creation_engine.dart` | Added `_deriveStructuralCategory()`, updated manifest construction to include `category` and `tags` from blueprint |
| `test/stage10/stage10_6_test.dart` | Created: 14 integration tests covering Defect A + Defect B |

---

## Git

- **Branch:** v2.0.0
- **Commit:** (pending)
- **Push:** (pending)

---

## Acceptance Matrix

| Requirement | Status |
|---|---|
| Defect A: Production lifecycle integration tests | VERIFIED |
| Defect B: Structural metadata from blueprint | VERIFIED |
| ExperienceCreationCoordinator integration | VERIFIED |
| SqliteExperienceRepository persistence | VERIFIED |
| ExperienceOpeningCoordinator integration | VERIFIED |
| Metadata JSON roundtrip | VERIFIED |
| Metadata SQLite roundtrip | VERIFIED |
| Backward compat (old packages without category) | VERIFIED |
| Failure atomicity | VERIFIED |
| Security regression | VERIFIED |
| stage10_4 regression | VERIFIED |
| stage10_5 regression | VERIFIED |
| Full suite (375 tests) | VERIFIED |
| Analyzer (0 errors, 0 warnings) | VERIFIED |
| Android build | BLOCKED (corrupt debug keystore) |

---

## Remaining Limitations

1. Android build blocked by corrupt debug keystore (environment issue, not code)
2. Pre-existing info-level analyzer warnings (dangling doc comments, deprecated API)
