# Software Cognition & Universal Software Acquisition Engine — Vision Milestone V11

## Overview

Vision Milestones V1-V9 gave Anything the ability to understand
*knowledge* (documents, articles, API references) and its own generated
*Experiences* (the World Graph). V11 extends this to understanding
*existing software itself* — repositories, packages, APIs, UI patterns,
and architecture — before generating new software. It does not replace
generation with assembly: **the generated application is always fresh,
built from semantic understanding, never from copied or reassembled
source code.**

## The architectural correction

The milestone's own brief included a course correction on the original
"fetch code from GitHub and build apps from it" framing, replacing it
with:

```
Intent -> Requirement Graph -> Software Cognition -> Semantic Software
Graph -> LLM Reasoning -> Fresh ExperiencePackage -> Design Review -> Runtime
```

This repository's actual, tested Kernel pipeline (`AnythingKernel.processIntent`,
unchanged since V7 in stage order) runs LLM reasoning *before* Requirement
Graph extraction (`_reasonWithKnowledgeLoop` at step 5, `RequirementExtractor.extract`
at step 5.5) — the reverse of the diagram's literal sequencing. Reordering
ten milestones' worth of tested pipeline stages to match the diagram
exactly would be a large, invasive, high-risk migration and is **not**
what this milestone implements.

Instead, V11 satisfies the diagram's *intent* — acquired software
understanding informs LLM reasoning, never bypasses generation — through
the pipeline's existing, already-safe extension point: the knowledge
refinement loop. `KnowledgeAcquisitionEngine`/`KnowledgeBundle` already
flow into `ModelApplicationReasoner`'s prompt through a delimited,
sanitized, size-bounded "acquired knowledge" boundary
(`lib/synthesis/model_reasoner.dart`, unchanged since V1).
`SoftwareCognitionCoordinator.toKnowledgeResource()`/`packageToKnowledgeResource()`
convert a reviewed, copyright-checked `RepositoryModel`/`PackageModel`
into a real `KnowledgeResource` (`KnowledgeResourceType.repositoryMetadata`/
`.packageInformation`) that a caller can feed into the same, unmodified
pipeline — reusing the proven-safe boundary rather than building a second
one. A full literal pipeline reorder is recorded as a real, scoped
recommendation for a future milestone (see Remaining Limitations), not
silently implemented as if it were the diagram.

## Mandatory audit finding: WebWeaveX already has a repository/document IR engine

Before writing any code, `package:webweavex`'s full export surface
(`lib/webweavex.dart`) and internals were read in full. The critical
finding: WebWeaveX already exports a deterministic, Python-parity
repository/document understanding engine —
`compileRepository(source, {path, files})`, `queryRepository(...)`,
`analyze(nodes, edges)`, `compileDocument(text)` — which internally
performs language detection, symbol extraction (classes/functions/
methods/interfaces/traits), dependency resolution (npm/cargo/go/pip/
gradle/maven/pub-shaped), call-graph/execution-flow reconstruction,
infra-signal detection (Docker/K8s/CI files), and a real, computed
confidence score. **Software Cognition performs zero acquisition,
crawling, or parsing of its own** — `RepositoryAnalyzer` is a pure
translation layer from this already-computed `Map<String, dynamic>` IR
into strongly-typed Dart, exactly mirroring the Bridge pattern V9
established for the World Graph.

Two small, genuine, documented gaps were filled rather than duplicated:
- **`pubspec.yaml` dependency parsing**: WebWeaveX's dependency resolver
  recognizes `requirements.txt`/`Cargo.toml`/`go.mod`/`package.json`/
  `build.gradle`/`pom.xml` shapes but only *tags* `pubspec.yaml` as using
  the `pub` package manager without extracting names from its YAML
  `dependencies:` block. `PackageAnalyzer.parsePubspecDependencies` is a
  small, real, indentation-based line parser filling exactly this gap.
- **OpenAPI spec paths/methods**: WebWeaveX's internal
  `reasonApiSurface`/`reasonApiContract` engines exist but are not part
  of its public export surface (`compileRepository` does not accept an
  OpenAPI spec parameter publicly). `APIAnalyzer.fromOpenApiJson` is a
  small, real, deterministic `paths`/`components.schemas` extractor
  filling this specific, confirmed-unreachable gap.
