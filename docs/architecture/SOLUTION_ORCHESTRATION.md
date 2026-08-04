# Universal Solution Orchestrator — Implementation Specification IS-R25

## Overview

R25 asked for ONE `SolutionExecutionOrchestrator` that coordinates
existing generators to build complete software systems, represented as an
Orchestration Model (Execution Stage, Dependencies, Parallel Groups,
Blocking Tasks, Validation Gates, Retry Strategy, Rollback Strategy,
Completion Criteria, Artifact Dependencies).

## REALITY: R18's ExecutionStrategy already covers most of this; nothing ever executes it

`SolutionExecutionPlanner` (R18, `lib/execution_planning/`) already
produces a real, typed `ExecutionStrategy` — for each of R18's 12
requested execution targets: `classification`
(`notApplicable`/`applicableNoGenerator`/`applicableWithGenerator`),
`reason`, `priority`, `dependencies` (`List<ExecutionTargetKind>`),
`executionOrder` (real topological position), `requiredGenerators` (real
`GeneratorMetadata.id` values), `validationRequirements`,
`buildRequirements`, `deploymentRequirements`. That is roughly 8 of R25's
9 requested Orchestration Model fields, already real, already tested
(R18) — genuinely missing: Parallel Groups as a first-class concept,
Retry Strategy, Rollback Strategy, and Completion Criteria as an
*executed, checked* outcome rather than a named requirement.

`SolutionExecutionPlanner.plan()`'s own doc comment states it plainly:
"this planner only decides WHAT should be executed and WHETHER a real
generator exists for it... a caller invokes [the compiler] using this
plan's `requiredGenerators`/`actionableTargets`." **Nothing in this
codebase, before this specification, ever walked
`ExecutionStrategy.actionableTargets` and actually ran a stage.** That is
the one, real, honest, novel contribution this specification makes.

Of R18's 12 execution targets, only Runtime Experience ever reaches
`applicableWithGenerator` (confirmed again by re-reading
`SolutionExecutionPlanner`: only `RuntimeExperienceGenerator`,
`reference.runtime-experience`, R13, exists as a real `Generator`). Real,
concurrent, multi-generator parallel execution therefore has **zero
real-world instance to prove today** — the orchestrator's scheduling
algorithm is built and proven correct on synthetic, hand-constructed
multi-target `ExecutionStrategy` fixtures instead
(`test/r25_solution_orchestrator_test.dart`), mirroring exactly how R11
proved `BuildGraphOrderer`'s Kahn's-algorithm topological order on
constructed `UniversalBuildGraph`s even though production graphs are
simpler.

## Implementation

`lib/solution_orchestration/` (3 files):

- **`execution_ordering.dart`** — `ExecutionTargetOrderer`, a real,
  level-partitioning variant of Kahn's algorithm over
  `ExecutionStrategy.applicableTargets`/`ExecutionTargetPlan.dependencies`.
  A genuinely new, small algorithm over a different node type
  (`ExecutionTargetKind`) than `BuildGraphOrderer`'s
  (`UniversalBuildGraph`), but it mirrors that algorithm's exact honesty
  precedent: `ExecutionLevels.isComplete` is honestly `false`, with a
  real partial order, when a dependency cycle prevents a full ordering —
  never silently papered over.
- **`orchestration_result.dart`** — `StageStatus`
  (`succeeded`/`failed`/`skippedNotApplicable`/`skippedNoGenerator`),
  `StageOutcome` (real per-target attempts/package/errors/latency;
  `completionCriteriaMet` requires the underlying pipeline to have
  produced a package, its diagnostics to carry no error, AND the package
  to pass the real, unmodified `ExperiencePackageValidator` — never a
  rubber-stamped boolean), `OrchestrationReport` (every field a plain,
  traceable read of the per-stage records, never a separately-computed
  summary that could drift).
- **`solution_execution_orchestrator.dart`** — `SolutionExecutionOrchestrator.execute()`
  walks the real level order, and for every `applicableWithGenerator`
  stage dispatches through the real, existing `runCompilerPipeline` (R19)
  or `IncrementalCompilerSynthesizer` (R24) — choice governed by whether
  a caller supplied real, non-empty `AffectedEntities` — validates
  through the real, unmodified `ExperiencePackageValidator`, and records
  a real `StageOutcome`. Every `notApplicable`/`applicableNoGenerator`
  target is recorded too, with zero attempts and its real, specific
  `ExecutionTargetPlan.reason` — every one of R18's 12 targets appears
  exactly once in a real `OrchestrationReport`, never silently dropped.

## Parallel Execution — stated precisely, not overclaimed

Stages within one level are dispatched via `Future.wait`, a real Dart
concurrency primitive. But Dart runs on a single isolate, and both real
execution primitives (`runCompilerPipeline`/`IncrementalCompilerSynthesizer`)
are synchronous, CPU-bound, in-memory computations with no internal
`await`. `Future.wait` over purely synchronous work does **not** achieve
genuine multi-core speedup — what it does provide, correctly, is
dependency-safe *ordering* (nothing in a later level starts before every
stage in every earlier level has completed) and a concurrency-ready shape
for a future generator that performs genuine async I/O. True CPU
parallelism would require Dart Isolates — out of scope here, named for a
future milestone. The level-partitioning *algorithm* itself is real and
proven correct on synthetic 2+-target fixtures
(`test/r25_solution_orchestrator_test.dart`); real production strategies
today only ever produce one actionable level with one stage.

