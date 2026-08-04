# Interface Generator Framework — Implementation Specification IS-R27

## Overview

R26 gave `SolutionExecutionOrchestrator` its first real multi-generator run
(Runtime Experience + Backend Service). R27 adds the third real
`Generator`, `RestApiGenerator`, and — because R18/R26 already wired the
dependency chain and dispatch machinery generically — gives the
orchestrator its first genuine THREE-generator run: Backend Service → REST
API → Runtime Experience, one `ExecutionStrategy`, real deterministic
ordering.

## REALITY: one precise classification gap, everything else already wired

Unlike R26 (four structural gaps), R27's investigation found the
infrastructure R26 built already generalizes almost for free:

1. **`SolutionExecutionPlanner._restApi()` hardcoded `applicableNoGenerator`**
   (`lib/execution_planning/solution_execution_planner.dart`) — "no
   Generator implementation exists to fulfill a REST API target yet" was
   the literal reason string, exactly mirroring `_backendService()`'s
   pre-R26 state. This is the one real gap R27 closes.
2. **The dependency chain was already wired.** `_restApi()` already
   declared `dependencies: const [ExecutionTargetKind.backendService]`,
   and `_runtimeExperience()` already conditionally depended on
   `ExecutionTargetKind.restApi` when applicable — both since R18. Once
   `_restApi()` flips to `applicableWithGenerator`, `ExecutionTargetOrderer`
   (R25, unmodified) naturally produces the real 3-level chain.
3. **`runGeneratorPipeline`/`GeneratorOptions`-JSON threading (R26) is
   already generic.** `RestApiGenerator` reuses BOTH unmodified — it is
   the SECOND generator to consume `BackendEngineeringPlan` via
   `options.values['backendEngineeringPlan']`, proving the convention
   generalizes rather than being a Backend-Service-specific one-off.
4. **`StageOutcome.backendArtifacts` (R26) is reused unmodified**, not
   extended with a new field — Backend Service and REST API both produce
   a real `List<Artifact>`, the SAME structural shape; a caller
   distinguishes which generator produced it via `target` itself.

## The fix, precisely

1. `SolutionExecutionPlanner._restApi()` flips its `hasApi && requiresBackend`
   branch to `applicableWithGenerator` with `requiredGenerators: ['reference.rest-api']`;
   the `notApplicable` branches (no API / no backend) are byte-for-byte
   unchanged.
2. New `RestApiGenerator` (`lib/generator_framework/reference/rest_api_generator.dart`)
   — implements `Generator` (R10) directly, no new abstraction layer (see
   "Interface Generator Framework" below).
