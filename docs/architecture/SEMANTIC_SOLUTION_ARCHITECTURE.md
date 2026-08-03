# Semantic Solution Architecture — Implementation Milestone R17

## Overview

R17 asked for ONE representation of a complete software system —
frontend, backend, database, authentication, storage, realtime,
messaging, notifications, background jobs, API, deployment,
observability, monitoring, configuration, policies, permissions,
secrets, scaling, caching, synchronization, offline support — sitting
before generation begins, consumed by the Universal Build Graph and
Generation Specification.

## REALITY: audit of the 20 requested categories

Of the 20, **11 were already real, tested production types** before
this milestone:

| Category | Already real in |
|---|---|
| Frontend | `ArchitectureCandidate` (`lib/software_architect/`, V2/V5) |
| Backend | `BackendEngineeringPlan` (`lib/backend_engineering/`, R8) |
| Database | `DatabaseSchemaModel` (R8) |
| Authentication | `AuthenticationModel` (R8) |
| Storage | `BackendStorageModel` (R8) |
| Background Jobs | `BackgroundJobsModel` (R8) |
| API | `ApiSpecificationModel` (R8) |
| Deployment | `DeploymentSpecificationModel` (R8) |
| Secrets | `SecretReference` inside `DeploymentSpecificationModel` (R8) — name-only |
| Permissions | `PermissionDecision` inside `ArchitectureCandidate` (V2) |
| Synchronization / Offline Support | `SynchronizationDecision` / `OfflineDecision` (V2) |

`CanonicalImplementationModel` (R9) already unifies `ArchitectureCandidate`
+ `BackendEngineeringPlan` — but into IMPLEMENTATION vocabulary
(entities/repositories/controllers), not the ARCHITECTURE vocabulary
(components/services/dependencies/responsibilities/boundaries/contracts/
lifecycle/ownership) R17 explicitly asked for. That gap — an
architecture-shaped view sitting *before* `CanonicalImplementationModel`
— is what `SemanticSolutionArchitecture` fills.