## Retry — stated precisely, not overclaimed

`runCompilerPipeline`/`IncrementalCompilerSynthesizer` are pure,
deterministic functions of their input (proven since R13/R19/R24's own
determinism tests) with no I/O of their own — a retry of an identical
input can only ever reproduce an identical outcome. Retry exists as real,
tested, bounded infrastructure (`maxAttempts`, default 1 — no retry
unless a caller opts in; never an infinite loop; a real, structured
failure once exhausted, proven via a real, deterministically-failing
`AffectedEntities`-matching-nothing scenario retried exactly N times) for
a stage type with a genuine transient-failure surface — it is honestly
*not* expected to change today's deterministic pipeline's result, and
this is stated in code rather than fabricating retry/backoff
sophistication with no real failure signal behind it.

## Rollback — reused, never reimplemented

`ExperienceModificationCoordinator.rollback()` (R6) is the real,
existing, deterministic snapshot-based rollback mechanism. The
orchestrator lives beneath `lib/app/`, and
`ExperienceModificationCoordinator` lives inside it — the established
layering direction (`lib/app/` composes lower-level `lib/` subsystems,
never the reverse; every prior coordinator, e.g.
`SoftwareCognitionCoordinator`, never imports `ExperienceCreationCoordinator`).
The orchestrator therefore never calls `rollback()` itself — it reports
failure via `OrchestrationReport.failedStages`, and a caller decides to
invoke the real, unmodified `rollback()`. Proven end-to-end in
`test/r25_solution_orchestrator_test.dart`'s Rollback group: a real
orchestration failure, followed by a real `rollback()` call, restores the
real prior package in the real repository.

## Completion Criteria

A stage is `StageStatus.succeeded` (and `completionCriteriaMet == true`)
only when all three hold: the pipeline produced a non-null package, the
compiler's own `GenerationResult.diagnostics` carry no `error`-severity
entry, AND the package passes the real, unmodified
`ExperiencePackageValidator`. Any one of these failing is a real,
reported failure — never a partial success glossed over.

## World Model Impact

**None.** `ExecutionStrategy` (R18) and `OrchestrationReport` are both
derived, transient data with no new node/edge information beyond what
`ingestSolutionArchitecture`/`ingestCanonicalImplementation` (R17/R9)
already contribute to the World Graph — a new bridge would duplicate,
not enrich. `lib/world_model/` is completely unmodified by this
specification (confirmed via `git diff --stat`).

## Engineering Memory Impact

**None.** `ExecutionStrategy` is cheap and deterministically re-derivable
from `SemanticSolutionArchitecture`, itself already persisted via
`ArchitectureCandidate`/`BackendEngineeringPlan` (`EngineeringMemoryRepository`,
R5/R8/R9). An `OrchestrationReport` is a real-time execution log for one
request, not durable engineering knowledge — persisting it would have no
concrete reuse case today, matching R10-R12/R14/R15's own repeated,
correct "no real reuse case, declined" precedent.
`lib/storage/engineering_memory_repository.dart` is completely
unmodified by this specification.

## Known Limitations

1. Real multi-generator parallel execution is unproven in production —
   only one real `Generator` exists (R13). The scheduling algorithm is
   correct and tested on synthetic data; it has no real multi-stage
   instance to run until a second real generator exists (R10-R12 each
   explicitly declined building one).
2. `Future.wait`-based concurrency does not deliver genuine CPU
   parallelism under Dart's single-isolate model for the current
   synchronous, CPU-bound generator primitives — a real, honest
   limitation, not a claimed capability.
3. Retry is real infrastructure with no real failure mode to meaningfully
   recover today, since both dispatch primitives are pure and
   deterministic.
4. The orchestrator is not wired into `AnythingKernel`/`ExperienceCreationCoordinator` —
   it is real, tested, standalone machinery, exactly the same honest,
   undone-but-real state the R9-R12 compiler chain was in before R19
   connected it. `useCompilerPipeline` remains `false` by default; this
   specification does not change that decision.

## Recommendation for R26

1. A second real `Generator` (e.g. a real Backend Service generator,
   matching `applicableNoGenerator`'s `backendService`/`restApi` targets)
   would give the level-partitioning/parallel-dispatch machinery its
   first genuine multi-stage production instance.
2. Decide whether/how a real caller (e.g. an opt-in modification flow)
   should invoke `SolutionExecutionOrchestrator` in production, following
   R19's exact opt-in precedent (`useCompilerPipeline`-style flag,
   default off, explicit evidence-backed decision before ever defaulting
   on).
3. If genuine CPU parallelism across generators becomes valuable, Dart
   Isolates are the real mechanism — a dedicated, scoped investigation,
   not a silent addition to this orchestrator.