- **UI/widget understanding** reuses WebWeaveX's own exported `Soup` HTML
  parser directly (`ComponentAnalyzer.analyzeHtml`) rather than building
  a second HTML engine, and derives Flutter widget/screen candidates from
  class names WebWeaveX's own symbol extraction already produced
  (`WidgetAnalyzer.fromClassNames`) — never a re-parse of source.

## Module map (`lib/software_cognition/`)

| Module | Real behavior |
|---|---|
| `software_types.dart`, `software_identity.dart`, `software_node.dart` | Shared vocabulary mirroring `WorldNode`/`WorldEdge`/`EntityIdentity`'s proven shape exactly — `SoftwareConfidence` is a `typedef` alias for the existing `Confidence` type (`lib/software_architect/confidence.dart`), never a duplicate. |
| `semantic_software_graph.dart` | `SemanticSoftwareGraph`, `SoftwareMerge` (real conflict surfacing), `SoftwareProjection`, `SoftwareTransformation` (the concrete, inspectable proof a fact stayed transformative). |
| `repository_model.dart` / `repository_analyzer.dart` | Real translation of `compileRepository`'s IR into `RepositoryModel` (dependencies, entrypoints, class/function names, infra signals, a typed graph). `acquireFromUrl` reuses `wwx.renderPage`/`extractSemanticContent` exactly as `WebWeaveXAdapter` does. |
| `package_model.dart` / `package_analyzer.dart` | Real `pubspec.yaml` dependency parsing plus evidence-backed capability inference from a small, named, checkable dependency→capability map (e.g. `sqflite` → "local storage"). |
| `component_model.dart` / `component_analyzer.dart` | `ComponentAnalyzer` counts real semantic HTML5 elements via WebWeaveX's own `Soup`; `WidgetAnalyzer` classifies already-extracted class names by a documented Flutter naming heuristic. |
| `api_model.dart` / `api_analyzer.dart` | Real OpenAPI `paths`/`components.schemas` extraction; real HTTP-verb-decorator interpretation of WebWeaveX's own symbol output. |
| `architecture_model.dart` / `architecture_analyzer.dart` | `ArchitectureAnalyzer` infers coarse layering from real top-level directory-name conventions (`ui/`→presentation, `data/`→data, etc.); `StorageAnalyzer` detects real, known storage dependencies; `DependencyProjections` gives real typed `DependencyGraph`/`ImportGraph`/`CodeRelationshipGraph` views by filtering the already-built graph — never a second graph engine. |
| `software_similarity.dart` | Deterministic Jaccard similarity over real extracted facts (dependencies, frameworks, structural node kinds, entrypoints) — never a fuzzy/model-driven score. |
| `software_pattern.dart` / `software_reasoner.dart` | Multi-source reasoning: N acquired repositories/packages are compared; a framework/capability repeated across ≥2 independent candidates (configurable) is accepted; anything seen in only one is reported but rejected — never silently dropped, never adopted from a single source. |
| `software_review.dart` | Reuses SCARE's own `ReviewSeverity` vocabulary (`lib/design_review/review_types.dart`) to flag low-confidence or unprovenanced understanding — a separate, additive pass, not a 16th mandatory Kernel-gated sub-reviewer (see Design Review Integration below). |
| `copyright_boundary.dart` | `CopyrightBoundary` flags a digest that is a large (≥200 char) verbatim excerpt of the original acquired source — a real, checkable proxy for "this stopped being transformative," not a legal determination. `AttributionCheck` reports which of License/Source/Author/Repository/Commit/Version a `SoftwareProvenance` actually carries. |
| `software_cognition_engine.dart` | Orchestrator: acquire → review → copyright-check, producing one `RepositoryCognitionResult`/`PackageCognitionResult` per acquisition. |
| `software_cognition_coordinator.dart` | Application-facing entry point (mirrors `EvolutionCoordinator`/`RuntimeIntelligenceCoordinator`/`WorldModelCoordinator`): converts a sound understanding to a real `KnowledgeResource`, bridges it into the World Graph, and offers (but does not auto-apply) Evolution-opportunity suggestions. |

## License / Attribution / Copyright

