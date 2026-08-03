# Canonical Implementation Model — Implementation Milestone R9

## Overview

Unifies frontend Engineering (`EngineeringCandidate`, Vision Milestone V3
— shaped for this codebase's own closed Flutter/Dart runtime vocabulary)
and backend Engineering (`BackendEngineeringPlan`, Implementation
Milestone R8 — real but domain-specific engineering decisions) into ONE
canonical, **language-independent** implementation representation: the
`CanonicalImplementationModel`. This is a universal software
intermediate representation a future language generator could target —
it does not itself generate implementation code in any language.

## Investigation finding

Neither `EngineeringCandidate` nor `BackendEngineeringPlan` was
language-independent: the former is expressed in Flutter/Dart-shaped
concepts (widgets, `GenericState`), the latter in domain-specific
engineering decisions (`DatabaseTable`, `ApiEndpoint`) rather than
generic implementation concepts (Entity, Repository, Controller). No
prior milestone produced a unifying, language-neutral vocabulary — this
is genuinely new capability work, sanctioned by this milestone's own
"if not existing, create only the minimum canonical abstractions
required."

## Module map (`lib/implementation_model/`)

| Module | Real behavior |
|---|---|
| `canonical_implementation_model.dart` | All 20-concept type vocabulary — `ImplementationEntity`/`Repository`/`Controller`/`Dto`/`Validator`/`Service` (real depth, from `BackendEngineeringPlan`), `StateContainerSpec`/`NavigationHandlerSpec`/`CapabilityAdapterSpec` (real depth, from `EngineeringCandidate`/`CapabilityRegistry`), `AuthenticationAdapterSpec`/`StorageAdapterSpec`/`BackgroundWorkerSpec` (thin, real wrappers over R8's own minimal models). Zero Flutter/Dart/Java/Kotlin/Swift/TypeScript/Python/Go/Node-specific constructs. |
| `canonical_implementation_planner.dart` | `CanonicalImplementationPlanner` — one deterministic derivation method per concern, mirroring `BackendEngineeringPlanner`'s (R8) own assembly shape. Consumes `CanonicalImplementationContext{engineering, backend, resolvedCapabilities}`. |
| `canonical_implementation_serialization.dart` | Hand-written `toJson()`/`fromJson()`, same convention as `backend_engineering_serialization.dart` (R8). |

## Honest depth statement

Entity/Repository/Controller/DTO/Validator/Service are genuinely
complete-feeling — derived directly from `BackendEngineeringPlan`'s
already-real `DatabaseTable`/`ApiEndpoint` data. StateContainer/
NavigationHandler/CapabilityAdapter are also real depth, derived from
`EngineeringCandidate`'s already-real `StateMachineDefinition`/
`NavigationEngineeringResult`/resolved `CapabilityDescriptor`s.
Authentication/Storage/Background-Worker are deliberately thin,
mirroring R8's own already-honest-and-minimal models with no added
richness. **Realtime Channel, Configuration, Serialization, Error
Handling, Logging, and Monitoring are NOT modeled at all** — no type,
no field — because no real upstream engineering decision exists
anywhere in this codebase to derive them from without inventing data.
This is a named, deliberate scope boundary, not an oversight.

## Language independence

A mechanically-checkable, tested property: `test/r9_canonical_implementation_model_test.dart`
scans every exported type/enum name and the full serialized JSON for a
forbidden-term list (`Widget`, `Flutter`, `Dart`, `Java`, `Kotlin`,
`Swift`, `TypeScript`, `Python`, `Node`, `React`, `Express`, `FastAPI`,
`Spring`). `GenericState` (Vision Milestone V3) is reused directly for
state names since it was already a generic, language-neutral
vocabulary (idle/loading/editing/saving/...) — not duplicated.

## AI boundary

Zero new LLM calls. `CanonicalImplementationPlanner.plan()` consumes
only the same, already-computed `EngineeringCandidate`/
`BackendEngineeringPlan`/resolved `CapabilityDescriptor`s — proven
directly by a real determinism test (the same Kernel run, twice,
produces byte-for-byte identical canonical implementation models).

## Kernel integration

`AnythingKernel.processIntent` gains one new step (8.5, between
Capability Resolution and `ExecutionPlan` construction) — additive,
deterministic, World-Model-ingested via the existing
`_ingestIntoWorldModelSafely` defensive contract (a failure here can
never fail generation). `ExecutionPlanReady` gained one additive
`canonicalImplementationModel` field, matching R5's `requirementGraph`
and R8's `backendEngineeringPlan` field precedent exactly.

## Engineering Memory integration

`EngineeringMemoryRepository` (R5, extended R8) gained a
`canonical_implementation_json` column via the same real, additive,
idempotent `ALTER TABLE` migration pattern (try/catch on "duplicate
column" as the idempotency signal). **Critical backward-compatibility
decision**: the row's `integrity_hash` formula was deliberately left
UNCHANGED (still 3 fields) — extending it would retroactively
invalidate every pre-R9 row's already-computed hash. A dedicated test
proves an R8-shaped row still loads correctly post-R9.

## World Model integration

No new `WorldNodeKind` was added. `ImplementationGraphBridge`
(`lib/world_model/bridges/implementation_graph_bridge.dart`) is
deliberately narrow: entity and API-endpoint nodes are already
ingested by `BackendGraphBridge` (R8) — re-adding them would be pure
duplication. The one genuinely new piece of information the CIM
contributes to the World Graph is entity-to-capability dependency
edges (`ImplementationDependency` with `DependencyKind.capability`),
emitted together with real nodes for both edge endpoints (a real bug —
edges emitted without nodes were silently rejected by
`GraphConsistency`'s "never dangling" contract — was found and fixed
during this milestone's own World Model integration test).

## Security

No privilege-escalation path: the model is non-executable specification
data. Capability isolation and the existing trust boundary are
unchanged; this milestone adds no new dispatch path and no new secret
storage.

## Known limitations

- Realtime Channel/Configuration/Serialization/Error-Handling/Logging/
  Monitoring are not modeled at all (see "Honest depth statement").
- Capability dependency edges use a literal `'app'` pseudo-node as the
  `fromId` rather than true per-entity attribution — no upstream signal
  ties a resolved capability to one specific entity.
- Consolidated into 3 files rather than R8's ~10-file convention, a
  deliberate ponytail-driven simplification for this milestone.
- Reusable-by-future-language-generators is structurally plausible
  (real, typed, language-independent, serializable) but not yet proven
  by an actual generator, since none exists yet.
