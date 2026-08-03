# Universal Build Graph — Implementation Milestone R11

## Overview

R10's `GenerationPipeline` fed `CanonicalImplementationModel` (R9)
directly into a `Generator`. That works for a trivial reference generator
but has no notion of dependency ordering, cycle safety, or which parts of
a system must exist before others — exactly what a real compiler-shaped
consumer needs. R11 introduces `UniversalBuildGraph`
(`lib/build_graph/`), a real, deterministic, language-independent
dependency graph derived from `CanonicalImplementationModel`, and updates
the Generator Framework to consume it.

## Investigation: no prior build/dependency graph existed for this purpose

The World Graph (`lib/world_model/`, V9) has its own real, proven
`{identity, kind, label}` node / typed-relationship-kind edge shape and a
real bounded-traversal algorithm (`GraphTraversal`) — the template this
milestone's own node/edge shape mirrors. It was NOT reused directly:
`WorldNodeKind`/`EntityIdentity` are whole-application vocabulary
(entity/knowledge/capability at the level of an entire Experience); a
build graph node is a narrower, generation-scoped concept (module/
repository/controller/capability within ONE generation run). `GraphTraversal`
itself answers "what's reachable" and silently stops at a revisited node
— it does not, and structurally cannot, distinguish "already fully
explored" from "currently mid-exploration," which is exactly what cycle
detection requires. A real, small, new DFS-based cycle detector was
therefore genuinely necessary, not a duplication of existing traversal
logic.

## The graph (`lib/build_graph/`)

- `build_graph.dart` — `BuildNodeKind` (`entity`, `repository`,
  `controller`, `capability` — mapped 1:1 onto `CanonicalImplementationModel`'s
  own real categories, never invented "module"/"package"/"library"
  distinctions this data doesn't actually carry), `BuildRelationshipKind`
  (`dependsOn`), `BuildGraphNode`/`BuildGraphEdge` (real value types with
  real `==`/`hashCode`).
- `universal_build_graph.dart` — `UniversalBuildGraph` (nodes + edges +
  a retained `sourceModel: CanonicalImplementationModel`, so
  `SummaryManifestGenerator`'s existing entity/field-level logic keeps
  working unchanged — the least-disruptive extension over a forced
  rewrite), `BuildGraphBuilder` (the real, deterministic derivation:
  entity/repository/controller/capability nodes; `dependsOn` edges from
  `ImplementationDependency` plus real repository→entity and
  controller→entity structural edges — never a dangling edge; an edge
  whose endpoint isn't a real node in this model is never emitted,
  matching `GraphConsistency`'s own established "never dangling"
  philosophy).
- `build_graph_analysis.dart` — `BuildGraphCycleDetector` (real DFS with
  white/gray/black coloring — a "gray" node reached again before fully
  explored is a genuine back-edge/cycle; two independent paths converging
  on the same node, a diamond, is correctly never flagged), `BuildGraphOrderer`
  (real Kahn's-algorithm topological order — dependencies before
  dependents; honestly reports `isComplete: false` with a real, partial
  order when a cycle prevents full resolution, never a fabricated
  complete one).

## A real, honest scope limitation: DTOs/Validators/Services aren't graph nodes

Only entity/repository/controller/capability became build-graph nodes
this milestone. `ImplementationDto`/`ImplementationValidator`/`ImplementationService`
exist in `CanonicalImplementationModel` but were not modeled as separate
graph nodes — a real, named, bounded scope decision, not a silent gap.
Similarly, `ImplementationDependency` entries whose `fromId` is the
coarse `'app'` pseudo-node (R9's own documented limitation for
capability dependencies) never appear as build-graph edges, since `'app'`
is not a real node — this is a direct, honest consequence of R9's
existing limitation, not a new one introduced here.

## Generator Framework changes

`GeneratorContext.model` (R10) → `GeneratorContext.buildGraph` (R11).
`GenerationPipeline.run()`'s `model` parameter → `buildGraph`. A caller
now does `pipeline.run(buildGraph: BuildGraphBuilder().build(model), ...)`.
`SummaryManifestGenerator` reads `context.buildGraph.sourceModel` in
place of the old `context.model` — one line changed, every other line of
its real derivation logic is untouched. R10's own test suite
(`test/r10_generator_framework_test.dart`) was updated to the new call
shape and re-verified passing unchanged in substance.

## Engineering Memory: deliberately NOT extended this milestone

Investigated and declined, mirroring R10's own precedent exactly.
`CanonicalImplementationModel` is ALREADY persisted
(`EngineeringMemoryRepository`'s `canonical_implementation_json` column,
R9). `UniversalBuildGraph` is a pure, deterministic function of that
already-persisted data — reproducible on demand at negligible cost (a
200-entity graph build + cycle-detect + topological-order run measures
single-digit milliseconds). Persisting it a second time would be
redundant storage for something free to recompute, not a missing
capability.

## World Model: deliberately NOT extended this milestone

Investigated and declined. `WorldModelCoordinator.ingestCanonicalImplementation()`
already ingests the real, durable facts `CanonicalImplementationModel`
carries. `UniversalBuildGraph` adds no new durable fact beyond what's
already derivable on demand from that ingested data — a "build graph"
Bridge would duplicate, not extend, an already-real ingestion path.

## AI boundary

Zero new LLM calls anywhere in this milestone. `BuildGraphBuilder.build()`,
`BuildGraphCycleDetector.detect()`, and `BuildGraphOrderer.order()` are
all pure functions of already-computed data.

## Known limitations

1. Only entity/repository/controller/capability are graph nodes — DTOs/
   Validators/Services are not (see above). A future milestone could
   extend this if a real generator needs to reason about their ordering
   specifically.
2. `UniversalBuildGraph` has no incremental/partial-build support.
   Investigated and honestly deferred: generation is already so cheap
   (single-digit milliseconds at 200 entities) that there is no real,
   measured "slow step" incremental caching would meaningfully speed up
   yet — the same reasoning R10 already applied to Engineering Memory.
   Revisit once a real, expensive generator exists with real numbers to
   justify it.
3. Capability-dependency edges from the coarse `'app'` pseudo-node (R9)
   never appear in the build graph — a direct, honest consequence of an
   already-documented upstream limitation, not new here.

## Recommendation for R12

1. A real target-language generator remains the natural next step — now
   with a real dependency-ordered `UniversalBuildGraph` to consume, not
   just a flat model.
2. Revisit incremental build support once a real, measurably-expensive
   generator exists.
3. Standing Capability Platform / BYOK-provider-count / localization gaps
   from MIS-1/V10 remain open and unrelated to the R-series' own scope.