**Confirmed genuinely missing** anywhere in this codebase (grepped, zero
hits beyond the one `SecretReference` file): Realtime, Messaging,
Notifications, Observability, Monitoring, Configuration, Policies,
Scaling, Caching. `CanonicalImplementationModel`'s own docstring (R9)
already made the identical honest call for several of these
("Realtime Channel/Configuration/Serialization/Error-Handling/Logging/
Monitoring are NOT modeled — no real upstream signal exists") — this
milestone is continuous with that precedent, not a new exception to it.

Of these 9, only **Caching** has real upstream signal:
`BackendEngineeringPlan.backgroundJobs.sourceStrategy` (R8) already
distinguishes `cacheFirst`/`networkFirst`/`manualRefresh`/`none` — the
same signal `BackgroundJobsModel.requiresBackgroundSync` already reuses
for a different purpose. `CachingModel.employsCaching` is an honest
restatement of that SAME field with explicit caching semantics, not an
independently-derived heuristic. The other 8 have zero real signal and
are honestly named in `SemanticSolutionArchitecture.unmodeledConcepts`
rather than fabricated.

## Design: compose, never duplicate

`SemanticSolutionArchitecture` (`lib/solution_architecture/`) holds
`ArchitectureCandidate` and `BackendEngineeringPlan` **by reference** —
never copies their fields into a parallel shape. Its only new data is:

- `components: List<SolutionComponent>` — a real, per-entity derived
  view restating already-real data (entity id/name, FK-derived
  dependencies, API-endpoint-derived contracts, storage-kind-derived
  lifecycle, backend-presence-derived boundary) as R17's own
  "Components/Services/Interfaces/Dependencies/Responsibilities/
  Boundaries/Contracts/Lifecycle/Ownership" vocabulary — one type
  capturing all nine concepts as fields, not nine separate new classes
  for what is fundamentally one derived view per entity.
- `caching: CachingModel` — the one real net-new signal (see above).
- `unmodeledConcepts: List<UnmodeledConcept>` — the 8 honest gaps, each
  with a real, specific reason, never a bare `List<String>`.

`SolutionArchitecturePlanner.plan(ArchitectureCandidate, BackendEngineeringPlan)`
is a pure, deterministic function — zero new AI call, mirrors
`BackendEngineeringPlanner`/`CanonicalImplementationPlanner`'s own
derivation-function-per-concern shape exactly.

## Canonical Implementation Model: deliberately NOT extended

`CanonicalImplementationContext`/`CanonicalImplementationModel` (R9,
extended R14/R15) are **untouched** by this milestone — no new field, no
new required parameter, proven by a dedicated backward-compatibility
test. Rationale: `CanonicalImplementationContext` already takes the SAME
two real sources (`engineering`, itself derived from
`ArchitectureCandidate`, and `backend`) that `SemanticSolutionArchitecture`
composes. Threading a third, redundant parameter through would not add
real information — `SolutionComponent`'s fields are themselves derived
from data `CanonicalImplementationModel` already has access to via its
existing two inputs. `SemanticSolutionArchitecture` is exposed
additively on `ExecutionPlanReady.solutionArchitecture` instead, for a
caller or future generator to consume directly.

## Universal Build Graph / Generation Specification: consumed transitively, unchanged

`BuildGraphBuilder.build()` reads only `entities`/`controllers`/
`capabilities` from `CanonicalImplementationModel` (`BuildNodeKind` is
`{entity, repository, controller, capability}` — confirmed unchanged
since R11). Since `CanonicalImplementationModel` was not extended this
milestone (see above), and `SemanticSolutionArchitecture` composes the
SAME two inputs that already flow into it, the Build Graph's
consumption chain is satisfied transitively — zero changes to
`lib/build_graph/` or `lib/generation_specification/` were necessary.
A dedicated test (`Generator compatibility (R17)`) proves the existing
`RuntimeExperienceGenerator`/`GenerationPipeline` still produce a valid
`ExperiencePackage`, unmodified.

## Software Cognition enrichment

Two new pattern analyzers, mirroring R14's `AuthenticationPatternAnalyzer`/
`NavigationPatternAnalyzer` shape exactly: `RealtimePatternAnalyzer`
(websocket/socket.io/pusher/ably/signalr/phoenix_socket/firebase_database
hints) and `CachingPatternAnalyzer` (redis/memcached/hazelcast/ehcache/
caffeine hints) — real, documented, non-exhaustive substring matches over
already-declared dependencies, never a re-parse of source. These give
real Software-Cognition-side grounding for 2 of the 9 architecture gaps;
the other 7 (messaging/notifications/observability/monitoring/
configuration/policies/scaling) are NOT given analyzers — none of them
are typically named, single-package dependencies the way auth/nav/
realtime/caching libraries are, so a dependency-hint heuristic would not
be a real signal for them.

Two new `SoftwareNodeKind` values (`realtimePattern`, `cachingPattern`)
and two new graph types (`RealtimePatternGraph`, `CachingPatternGraph`)
were added following R14's exact precedent; `SoftwareGraphBridge`'s
existing exhaustive mapping was extended to route both into the SAME
`WorldNodeKind.softwareComponent` catch-all every other pattern kind
already uses — no new `WorldNodeKind`.

## World Model integration

New `SolutionArchitectureGraphBridge` (`lib/world_model/bridges/`),
following the same pure-translation pattern every other bridge uses.
REALITY before R17: frontend `ArchitectureCandidate` was **never**
ingested into the World Graph at all — confirmed by grep (zero
references in `world_model_coordinator.dart` before this milestone).
`BackendGraphBridge` (R8) already ingests backend entities/endpoints;
this bridge's genuinely new contributions are:

1. Frontend entities — resolved via the SAME `stableId: entity.id`
   convention `BackendGraphBridge` already uses, so a shared entity
   unifies into the SAME node whether observed from the frontend or the
   backend, proven by a dedicated no-duplicate test.
2. Permission-depends-on-capability edges (`PermissionDecision`) —
   never previously ingested anywhere.
3. A real caching signal node (`WorldNodeKind.softwareComponent`,
   labeled `caching:<strategy>`) only when caching is real — never
   fabricated when it isn't.

Wired into the Kernel at Step 7.9, immediately after
`backendEngineeringPlan` is computed, via the same
`_ingestIntoWorldModelSafely` defensive, non-failing pattern every
other ingestion call site uses (R1).

## Engineering Memory

Not extended. `SemanticSolutionArchitecture` derives deterministically
and cheaply from `ArchitectureCandidate`/`BackendEngineeringPlan`, both
already persisted in full fidelity via `EngineeringMemoryRepository`
(R5/R8/R9) — recomputing it from the persisted pair costs one cheap,
pure function call, so there is no real reuse case for a third,
independent persistence path (matching R10-R12's own repeated,
documented restraint).

## AI boundary

Zero new LLM/reasoning calls. `SolutionArchitecturePlanner.plan()` is a
pure, deterministic function of its two already-reasoned inputs.

## No duplicate architecture

No second Compiler, Build Graph, Runtime, Generator Framework, World
Model, Capability Platform, Knowledge Engine, or AI Boundary.
`lib/generator_framework/`, `lib/build_graph/`, `lib/runtime/` are
completely untouched by this milestone (`git diff --stat`).

## Known limitations

1. Realtime/Messaging/Notifications/Observability/Monitoring/
   Configuration/Policies/Scaling remain honestly unmodeled at the
   architecture-decision level (`unmodeledConcepts`) — real Software
   Cognition signal exists for Realtime/Caching only (see above); the
   other 7 have zero real signal anywhere in this codebase today.
2. `SolutionComponent.responsibility` is a deterministic, templated
   sentence (`'Owns and manages <name> records and behavior.'`), not a
   reasoned description — an honest, named simplification, the same
   kind of templating `RuntimeExperienceGenerator` (R13) already uses
   for `ExperienceManifest.description`.
3. `SemanticSolutionArchitecture` is not yet consumed by any generator
   beyond being exposed on `ExecutionPlanReady` — no generator today
   reads architecture-level component/caching data directly (the
   existing `RuntimeExperienceGenerator` still reads
   `CanonicalImplementationModel` only, unchanged).

## Recommendation for R18

1. If Caching/Realtime prove valuable in practice, extend
   `CachingPatternAnalyzer`/`RealtimePatternAnalyzer`'s corroborated
   findings into `SemanticSolutionArchitecture` itself (today they only
   reach the World Graph via `SoftwareGraphBridge`, not
   `SolutionArchitecturePlanner`) — a real, additive follow-on, not
   started here to keep this milestone's scope honest.
2. `CapabilityRegistry`'s zero-production-callers finding (R14/R15,
   still unaddressed) continues to deserve independent architectural
   review.
3. The R13 `ExperienceHostScreen` detail-cache characteristic and R10's
   "second, genuinely different generator" recommendation remain open.
4. R16's own recommendations (UI toggle for `autoDiscoverKnowledge`,
   `model_reasoner.dart` prompt/schema richer categories) remain open.

**DO NOT START R18 — per this milestone's own stop condition, wait for
external architectural review.**
