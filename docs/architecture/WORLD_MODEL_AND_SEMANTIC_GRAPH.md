# World Model & Semantic Graph (WMSG) — Vision Milestone V9

## Overview

`lib/world_model/` unifies everything Anything already reasons about —
Experiences, entities, capabilities, knowledge, workflows, evolution
proposals, review findings, learned usage patterns — into ONE typed,
persistent, versioned graph. It does not replace any existing graph
(`DependencyGraph` V4, `EvolutionGraph` V7, `KnowledgeGraph` V1/V2, every
RIL graph V8); it **bridges** them: a small set of pure translation
functions map each one's already-typed output into the shared
`WorldNode`/`WorldEdge` shape those graphs already use.

## Repository audit findings that shaped this design

Before writing any code, `KnowledgeGraph`, existing identity schemes, the
persistence lifetime of `ReviewMemory`/`EvolutionMemory`/RIL's memories,
`ModificationEngine`'s integration surface, the shared node/edge pattern
across every existing graph, and `pubspec.yaml` were audited:

- **`KnowledgeGraph` is purely transient** — rebuilt fresh from
  `AnythingKernel._lastAcquiredKnowledge` every `processIntent` call,
  never persisted. A World Graph wanting durable knowledge nodes must
  capture it at Kernel-call time via `KnowledgeGraphBridge`.
- **Only capabilities have a pre-existing, stable, cross-experience
  identity today** (`CapabilityDescriptor.id`). Entities, workflows,
  recommendations, and automations have zero persisted identity —
  `EntityIdentity` is the first system to give them one.
- **`ReviewMemory`/`EvolutionMemory`/RIL's memories are confirmed
  in-memory only** — zero SQLite/disk writes anywhere in
  `lib/design_review/`, `lib/evolution/`, or `lib/runtime_intelligence/`.
  `WorldMemory` follows the identical, already-established honesty
  pattern rather than claiming a durability none of them actually have.
- **`ModificationEngine.modify()` exposes no pre-flight hook** — any
  "analyze impact before modifying" logic must live in a wrapping
  coordinator, exactly how `EvolutionCoordinator`/
  `RuntimeIntelligenceCoordinator` already wrap it from outside.
- **Every existing graph shares one node/edge shape**: `DependencyNode`
  (V4) / `EvolutionGraphNode` (V7) / `RilNode` (V8) are all
  `{id, kind, label}`, with a graph-specific edge type. `WorldNode`
  mirrors this exactly, and every Bridge is a pure translation function
  — never a competing graph engine.
- **No graph-database, vector-search, or embedding dependency exists** —
  "semantic search"/"graph traversal" are built from plain Dart
  adjacency-list structures, exactly like every existing graph.

## Everything becomes a node — through one typed vocabulary

`WorldNodeKind`: experience, entity, capability, knowledge, workflow,
schedule, recommendation, evolution, review, automation, storage,
project, observation, learning. `RelationshipKind`: contains, references,
dependsOn, extends_, duplicates, derivedFrom, produces, consumes,
improves, replaces, relatesTo. Never a raw string, never inferred from a
keyword.

## Entity Identity — stable, without a database

`EntityIdentity` is either (a) `EntityIdentity.stable(kind, id)` —
reusing an already-stable id that exists elsewhere (a capability id, an
Experience id), or (b) `EntityIdentity.structural(kind, signature)` — a
deterministic fingerprint built from sorted, typed signature parts (an
entity's name + its field TYPE names, never data). Two structurally
identical things — a "Person" entity in one Experience and a "Person"
entity in an unrelated one — resolve to the exact same identity, purely
because they're the same *shape*. This satisfies "no duplicate
identities" as a mathematical property of the function, not a database
constraint, and stays fully deterministic (the milestone's own repeated
requirement) since it never depends on insertion order or a random UUID.
`EntityResolver` is the single place this decision is made.

## The Semantic Graph — a real projection, not a second graph

`SemanticGraph` is literally `WorldNode`/`WorldEdge` (`typedef
SemanticNode = WorldNode`), restricted via `GraphProjection` to the kinds
this milestone's own Semantic Graph section names (experience, entity,
knowledge, capability, workflow, plus the runtime-derived
observation/learning/recommendation/automation kinds). It can never drift
from the real `WorldGraph` because it IS the real `WorldGraph`, filtered.

