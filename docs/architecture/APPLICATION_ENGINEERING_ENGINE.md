# Application Engineering Engine (AEE) — Vision Milestone V3

## Overview

`lib/application_engineering/` sits between ASAE's approved
`ArchitectureCandidate` (V2) and the existing `AppBlueprint`/`ExperienceSpec`/
`ExecutionPlan`/`CreationEngine`/Runtime pipeline. Before V3, an approved
architecture converted straight to a blueprint with no explicit record of
*how* it should be engineered — what event graph and state machine each
entity's CRUD gets, how the UI binds to state, to data, and to capabilities,
what the offline/sync/persistence/lifecycle/accessibility/performance/
security posture actually is. AEE makes every one of those a real, typed,
justified `EngineeringDecision`, subjects the whole assembly to review, runs
a bounded refinement loop, and only then lets the (possibly corrected)
result shape the same `AppBlueprint`/`ExperienceSpec` types everything
downstream already consumes.

Nothing about ASAE itself changed — `RequirementExtractor`, the 13
sub-planners, `SelfCritic`, and `RefinementPlanner` are untouched. AEE is a
genuine, mandatory additional stage, not a replacement for architecture
planning.

## Pipeline

```
ArchitectureCandidate (approved, from the existing, certified ASAE)
  │
  ▼
BehaviorEngineering        -> EventGraph + StateMachineDefinition per entity,
  │                            gated on real InteractionDecision flags
  │                            (canCreate/canUpdate/canDelete/supportsSearch/
  │                            supportsFilter/supportsSort); read is always
  │                            present. States are always GenericState
  │                            (idle/loading/editing/saving/deleting/
  │                            searching/filtering/sorting/refreshing/
  │                            offline/synchronizing/completed/error) —
  │                            never a domain-specific state name.
  ▼
DataEngineering            -> index/aggregation/migration decisions, honestly
  │                            grounded in the real single-generic-table
  │                            JSON-blob storage design.
  ▼
NavigationEngineering      -> modal edges, deep-link/history/recovery
  │                            decisions, grounded in ExperienceRouter's
  │                            real, already-tested rejection behavior.
  ▼
InteractionEngineering     -> single-selection/confirmation reported real
  │                            (tested); batch-selection/undo/redo/context-
  │                            menu/grouping reported NOT implemented —
  │                            never fabricated.
  ▼
BindingEngineering         -> typed BindingGraph using the exact identifier
  │                            conventions ExperienceRenderer/
  │                            ExperienceFormController already use
  │                            (form_<fieldId>, searchTerm, entity ids).
  ▼
ValidationEngineering      -> entity/relationship/action/transition-level
  │                            rules (fieldCount>0, explicit delete policy,
  │                            every action has an effect, no self-loop
  │                            transitions).
  ▼
PersistenceEngineering,    -> wraps V2's per-entity storage decision;
OfflineEngineering,           OfflineCapability -> OfflineStrategy
SynchronizationEngineering    (offlineFirst/cacheFirst/onlineRequired);
  │                            SynchronizationEngineering is explicitly
  │                            architecture-only — a typed strategy record,
  │                            no network client code.
  ▼
LifecycleEngineering,      -> hooks/aspects mapped to the real classes that
AccessibilityEngineering,     already realize them (CreationEngine,
PerformanceEngineering,       SqliteExperienceRepository,
SecurityEngineering           ExperienceOpeningCoordinator, AnythingRuntime,
  │                            Flutter Material defaults, RuntimeSecurityLimits,
  │                            Kaalka) — the key honest finding:
  │                            virtualization is NOT real today (generated
  │                            lists use Column + List.generate, not
  │                            ListView.builder).
  ▼
EngineeringPlanner         -> EngineeringCandidate (all of the above,
  │                            + overallConfidence, a real computed mean)
  ▼
EngineeringReview          -> EngineeringReviewResult (typed issues: dangling
  │                            bindings, behavior inconsistencies,
  │                            unsatisfied validations, low confidence)
  ▼
EngineeringRefinement      -> EngineeringPlan (loops: fix auto-fixable
  │                            critical issues, re-review, up to
  │                            maxIterations=3; terminates the moment
  │                            nothing fixable remains or the budget is
  │                            exhausted — mirrors ASAE's RefinementPlanner)
  ▼
EngineeringToBlueprintAugmenter -> compiles the approved EngineeringPlan's
  │                            generic state machine into the *existing*
  │                            BehaviorGraph/StateSchema vocabulary: one
  │                            `<entityId>_status` StateVariable per entity,
  │                            one `stateWrite` BehaviorNode per in-flight
  │                            action wired onto that action's already-
  │                            existing `<actionId>_event` node.
  ▼
(unchanged) ExperienceSpec -> ExecutionPlan -> CreationEngine -> Runtime
```