Every acquired understanding carries a `SoftwareProvenance` (source URL,
author, repository URL, commit, version, retrieval time, provider) plus
the existing `LicenseMetadata` type (`lib/knowledge/knowledge_resource.dart`,
reused directly, never duplicated). `AttributionCheck.evaluate()` reports
exactly which fields are present — most real-world acquisitions will
honestly show `author`/`commit`/`version` as missing unless the caller
supplies them, since Software Cognition never fabricates provenance it
wasn't given. `CopyrightBoundary.check()` is invoked as part of
`SoftwareCognitionEngine.understandRepository()`; a `RepositoryCognitionResult`
is only `isSound` when both the copyright check passes and no critical
review issue exists — `SoftwareCognitionCoordinator.toKnowledgeResource()`
returns `null` rather than fabricate a resource from an unsound result.

## World Model Integration

A 6th Bridge, `SoftwareGraphBridge` (`lib/world_model/bridges/software_graph_bridge.dart`),
translates a `SemanticSoftwareGraph` into a `GraphUpdate` exactly like the
existing five. `WorldNodeKind` gained three new values (`repository`,
`softwarePackage`, `softwareComponent` — confirmed safe via a repo-wide
grep showing zero exhaustive `switch` statements over `WorldNodeKind`).
Acquired `entity`/`capability`-kind software nodes deliberately unify
with the World Graph's own `entity`/`capability` kinds rather than a
separate software-only kind, so a real structural match is possible.
`WorldModelCoordinator.ingestSoftwareGraph()` is additive, mirroring
every other `ingest*` method.

## Evolution Integration

`SoftwareCognitionCoordinator.suggestEvolutionOpportunities()` compares
accepted, multi-source-supported recommendations against the current
design's declared capabilities (`EvolutionContext.blueprint.requiredCapabilities`)
and produces real `EvolutionOpportunity` values in the existing
`missingCapability` category — reusing Evolution's own typed vocabulary,
never a parallel one. This is deliberately **not** wired into
`EvolutionObserver.observe()` automatically: a caller merges the returned
list with `EvolutionObserver`'s own output. This mirrors the same
"real, available, not-yet-auto-wired" scope boundary V9 documented for
`precheckModification()` before V10 wired it into the production path —
a natural, named candidate for a future milestone once Software
Cognition's acquisition step itself is wired into a real composition
root.

## Design Review Integration

`SoftwareReview` reuses SCARE's own `ReviewSeverity` enum directly. It is
a separate, additive review pass over acquired *understanding*
(confidence, provenance completeness) — not a 16th sub-reviewer wired
into `DesignReviewEngine`'s mandatory Kernel-gated review, since
`ReviewContext`'s shape is depended on by all 15 existing reviewers and
every test that constructs one, and Software Cognition's acquisition is
optional, not a mandatory part of every generation. This mirrors how
`EvolutionReviewer` (V7) reused `ReviewSession` directly without SCARE
re-running its own review pass.

## Real bugs found and fixed during this milestone

1. **`ArchitectureAnalyzer`'s top-level directory filter excluded every
   directory.** Directory paths from `RepositoryStructure` end with a
   trailing `/` (e.g. `"ui/"`); the original filter checked
   `!path.contains('/')` to mean "top-level," which is false for every
   directory path by construction. Fixed by stripping the trailing slash
   before checking for a nested `/`. Caught immediately by
   `test/software_cognition/component_api_architecture_test.dart`.
2. **`CopyrightBoundary`'s "digest larger than source" check produced
   false positives.** A legitimate, fixed-format digest (purpose,
   language, dependency/entrypoint counts, test/CI/Docker flags) can
   easily exceed a genuinely small source snippet's length without being
   remotely non-transformative — this heuristic didn't correlate with
   actual copying and was removed rather than patched around, leaving
   only the real, meaningful signal (a large verbatim substring match).

## Play Store / OSS compliance

Software Cognition adds no new capability surface reachable from a
generated Experience's behavior graph, no `eval`/`dart:mirrors`/runtime
compilation, and no new acquisition engine — every acquisition path
routes through `package:webweavex`'s own `renderPage`/`extractSemanticHtml`/
`extractSemanticContent`/`Soup`, identical to the pattern
`WebWeaveXAdapter` already established in V1. It remains declarative and
deterministic throughout.

## Known limitations

- The literal `Intent -> Requirement Graph -> Software Cognition ->
  Semantic Software Graph -> LLM Reasoning` pipeline reorder from the
  milestone's own corrected diagram was not implemented — acquired
  software understanding flows into reasoning via the existing knowledge
  pathway instead (see "The architectural correction" above).
