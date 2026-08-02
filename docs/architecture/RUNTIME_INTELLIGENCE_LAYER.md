# Runtime Intelligence Layer (RIL) — Vision Milestone V8

## Overview

`lib/runtime_intelligence/` gives the Runtime a way to observe how a
generated Experience is actually used, learn real structural patterns
from that usage, recommend real improvements, and plan (never execute)
automations — without becoming nondeterministic, without collecting
personal content, and without building a second AgentManager/
TaskManager/WorkflowManager next to the systems that already exist.

Every stage reuses something already built: Observation reuses the
Runtime's own real, already-broadcasting streams; Recommendation reuses
Design Review (SCARE, V6) and Evolution (V7) directly for review and
dedup; Automation reuses the existing `CapabilityRegistry` for validation
and the existing `ModificationEngine`'s vocabulary conceptually (though
this milestone never compiles a plan into an operation — see Known
Limitations); scheduling reuses the existing `clock`/`notifications`
capability ids rather than inventing a parallel taxonomy.

## Repository audit findings that shaped this design

Before writing any code, Runtime event flow, the Capability platform,
Universal Synthesis/persistence, `pubspec.yaml` dependencies, and the
current Kernel pipeline were audited:

- **Real, already-broadcasting hooks exist and needed no new plumbing**:
  `ExperienceRouter.events` (`Stream<NavigationEvent>`),
  `ExperienceQueryController.stateStream` (`Stream<QueryState>` per
  entity), and `ExperienceStateEngine.watch(stateId)` (`Stream<dynamic>`
  per state variable). `ObservationEngine` subscribes to these directly —
  no modification to the runtime it observes.
- **No hook exists for action dispatch or behavior execution**
  (`AnythingRuntime.dispatchEvent`/`BehaviorInterpreter.execute` are
  plain synchronous calls). `ObservationEngine` exposes
  `recordFailure`/`recordCapabilityUsage` as an additive, optional call
  a caller can make from those code paths — it does not require
  modifying `BehaviorInterpreter` itself this milestone.
- **The Capability platform has two separate abstractions**:
  `CapabilityRegistry`/`CapabilityDescriptor` (Kernel-level, used for
  resolution) and `PlatformCapability` (real `execute()` implementations).
  `ClockCapability` is genuinely real (`DateTime.now()`); `Notification
  Capability` only has an in-memory `FakeNotificationService` backing it
  — confirmed via grep: no `flutter_local_notifications`, `workmanager`,
  `cron`, `AlarmManager`, or `Timer.periodic`-based background execution
  exists anywhere in this codebase. This directly justifies why
  `AutomationExecutor`/`BackgroundCoordinator` are declarative-only (see
  below) rather than fabricating live OS scheduling.
- **No cross-Experience relationship mechanism exists**:
  `ExperiencePackage`/`ExperienceMetadataRecord` have no foreign key, no
  tags field, nothing referencing another Experience.
  `ExperienceRelationshipGraph`/`CollaborationGraph` are therefore
  honestly **inference-only**, built from independently-persisted,
  purely structural fingerprints (shared capability ids, shared entity
  field *type* names — never field values or record data), never a
  live/persisted link.
- **No new dependency was added or needed.** `sqflite`/
  `shared_preferences` (already used by `SqliteExperienceRepository`/
  `ActivityRepository`) fully cover `ObservationMemory`/`LearningMemory`/
  `AutomationMemory`'s persistence needs conceptually (this milestone
  keeps them in-memory, matching `ReviewMemory`/`EvolutionMemory`'s own
  Kernel-instance-lifetime scope).
- **The Kernel pipeline is unchanged since V7**, confirming Observation
  is inherently post-Runtime: an Experience must actually run before
  there is anything to observe, and Runtime execution happens outside
  `AnythingKernel.processIntent`'s synchronous flow. `RuntimeIntelligence
  Coordinator` is therefore a separate, application-facing entry point
  — mirroring `EvolutionCoordinator`/`ExperienceModificationCoordinator`
  exactly — never a fabricated Kernel pipeline stage.

## Pipeline (as actually implemented)

```
Real runtime session (ExperienceRouter / ExperienceQueryController /
ExperienceStateEngine, already running)
  │
  ▼