## Compilation, not reinvention

The milestone's instruction that "Runtime must understand Behavior Graph,
State Machine, Binding Graph, Lifecycle Graph" is satisfied by **compiling**
AEE's typed `StateMachineDefinition`/`EventGraph`/`BindingGraph` down into
the BehaviorGraph/StateSchema vocabulary `BehaviorInterpreter` already
executes — not by rewriting the interpreter. `EngineeringToBlueprintAugmenter`
adds new `stateWrite` nodes and string-typed `StateVariable`s wired onto
the *already-existing* event nodes `CreationEngine._buildBehaviorFromBlueprint`
builds from the blueprint. `BehaviorInterpreter` itself is byte-for-byte
unchanged from M2; it genuinely executes the compiled state machine only
because that state machine is expressed in a form it already understands —
analogous to a compiler lowering a high-level construct to an existing
instruction set, not the CPU being redesigned. This is proven, not just
argued, by `test/application_engineering/kernel_creation_runtime_integration_test.dart`,
which dispatches a real generated event through the real, unmodified
`BehaviorInterpreter` and observes the `<entity>_status` state variable
actually transition.

## No bypass

`AnythingKernel.processIntent` runs `EngineeringPlanner().plan()` and
`EngineeringRefinement().refine()` for every approved `ArchitectureCandidate`,
immediately after blueprint validation and before `ExperienceSpec`
conversion; there is no code path from an approved architecture to an
`ExecutionPlanReady` outcome that skips it (verified in
`test/application_engineering/kernel_creation_runtime_integration_test.dart`,
and by the fact that `test/stage10` + `test/stage11` — M1's real,
novel-domain, real-SQLite certification, 388 tests — pass unchanged with
AEE now mandatory in that exact path).

If engineering refinement exhausts its iteration budget while critical
issues remain, `processIntent` returns `PlanningFailed` rather than shipping
an engineering plan AEE itself flagged as unsound — fail-closed, matching
ASAE's and the knowledge loop's existing philosophy.

## ExperienceSpecification and ExecutionPlan now derive from EngineeringPlan

`ExperienceSpec` carries an optional `engineeringPlan` field, populated by
`BlueprintToSpecConverter.convert(blueprint, engineeringPlan: plan)` inside
the Kernel — the same object `ExecutionPlanReady.engineeringPlan` carries.
`ExecutionPlan` construction (`_buildPlan`) is otherwise unchanged: the plan
it builds still describes the same validate/synthesize/persist steps, now
downstream of a spec that is itself derived from the engineered (not raw
architectural) blueprint. `CreationContext.engineeringPlan` threads the same
plan into `CreationEngine`, which augments the generated `BehaviorGraph`/
`StateSchema` when (and only when) an approved plan is present — every
pre-V3 caller that never supplies one gets byte-for-byte the same output as
before this milestone.

## Strong typing

Every class in `lib/application_engineering/` uses real typed fields —
`List<T>`, enums (`GenericState`, `BindingKind`, `EffectKind`, ...), nested
value classes — never `Map<String, dynamic>` or `dynamic` in its public data
model. `BehaviorNode.config`/`BehaviorEdge` are the one exception, because
they are the *existing*, already-certified `BehaviorGraph` primitives AEE
compiles into, not a new AEE-owned type.

## WebWeaveX and Kaalka

Unchanged, canonical, not duplicated. AEE introduces no new extraction or
protection logic; `SecurityEngineering`'s findings are a *record* of the
existing M2-audited posture (Kaalka is the sole canonical protection
mechanism; CredentialVault exists but is unused; capability declarations are
requests, not authority), not a reimplementation of any of it.

## Known limitations

- `InteractionEngineering`, `AccessibilityEngineering`, and
  `PerformanceEngineering` are honesty audits, not new capabilities — they
  report what the existing renderer/runtime does and does not do
  (batch-selection/undo/redo/context-menu/grouping, custom Semantics,
  list virtualization: all NOT implemented) rather than building them.
- `SynchronizationEngineering` produces an intended future strategy only;
  Anything has no server component and this milestone adds none.
- `EngineeringRefinement` can only auto-fix issues it has an explicit fix
  for (dangling bindings, behavior inconsistencies referencing an
  undeclared event). Other critical issues (e.g. persistently low
  confidence) cause a fail-closed `PlanningFailed` rather than a
  fabricated fix.
- The compiled state machine only adds a generic `<entity>_status` variable
  and its in-flight/terminal writes; it does not yet model guarded
  transitions, parallel states, or cross-entity state machines — a
  deliberately conservative first compilation target.