3. `SolutionExecutionOrchestrator._runStage` (R26's dispatch pattern)
   gains a third branch: `target == ExecutionTargetKind.restApi` →
   `_runRestApiStage`, mirroring `_runBackendServiceStage` almost exactly
   (same `backendPlan`-required precondition, same completion criteria:
   zero diagnostic errors, at least one artifact, every artifact valid
   JSON).

## Why "Interface Generator Framework" built no new abstraction

R27's own explicit rule: "DO NOT create Second Generator Framework."
`RestApiGenerator` is named "the first implementation" with no second
(e.g. GraphQL) in scope this milestone. Building `InterfaceGenerator
extends Generator` now would be an abstraction with exactly one real
implementation — the precise anti-pattern R18/R21/R23/R24/R25 each
declined for the same reason. The real, demonstrated "framework" claim:
R26's `GeneratorOptions`-JSON convention generalized across a second
generator, proven, not scaffolded for a hypothetical third.

## RestApiGenerator output

One aggregate `Artifact` (`ArtifactKind.manifest`, mirrors
`RuntimeExperienceGenerator`/`BackendServiceGenerator`'s own "one real
generator-produced aggregate" precedent) containing:

- **Endpoint Definitions/Routes** — `ApiEndpoint.path`/`.method`/`.operation`
  (R8, unchanged).
- **Request Models** — a REAL join: `ApiEndpoint.requestFields[].name`
  against `ImplementationEntity.fields[].name` (R9/R20). Both trace back
  to the SAME `entity.fields` iteration in `BackendEngineeringPlanner`
  (`ApiRequestField(name: field.name, ...)` and
  `DatabaseColumn(name: field.name, ...)` → `ImplementationField.name`) —
  identical by construction for the same logical field, never a fuzzy
  match, never a fabricated type.
- **Response Models** — the target entity's real field shape, for
  `get`/`list`/`search` operations only (matching the real read-vs-write
  operation split `ApiOperation` already models).
- **Authentication Requirements** — `AuthenticationModel.requiresCredentials`/
  `.providerIndependent` (R8), unmodified.
- **OpenAPI-3.0-*shaped* JSON** — a real `paths` object keyed by
  `ApiEndpoint.path`, per-method operation objects with `operationId`,
  request/response schema — a real, deterministic RESHAPING of already-real
  data into a well-known specification format, never new fabricated
  content.

## Honest, named limitations (never fabricated)

- **Authorization Rules**: no per-endpoint role/scope concept exists
  anywhere upstream — `AuthenticationModel` carries only two booleans
  (confirmed by reading its own doc comment, R8). Reported via
  `GenerationDiagnostic(category: skippedFeature)`.
- **Error Models**: no per-endpoint failure-mode signal exists anywhere
  upstream. A generic RESTful-convention error shape (404/400/500) was
  considered and declined — it would be invented convention, not derived
  from real per-app signal, indistinguishable from the exact "ad hoc
  generation" the user's Milestone R8 constraint forbids. Reported via
  `GenerationDiagnostic(category: skippedFeature)`.

## Mandatory vision validation: three real generators, one ExecutionStrategy

`test/r27_rest_api_generator_test.dart`'s centerpiece test builds a real
backend-required, API-bearing `SemanticSolutionArchitecture`, plans it
into ONE `ExecutionStrategy` where Backend Service, REST API, and Runtime
Experience are all `applicableWithGenerator`, and runs
`SolutionExecutionOrchestrator.execute()` — all three succeed, with a real
check that the level ordering is exactly Backend Service → REST API →
Runtime Experience (three distinct levels, in that order).

## Standing constraint, still in force

Same as R8/R26: never SQL, never server framework code, never controller
implementations, never routing implementation code — output is real,
typed, JSON-serializable SPECIFICATION data only. Verified by a dedicated
test grepping the generator's own output for forbidden patterns (zero
hits).

## AI boundary

Zero new LLM calls. `RestApiGenerator.generate()` is a pure, deterministic
function of its `GeneratorContext` (`BackendEngineeringPlan` via
`GeneratorOptions`, `CanonicalImplementationModel` via `buildGraph.sourceModel`).

## No duplicate architecture

No second Compiler/Generator Framework/Runtime/Backend Generator/AI
Boundary/World Model. `RuntimeExperienceGenerator` and
`BackendServiceGenerator` are read, never modified, by this specification.
`lib/world_model/`, `lib/storage/engineering_memory_repository.dart`,
`lib/software_cognition/`, `lib/engineering_intelligence/`,
`lib/backend_engineering/`, `lib/generator_framework/generator.dart`,
`lib/generator_framework/generation_pipeline.dart`,
`lib/creation/creation_engine.dart` are all completely unchanged.

## Known limitations

1. Authorization Rules and Error Models remain unmodeled (see above) —
   real gaps, not silently dropped.
2. No incremental-synthesis path for REST API stages yet (mirrors
   `BackendServiceGenerator`'s identical, already-named limitation, R26) —
   `IncrementalCompilerSynthesizer` (R24) remains Runtime-Experience-only.
3. `useCompilerPipeline` remains opt-in, default `false` — this
   specification's own code never references the flag at all.

## Recommendation for R28

1. If a genuine second interface generator (e.g. GraphQL) becomes
   real-signal-backed, that is the point at which a shared
   `InterfaceGenerator` abstraction would be justified by TWO real
   implementations, not zero or one.
2. Extend `IncrementalCompilerSynthesizer`'s entity-scoping logic to
   Backend Service/REST API stages, closing the "no incremental path"
   limitation named above and by R26.
3. Keep `useCompilerPipeline` opt-in until a future milestone makes an
   explicit, evidence-backed call — R19-R27's compiler certification
   corpus (R23) is the natural place to gather that evidence as the
   corpus grows to include multi-generator fixtures.