Observation      -> ObservationEngine subscribes to the real streams,
  │                  records purely structural ObservationRecords into
  │                  ObservationMemory. Never raw content.
  ▼
Learning         -> UsageGraph.fromRecords aggregates real usage
  │                  frequencies; PatternDetector finds real, structural
  │                  regularities (frequent pairs, frequent capabilities,
  │                  navigation loops, sequential workflows);
  │                  LearningEngine records versioned LearningRecords.
  ▼
Recommendation   -> RecommendationEngine turns patterns into typed
  │                  Recommendations, deduped against a real Evolution
  │                  (V7) EvolutionRoadmap so nothing is proposed twice;
  │                  RecommendationReview verifies the pattern is still
  │                  real before accepting.
  ▼
Automation Planning -> AutomationPlanner turns accepted automation/
  │                  workflow recommendations into a declarative
  │                  AutomationPlan (NOT executable code);
  │                  AutomationExecutor validates every step's
  │                  capability against the real CapabilityRegistry —
  │                  never invokes anything; BackgroundCoordinator
  │                  queues eligible plans into typed BackgroundJobs,
  │                  bounded by BackgroundBudget/BackgroundPolicy.
  ▼
Prediction       -> PredictionEngine ranks real UsageGraph frequencies
                     into "likely next action" and "automation
                     opportunity" forecasts.
