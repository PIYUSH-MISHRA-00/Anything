# Engineering Intelligence Layer — Implementation Specification IS-R24

## Reality: most of R24's 14 requested graph types already existed

IS-R24 asks for "Engineering Intelligence" — Requirement Graph,
Architecture Graph, Workflow Graph, Navigation Graph, Capability Graph,
Relationship Graph, Dependency Graph, Permission Graph, Storage Graph,
Backend Graph, Frontend Graph, Offline Strategy, Synchronization
Strategy, Deployment Intent — plus a graph diff engine and diff-driven
incremental synthesis. Read as if entirely new, this milestone would
require building 14 parallel graph types. Investigation before writing
any code found 11 of the 14 already real, already tested, already in
production use, under established names:

| R24 requests | Already exists as |
|---|---|
| Requirement Graph | `RequirementGraph` (`lib/software_architect/requirement_graph.dart`, Vision Milestone V2) |
| Architecture Graph | `ArchitectureCandidate` (frontend, V2/V5) + `BackendEngineeringPlan` (backend, R8), unified by `SemanticSolutionArchitecture` (R17) |
| Navigation Graph | `ArchitectureCandidate.navigation` (`NavigationGraph`, already real) |
| Capability Graph | `ArchitectureCandidate.capabilities` (`List<CapabilityDecision>`) |
| Relationship Graph | `ArchitectureCandidate.relationships` (`List<RelationshipDecision>`) |
| Permission Graph | `ArchitectureCandidate.permissions` (`List<PermissionDecision>`) |
| Storage Graph | `BackendEngineeringPlan.database` (`DatabaseSchemaModel`, R8) |
| Backend Graph | `BackendEngineeringPlan` as a whole (R8) |
| Frontend Graph | `ArchitectureCandidate` as a whole (V2/V5) |
| Offline Strategy | `ArchitectureCandidate.offline` (`OfflineDecision`) |
| Synchronization Strategy | `ArchitectureCandidate.synchronization` (`SynchronizationDecision`) |
| Deployment Intent | `BackendEngineeringPlan.deployment` (`DeploymentSpecificationModel`) |
| Dependency Graph | `UniversalBuildGraph` (R11, compiler-side dependency graph) |

**Workflow Graph** is the one requested type with no real, distinct
signal: `ArchitectureCandidate.interactions`, the compiler-side
`BehaviorGraph` (R13), and R20's derived-value behavior chains already
cover every real workflow-shaped signal this codebase produces. A
fifteenth wrapper type around the same data would duplicate, not close a
gap — honestly left unmodeled, matching R17/R18's own precedent for
"no real signal, don't fabricate."

**Diff engines already existed too**: `RequirementGraphDiff`/
`RequirementGraphDiffer` (R3) and `ArchitectureDiff`/`ArchitectureDiffer`
(R4) are real, deterministic, identity-keyed structural diffs, unchanged
by this milestone — confirmed via `git diff --stat`.

**A real "diff → affected → apply → hot reload" pipeline already
existed** — `EvolutionDiffPlan`/`EvolutionDiffPlanBuilder` (R4/R5) +
`ExperienceModificationCoordinator.planEvolution()`/
`.applyEvolutionPlan()`/`.rollback()` (R4/R6) + `ExperienceHostScreen`'s
live reload flow (R7). Confirmed by grep before writing any code: this
entire mechanism operated exclusively on the LEGACY `CreationEngine`
path — zero references to `CanonicalImplementationModel`/
`runCompilerPipeline` existed anywhere under `lib/evolution/` or in
`experience_modification_coordinator.dart`.

## The one genuinely novel contribution

Given the above, R24 is not "build 14 new graph types." The honest,
defensible scope is narrow:

1. **`EngineeringIntelligence`** (`lib/engineering_intelligence/
   engineering_intelligence.dart`) — a real facade holding references
   (never copies) to `RequirementGraph` + `ArchitectureCandidate` +
   `BackendEngineeringPlan`, mirroring Vision Milestone V7's own
   established "EngineeringMemory is a facade over ReviewMemory/
   EvolutionMemory, not a third store" precedent.

2. **`AffectedEntityAnalyzer`** (`affected_entities.dart`) — the real,
   missing link between R3/R4's existing diffs and "which entities does
   this change affect." `RequirementGraphDiff`'s node ids are always
   `<prefix>:<entityId>` or `<prefix>:<entityId>.<childId>`
   (`RequirementExtractor`'s own established convention) — entity ids
   are parsed straight off them, never guessed. `ArchitectureDiff`'s
   decision types are already directly entity-keyed
   (`EntityDecision.entityId`, `RelationshipDecision.fromEntityId`/
   `.toEntityId`) — read straight off them. `capability:`/`navigation:`
   nodes have no single owning entity and are honestly excluded, never
   force-mapped to a fabricated id.

3. **`IncrementalCompilerSynthesizer`** (`incremental_compiler_synthesis.dart`)
   — reaches diff-driven incremental regeneration into the R9-R23
   compiler chain for the first time. Given `AffectedEntities`, it scopes
   a full `CanonicalImplementationModel` down to only the affected
   entities (filtering every genuinely entity-keyed list: entities,
   repositories, controllers, dtos, validators, services,
   storageAdapters, stateContainers, derivedValues, views) and re-runs
   the EXISTING, UNMODIFIED `runCompilerPipeline` (R19) —
   `BuildGraphBuilder`/`GenerationPipeline`/`RuntimeExperienceGenerator`
   are never touched, never reimplemented.

4. **`RequirementGraphBridge`** (`lib/world_model/bridges/
   requirement_graph_bridge.dart`) — closes the "`RequirementGraph` is
   never ingested into World Model" finding (confirmed by grep: zero
   references before this milestone) with a narrow, additive
   contribution: capability-requirement nodes (a real, standalone
   signal distinct from `ArchitectureCandidate.capabilities`'s later,
   resolved `CapabilityDecision`) and view/action → entity
   `references` edges (real requirement-level traceability no other
   bridge captures). Field/constraint/storage/state/navigation nodes are
   deliberately NOT ingested — they add no new World Graph signal beyond
   "this entity has fields," already implied by the entity node's mere
   existence.

