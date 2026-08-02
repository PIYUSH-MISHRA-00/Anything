# Feature Discovery & Dependency Intelligence Engine (FDI) — Vision Milestone V4

## Overview

`lib/feature_discovery/` sits between the existing `RequirementGraph`
(V2's `RequirementExtractor`) and Architecture Planning. Before V4,
Anything engineered exactly what the requirement graph described — every
entity/field/view/action/capability the reasoner emitted, nothing more.
FDI adds a real, typed, structural discovery pass that surfaces
cross-cutting features implicit in the app's *shape* — search, indexing,
relational navigation, permission strategy, offline posture, reporting —
before Architecture ever runs, and hands the resulting `FeatureGraph` to
both Architecture (implicitly, via the requirement/knowledge graphs it
already consumed) and Engineering (explicitly, via `EngineeringContext`).

Nothing about `RequirementExtractor`, `ArchitecturePlanner`, or
`EngineeringPlanner`'s core signal path changed — FDI is a genuine,
mandatory additional stage, not a replacement for any of them.

## Pipeline

```
RequirementGraph (V2, unchanged) + KnowledgeGraph (if knowledge acquired)
  │
  ▼
FeatureDiscoveryEngine.discover() -> FeatureCandidate list, one rule per
  │   structural signal: one Data + one Persistence feature per entity;
  │   one Relational feature per reference field; one Search + one Index
  │   feature per list-type view; one Capability feature per required
  │   capability; one aggregate Navigation/Validation/State feature when
  │   their trigger nodes exist; one Reporting feature per derived value;
  │   one Offline Strategy feature (always); one Data Protection (Kaalka)
  │   feature (always); a Permission Strategy feature when a permission-
  │   requiring capability is present; a (today dormant) Credential
  │   Storage feature when a credential-requiring capability is present.
  ▼
FeatureClassifier               -> de-duplicates candidates sharing an id,
  │                                 merging evidence rather than dropping it
  ▼
FeatureDiscoveryEngine._buildEdges -> feature-to-feature FeatureEdges:
  │                                 Search --requires--> Index --requires-->
  │                                 Persistence; Capability --dependsOn-->
  │                                 Permission Strategy / Credential
  │                                 Storage; Credential Storage --requires-->
  │                                 Data Protection + Permission Strategy;
  │                                 Relational/Reporting --dependsOn-->
  │                                 the owning entity's Persistence;
  │                                 Offline --dependsOn--> every Persistence
  ▼
FeaturePriorityAnalyzer + FeatureComplexityAnalyzer -> one FeatureDecision
  │                                 + FeatureComplexity per candidate
  ▼
FeatureConfidenceAnalyzer       -> real mean of every FeatureDecision's
  │                                 own confidence -> FeatureGraph.overallConfidence
  ▼
FeatureReviewer                 -> FeatureReviewResult (typed issues:
  │                                 duplicate/dangling/conflicting/
  │                                 impossible/lowConfidence features)
  ▼
FeatureRefinement                -> FeaturePlan (loops: fix auto-fixable
  │                                 critical issues, re-review, up to
  │                                 maxIterations=3; mirrors ASAE's and
  │                                 AEE's proven-terminating design)
  ▼
Architecture (unchanged) -> Engineering (now receives EngineeringContext.
                             featureGraph = FeaturePlan.finalGraph)
```

## Dependency Graph — a separate, lower-level model

`DependencyGraph`/`DependencyNode`/`DependencyEdge` model what a
`FeatureGraph` edge does *not*: the concrete primitive (capability,
permission, storage, navigation) a feature ultimately bottoms out in — not
another feature. `DependencyGraphBuilder` runs five `DependencyResolver`s
(`StorageDependencyResolver`, `CapabilityDependencyResolver`,
`PermissionDependencyResolver`, `NavigationDependencyResolver`,
`OfflineDependencyResolver`) over every `FeatureCandidate`, assembling one
node per feature plus one per unique concrete primitive, and one typed
edge per resolved `FeatureDependency`. This is the graph that realizes the
milestone's example chain literally: `Search --requires--> Index
--requires--> Persistence --requires--> storage:sqlite`.

## Capability Discovery — honest, not fabricated

Every required capability becomes a `FeatureCategory.capability` feature.
Its priority is decided by whether this codebase actually implements it
(Clock/Notifications/HTTP/AI/Knowledge/File — the same six capabilities
`docs/security/CAPABILITY_SECURITY_MATRIX.md` documents): implemented +
explicitly requested -> mandatory; implemented + inferred -> recommended;
**not implemented -> `FeaturePriority.experimental`, confidence 0.0** —
mirroring V2's `CapabilityPlanner.resolved = false` pattern exactly, never
fabricated as available.

## The Authentication -> Credential Storage -> Kaalka -> Permission Strategy chain

This example from the milestone's brief is implemented as real, tested
code with a **documented, currently dormant trigger** — matching the same
honesty pattern already established for `StorageKind.file`/`credentialVault`
(V2) and `SecurityDecision.requiresCredentialVault` (always `false` today,
V2/V3): no capability implemented in this codebase resolves credentials,
so `FeatureDiscoveryEngine.credentialRequiringCapabilities` (`{'oauth',
'accounts'}`) never fires in production. The chain is proven correct via
`test/feature_discovery/dependency_resolver_test.dart` and
`feature_priority_complexity_test.dart` using those ids directly as test
fixtures — the same technique V2's capability tests use for `'bluetooth'`.

## Why Feature Discovery doesn't take an ArchitectureCandidate

The milestone's own pipeline diagram places Feature Discovery *before*
Architecture (`RequirementGraph -> KnowledgeGraph -> Feature Discovery ->
Review -> Refinement -> Architecture`). Taking an `ArchitectureCandidate`
as an input would therefore create a circular dependency (Architecture
would need to run before the stage that's supposed to run before it).
`FeatureDiscoveryContext` instead carries the `SemanticApp` + real
`RequirementGraph` (+ optional `KnowledgeGraph`) — the same inputs
`RequirementExtractor` itself consumes — which is exactly the right level
of structural detail FDI's rules need (entity/field/view/capability shape,
non-functional offline/security signals), without needing Architecture's
already-planned interaction/storage/security decisions.

## Engineering now consumes FeatureGraph

`EngineeringContext.featureGraph` (optional, for backward compatibility
with pre-V4 test fixtures — the Kernel unconditionally supplies a real,
approved one in production) is genuinely read, not merely carried:
`DataEngineering.plan()` corroborates its index recommendation (raising
confidence from 0.7 to 0.85) whenever a matching Index feature was
independently discovered for that entity; `OfflineEngineering.plan()`
cites the discovered Offline Strategy feature's priority directly in its
rationale. Both cross-references are additive — the underlying decision
(which index to recommend, which offline strategy to pick) is still made
from the real `ArchitectureCandidate`/`SemanticApp`, exactly as before this
milestone; FeatureGraph corroborates and explains, it does not override.

## No bypass

`AnythingKernel.processIntent` runs `FeatureDiscoveryEngine.plan()` and
`FeatureRefinement().refine()` for every `ReasoningReady` result,
immediately after requirement extraction and before Architecture Planning;
there is no code path from a `SemanticApp` to an `ExecutionPlanReady`
outcome that skips it (verified in
`test/feature_discovery/kernel_integration_test.dart`, and by the fact
that `test/stage10` + `test/stage11` — M1's real, novel-domain, real-SQLite
certification, 388 tests — pass unchanged with FDI now mandatory in that
exact path). If feature refinement exhausts its budget while critical
issues remain, `processIntent` returns `PlanningFailed` — fail-closed,
matching ASAE's, AEE's, and the knowledge loop's existing philosophy.

## WebWeaveX and Kaalka

Unchanged, canonical, not duplicated. FDI introduces no new extraction or
protection logic; its Kaalka-related "Data Protection" feature and
Credential Storage chain are records of the existing, audited posture (see
above), never a reimplementation.

## Strong typing

Every class in `lib/feature_discovery/` uses real typed fields — `List<T>`,
enums (`FeatureCategory`, `FeaturePriority`, `ComplexityLevel`,
`FeatureRelationKind`, `DependencyNodeKind`), nested value classes — never
`Map<String, dynamic>` or `dynamic` in its public data model.
`FeatureComplexity`'s nine cost dimensions are all the bounded
`ComplexityLevel` enum (`none`/`low`/`medium`/`high`), never a raw,
uncalibrated number.

## Known limitations

- `FeatureDiscoveryContext.knowledge` is accepted for future use; no
  current discovery rule consumes a `KnowledgeGraph` node, since no
  current node type structurally implies a first-class feature beyond
  what the app's own entity/field/view/capability shape already captures.
- `FeatureRefinement` can only auto-fix issues it has an explicit fix for
  (duplicate features, dangling edges); conflicting-feature and
  low-confidence issues fail closed rather than being fabricated as fixed
  (no discovery rule currently produces a `conflictsWith` edge, so that
  check is real, tested, dormant code — the same pattern as the
  credential-storage chain above).
- The "LMS -> authentication/courses/lessons/roles" example in the
  milestone brief describes semantic domain understanding an LLM
  provides, not structural graph analysis — FDI deliberately does not
  pattern-match domain words (that would violate "no domain hardcoding"),
  so features like "authentication" are only discoverable once a real
  signal for user-identity/credentials exists in the requirement graph;
  today none does, and this is recorded honestly above rather than faked.