```

`RuntimeIntelligenceEngine.run()` is the single, deterministic facade
over this whole pass (mirroring `DesignReviewEngine`/`EvolutionEngine`).
`RuntimeIntelligenceCoordinator` is the application-facing entry point
that owns the persistent memories and attaches `ObservationEngine` to
real runtime objects.

## Observation — privacy by construction, not by policy

`ObservationRecord` has no field capable of holding personal content: it
is built entirely from ids, counts, booleans, and enums (`category`,
`experienceId`, `screenId`, `entityId`, `capabilityId`, `succeeded`,
`count`, `timestamp`). Search terms, filter values, form field values,
navigation arguments, and query results are read by `ObservationEngine`
only to compute a **count** or a **category** — the underlying content is
never stored, never passed to a constructor, never reachable from
anywhere in this package. This is verified directly in
`test/runtime_intelligence/observation_engine_test.dart` by driving real
runtime objects with a deliberately "personal" value and asserting it
never appears in the resulting record.

## Learning and Pattern Detection

`UsageGraph.fromRecords` aggregates usage counts and screen-to-screen
co-occurrence, grouped by experience so one session's chain never bleeds
into another's. `PatternDetector` finds four real, structural kinds —
`frequentFeaturePair`, `frequentCapability`, `navigationLoop`, and
`sequentialWorkflow` (the literal "creates a task app → calendar →
reminder" shape from this milestone's own example, detected purely from
counted co-occurrence, never a domain template). `LearningEngine` is
deterministic and versioned: the same `UsageGraph` and threshold always
produce the same patterns, and every learning pass gets a new version
number in `LearningMemory` — nothing is ever overwritten.

## Recommendation — reuses SCARE and Evolution, never duplicates them

`RecommendationReview` mirrors `EvolutionReviewer`'s "verify the evidence
is still real" pattern exactly: a recommendation is accepted only if its
source pattern is still present in `LearningMemory`. `RecommendationEngine`
reuses Evolution's own `EvolutionRoadmap` directly for deduplication — a
recommendation whose description already matches a real Evolution
proposal is dropped, since Evolution already surfaced it. Nothing is ever
automatic: every recommendation is reviewed before it can become an
`AutomationPlan`.

## Automation and Scheduling — declarative only, honestly

Per this milestone's own directive ("NOT executable code. Declarative
plans" / "No isolates running unknown logic"), `AutomationExecutor` only
ever *validates* that a plan's steps name real, resolvable capabilities
(via the **existing** `CapabilityRegistry.resolve()`) — it never invokes
a capability, never schedules a timer, never runs any code.
`BackgroundCoordinator` produces a typed queue of `BackgroundJob`s
describing what *would* run and when — real OS-level background
execution does not exist in this codebase today (confirmed by the audit),
so this is honestly the typed plan a future milestone's real scheduler
would consume, never fabricated live execution. `NotificationPlanner`/
`ReminderPlanner` plan declarative notification/reminder descriptions the
same way, never calling the existing (fake-backed)
`NotificationCapability` themselves.

Scheduling supports `once`/`daily`/`weekly`/`monthly`/`conditional`
(`ScheduleFrequency`) with typed `AutomationConstraint`s
(`capabilityAvailability`/`networkAvailability`/`batteryNotLow`) — every
dimension typed, none of it wired to a real OS scheduler yet.

## Multi-Experience and Collaboration — inference-only, honestly

`ExperienceRelationshipGraph.infer()` compares purely structural
`ExperienceFingerprint`s (capability ids, entity field *type* names —
never data) across independently-persisted Experiences and surfaces a
real, explained relationship (`sharesCapability`/`sharesDataShape`) only
when a genuine overlap exists — never a keyword match, never a hardcoded
pair. `CollaborationGraph.fromRelationshipGraph()` is a real, filtered
VIEW of that same graph, restricted to pairs with 2+ independent
structural signals — reused, not a second competing inference pass.
`RuntimeIntelligenceCoordinator.buildRelationshipGraph()` builds this from
real, already-persisted `ExperiencePackage`s via the existing
`SqliteExperienceRepository` — read-only, real file I/O.

## Prediction

`PredictionEngine.predictNextAction()` ranks real outgoing `UsageGraph`
edges from the current screen by co-occurrence count — deterministic,
never fabricated for an unvisited screen. `predictAutomationOpportunities()`
surfaces sequential-workflow patterns above a confidence threshold as
real automation candidates.

## Kernel Integration

No new mandatory `AnythingKernel.processIntent` stage was added — the
audit confirmed (and this milestone's own aspirational pipeline diagram
implies) that Observation only makes sense once an Experience is actually
running, which happens after `processIntent` returns and outside its
synchronous flow. Integration is by **reuse**: `RuntimeIntelligenceEngine`
consumes a real, Kernel-produced `EvolutionRoadmap` directly (see
`test/runtime_intelligence/kernel_evolution_integration_test.dart`, which
runs a real `AnythingKernel.processIntent()` and feeds its output in) and
`RuntimeIntelligenceCoordinator` consumes the real `CapabilityRegistry`
for automation validation — never a fabricated pipeline stage.

## WebWeaveX and Kaalka

Unchanged, canonical, not duplicated. RIL introduces no extraction,
crawling, search, or cryptographic logic of any kind.

## Strong typing

Every class in `lib/runtime_intelligence/` uses real typed fields — enums,
`List<T>`, nested value classes, `RilNode` reused across every graph
(`InteractionGraph`/`UsageGraph`/`CollaborationGraph`/
`ExperienceRelationshipGraph`, mirroring `DependencyGraph` (V4) /
`EvolutionGraph` (V7)'s node/edge shape exactly) — never `Map<String,
dynamic>` or `dynamic` in its public data model.

## Known limitations

- `ObservationEngine` is a real, tested, attachable component but
  `ExperienceHostScreen` does not yet auto-attach it in production — a
  deliberate scope decision to avoid an invasive, higher-risk change to
  the most heavily-tested file in the runtime this milestone, matching
  the same "real capability, not yet wired into that pipeline" pattern
  already established for `ReviewMemory` (V6) and `EvolutionCoordinator`
  (V7).
- `AutomationExecutor`/`BackgroundCoordinator` are 100% declarative —
  no `AutomationPlan` step is ever actually invoked, and no real OS-level
  timer, alarm, or notification is ever scheduled. This is a deliberate
  reading of this milestone's own "NOT executable code" directive, not an
  oversight.
- `ExperienceRelationshipGraph`/`CollaborationGraph` are inferred at
  query time from independently-persisted per-Experience data; there is
  no persisted, live cross-Experience link anywhere in the schema.
- `ObservationMemory`/`LearningMemory`/`AutomationMemory` are scoped to
  whatever owns the `RuntimeIntelligenceCoordinator` instance's lifetime
  (in-memory, like `ReviewMemory`/`EvolutionMemory`) — not yet persisted
  across process restarts.
- Action-dispatch and behavior-execution level observation
  (`AnythingRuntime.dispatchEvent`/`BehaviorInterpreter.execute`) has no
  live hook yet; `ObservationEngine.recordFailure`/`recordCapabilityUsage`
  exist for a caller to invoke from those code paths, but neither is
  wired into `BehaviorInterpreter` itself this milestone.
