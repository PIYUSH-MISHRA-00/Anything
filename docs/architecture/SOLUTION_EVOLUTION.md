# Solution Evolution — Implementation Specification IS-R29

## Reality

Every piece of real logic "what should happen next after generation
completes" needs already existed before this specification, individually,
untied together:

| Concern | Real, existing mechanism |
|---|---|
| Structural diffing | `RequirementGraphDiffer` (R3), `ArchitectureDiffer` (R4) |
| Diff → affected entities | `AffectedEntityAnalyzer` (R24) |
| Historical "before" state | `EngineeringMemoryRepository.load()` (R5/R8/R9) |
| Incremental execution | `IncrementalCompilerSynthesizer` (R24) |
| Full execution | `SolutionExecutionOrchestrator.execute()` (R25-R27) |
| Deployment readiness | `ArtifactIntelligenceEngine.analyze()` (R28) |

Nothing combined these into a "no-op / validate / regenerate-which-targets /
incremental-vs-full / is-this-deployable" decision. `SolutionEvolutionEngine`
(`lib/solution_evolution/solution_evolution.dart`) is that missing
composition layer — a pure, deterministic decision function, never a new
diff algorithm, executor, or validator.

### The one real structural asymmetry

`IncrementalCompilerSynthesizer.synthesize()` calls `runCompilerPipeline`
(`lib/compiler_integration/compiler_pipeline_runner.dart`, R19), which
remains hardcoded to `RuntimeExperienceGenerator` — confirmed unchanged
through R26/R27's own generalization of the sibling `runGeneratorPipeline`.
**There is no incremental path anywhere for Backend Service or REST API.**
Any real change reaching either of those two targets can only ever be
resolved by a full `SolutionExecutionOrchestrator.execute()` re-run (or a
direct `runGeneratorPipeline` call against `BackendServiceGenerator`/
`RestApiGenerator`).

`SolutionEvolutionEngine.planRegeneration()` reports this honestly via
`CompilationMode`: `.incremental` is only ever offered when Runtime
Experience is the *sole* regeneration target; the presence of
`regenerateBackend`/`regenerateRestApi` in the recommended action set always
forces `.full`. This is proven directly by scenario 2 in
`test/r29_solution_evolution_test.dart`.

### Why target applicability is read from `ExecutionStrategy`, not re-derived per entity