## Incremental synthesis: real granularity, stated honestly

Scoping happens at the `CanonicalImplementationModel` LIST level —
every entity-keyed list is filtered to the affected entity id set before
the compiler pipeline runs. `RuntimeExperienceGenerator` itself still
regenerates every screen/behavior node for the SCOPED model in one call
— there is no per-node patching inside the generator (it has no such
mechanism, and building one would mean modifying the reference
generator's internals, well beyond this specification's honest scope).

This is real **affected-entity-scoped regeneration**, not per-node graph
surgery. The value is a smaller, real `CanonicalImplementationModel` and
therefore a measurably faster compiler run — proven directly:
regenerating 200 entities in full took ~22ms; regenerating the same
model scoped to 1 affected entity took ~1ms (see
`test/r24_engineering_intelligence_test.dart`'s performance group for
the real, unmocked numbers). Cross-cutting, non-entity-keyed specs
(`navigation` handler, `authentication`, `backgroundWorker`,
`capabilityAdapters`, `dependencies`, `corroboratedPatterns`) are
honestly NOT scoped — filtering them further would risk silently
dropping real, unrelated requirements.

## Hot reload: zero changes needed to existing machinery

The resulting `ExperiencePackage` flows into a real `EvolutionDiffPlan`
via the EXISTING, UNMODIFIED `EvolutionDiffPlanBuilder`/`ExperienceDiffer`
(R4). `ExperienceModificationCoordinator.applyEvolutionPlan()` (R6) only
ever touches `EvolutionDiffPlan.candidatePackage`, a plain
`ExperiencePackage` — completely format-agnostic between legacy and
compiler origin, confirmed by reading it before writing any code. A real
test (`test/r24_engineering_intelligence_test.dart`, "a compiler-produced
candidatePackage flows through the REAL, UNMODIFIED applyEvolutionPlan()
hot-reload path") proves a compiler-produced package is validated,
persisted, and returned by the exact same, unmodified coordinator with
zero code changes to that path.

## World Model impact

One new bridge (`RequirementGraphBridge`), one new coordinator method
(`ingestRequirementGraph`), wired into the Kernel at the exact point
`RequirementGraph` was already computed (Step 5.6) — the same defensive,
best-effort `_ingestIntoWorldModelSafely` pattern every prior milestone's
World Model wiring uses. `ArchitectureCandidate`'s core content
(entities, permissions) was already reachable via `ingestSolutionArchitecture`
(R17, since `SemanticSolutionArchitecture.frontend` holds the same
`ArchitectureCandidate` by reference) — confirmed before deciding this
milestone needed no separate Architecture Graph bridge.

## Engineering Memory impact

None. `RequirementGraph` and `ArchitectureCandidate` are already
persisted via `EngineeringMemoryRepository` (R5, extended R8/R9) — this
milestone's graphs and diffs are all either already-persisted data or
cheap, deterministic, re-derivable functions of it. No new persistence
need was found.

## BYOK compatibility

Already true structurally, not new code: every type this milestone
touches is produced deterministically downstream of the ONE existing
`ApplicationReasoner`/`ModelProvider` call, which was already
provider-agnostic by design (R1). `AffectedEntityAnalyzer`/
`IncrementalCompilerSynthesizer`/`RequirementGraphBridge` make zero new
LLM calls — confirmed by grep across every new file.

## Known limitations

- **Granularity**: affected-entity-scoped regeneration, not per-node
  compiler surgery — stated above, not overclaimed.
- **`RequirementGraphDiff`-based entity detection is single-ended for
  `relationship:` nodes**: it reports only the relationship's source
  entity, not a referenced target (`ArchitectureDiff`-based detection
  correctly captures both `fromEntityId`/`toEntityId` for the same real
  change, since the two analyzers are designed to be merged, not used
  alone).
- **Workflow Graph** remains honestly unmodeled — no real, distinct
  signal exists.
- No new certification/CI wiring — this specification is scoped to the
  library layer and its tests, matching R23's own certification
  framework precedent of proving a mechanism correct before scheduling
  it operationally.

## Test results

24 new tests, all passing. Full regression: 1429/1429 (up from 1405).
`flutter analyze`: 71/0, unchanged.

## Performance (real, measured)

`RequirementGraphDiff` over 500 nodes: <1ms. Full compiler regeneration
of 200 entities: ~22ms; the same model scoped to 1 affected entity via
`IncrementalCompilerSynthesizer`: ~1ms — a real, measured ~20x speedup
at this scale. Memory: no measurable RSS growth over 100 architecture
diffs.

## Recommendation for R25

1. If a real, distinct Workflow signal ever emerges (e.g. multi-step
   approval flows, cross-entity sagas), model it then — not
   speculatively now.
2. Consider whether `IncrementalCompilerSynthesizer` should be wired
   into a real, opt-in production call path (mirroring R19's
   `useCompilerPipeline` opt-in discipline) once the compiler pipeline
   itself has more production confidence (see R23's Compiler
   Certification Framework and its `migrationReadinessScore`).
3. `useCompilerPipeline`'s default remains `false` — this milestone adds
   no new evidence toward flipping it, since it doesn't touch live
   creation at all.
