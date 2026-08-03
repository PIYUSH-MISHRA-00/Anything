# Generator Framework — Implementation Milestone R10

**Updated Implementation Milestone R11**: `GeneratorContext`/
`GenerationPipeline.run()` now consume `UniversalBuildGraph`
(`lib/build_graph/`, R11) instead of `CanonicalImplementationModel`
directly — see `docs/architecture/UNIVERSAL_BUILD_GRAPH.md` for the full
account. `UniversalBuildGraph.sourceModel` retains the original model, so
every real-depth field `SummaryManifestGenerator` already used is still
reachable unchanged; only the field name it reads through changed
(`context.model` → `context.buildGraph.sourceModel`).

## Overview

R9's `CanonicalImplementationModel` unified frontend `EngineeringCandidate`
(V3) and backend `BackendEngineeringPlan` (R8) into one language-independent
implementation vocabulary — but had no real consumer, so its "reusable by
future language generators" claim was structurally plausible, not proven.
R10 closes that gap: a real, language-independent `Generator` interface
(`lib/generator_framework/`) plus exactly one intentionally minimal
reference generator (`SummaryManifestGenerator`) that consumes a real
`CanonicalImplementationModel` and produces real, deterministic artifacts.

**This milestone does not generate any real target-language code.** Per
its own explicit "IMPORTANT ARCHITECTURAL REQUIREMENT," a production
Flutter/backend/web/desktop/mobile generator is out of scope — the
reference generator's only job is to prove the framework works.

## Investigation: no prior generator abstraction existed

`GenericPackageBuilder` (`lib/synthesis/generic_package_builder.dart`) was
the closest candidate. Its own doc comment states plainly: "This is NOT
part of the production pipeline... test-only... DO NOT use this in
production code." It is a single-purpose, Anything-internal helper that
converts `AppBlueprint` directly to `ExperiencePackage` for test
convenience — categorically different from a pluggable, language-neutral,
multi-target generator interface. No duplication occurred; this is
genuinely new, sanctioned work.

## The framework (`lib/generator_framework/`)

- `generator.dart` — `Generator` (the ONE canonical `abstract interface
  class` every future language generator implements), `GeneratorContext`
  (wraps a `CanonicalImplementationModel` + `GeneratorTarget` +
  `GeneratorOptions`), `GeneratorTarget` (an opaque id/name, never a
  language enum), `GeneratorMetadata`/`GeneratorVersion`/
  `GeneratorCapability` (real, small identity/versioning/capability
  declaration, mirroring `CapabilityDescriptor`'s own
  declare-before-invoke pattern).
- `artifact.dart` — `Artifact` (real path + typed `ArtifactKind` + string
  content), `ArtifactGroup` (a named grouping). Content is DATA only —
  this framework never writes to disk, never executes anything.
- `generation_result.dart` — `GenerationResult` (artifact groups +
  diagnostics + dependency manifest), `GenerationDiagnostic` (typed
  severity + category, never a bare string), `DependencyManifest`/
  `DependencyReference` (real, language-neutral named dependencies).
- `generation_pipeline.dart` — `GenerationPipeline`, a real, thin
  dispatcher (`CanonicalImplementationModel` + `Generator` + `Target` →
  `GenerationResult`). Not a second Kernel/Planner — no reasoning, no
  multi-stage decision-making, one deterministic delegation.
- `reference/summary_manifest_generator.dart` — `SummaryManifestGenerator`,
  the one reference implementation. Emits one small, deterministic text
  artifact per entity plus one manifest artifact — real data derived from
  the real `CanonicalImplementationModel`, never a fabricated placeholder.

## Language independence

Every type above is free of Flutter/Dart/Java/Kotlin/Swift/TypeScript/
Python/Go/Node-specific constructs, matching the discipline R9 already
established and mechanically verified for `CanonicalImplementationModel`
itself.

## Determinism

`GenerationPipeline.run()` adds no randomness, timestamps, or I/O of its
own. The same `(model, generator, target, options)` always produces a
structurally identical `GenerationResult` — proven directly by a dedicated
test (`test/r10_generator_framework_test.dart`), not merely assumed.

## Engineering Memory: deliberately NOT extended this milestone

Investigated and declined, mirroring R3's real Engineering Cache YAGNI
decision. `EngineeringMemoryRepository` (R5, extended R2/R8/R9) persists
**engineering decisions** — real, expensive-to-recompute artifacts of the
deterministic planning pipeline (`RequirementGraph`, `ArchitectureCandidate`,
`BackendEngineeringPlan`, `CanonicalImplementationModel`). A generation
RUN's output is categorically different: it is a pure, deterministic
function of the ALREADY-persisted `CanonicalImplementationModel` — fully
reproducible on demand, at negligible cost (a 200-entity reference
generation run measures ~1ms), by re-running the pipeline. Persisting
generated artifact bytes (or even generator run metadata) a second time
would be genuine redundant storage for something that costs nothing to
recompute — not a missing capability. If a REAL future generator becomes
expensive enough that recomputation is undesirable (e.g. a real Flutter
generator invoking real code formatting/compilation steps), that
generator's own real cost profile should motivate revisiting this
decision then, with real numbers — not speculatively now.

## World Model: deliberately NOT extended this milestone

Investigated and declined, for the same underlying reason. Generator/
Artifact/Dependency/Target concepts would only warrant real World Model
representation if generation produced a durable, queryable FACT about an
Experience (e.g., "this Experience has generated backend source checked
into some real location"). Nothing in this milestone produces or persists
a durable artifact anywhere — the reference generator's output is
returned to the caller as in-memory `GenerationResult` data and nothing
more. Adding a Bridge for artifacts that don't durably exist would be
speculative, ungrounded World Graph noise, not a real fact. This should be
revisited once (if) a real future generator's output is actually persisted
somewhere durable.

## AI boundary

Zero new LLM calls anywhere in this milestone. `Generator.generate()` is
a pure function of its `GeneratorContext` — no reasoning, no external call.

## Known limitations

1. Only one reference generator exists (`SummaryManifestGenerator`) — no
   real target-language generator has been built yet. "Reusable by future
   language generators" remains structurally sound (a real, typed,
   language-independent interface exists and is proven to work against
   real R9 output) but is validated by exactly one, deliberately trivial,
   consumer — not yet by a second, independently-built one.
2. `Generator.generate()` is synchronous — a real future generator that
   needs genuine async I/O (e.g., writing files, calling a formatter
   subprocess) will need this interface extended with an async signature.
   Not attempted here since no real generator yet demonstrates the need.
3. `GeneratorOptions` is an untyped `Map<String,String>` — deliberately
   minimal since no real generator yet has concrete, typed options to
   express. A future real generator with genuine configuration needs
   should motivate a real, typed extension then.
4. Engineering Memory and World Model integration are both deliberately
   deferred (see above) — real, justified YAGNI, not silent gaps.

## Recommendation for R11

1. A real target-language generator (the natural next step this framework
   was built to enable) — likely the highest-value next milestone, and
   the first real test of whether the `Generator` interface's shape holds
   up under genuine complexity.
2. Revisit Engineering Memory/World Model integration once a real
   generator's actual cost/persistence needs are known.
3. Standing Capability Platform / BYOK-provider-count / localization gaps
   from MIS-1/V10 remain open and unrelated to the R-series' own scope.
