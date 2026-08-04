# Backend Service Generator — Implementation Specification IS-R26

## Overview

R25 built the real execution engine (`SolutionExecutionOrchestrator`) but
only ever had ONE real `Generator` to dispatch: `RuntimeExperienceGenerator`
(R13). R26's purpose is Anything's first genuine multi-generator
production target — `BackendServiceGenerator`, the second real `Generator`
implementation, transforming the already-real `CanonicalImplementationModel`
(R9) + `BackendEngineeringPlan` (R8) into real, typed backend
specification artifacts.

## REALITY: four precise structural gaps, verified before writing any code

1. **`runCompilerPipeline` hardcoded `RuntimeExperienceGenerator`**
   (`lib/compiler_integration/compiler_pipeline_runner.dart`) — the ONLY
   real call path into `GenerationPipeline` always constructed
   `RuntimeExperienceGenerator()` directly. There was no way to run the
   pipeline against any other `Generator` from production code.
2. **`SolutionExecutionPlanner._backendService()` always returned
   `applicableNoGenerator`** (`lib/execution_planning/solution_execution_planner.dart`)
   — "no Generator implementation exists to fulfill a backend-service
   target yet" was hardcoded, since no such generator existed before this
   specification.
3. **`StageOutcome.package` was `ExperiencePackage?`-typed** — Runtime
   Experience-specific. A Backend Service stage's real output (typed
   `Artifact`s) is structurally different and was never representable.
4. **`GeneratorContext` had no field for `BackendEngineeringPlan`** — and
   the correct fix was NOT to add one. `CanonicalImplementationModel`
   deliberately abstracts away `BackendEngineeringPlan`'s row-level
   richness (real column types, real HTTP methods, real `SecretReference`
   names) — a real Backend Service Generator needs the original plan.

## The fix, precisely

1. **`runGeneratorPipeline`** (new, generic, `compiler_pipeline_runner.dart`)
   — the real, generator-agnostic primitive: builds the `UniversalBuildGraph`
   and runs `GenerationPipeline.run()` against ANY `Generator`, returning
   the raw `GenerationResult` (never decoded into any particular artifact
   shape). `runCompilerPipeline` is now a **100%-backward-compatible thin
   wrapper** over it — same signature, same behavior, same
   `ExperiencePackage` decode. Every R19-R25 call site is byte-for-byte
   unaffected (proven by a dedicated regression test).
2. **`BackendServiceGenerator implements Generator`** (new,
   `lib/generator_framework/reference/backend_service_generator.dart` —
   the same `reference/` directory `RuntimeExperienceGenerator`/
   `SummaryManifestGenerator` already live in). Reads a real
   `BackendEngineeringPlan` from `GeneratorContext.options.values['backendEngineeringPlan']`
   (JSON-encoded, using the plan's own existing `toJson()`/`fromJson()`,
   R8) — `GeneratorOptions` is exactly the generic, generator-interpreted
   extension point the framework already provides (R10); no new required
   field was added to the core `Generator` interface, so
   `SummaryManifestGenerator` and every future generator are unaffected.
3. **`SolutionExecutionPlanner._backendService()`** now returns
   `applicableWithGenerator` with `requiredGenerators: ['reference.backend-service']`
   when `requiresBackend` is true — the exact "R18 deliberately never
   invokes a generator, R26 finally gives Backend Service one" transition
   R18's own doc comment named as the deferred gap.
4. **`StageOutcome.backendArtifacts`** (new, additive, `List<Artifact>?`)
   — a Backend Service stage populates this and leaves `.package` null; a
   Runtime Experience stage populates `.package` and leaves this null.
   Never an overloaded/repurposed field.
5. **`SolutionExecutionOrchestrator._runStage`** now dispatches on
   `target`: a `backendService` stage runs through
   `runGeneratorPipeline`/`BackendServiceGenerator`; every other target
   (today, only ever `runtimeExperience`) runs through the exact,
   unchanged R25 logic (renamed `_runRuntimeExperienceStage`, byte-for-
   byte identical body). This is real dispatch, not hard-coded execution:
   WHICH targets are even attempted is still decided entirely by
   `ExecutionStrategy` — this only decides HOW to run an already-approved
   target.

## Output: real, typed specification artifacts — never fake backend generation

The user's own explicit R8 addendum still governs this generator: *"Do
not allow Claude to 'fake' backend generation by emitting source code
templates... Anything should synthesize software from semantic
understanding and deterministic engineering — not from increasingly
large prompts or ad hoc code generation."*

`BackendServiceGenerator` emits ONE aggregate `Artifact`
(`ArtifactKind.manifest`, mirroring `RuntimeExperienceGenerator`'s own
"one real, generator-produced aggregate over the whole graph"
precedent), containing:

- `database`/`api`/`authentication`/`storage`/`backgroundJobs`/`deployment`
  — the real `BackendEngineeringPlan` sections, via its own unmodified
  `toJson()` (R8). `secretReferences` remain name-only, never a value.
- `repositories`/`services` — real NAME/SIGNATURE data from
  `CanonicalImplementationModel.repositories`/`.services` (R9) — already
  name/operation-signature-only, never bodies.
- `migrations` — a real, structural restatement of
  `DatabaseSchemaModel.tables`' own column/foreign-key data (WHAT would
  need to exist) — **never literal SQL DDL**. A dedicated test greps the
  generated content for `CREATE TABLE`/`INSERT INTO`/server-framework
  import syntax/`Process.run`/`Process.start` — zero hits, mirroring R8's
  own established check.

Honest, named limitation (never fabricated): **Realtime configuration**
has zero real signal anywhere in `BackendEngineeringPlan` — confirmed by
reading every one of its 6 sub-models, none names a websocket/push/
live-channel concept. Reported via
`GenerationDiagnostic(category: skippedFeature)`.

## Mandatory vision validation: real multi-generator execution

A dedicated end-to-end test builds ONE real `ExecutionStrategy` (from a
backend-required `SemanticSolutionArchitecture`) where BOTH
`backendService` AND `runtimeExperience` reach `applicableWithGenerator`,
runs it through the real, unmodified `SolutionExecutionOrchestrator`, and
proves: both stages succeed; `backendService`'s output lands in
`.backendArtifacts` (never `.package`); `runtimeExperience`'s lands in
`.package` (never `.backendArtifacts`); and real dependency-safe level
ordering places `backendService` strictly before `runtimeExperience`
(reusing `runtimeExperience`'s own pre-existing R18 dependency on
`backendService` — no new dependency wiring was needed).

## Known limitations

- `BackendServiceGenerator` has no incremental-synthesis path
  (`IncrementalCompilerSynthesizer`, R24, remains Runtime-Experience-
  specific) — a Backend Service stage always runs a full
  `runGeneratorPipeline` call, never scoped to affected entities.
- A missing `backendPlan` on an `applicableWithGenerator` `backendService`
  target is a real, immediate `StageStatus.failed` (attempts: 1, never
  retried) — a precondition failure, not a transient one; proven by a
  dedicated test.
- REST API remains `applicableNoGenerator` — R26 built a Backend Service
  generator, not a REST API one; that gap is unchanged and named for a
  future milestone.

## Recommendation for R27

A real REST API generator (or extending `BackendServiceGenerator` to
also satisfy the `restApi` target, since both already draw from the SAME
`BackendEngineeringPlan.api`) would close R18's last `applicableNoGenerator`
gap and give the orchestrator a real 3-target dependency chain
(`backendService` → `restApi` → `runtimeExperience`) to execute for the
first time.