## Graph operations

`GraphIndex` builds O(1) id→node/edge lookup maps once per graph.
`GraphTraversal` is a deterministic, bounded (never unbounded — always
stops at `maxDepth`) breadth-first walk that never revisits a node, so a
cyclic graph can never cause an infinite loop (tested directly).
`GraphQuery`/`GraphSearch` are the typed target of "Natural language ->
Semantic Query -> Graph Traversal -> Typed Results." `GraphProjection`/
`GraphView` produce real, bounded sub-graphs — the substrate for "show
everything related to X." `GraphUpdate` is the typed diff every Bridge
produces; `GraphMerge` combines updates with real conflict detection
(identical identity + identical kind/label deduplicates cleanly;
identical identity + different kind/label is a real, surfaced
`GraphConflict`, never silently overwritten); `GraphConsistency` checks
for dangling edges — the fail-closed gate `WorldPlanner` requires before
any update is considered approved.

## Impact Analysis and Dependency Analysis

`ImpactAnalyzer` answers "what depends on this / what breaks if this
changes / which Experiences use this" via real, bounded reverse graph
traversal over contains/references/dependsOn/consumes/produces/extends_
edges. `DependencyAnalyzer` is the forward counterpart. Neither is a
heuristic guess — both are `GraphTraversal` calls over real, already-
ingested edges.

## Semantic Search — honestly scoped

`SemanticQueryEngine.parseIntent()` is a minimal, deterministic
structural parser matching a small, fixed vocabulary of relationship
phrases ("depends on", "contains", "related") to a real
`RelationshipKind` — never an NLP or embedding engine (none exists as a
dependency, confirmed by audit). This milestone's own User Experience
section explicitly permits these capabilities to "remain internal in
V9" — the requirement satisfied here is that the typed
`GraphQuery -> GraphTraversal -> Typed Results` architecture exists and
works, proven directly by tests, not that free-text understanding does.

## World Memory, History, and Versioning

`WorldModelEngine.apply()` is Plan (review + merge via `WorldPlanner`) ->
Commit -> Version -> Record: an update is only ever applied if the merge
was clean AND the resulting graph is structurally consistent; a rejected
update leaves the model completely unchanged, never partially applied
(tested directly). Every successful apply advances `WorldVersion` and
records a `WorldSnapshot` into `WorldHistory` (append-only) and
`WorldMemory` (recall-by-version) — the same honestly-scoped, in-memory,
coordinator-instance-lifetime pattern already established for
`ReviewMemory`/`EvolutionMemory`/RIL's memories.

## Graph modifications must pass Review — reusing SCARE's philosophy

SCARE's own `DesignReviewEngine.review()` is bound to
`ReviewContext`/`ArchitectureCandidate` and cannot be re-invoked directly
on a `WorldGraph`. `GraphConsistency` is the fail-closed gate applied
here instead — the same review-before-commit philosophy SCARE
established, applied to graph structure specifically. When an update
originates from an `EvolutionProposal` or a `ReviewSession` finding, that
artifact **already passed SCARE** before reaching `WorldPlanner` — this
is real reuse of that prior approval, not a second review pass over the
same decision.

## Bridges — pure translation, never duplicate reasoning

- `KnowledgeGraphBridge`: `KnowledgeGraphNode`/`KnowledgeConceptLink` ->
  `knowledge`-kind `WorldNode`/`relatesTo` `WorldEdge`. Knowledge acquired
  through `package:webweavex` becomes graph nodes exactly as this
  milestone requires — never a second acquisition, extraction, or
  parsing implementation.
- `ExperienceGraphBridge`: a real, persisted `ExperienceMetadataRecord`+
  `ExperiencePackage` (read via the existing `SqliteExperienceRepository`)
  -> an `experience` node, `entity` nodes (structural fingerprint —
  name + field TYPE names, never data), `capability` nodes (stable
  capability id), and `contains`/`consumes` edges.
- `EvolutionGraphBridge`: a real `EvolutionRoadmap` (V7) -> `evolution`
  nodes and `improves` edges to the node each proposal would affect.
- `RuntimeGraphBridge`: a real `UsageGraph`/learned `LearningRecord`s
  (V8) -> `workflow`/`entity`/`capability` nodes with `relatesTo` edges
  carrying real co-occurrence-derived confidence, and `learning` nodes
  for every learned pattern.
