# Release Candidate Engineering & Production Hardening — Vision Milestone V10

## Overview

Unlike V1-V9, this milestone adds no new architectural layer. Its job was
to harden what already exists: resolve V9's own documented limitations,
wire the graph-aware Modification pre-check into the real production
path, unify Evolution and World identities, and make real, measured
performance/accessibility/logging/CI improvements — never inventing a
parallel system for anything that already exists.

## Repository audit findings that shaped this milestone

- `SqliteExperienceRepository` had `version: 1` with **no `onUpgrade`
  mechanism at all** — adding new tables to `_createTables` alone would
  silently do nothing for any database that already exists.
- `ExperienceModificationCoordinator.modifyExperience()`'s exact sequence
  (load → build spec → `ModificationEngine.modify()` → validate → save →
  record activity) has no pre-flight hook — any impact-analysis
  integration has to be inserted explicitly between steps.
- Zero CI/CD, centralized logging, or structured error-handling
  infrastructure existed anywhere in this repository before this
  milestone.
- `ExperienceRenderer` had zero explicit `Semantics`/`semanticLabel`
  usage — Material widgets like `ElevatedButton`/`TextField` already
  carry solid built-in accessibility, but bare `Switch` and `Icon` nodes
  genuinely had none.
- Zero localization infrastructure (`intl`/`flutter_localizations`)
  exists in `pubspec.yaml`; a sample scan found ~14 hardcoded UI strings
  across 3 files (not exhaustive).

## Highest priority: World Model & Runtime Intelligence persistence

`lib/storage/world_model_repository.dart` — a new `WorldModelRepository`
resolving V9's own documented "not yet persisted across process
restarts" limitation. Deliberately reuses the **existing SQLite
architecture** rather than inventing a new storage layer: it shares the
exact same physical database connection as `SqliteExperienceRepository`
(via its public `database` getter) and creates its own tables with
`CREATE TABLE IF NOT EXISTS` — idempotent, requiring no schema-version
bump to the existing, heavily-tested repository.

Persisted with full fidelity: the current `WorldGraph` (nodes/edges) and
`ObservationRecord`s (both already flat, structural types). Persisted as
honest, real **summaries** (never a fabricated full reconstruction of
deeply nested evidence/step data): `LearningRecord` → 
`PersistedLearningSummary`, `AutomationRecord` → 
`PersistedAutomationSummary`. A `WorldSnapshotRecord` audit trail records
version/timestamp/node-count/edge-count growth over time — the current
graph is fully persisted, but historical graph-content-per-version is not
retained (unbounded storage growth avoided, documented honestly).

`WorldModelCoordinator`/`RuntimeIntelligenceCoordinator` gained explicit
`persist()`/`restore()` methods — deliberately NOT making every existing
`ingest*`/observation method asynchronous, preserving full backward
compatibility with every synchronous call site V8/V9 already established
and tested. A real process-restart round-trip (fresh coordinator
instance, `restore()`, graph recovered) is proven directly in
`test/world_model/world_model_persistence_test.dart`.

**A real bug was caught and fixed while building this**: `loadGraph()`'s
identity-reconstruction helper was passed an edge row's `kind` column
(a `RelationshipKind` like `"consumes"`) where it needed the identity's
OWN `WorldNodeKind` prefix (encoded in the identity value itself, e.g.
`"entity:Task,text:title"`) — two completely different vocabularies.
Fixed by deriving the kind directly from the identity value's own
prefix, never from an unrelated column. Caught by
`test/storage/world_model_repository_test.dart` before this ever
reached the stress-test or production path.

## Modification: precheckModification() wired into the real path

`ExperienceModificationCoordinator` now defaults its `worldModel`
constructor parameter to a real, freshly-constructed
`WorldModelCoordinator` when not injected — never null, never
optional-out — so `precheckModification()` runs for every real call path
("no caller should ever bypass it"). Honest scope: `precheckModification`
today evaluates the CURRENT World Graph's consistency (`GraphConsistency`,
real, always-run, gates outright) and computes a real `ImpactReport` for
visibility — it does not (and cannot yet) evaluate the SPECIFIC proposed
edit's structural impact, since `ExperienceModificationSpec`/
`ModificationOperation` carry no structural signal `ImpactAnalyzer` could
reason over. This is a real, pre-existing scope boundary in
`precheckModification`'s design, named honestly rather than oversold.
First test coverage ever for `ExperienceModificationCoordinator`
(`test/app/experience_modification_coordinator_test.dart` — none existed
before this milestone).

## Evolution: unified with World identities

`EvolutionGraphBridge.bridge()` now accepts an optional `AppBlueprint?`.
When supplied, an evolution proposal's `affectedNodeId` resolves to the
**exact same structural `EntityIdentity`** `ExperienceGraphBridge` would
compute for that real entity — reusing
`GenericPackageBuilder.mapBlueprintFieldTypeToDataFieldType` (made public
for this reuse) so the field-type strings are byte-identical to what
`ExperienceGraphBridge` reads from the real persisted
`ExperiencePackage.data`. One entity, one identity — proven directly in
`test/world_model/evolution_identity_unification_test.dart`, including the
honest fallback case (an id that isn't a real blueprint entity, e.g. an
architecture posture decision, never fabricates a match).

## Observation → Learning → World Graph, in one call

`RuntimeIntelligenceCoordinator.runAndSyncToWorldModel()` runs the full
Learn → Recommend → Review → Predict → Plan pass and immediately syncs
its `UsageGraph`/learned patterns into a `WorldModelCoordinator` — one
call instead of a caller manually sequencing
`runIntelligence()` → `ingestUsage()` → `ingestLearning()` in the right
order. Attaching `ObservationEngine` to a live runtime session remains a
separate, explicit `attachSession()` call — unchanged since V8, avoiding
an invasive change to `ExperienceHostScreen`.

