# Solution Execution Planner — Implementation Milestone R18

## Overview

R18 asked for ONE `SolutionExecutionPlanner` that transforms
`SemanticSolutionArchitecture` (R17) into an `ExecutionStrategy` —
representing 12 requested "Execution Targets" (Runtime Experience,
Flutter Application, Backend Service, REST API, GraphQL API, Website,
Desktop Application, Mobile Application, CLI Tool, Library, Plugin,
Agent), each with Priority/Dependencies/Execution Order/Required
Generators/Validation Requirements/Build Requirements/Deployment
Requirements — with the Generator Framework "consuming Execution
Strategy rather than deciding execution internally."

## REALITY #1: the R9-R13 compiler chain has zero production callers

Confirmed by grep before writing any code:

```
grep -rln "GenerationPipeline(" lib/    -> generation_pipeline.dart only
grep -rln "RuntimeExperienceGenerator(" lib/ -> runtime_experience_generator.dart only
grep -rln "BuildGraphBuilder(" lib/     -> universal_build_graph.dart only
```

The entire `CanonicalImplementationModel` -> `UniversalBuildGraph` ->
`GenerationSpecification` -> `Generator`/`GenerationPipeline` ->
`RuntimeExperienceGenerator` -> `ExperiencePackage` chain is real and
fully tested (R13's own widget test proves it renders through the real,
unmodified Runtime) but has never once been invoked outside of tests.
The live, production "create an Experience" path
(`ExperienceCreationCoordinator._createExperience` ->
`CreationEngine.create` -> `AppBlueprint`/`ExperienceSpec`) is the
original V3-era blueprint-to-package conversion — it does not call
`BuildGraphBuilder`, `GenerationPipeline`, or `RuntimeExperienceGenerator`
at all. This mirrors exactly what R14 found about
`SoftwareCognitionCoordinator` before R14 wired it in.

**R18 does not change this.** `SolutionExecutionPlanner` produces a real
plan naming which generator a caller *could* invoke and why — it never
invokes one itself. Wiring the compiler chain into the live creation
path was investigated and deliberately declined this milestone (see
"Why not wire it in" below) — it remains real, tested, and available for
a future milestone, exactly the state the compiler chain itself was in
between R9 and R13.

## REALITY #2: only 3 of 12 requested targets have real signal; only 1 has a real generator