- `SoftwareCognitionCoordinator` is not wired into any real composition
  root yet (no screen/flow in `lib/features/` calls it) — it is a real,
  tested, available capability, matching the same honest scope boundary
  every prior milestone's newly-introduced coordinator started with.
- `RepositoryAnalyzer`'s repository-tree understanding is acquired-text-
  scoped (one file's source plus a caller-supplied file-path listing for
  infra/CI/test detection), not a full recursive multi-file AST index —
  WebWeaveX's own public `compileRepository` API is scoped the same way.
- `decorators`/`imports` extraction from `compileRepository`'s public
  output are frequently empty in practice — WebWeaveX's own regex-based
  symbol extraction populates classes/functions/methods/interfaces/
  traits but not decorators/imports via the reachable public path;
  `APIAnalyzer.fromDecorators`'s interpretation logic is real and tested
  against a synthetic list, but rarely has real decorator data to work
  with today.
- `suggestEvolutionOpportunities`/`SoftwareReview` are real, tested,
  additive capabilities not yet auto-invoked by `EvolutionObserver`/
  `DesignReviewEngine` — a deliberate, named scope boundary (see
  Evolution/Design Review Integration above).

## Implementation Milestone R14 — Software Cognition Engine, Semantic Software Understanding (2026-08-03)

R14's own mandatory first step was to audit the repository for existing
"Software Graph / Knowledge Graph / Semantic Model / Repository Analysis"
abstractions before writing any code — this document and
`lib/software_cognition/` (unchanged file count: 23) are exactly what
that audit found. R14 is therefore an extension of this same, single
engine, never a second one. Everything below is additive; every prior
section of this document remains accurate.

### What was orphaned, and what R14 wired

MIS-1 Part 2 (2026-08-03, before this milestone) found
`SoftwareCognitionCoordinator` had zero production callers. That
finding was already partially stale by the time R14 started — R1 had
since wired `toKnowledgeResource()`/`understandRepositoryFromUrl()`
into `ExperienceCreationCoordinator._acquireSoftwareCognitionSeed`
(`lib/app/creation_coordinator.dart`), giving the WebWeaveX-consumption
half of the coordinator a real caller. Re-auditing directly (grep, not
assumption — Principal Architect Mode Rule 3) confirmed the OTHER half,
`syncToWorldModel`/`syncPackageToWorldModel`, still had zero production
callers. R14 closes exactly this gap: the same
`_acquireSoftwareCognitionSeed` method now also calls
`syncToWorldModel(worldModel, result.model)`, best-effort, whenever a
sound acquisition and an injected `WorldModelCoordinator` are both
present — the identical non-blocking, try/catch-swallowed,
accept-only-on-success contract every other `ingest*` call site in this
codebase already uses (see `ingestExperience` two lines below it in the
same method). No new World Model method was written; `ingestSoftwareGraph`
(V11) and `SoftwareGraphBridge` (V11, the 6th Bridge) are unchanged.

### Output taxonomy audit (this milestone's own "FIRST INVESTIGATION" requirement)

R14 asked for eleven output categories. Checked directly against
`lib/software_cognition/`'s existing modules:

| Category | Status before R14 |
|---|---|
| Entities | Already real (`RepositoryModel`/`entity`-kind `SoftwareNode`s) |
| Capabilities | Already real (`PackageAnalyzer`'s dependency->capability map) |
| Relationships | Already real (`SemanticSoftwareGraph` edges) |
| Architecture Patterns | Already real (`ArchitectureAnalyzer`) |
| API Contracts | Already real (`APIAnalyzer`) |
| Storage Patterns | Already real (`StorageAnalyzer`) |
| Dependency Knowledge | Already real (`RepositoryModel.dependencies`/`PackageModel.dependencies`) |
| Technology Metadata | Already real (`RepositoryModel.frameworks`/metadata) |
| Workflows | Already real — `DependencyProjections.codeRelationshipGraph`'s calls/references projection over WebWeaveX's own call-graph reconstruction IS a workflow representation; no second engine was built for this |
| Authentication Patterns | **Missing — filled this milestone** |
| Navigation Patterns | **Missing — filled this milestone** |

`AuthenticationPatternAnalyzer`/`NavigationPatternAnalyzer`
(`lib/software_cognition/architecture_analyzer.dart`) fill the two real
gaps, using the exact same shape as the existing `StorageAnalyzer`: a
small, documented, non-exhaustive list of well-known dependency names
matched case-insensitively as substrings against a repository's
already-declared dependencies — never a re-parse of source, never a
claim of understanding actual auth/nav flow logic. Two new
`SoftwareNodeKind` values (`authenticationPattern`, `navigationPattern`)
were added; `SoftwareGraphBridge`'s exhaustive `switch` (the one place
in the codebase that pattern-matches every `SoftwareNodeKind`) unifies
both into the existing `WorldNodeKind.softwareComponent` catch-all,
exactly like `endpoint`/`schema`/`database`/`architectureLayer` already
do — no new World Graph node kind was needed.