`CanonicalImplementationPlanner._planRepositories()`/`._planControllers()`
(R9) build `ImplementationRepository`/`ImplementationController` from
`BackendEngineeringPlan.database`/`.api` **unconditionally** — independent of
whether the solution actually needs a backend (`BackendEngineeringPlan.api`
is derived unconditionally from `InteractionDecision`'s CRUD flags, per
R18's own documented finding). This means "does this affected entity have a
repository/controller in `CanonicalImplementationModel`" is **not** a
reliable per-entity signal for "does Backend Service/REST API need to
regenerate" — a fully-offline app can still carry non-empty repositories/
controllers that nothing will ever execute.

`requiresBackend`/`hasApi` are real, whole-*solution*-level decisions
`SolutionExecutionPlanner` (R18) already makes correctly. `planRegeneration`
therefore takes the caller's already-computed `ExecutionStrategy` for the
"after" state and reads `ExecutionTargetPlan.classification` directly —
reusing R18's own decision, never re-deriving a finer-grained per-entity
version the underlying data doesn't actually support.

## Design

```dart
class SolutionEvolutionEngine {
  RegenerationPlan planRegeneration({
    required RequirementGraph beforeRequirements,
    required RequirementGraph afterRequirements,
    required ArchitectureCandidate beforeArchitecture,
    required ArchitectureCandidate afterArchitecture,
    required ExecutionStrategy afterExecutionStrategy,
  });

  DeploymentDecision decideDeployment(ArtifactIntelligenceReport report);
}
```

Both methods are **pure** — synchronous, no `Future`, no I/O, no call to
`SolutionExecutionOrchestrator.execute()`, `IncrementalCompilerSynthesizer
.synthesize()`, `runCompilerPipeline`/`runGeneratorPipeline`, or any
generator. This mirrors `SolutionExecutionPlanner`'s own R18 "decide, never
invoke" precedent exactly, applied one layer up: `SolutionExecutionPlanner`
decides WHICH targets are applicable; `SolutionEvolutionEngine` decides
WHETHER regeneration is warranted at all, and if so, WHICH of the already-
applicable targets are affected by a specific change and HOW (incremental vs
full) to regenerate them.

Per this specification's own explicit rule — "Solution Orchestrator: Remain
unchanged... Consume Evolution decisions only when invoked externally. Never
embed feedback logic inside `execute()`" — `SolutionExecutionOrchestrator
.execute()` was not touched (confirmed via `git diff --stat`). A caller
consults `SolutionEvolutionEngine` first, then separately decides whether to
invoke `execute()` or `IncrementalCompilerSynthesizer` based on the returned
`RegenerationPlan` — this engine never wires itself into that call graph.

### Action vocabulary

| `EvolutionAction` | Real meaning |
|---|---|
| `noAction` | Both `RequirementGraphDiff` and `ArchitectureDiff` are empty. |
| `validate` | Always paired with at least one real `regenerate*` action — never present alone as a substitute for regeneration, never present when nothing changed. |
| `regenerateRuntime` | Runtime Experience is `applicableWithGenerator` in `afterExecutionStrategy`. |
| `regenerateBackend` | Backend Service is `applicableWithGenerator`. |
| `regenerateRestApi` | REST API is `applicableWithGenerator`. |

A real, honest edge case: a diff can be non-empty (e.g. a `RequirementGraph`
node changed) while *no* target in `afterExecutionStrategy` is
`applicableWithGenerator` (an architecture with neither frontend entities
nor backend need). `planRegeneration` reports `{EvolutionAction.validate}`
with `CompilationMode.none` in this case — never a fabricated `regenerate*`
action for a target nothing can act on, and `validate` still names the real
fact that something structurally changed and is worth a look even with
nothing to regenerate. Proven directly by a dedicated test.

### Deployment decisions

`decideDeployment()` is a thin, honest restatement of
`ArtifactIntelligenceReport.deploymentReady` (R28) as one of this engine's
own named action types — `ArtifactIntelligenceEngine` already computes the
real, richer readiness signal (including the real dependency-fulfilment
check `OrchestrationReport.succeeded` alone does not make); this method adds
no new readiness logic of its own.

## World Model / Engineering Memory

Both **declined**, matching this project's own repeated, correct precedent
(R10-R12/R14/R15/R24/R28's "cheap to recompute, no real reuse case,
declined" pattern): a `RegenerationPlan`/`DeploymentDecision` is a
deterministic function of already-persisted `EngineeringMemoryRecord` data
(`RequirementGraph`/`ArchitectureCandidate`, R5/R8/R9) plus a fresh request's
equivalent state — recomputing it is cheap and always current. Persisting a
decision risks it going stale relative to the real state it was computed
from, with no real, concrete case in this codebase today that needs a
historical record of past decisions rather than the ability to recompute the
current one.

## Test results

15 new tests in `test/r29_solution_evolution_test.dart`, including the three
mandatory, distinguishing scenarios: frontend-only change (incremental),
backend-affecting change (full, never incremental), and no change at all
(no-op). Full regression suite unaffected — every existing
`SolutionExecutionOrchestrator`/`IncrementalCompilerSynthesizer` test passes
unmodified, since neither was touched.

## Known limitations

- The Backend Service/REST API incremental-path asymmetry is real and
  structural, not a limitation of this engine — it correctly reports what
  the underlying compiler infrastructure can actually do.
- `validate`'s real meaning is "worth a validation pass," not a specific,
  distinct validation ALGORITHM — the caller still owns which validator
  (`ExperiencePackageValidator`/`ArtifactIntelligenceEngine`) to actually
  run.
- No historical trend/decision-log is modeled (declined, see above) — a
  future milestone with a genuine, concrete need for one should make that
  case explicitly rather than this specification defaulting to persistence.

## Recommendation for R30

Wire `SolutionEvolutionEngine` into a real, external caller (e.g. a future
modification-request flow) that actually acts on its recommendations —
today it is proven correct in isolation but has no production caller yet,
the same honest, undone-but-real state several prior compiler-chain pieces
were in before their own integration milestones (R13 before R19, R18 before
R26).
