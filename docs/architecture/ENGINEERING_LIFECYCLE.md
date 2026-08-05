# Engineering Lifecycle Coordinator — Implementation Specification IS-R30

## REALITY

R25-R29 built a complete, real, deterministic engineering pipeline —
`SolutionEvolutionEngine` (R29, decides what should happen next),
`IncrementalCompilerSynthesizer` (R24, executes a scoped, incremental
recompile), `SolutionExecutionOrchestrator` (R25-R27, executes a full,
multi-generator recompile), `ArtifactIntelligenceEngine` (R28, judges
whether a completed execution is deployment-ready) — but two real pieces
had ZERO production callers before this milestone, confirmed by grep:

- `SolutionEvolutionEngine(` appeared only in its own defining file
  (`lib/solution_evolution/solution_evolution.dart`) and in
  `test/r29_solution_evolution_test.dart`.
- `IncrementalCompilerSynthesizer.buildEvolutionPlan(` appeared only in its
  own defining file (`lib/engineering_intelligence/incremental_compiler_synthesis.dart`)
  and in `test/r24_engineering_intelligence_test.dart`.

Nothing tied the whole pipeline together into one real, callable
production entry point. `EngineeringLifecycleCoordinator`
(`lib/app/engineering_lifecycle_coordinator.dart`) is that missing
composition — a pure orchestration layer over already-real, already-tested
subsystems. It introduces zero new diffing, execution, artifact-analysis,
or persistence/rollback logic.

## Flow

```
AnythingKernel.processIntent()        (unchanged — the ONE reasoning call)
  -> SolutionEvolutionEngine.planRegeneration()   (R29, unchanged)
  -> IncrementalCompilerSynthesizer.synthesize()  (R24, unchanged)
     OR SolutionExecutionOrchestrator.execute()   (R25-R27, unchanged)
  -> ArtifactIntelligenceEngine.analyze()         (R28, unchanged — FULL path only)
  -> SolutionEvolutionEngine.decideDeployment()   (R29, unchanged — FULL path only)
  -> ExperienceModificationCoordinator.applyEvolutionPlan()  (R6, unchanged)
     — called only on `allowed`, never on `blocked`.
```

## Commit mechanism

`IncrementalCompilerSynthesizer.buildEvolutionPlan()` (R24) already builds a
real `EvolutionDiffPlan` from an `IncrementalSynthesisResult`, via the
existing `ExperienceDiffer`/`EvolutionDiffPlanBuilder` (R4) — reused
unmodified for the incremental path. No analogous helper existed for the
FULL path (an `OrchestrationReport`'s Runtime Experience package), so this
milestone adds one small, coordinator-local method
(`_buildEvolutionPlanFromReport`) that mirrors `buildEvolutionPlan()`'s
exact body, sourcing the candidate package from
`OrchestrationReport.outcomeFor(runtimeExperience)?.package` instead — never
a change to `IncrementalCompilerSynthesizer`/`SolutionExecutionOrchestrator`
themselves.

## Rollback flow — Design A, chosen deliberately

`ExperienceModificationCoordinator.rollback()`'s real contract (confirmed by
reading it) is "restore an already-persisted PRIOR package" — it has no
concept of "prevent a persist that hasn't happened yet."
`applyEvolutionPlan()`'s own validate-then-persist is atomic. Since this
coordinator ALWAYS runs the real deployment gate (`ArtifactIntelligenceEngine`
+ `decideDeployment()` for the full path; a real, honest equivalent check for
the incremental path — see below) BEFORE ever calling `applyEvolutionPlan()`,
a `blocked` decision means `applyEvolutionPlan()` is simply never invoked —
the prior package remains authoritative, untouched.