### CanonicalImplementationModel enrichment — what was built, and what was deliberately not

R14's own text: "Software Cognition must enrich future
CanonicalImplementationModels. Never generate them directly." A new,
additive field pair was built:

- `CanonicalImplementationContext.corroboratingRecommendations`
  (`List<SoftwareRecommendation>`, default empty) — a caller passes
  ONLY recommendations it already accepted
  (`SoftwareRecommendation.accepted`, V11's own real, ≥2-independent-
  source acceptance gate in `SoftwareReasoner`).
- `CanonicalImplementationModel.corroboratedPatterns`
  (`List<CorroboratedPattern>`, default empty) —
  `CanonicalImplementationPlanner._planCorroboratedPatterns()`
  deterministically carries every accepted recommendation forward
  verbatim (name/description/confidence score/supporting-source count).

This is a **pass-through of already-validated evidence, never new
inference**. An earlier design considered during this milestone's
investigation — automatically cross-referencing acquired understanding
against this generation's own resolved capabilities
(`CapabilityAdapterSpec`/`CapabilityDescriptor`) — was investigated and
explicitly rejected: `CapabilityRegistry` (`lib/capabilities/registry/`,
distinct from the runtime `CapabilityPlatform` `AppComposition.production()`
registers `ClockCapability`/`HttpCapability`/etc. into) is **never
populated with any `CapabilityDescriptor` in production code** —
confirmed via a repo-wide grep of `lib/` (only test fixtures like
`test/app/r1_composition_root_test.dart`'s `_registryWithStorage()`
construct one). Cross-referencing against a registry that is always
empty in every real generation would be exactly the kind of vacuous
integration point Rule 5 ("no speculative systems — solve only real,
cited gaps") warns against. This is named here as a real, separate,
pre-existing structural finding for architectural review — it predates
R14 and is unrelated to Software Cognition itself.

A second scope decision, also deliberate: `corroboratingRecommendations`
is **not** threaded through `AnythingKernel.processIntent`'s own
signature. The only real production caller
(`ExperienceCreationCoordinator.createFromIntent`) acquires at most one
`referenceUrl` per creation. `SoftwareReasoner.reasonAboutRepositories`/
`reasonAboutPackages` require `minSupportingCandidates` (default 2)
independently-acquired candidates before ANY recommendation is
accepted — with today's single-acquisition production flow, this gate
can mathematically never produce an accepted recommendation. Wiring a
Kernel parameter that would always receive an empty list in every real
invocation would not be honest, tested integration work; it would be
dead plumbing. The mechanism itself is real, tested, and proven correct
at the `CanonicalImplementationPlanner` boundary directly
(`test/r14_software_cognition_enrichment_test.dart`) — Kernel-level
wiring is a named, scoped recommendation for whenever a real
multi-reference acquisition caller exists (see Known limitations
below).

### Known limitations

- `corroboratingRecommendations`/`corroboratedPatterns` are real and
  tested at the planner boundary but not yet reachable from
  `AnythingKernel.processIntent` in production — see above.
- `CapabilityRegistry` has zero production callers registering any
  capability, a real, separate, pre-existing structural finding
  surfaced (not fixed) by this milestone's investigation.
- `SoftwareCognitionCoordinator.suggestEvolutionOpportunities` (V11)
  still has zero production callers — unchanged by R14, since it
  requires the same multi-repository-acquisition caller the
  CanonicalImplementationModel enrichment hook above is also blocked
  on; both are the same, single, named future gap.
- `AuthenticationPatternAnalyzer`/`NavigationPatternAnalyzer`'s hint
  lists are small and documented, not exhaustive — same honest
  precedent as `_storageDependencyHints`.
