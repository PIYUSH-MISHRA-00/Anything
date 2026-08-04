# Artifact Intelligence Engine (Implementation Specification IS-R28)

## Reality

R27 completed the third real production `Generator` (REST API). All
three real generators (`RuntimeExperienceGenerator`/`BackendServiceGenerator`/
`RestApiGenerator`) run through `SolutionExecutionOrchestrator`
(R25-R27), which already produces a real, structured
`OrchestrationReport` after a run.

Two real, pre-existing facts grounded this specification:

1. **`OrchestrationReport.succeeded` is real but COARSE.** Its exact
   definition (`lib/solution_orchestration/orchestration_result.dart`):
   `levelOrderingComplete && stages.every((s) => s.status != StageStatus.failed)`.
   It does not check that a *succeeded* stage's real, structural
   dependencies (`ExecutionTargetPlan.dependencies`, R18) were themselves
   fulfilled — a dependency that was merely `skippedNoGenerator`/
   `skippedNotApplicable` (never `failed`) lets `succeeded` report `true`
   even though a real prerequisite never produced anything.
2. **`GenerationResult.dependencyManifest`/`DependencyReference`**
   (`lib/generator_framework/generation_result.dart`, R10) is a real,
   pre-existing "artifact dependency" concept — confirmed by grep, never
   populated by any of the 3 real generators. Investigated and **not**
   used as this specification's integration point: it models per-artifact
   ecosystem-package dependencies (e.g. `http-client >=1.0.0`), a
   different real concern than the EXECUTION dependencies
   `ExecutionTargetPlan.dependencies` already encodes. Populating it with
   invented package names for generators that emit no real ecosystem
   signal would fabricate data.

## Proposed / Rationale

Build a real, pure, POST-hoc analysis layer — `ArtifactIntelligenceEngine`
(`lib/artifact_intelligence/artifact_intelligence.dart`) — over an
ALREADY-COMPLETED `OrchestrationReport` plus the `ExecutionStrategy` that
produced it. It never re-plans, never re-executes, never touches
`SolutionExecutionOrchestrator.execute()`'s own tested logic (confirmed
unmodified via `git diff --stat`). This matches R28's own explicit
design: "Solution Orchestrator: Consume Artifact Intelligence only for
execution validation" — a caller runs `execute()`, then separately
invokes `ArtifactIntelligenceEngine().analyze(report, strategy)`.