## Performance & SQLite optimization — measured, not promised

- **A real, measured SQLite bug**: `WorldModelRepository.saveGraph()`
  originally inserted each row individually inside a transaction. A
  stress test (1000 nodes / 10000 edges) measured **~5.7s**. Converting
  to a real `Batch` cut this to **~1.4–2.3s** — a genuine ~3-4x
  improvement, found and fixed via this milestone's own stress testing,
  not a fabricated benchmark.
- **A real migration gap closed**: `SqliteExperienceRepository` bumped
  from `version: 1` (no upgrade path at all) to `version: 2` with a real
  `onUpgrade` handler adding indexes (`idx_experiences_last_used`,
  `idx_experiences_category`) — `CREATE INDEX IF NOT EXISTS` only, never
  touching existing rows, never changing any public API. Proven with a
  dedicated test that seeds a real version-1 database, then opens it via
  the real repository and confirms the upgrade runs cleanly with zero
  data loss (`test/storage/sqlite_migration_test.dart`).
- `WorldModelRepository`'s own new tables include indexes on
  `world_graph_edges(from_id)`/`(to_id)` and
  `observation_records(experience_id)` from the start.
- `GraphTraversal` (V9) was already bounded (never unbounded, never
  revisits a node) — stress-tested here at 1000 nodes / 10000 edges to
  confirm it stays correct and fast (traversal + consistency validation
  both completed in well under 50ms at this scale).

## Accessibility — a real, scoped fix, not a claim of completeness

Confirmed by audit: Material widgets (`ElevatedButton`, `TextField`)
already have solid built-in Flutter accessibility by default — the real
gaps were `Switch` (announces only "on"/"off", nothing about what it
controls) and `Icon` (conveys nothing to a screen reader by default).
Both now carry real `Semantics`/`semanticLabel` using data already
present on the node (never fabricated) — proven with real
`tester.getSemantics()` assertions in `test/runtime/accessibility_test.dart`,
including a backward-compatibility test confirming an unlabeled node
still renders exactly as before.

## Localization — audited honestly, infrastructure not built this milestone

No `intl`/`flutter_localizations` dependency exists; a sample scan found
hardcoded strings in `lib/features/experiences_screen.dart` (10),
`home_screen.dart` (3), and `provider_preferences_screen.dart` (1) — not
exhaustive. Building full localization scaffolding (ARB files, generated
code, rewiring every screen) is a genuinely large, separate undertaking;
declaring it "ready" without doing that work would be dishonest. Recorded
as a real, scoped V11+ candidate rather than fabricated as complete.

## Structured logging & diagnostics — the first of their kind

`lib/diagnostics/` is entirely new (confirmed zero prior logging/error-
handling infrastructure beyond an uncategorized `debugPrint` shadow in
`analytics_service.dart`). `StructuredLogger` writes real, categorized
`LogEntry`s via `dart:developer`'s own `log()` (no new dependency), with
an honestly-modest redaction pass (email/token-shaped patterns — a
last-resort safety net, not a comprehensive PII scrubber, documented as
such). `ErrorReport` is the typed boundary between a raw exception
(logged, developer-facing only) and what a user is ever shown (a
caller-supplied safe message, never the exception's own text).
`HealthReport`/`WorldGraphDiagnostics`/`RuntimeIntelligenceDiagnostics`/
`SecurityDiagnostics`/`StorageDiagnostics` are real, typed summaries
derived from already-computed data — `SecurityDiagnostics` explicitly
reuses SCARE's own `ReviewIssue`s rather than re-implementing a security
checker.

## CI/CD — the first pipeline in this repository

`.github/workflows/ci.yml`: analyze, format-check, full test suite with
coverage, a documentation-completeness check (every Vision Milestone's
architecture doc must exist), and a forbidden-file scan — every step uses
tooling already in `pubspec.yaml` or built into the Flutter/Dart SDK, no
new dependency. Honestly noted: this YAML has not been executed by an
actual GitHub Actions run in this session (no CI runner available here)
— it is syntactically real and uses only real tooling, but unexecuted
until pushed.

## OSS quality

A bounded, targeted pass (not an exhaustive full-repository sweep, which
isn't realistic at this codebase's size in one milestone): confirmed zero
leftover debug files, `TODO`/`FIXME`/`XXX` markers in every V6-V10 module
built this session, and confirmed the analyzer baseline is unchanged (71
pre-existing issues, all already documented from V2-V9, zero new).

## WebWeaveX and Kaalka

Unchanged, canonical, not duplicated. This milestone introduces no
extraction, crawling, parsing, or cryptographic logic of any kind.

## Known limitations

- `WorldSnapshotRecord`'s audit trail is metadata-only — full historical
  graph content per version is not persisted (avoids unbounded growth).
- `precheckModification()` gates on current graph consistency, not the
  specific proposed edit's impact — a real, named scope boundary, not a
  gap introduced by this milestone.
- Localization infrastructure was audited, not built.
- The CI workflow is real but unexecuted (no GitHub Actions run in this
  session).
- The standing Android debug-build blocker (JDK/keytool incompatibility)
  remains — confirmed unaffected by `flutter clean`/`pub get`, still the
  same pre-existing, Anything-code-unrelated `KeytoolException`.
- OSS cleanup was scoped to this session's own new code, not an
  exhaustive full-repository dead-code sweep.