- `ReviewGraphBridge`: a real Design Review `ReviewSession` (V6) ->
  `review` nodes related to the architecture element each finding
  concerns.

## Kernel Integration

No new mandatory `AnythingKernel.processIntent` stage was added.
`ReviewSession`/`EvolutionRoadmap` are already returned on
`ExecutionPlanReady`; `WorldModelCoordinator.ingestReviewSession()`/
`ingestEvolutionRoadmap()` consume them directly (proven in
`test/world_model/kernel_integration_test.dart` against a real
`AnythingKernel.processIntent()` run) — integration by reuse of
already-typed Kernel output, never a fabricated pipeline stage, matching
the exact same architecture decision already made for Evolution
Planning (V7) and Runtime Intelligence (V8).

## Modification Integration

`ModificationEngine.modify()` is never modified — `WorldModelCoordinator.
precheckModification(experienceId)` is a real, tested, separate call a
caller makes BEFORE invoking the existing `ModificationEngine`/
`ExperienceModificationCoordinator`, returning a real `ImpactReport` plus
the current graph's `GraphValidation`. This is the same "real capability,
not yet auto-wired into that pipeline" pattern already established for
`ReviewMemory` (V6), `EvolutionCoordinator`'s package-observation gap
(V7), and `ObservationEngine`'s `ExperienceHostScreen` non-wiring (V8).

## WebWeaveX and Kaalka

Unchanged, canonical, not duplicated. WMSG introduces no extraction,
crawling, parsing, or cryptographic logic of any kind — `KnowledgeGraph
Bridge` only ever translates `package:webweavex`-acquired resources
already converted into `KnowledgeGraphNode`s by the existing
`KnowledgeGraphBuilder`. Protected Experiences' protection metadata is
untouched; `ExperienceGraphBridge` reads only `ExperiencePackage.data`/
`capabilityDeclarations`, never `PackageIntegrity`/Kaalka-protected
envelopes.

## Strong typing

Every class in `lib/world_model/` uses real typed fields — enums,
`List<T>`, `EntityIdentity`/`RelationshipIdentity` value types — never
`Map<String, dynamic>` or `dynamic` in its public data model.

## Known limitations

- `EntityIdentity.structural` fingerprints are exact-match only: an
  evolution proposal's `affectedNodeId` (a raw entity/decision id) does
  not always align with `ExperienceGraphBridge`'s structural fingerprint
  (name + field types) for what is conceptually "the same" entity —
  `EvolutionGraphBridge` adds its own node for the affected id rather
  than silently guessing a match, documented honestly as a real,
  un-unified reference rather than papered over.
- `WorldMemory`/`WorldHistory` are scoped to whatever owns the
  `WorldModelCoordinator` instance's lifetime — not yet persisted across
  process restarts, exactly like every prior milestone's memory stores.
- `WorldModelCoordinator.precheckModification()` is real and tested but
  not yet auto-invoked by `ExperienceModificationCoordinator`/
  `ModificationEngine` — a caller must invoke it explicitly.
- `SemanticQueryEngine.parseIntent()` is a minimal, fixed-vocabulary
  structural parser, not natural language understanding — explicitly
  permitted to remain internal-only by this milestone's own User
  Experience section.
- `ObservationEngine`/`ExperienceHostScreen` still aren't auto-wired
  (a V8 limitation, unchanged by this milestone) — so `RuntimeGraphBridge`
  ingests whatever `UsageGraph`/`LearningRecord`s a caller already has,
  not a live, continuously-updating stream.
- `ingestKnowledge` — real since V9, but had zero real call sites until
  Implementation Milestone R2, which wired it into
  `AnythingKernel.processIntent` (reusing the `KnowledgeGraph` already
  computed for Feature Discovery) and fixed a real `KnowledgeGraphBridge`
  identity bug in the process. See
  `docs/architecture/KNOWLEDGE_ENGINE.md`'s "World Graph ingestion
  (Implementation Milestone R2)" section for the full account, including
  the honest limit of what "represent conflicting knowledge" achieves
  today (a real, surfaced `GraphConflict`, not a co-existing pair of
  nodes — `WorldNode`'s minimal shape has no confidence/freshness field
  to hold a second observation).