Artifact provenance (which real `GeneratorMetadata.id` produced a
stage's output) is read directly off the ALREADY-REAL
`ExecutionStrategy.forTarget(target).requiredGenerators` (R18) — no new
field was threaded through `StageOutcome`.

## Implementation

`lib/artifact_intelligence/artifact_intelligence.dart` (one file):

- `ArtifactKnowledge` — per-target real, derived view: `target`,
  `status`, `producedBy` (real `GeneratorMetadata.id`s, empty for
  non-generated targets), `dependsOn`/`consumedBy` (real dependency
  edges, both directions), `completionCriteriaMet`/`errors` (a direct,
  unmodified read of `StageOutcome`'s own fields).
- `CompatibilityCheck` — one real, named cross-artifact invariant and its
  result.
- `ArtifactIntelligenceReport` — `knowledge` (one per stage),
  `compatibilityChecks`, `deploymentReady`, `deploymentBlockers`.
- `ArtifactIntelligenceEngine.analyze(OrchestrationReport, ExecutionStrategy)`
  — the one, pure, deterministic entry point.

## Dependency Analysis

`dependsOn`/`consumedBy` are a direct, real join over
`ExecutionTargetPlan.dependencies` — never re-derived, never fabricated.
For the real 3-generator chain: Backend Service has no dependencies and
is consumed by REST API; REST API depends on Backend Service and is
consumed by Runtime Experience (when applicable).

## Validation

`ArtifactKnowledge.completionCriteriaMet`/`.errors` are a direct,
unmodified read of `StageOutcome`'s own already-real completion-criteria
fields (R25) — Artifact Intelligence never re-implements validation, only
aggregates and reports it at the artifact-set level.

## Compatibility

**The one real, checkable cross-artifact invariant among the 3 real
generators**: `BackendServiceGenerator` and `RestApiGenerator` both
serialize `BackendEngineeringPlan.authentication` under an identical
`'authentication'` JSON key (`{requiresCredentials, providerIndependent}`
— confirmed by reading `backend_engineering_serialization.dart` and
`rest_api_generator.dart`). For one real orchestration run both artifacts
derive from the SAME `BackendEngineeringPlan`, so they must agree — a
real, deterministic JSON-equality check, proven both for the passing case
(one real run) and a deliberately-constructed failing case (two different
plans).

No other real, derivable cross-artifact invariant was found. Runtime
Experience's manifest carries no backend-derived signal to cross-check —
`RuntimeExperienceGenerator` hardcodes `networkMode: NetworkMode.none`
regardless of backend presence (confirmed by reading it) — comparing it
against backend presence would be comparing against a constant, not real
signal. Honestly not checked.

## Deployment Readiness

`ArtifactIntelligenceReport.deploymentReady` is real and RICHER than
`OrchestrationReport.succeeded`: it additionally requires every
`succeeded` stage's real, structural dependencies to have themselves
`succeeded` (never merely skipped or failed), and every compatibility
check to pass.

**The mandatory proof this specification exists for**
(`test/r28_artifact_intelligence_test.dart`, "Deployment readiness"
group): a synthetic `ExecutionStrategy` where REST API structurally
depends on Backend Service, but Backend Service's own stage outcome is
`skippedNoGenerator` (a real, non-failure classification) while REST
API's stage still reports `succeeded`. `OrchestrationReport.succeeded`
reports `true` (no stage literally failed) — but
`ArtifactIntelligenceReport.deploymentReady` correctly reports `false`,
with a real, named blocker identifying exactly which dependency was
never fulfilled. A second test confirms the ordinary case (a real
dependency `failed`) is caught by both signals, as expected.

This synthetic construction (not a real production `ExecutionStrategy`
today) mirrors R25's own precedent of proving `ExecutionTargetOrderer`'s
correctness on constructed multi-target fixtures — the algorithm is real
and proven, even though today's real 3-generator strategy always
succeeds or fails as a coherent whole.

## World Model Impact

**None.** `ArtifactIntelligenceReport` is cheap, deterministic,
recomputable analysis of an already-completed, non-persisted
`OrchestrationReport` — it has no durable identity independent of that
run. `lib/world_model/` is completely unmodified (confirmed via `git
diff --stat`), matching R25's own identical "no real reuse case" decision
for `ExecutionStrategy`/`OrchestrationReport`.

## Engineering Memory Impact

**None**, for the same reason — `lib/storage/engineering_memory_repository.dart`
is completely unmodified.

## Known Limitations

1. Only the one real, checkable cross-artifact invariant (authentication
   consistency between Backend Service and REST API) is modeled — no
   other real signal exists among the 3 real generators today.
2. "Future Flutter/GraphQL/Deployment/Documentation" artifact
   understanding is explicitly out of scope — R28's own "SEMANTIC
   ANALYSIS" section names these as FUTURE; no such generator exists yet
   to analyze.
3. `GenerationResult.dependencyManifest` (R10) remains orphaned — a real,
   honest, pre-existing gap, not this specification's integration point
   (see Reality above).
4. Deployment readiness's dependency-fulfillment check is proven
   correct on synthetic fixtures; today's real 3-generator production
   strategy has no scenario where it would actually diverge from
   `OrchestrationReport.succeeded`'s own coarser signal (both real
   generators either both run to completion or the whole run fails
   together) — the richer signal is real, tested, and available for when
   that changes (e.g. a future generator with a genuine partial-failure
   mode).

## Recommendation for R29

1. If a 4th real generator is ever built with a genuine, independent
   failure mode, Artifact Intelligence's deployment-readiness check gets
   its first real-world divergence from `OrchestrationReport.succeeded`
   — worth re-verifying against a real (not synthetic) scenario at that
   point.
2. If `GenerationResult.dependencyManifest` ever gets a real generator
   that names genuine ecosystem-package dependencies, extend
   `ArtifactKnowledge` to surface it — do not populate it speculatively
   before that real need exists.