`lib/generator_framework/reference/` contains exactly two generators:
`SummaryManifestGenerator` (R10, explicitly test-shaped, "DO NOT use
this in production code") and `RuntimeExperienceGenerator` (R13, real).
R10, R11, and R12 each explicitly, repeatedly declined building
Flutter/backend/web/desktop/mobile generators — a deliberate, three-times
repeated scope decision, not an oversight.

| Target | Classification | Real signal |
|---|---|---|
| Runtime Experience | `applicableWithGenerator` | `ArchitectureCandidate.entities` non-empty; real generator `reference.runtime-experience` (R13) |
| Backend Service | `applicableNoGenerator` when needed | `BackendEngineeringPlan.deployment.requiresBackend` |
| REST API | `applicableNoGenerator` when needed | `BackendEngineeringPlan.api.endpoints` non-empty **AND** `requiresBackend` (see the real bug this milestone found, below) |
| Flutter Application | `notApplicable` (always) | The Anything host app already IS the one Flutter application every Experience runs inside; no per-solution "build a standalone Flutter app" target exists |
| GraphQL API | `notApplicable` (always) | `ApiSpecificationModel` only models REST-shaped `HttpMethod` endpoints; zero GraphQL concept anywhere upstream |
| Website / Desktop Application / Mobile Application / CLI Tool / Library / Plugin / Agent | `notApplicable` (always) | Zero signal anywhere in `ArchitectureCandidate`/`BackendEngineeringPlan`/`SemanticSolutionArchitecture` |

Every `notApplicable` target carries a real, specific, non-generic
reason (tested: all 9 reasons are pairwise distinct — an earlier draft
of this milestone accidentally gave Desktop and Mobile Application the
identical reason text; the R18 test suite caught this and it was
corrected to name each platform's own real absence of signal).

## A real bug this milestone found and fixed

`ApiSpecificationModel.endpoints` is derived unconditionally from
`InteractionDecision`'s CRUD flags (R8) — **independent of whether the
architecture actually needs a backend at all.** A fully-offline
architecture with `canCreate`/`canRead`/`canUpdate`/`canDelete: true`
still produces a non-empty `endpoints` list, even though nothing would
ever deploy or call them (`deployment.requiresBackend` is `false`). The
first draft of `SolutionExecutionPlanner` classified REST API as
applicable whenever `endpoints` was non-empty, which — given this real
upstream behavior — meant REST API was classified applicable even for
fully-offline solutions. The test `entities present, no backend need:
only Runtime Experience is applicable` caught this immediately. Fixed:
REST API's real applicability signal is `endpoints.isNotEmpty &&
deployment.requiresBackend` — both conditions, not either alone. Runtime
Experience's dependency list was fixed the same way: it only names
`backendService`/`restApi` as dependencies when those targets are
themselves genuinely applicable, never a dependency on a target this
planner has classified `notApplicable`.

## Execution order

Among applicable targets only: Backend Service (order 0, if needed) ->
REST API (order 1, if needed, depends on Backend Service) -> Runtime
Experience (order 2, or 0 if no backend is needed at all, depends on
whichever of the above are actually applicable). `notApplicable` targets
carry order 0 (unordered — never executed).

## Why not wire the compiler chain into the live creation path

Investigated and deliberately declined this milestone. The live
`_createExperience` path and the R9-R13 compiler chain produce
`ExperiencePackage`s via two structurally different routes
(`CreationEngine`'s blueprint conversion vs.
`RuntimeExperienceGenerator`'s `CanonicalImplementationModel`-driven
generation) that have never been proven equivalent for a real user's
actual creation request — only for hand-built test fixtures (R13's
centerpiece test). Switching live creation to the new path, even
opt-in, risks producing a genuinely different `ExperiencePackage` shape
for the same intent than what `CreationEngine` would have produced,
which is a correctness risk this milestone's real scope (a planner, not
a compiler-chain migration) does not justify taking on. `ExecutionStrategy`
is exposed additively on `ExecutionPlanReady` (R18) so a future,
dedicated milestone can make this call deliberately, with its own real
equivalence testing — matching this project's standing rule against
forcing a risky change just to claim "vision validation."

## World Model / Engineering Memory

Neither is touched by this milestone. `ExecutionStrategy` is a cheap,
pure, deterministic function of `SemanticSolutionArchitecture`, which is
itself already derived from data Engineering Memory already persists in
full (`ArchitectureCandidate`, `BackendEngineeringPlan`). Recomputing it
on demand costs nothing measurable (see Performance) and there is no
real cross-request reuse case — the same restraint R10/R11/R12 already
applied to Engineering Memory for their own outputs.

## AI boundary

Zero new LLM calls. `SolutionExecutionPlanner.plan()` is a pure function
of its `SemanticSolutionArchitecture` argument.

## No duplicate architecture

`lib/generator_framework/`, `lib/build_graph/`,
`lib/generation_specification/` are completely untouched by this
milestone (verified via `git diff --stat`). `lib/execution_planning/`
imports none of them — it only names the real, existing
`RuntimeExperienceGenerator`'s `GeneratorMetadata.id` as a plain string
constant, never importing the generator itself, keeping the planning
layer's only real dependency on `lib/solution_architecture/`.

## Known limitations

1. Only 3 of 12 requested targets carry any real signal; the other 9 are
   honestly, permanently `notApplicable` given this codebase's current
   architecture models — not a per-request judgment call.
2. `ExecutionStrategy` is produced on every Kernel run but never
   consumed by anything in production yet — matching the compiler
   chain's own pre-R13 state.
3. `validationRequirements`/`buildRequirements` name real classes/steps
   by string (e.g. `'ExperiencePackageValidator (...)'`) rather than a
   typed reference, since `lib/execution_planning/` deliberately has no
   import dependency on `lib/creation/`/`lib/generator_framework/`.

## Recommendation for R19

If the compiler chain is to gain its first production caller, that
should be its own, dedicated, carefully-scoped milestone — with real
equivalence testing between `CreationEngine`'s and
`RuntimeExperienceGenerator`'s output for the same intent — rather than
a side effect of execution planning.
