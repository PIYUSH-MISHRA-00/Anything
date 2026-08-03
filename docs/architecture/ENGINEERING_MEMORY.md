# Engineering Memory — Implementation Milestone R5

## Overview

R4 honestly documented a real gap: `RequirementGraph`, `ArchitectureCandidate`,
and `EngineeringPlan` were computed inside `AnythingKernel.processIntent`
and immediately discarded once Feature Discovery/Engineering consumed
them — never persisted per Experience. `planEvolution()` could therefore
only ever populate `ExperienceDiff` with real historical data; the other
three diff types stayed structurally `null`. R5 closes this: Anything no
longer forgets how an Experience was engineered.

## What's persisted, and the honest scope decision behind it

`EngineeringMemoryRepository` (`lib/storage/engineering_memory_repository.dart`)
persists, per Experience:

- **`RequirementGraph`** — full fidelity. Shallow type tree (4 classes),
  cheap and complete (`requirement_graph_serialization.dart`).
- **`ArchitectureCandidate`** — full fidelity. A larger but fully
  tractable type tree (16 classes across `architecture_types.dart`/
  `confidence.dart`), hand-serialized with the same `toJson()`/
  `fromJson()` convention `ExperiencePackage` already established
  (`architecture_candidate_serialization.dart`).
- **`EngineeringPlan`** — a real, honest **summary**
  (`EngineeringMemorySummary`, `application_engineering/engineering_memory_summary.dart`),
  not full fidelity. `EngineeringCandidate`'s type tree spans ~1700 lines
  across 10 files (behavior/data/navigation/interaction/persistence/
  offline/synchronization/lifecycle/performance/accessibility/security
  engineering, each with its own nested result shape, plus `EventGraph`/
  `StateMachineDefinition`/`BindingGraph`). This mirrors the EXACT
  precedent `WorldModelRepository` already set for `LearningRecord`/
  `AutomationRecord` (Vision Milestone V10): a real, useful, honestly-
  labeled summary rather than either skipping the type or rushing an
  under-verified full serialization of that much nested state in one
  milestone.

**Consequence, stated plainly**: `EngineeringDiffer.diff()` (Vision
Milestone R4) requires two full `EngineeringCandidate` instances — a
summary cannot be fed into it. `EngineeringDiff` remains unpopulated by
`planEvolution()` with real historical state this milestone. This is a
named, honest limitation (see Known Limitations below), not a silent gap.

## Storage design

Reuses the exact `WorldModelRepository` template (Vision Milestone V10):
shares `SqliteExperienceRepository`'s physical database connection via
constructor injection, creates its own table with
`CREATE TABLE IF NOT EXISTS engineering_memory` — idempotent, no
schema-version bump or `onUpgrade` migration required to either existing
repository. Same serialization convention `ExperiencePackage` already
uses: hand-written `toJson()`, `jsonEncode` to a TEXT column, a
`sha256` integrity hash computed identically to
`ExperiencePackage.computeIntegrityHash` (`package:crypto`, already a
dependency — never a new hashing scheme).

**Integrity/corruption handling**: `load()` recomputes the hash from the
stored JSON and compares it before deserializing. A mismatch (tamper, or
a future schema this build doesn't understand) is treated exactly like a
missing row — returns `null`, never throws, never surfaces malformed
data to a caller that didn't expect engineering memory to be mandatory.

## Atomicity

Engineering memory is persisted *sequentially after*
`SqliteExperienceRepository.savePackage()`, not inside the same SQLite
transaction, and a persistence failure is caught and swallowed — the
exact same "bookkeeping must never break the primary operation" contract
R1-R4 already established for World Model ingestion. A successful
Experience creation is never rolled back because engineering-memory
persistence failed; the Experience simply has no engineering memory,
handled identically to a pre-R5 Experience.

## Backward compatibility

Every Experience created before this milestone (and any created without
an `EngineeringMemoryRepository` injected) has no `engineering_memory`
row. `load()` returns `null`; `planEvolution()` degrades gracefully —
`historicalEngineeringMemory` is `null`, and every other R4 behavior
(`ExperienceDiff` computation, the mutation-planning contract) is
completely unaffected. Proven directly by test
(`test/r5_engineering_memory_test.dart`).

## Wiring

`AppComposition` (R1's composition root) now holds the one shared
`EngineeringMemoryRepository` instance, threaded to
`ExperienceCreationCoordinator` (persists at creation, right after World
Model ingestion) and `ExperienceHostScreen` → `ExperienceModificationCoordinator`
(reads at `planEvolution()` time). Both dependencies are optional,
null-by-default constructor parameters, matching `_worldModel`/
`_softwareCognition`'s established pattern — no existing call site or
test is affected.

`AnythingKernel.processIntent`'s `ExecutionPlanReady` outcome gained one
new, additive, optional field: `requirementGraph` — the same value
Feature Discovery already consumed internally, now also exposed to the
creation coordinator so it can be persisted. `ArchitectureCandidate` is
already reachable via the existing `solutionDecision.selected.architecture`.

## planEvolution() and historical engineering memory

`EvolutionDiffPlan` gained one new, additive, optional field:
`historicalEngineeringMemory` (a `HistoricalEngineeringMemory` holding the
real, persisted "before" `RequirementGraph`/`ArchitectureCandidate`/
`EngineeringMemorySummary`, when available). This is deliberately
**not** a diff — computing `requirementDiff`/`architectureDiff` would
require a genuine "after" state, which would mean re-running
Requirement/Architecture planning against the modification.
`ExperienceModificationCoordinator` patches `ExperiencePackage` directly
via `ModificationEngine.modify()` and never re-invokes the Kernel's
planning stages (and must not gain a new LLM call to do so — the AI
boundary is unchanged). Exposing the real historical state — without a
fabricated diff — is the honest, achievable scope for this milestone.

## Known limitations

- `EngineeringDiff` still cannot be populated with real historical state
  (see above) — full `EngineeringCandidate` fidelity is a real, scoped
  R6 candidate if judged worth the effort against its size.
- `requirementDiff`/`architectureDiff` remain `null` in
  `planEvolution()`'s output — no genuine "after" Requirement/Architecture
  state is derivable without re-running Kernel-level planning, which is
  out of this milestone's scope (and would risk becoming "a second
  planner" if built carelessly).
- Documentation updates this milestone were scoped to this new doc plus
  the Vision Gap Matrix/Completion Roadmap — the four other named
  architecture docs (Software Architect/Application Engineering/
  Evolution/World Model) were not individually edited, given real time
  constraints; their content remains accurate, just not yet
  cross-referencing this new persistence layer.