**`LifecycleResult.rollbackPerformed` is therefore always `false` from this
coordinator's own internal `evolveExperience()` flow** — stated honestly
rather than fabricating a scenario to force `true` (mirrors R29's own
identical, honestly-reported "RollbackPerformed not reachable from this
engine's own flow" finding). `rollback()` itself remains real, tested, and
reachable: a caller holding a returned `LifecycleResult.previousPackage`
after a `deployed` outcome can separately invoke
`ExperienceModificationCoordinator.rollback()` later (e.g. a user tapping
"Undo" — the exact UI-level pattern R7 already established for
`applyEvolutionPlan()`'s own `previousPackage`) — proven directly in
`test/r30_engineering_lifecycle_test.dart`'s "Rollback flow" group.

## Deployment flow — the FULL-vs-INCREMENTAL asymmetry, stated honestly

`ArtifactIntelligenceEngine.analyze()` is built for a COMPLETE
`OrchestrationReport` where every applicable target was genuinely attempted
this cycle — its cross-target dependency check (`_deploymentBlockers`) reads
`report.outcomeFor(dep)` for every real structural dependency
`ExecutionTargetPlan.dependencies` names. For an INCREMENTAL
(Runtime-Experience-only) run, `runtimeExperience`'s own
`ExecutionTargetPlan.dependencies` may still legitimately name
`backendService`/`restApi` (a real, app-level fact — the solution HAS a
backend — independent of whether THIS diff touched it). Constructing a
synthetic `OrchestrationReport` with only the one real incremental stage
would either (a) omit those dependency targets entirely, making
`_deploymentBlockers` treat them as "missing" and incorrectly block a
perfectly good incremental change, or (b) require fabricating a "succeeded"
status for a dependency that was NOT actually re-verified this cycle — both
dishonest.

The incremental path therefore uses its own simpler, real, honest deployment
gate instead: `IncrementalSynthesisResult.succeeded` (package produced, zero
compiler diagnostic errors) AND a real `ExperiencePackageValidator.validate()`
re-check (the SAME real check `SolutionExecutionOrchestrator
._runRuntimeExperienceStage` already performs internally for a full run) —
never routed through `ArtifactIntelligenceEngine`/`decideDeployment()`, which
are reserved for the FULL path where they have a genuinely complete report
to analyze. `LifecycleResult.artifactIntelligenceReport` is therefore always
`null` for an incremental-path result — named honestly, not silently
omitted.

## Real, honestly-reachable proof scenarios

`test/r30_engineering_lifecycle_test.dart` proves, end-to-end, through the
real `AnythingKernel`/real sqlite storage/real generators (never a
hand-built fake package):

1. **No engineering memory** — `noEngineeringMemory`, a real, honest early
   exit rather than a fabricated empty-graph fallback.
2. **No-op** — an unchanged app produces `noChangeDetected`; zero execution
   primitives invoked; the prior package is confirmed untouched.
3. **Incremental deploy** — a real, backend-free frontend-only entity
   addition deploys via `IncrementalCompilerSynthesizer`; the real,
   newly-persisted package is confirmed via repository read-back.
4. **Incremental blocked** — a real, naturally-reachable failure: removing
   an entity is correctly detected as the sole affected entity (the
   unchanged `trip` entity never appears in the diff at all), but
   `IncrementalCompilerSynthesizer` scopes the model down to an id that no
   longer exists — a real, honest limitation named here: incremental
   synthesis has no real handling today for "the affected entity was
   deleted," only for "the affected entity changed." The candidate is
   correctly never persisted.
5. **Full deploy** — a real backend-affecting entity addition (requesting
   the real `http` capability, which the real `SecurityPlanner` turns into
   `NetworkMode.restrictedHttps` → `requiresBackend: true`) deploys via the
   full `SolutionExecutionOrchestrator`, producing a real, complete
   `OrchestrationReport` + `ArtifactIntelligenceReport` with
   `deploymentReady: true`.
6. **Full-path deployment-gate composition** — proven correct on a real,
   reachable failure (`backendPlan` omitted for a backend-needed strategy,
   the exact real precondition `_runBackendServiceStage` itself already
   guards) rather than a fabricated `ArtifactIntelligenceReport`. A genuine
   full-path-BLOCKED outcome reachable from `evolveExperience()`'s own
   top-level call is not naturally reachable today, since a correctly-wired
   real Kernel run always populates a real `BackendEngineeringPlan`
   whenever `executionStrategy` marks `backendService` applicable
   (`ExecutionPlanReady`'s own doc comment: "Null only for outcomes that
   never reach this point — there are none on the production path") —
   named honestly rather than forced.
7. **Rollback** — a separate, later, caller-invoked `rollback()` call
   genuinely restores the prior package.

## World Model / Engineering Memory

Both remain completely unchanged (confirmed via `git diff --stat`) — this
coordinator only READS `EngineeringMemoryRepository.load()` (the existing,
real "before" state source) and writes through the existing
`ExperienceModificationCoordinator`/`WorldModelCoordinator` paths those
already own. No new persistence concept was introduced.

## Known limitations

- `RollbackPerformed:true` is not reachable from this coordinator's own
  `evolveExperience()` call (Design A) — real, tested, and reachable only
  via a separate, later caller decision.
- A full-path deployment-BLOCKED outcome is not naturally reachable from
  `evolveExperience()`'s own top-level call with a correctly-wired real
  Kernel — proven correct at the underlying composition level instead.
- Incremental synthesis has no real handling for entity deletion (scopes to
  an empty model, producing an honest `blocked` result rather than a
  silent no-op or crash) — a real, structural limitation of
  `IncrementalCompilerSynthesizer` (R24) this milestone surfaced but does
  not fix (fixing it would mean modifying R24's own unchanged subsystem,
  out of this milestone's scope).

## Recommendation for R31

Wire `EngineeringLifecycleCoordinator` into a real UI-level caller (mirroring
R7's own `ExperienceHostScreen` wiring for `applyEvolutionPlan()`/
`rollback()`) so a real user-initiated modification can flow through the
full closed-loop pipeline this milestone finally connects end-to-end.
Separately, consider whether `IncrementalCompilerSynthesizer`'s entity-
deletion gap (finding 4 above) is worth a small, dedicated fix in a future
milestone scoped to R24's own subsystem.
