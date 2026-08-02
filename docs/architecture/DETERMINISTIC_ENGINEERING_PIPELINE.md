# Deterministic Engineering Pipeline — Implementation Milestone R3

## Overview

R3's own spec framed its objective as "transform Anything from an
AI-assisted generator into an AI-driven software engineering system."
Investigation (per Rule 3, "reality wins," and the discipline R2 already
established) found this transformation was **already substantially
complete** before this milestone started — eleven Vision Milestones had
already built exactly one mandatory LLM call site plus a fully
deterministic downstream pipeline. R3's real, scoped work was: (1)
formally verify and document that this is true, (2) close two genuine,
narrow gaps (Knowledge/Software Cognition and World Model data existed
but did not yet influence engineering decisions), and (3) add a real,
tested, planning-only Requirement Graph diff — the first piece of
"Incremental Engineering" infrastructure, with Architecture/Engineering/
Experience diff explicitly deferred rather than built half-finished.

## Investigation findings (verification only — no code changed for these)

- **AI Boundary**: exactly one call site, `_reasonWithKnowledgeLoop`
  (`lib/kernel/anything_kernel.dart`, Kernel Step 5). Every subsequent
  stage (5.5 through 11) is deterministic Dart — re-verified by grep
  across `lib/software_architect/`, `lib/application_engineering/`,
  `lib/feature_discovery/`, `lib/solution_reasoning/`,
  `lib/design_review/`, `lib/evolution/`. One harmless false-positive
  found and confirmed: `ArchitectureToBlueprintConverter.convert()`
  threads an `ApplicationReasoner` reference into `SynthesisPlanner`'s
  constructor, but only ever calls `SynthesisPlanner.convertToBlueprint()`
  — a different method from the one that calls `.reason()` — so no
  second AI call actually occurs on this path.
- **Architecture Graph**: `ArchitectureCandidate` (`lib/software_architect/`,
  produced by Solution Reasoning at Kernel Step 6) already IS the real,
  typed representation of layers/modules/dataflow/navigation/storage/
  capabilities/security R3 asked for. No parallel graph built.
- **Engineering Graph**: `EngineeringPlan`'s typed `EventGraph`/
  `StateMachine`/`BindingGraph` output (`lib/application_engineering/`,
  assembled by `EngineeringPlanner` from 13 modules) already IS the real
  representation of component/storage/capability-binding/state-ownership/
  validation/routing decisions R3 asked for. No parallel graph built.
- **Capability Resolution determinism**: Kernel Step 8's
  `CapabilityRegistry.resolve(capabilityIds)` was already deterministic
  (no reasoning pass) — re-confirmed, unchanged.
- **Engineering Cache**: investigated and deliberately NOT built.
  `KnowledgeAcquisitionEngine`'s cache pays off because the same query/
  URL genuinely repeats across sessions. `SemanticApp` (the input to
  Requirement/Architecture/Engineering planning) is LLM-derived and
  request-unique — two independent user requests essentially never
  produce a structurally identical `SemanticApp`, so a cache here would
  have a real-world hit rate near zero. Building one anyway would be
  speculative complexity with no measurable benefit (YAGNI) — skipped;
  revisit only if profiling ever shows `RequirementExtractor`/
  `ArchitecturePlanner`/`EngineeringPlanner` as an actual hot path.

## What was genuinely built

### Knowledge / Software Cognition → Feature Discovery confidence enrichment

`FeatureConfidenceAnalyzer.analyze()` (`lib/feature_discovery/feature_confidence_analyzer.dart`)
gained two optional, additive parameters:
- `knowledge: KnowledgeGraph?` — when a real, non-empty `KnowledgeGraph`
  is present (the SAME type Knowledge acquisition and Software Cognition
  both already produce via R1's `seedKnowledge`/R2's
  `KnowledgeGraphBuilder` — one path, never a parallel one), its nodes'
  mean `trust.confidence` nudges the overall Feature Discovery confidence
  by a small, bounded amount (±0.1 max), centered on neutral trust (0.5)
  so genuinely low-trust knowledge can lower confidence, never a
  one-directional "knowledge exists therefore confident" fallacy.
- `priorCapabilityIds: Set<String>` — capability ids already observed as
  real `WorldNodeKind.capability` nodes in the World Graph nudge
  confidence up by a small, bounded amount (+0.05), since a capability
  the user has genuinely used before is real corroborating evidence.

Both signals are structural (numeric trust scores, set membership) —
never textual/keyword matching, preserving Vision Principle 1. Omitted
entirely, `analyze()`'s output is byte-for-byte identical to pre-R3.

Wired via `FeatureDiscoveryContext.priorCapabilityIds` (new field, empty
by default) and `FeatureDiscoveryEngine.plan()` (passes both signals to
the confidence analyzer).

### World Model read-enrichment (new, the reverse of R2's write path)

`AnythingKernel._priorCapabilityIdsSafely()` — the read-side counterpart
to R1's `_ingestIntoWorldModelSafely()`: queries
`_worldModel?.model.graph.nodesOfKind(WorldNodeKind.capability)` for
this session's capability labels, returning an empty set on any failure
or when no `_worldModel` is injected. Called once, right before Feature
Discovery. A World Model read failure can never break generation, the
same defensive contract R1/R2 already established for writes.

Deliberately scoped to ONE concrete, testable signal (capability
familiarity) rather than an open-ended "learned patterns" claim — a
concrete, real, falsifiable enrichment beats a vague, unfalsifiable one.

### Requirement Graph Diff — Incremental Engineering, planning-only

New file `lib/software_architect/requirement_graph_diff.dart`:
`RequirementGraphDiff` (added/removed nodes, added/removed relations) and
`RequirementGraphDiffer.diff(before, after)` — a real, deterministic,
structural comparison mirroring `GraphMerge`/`GraphConflict`'s
already-established shape (Vision Milestone V9): nodes compared by id,
a same-id-different-content node is an explicit remove+add pair (never a
silent overwrite), relations compared by their full `(fromId, toId,
type)` triple. Measured on a 500/500-node synthetic diff: ~1ms.

**Explicitly planning-only**, per R3's own scope: this computes what
changed, it does not apply anything to a running Experience — that
belongs to R5's "runtime patching." Architecture/Engineering/Experience
Diff are a natural, scoped extension of this exact pattern, deliberately
deferred (Rule 6, "no TODO architecture" — one complete, tested diff
type beats four incomplete ones) rather than built under this
milestone's time budget.

## Known limitations

- Only `RequirementGraphDiff` was built; `ArchitectureDiff`/
  `EngineeringDiff`/`ExperienceDiff` are a real, scoped R4+ candidate,
  not started.
- The diff chain is not wired into `ExperienceModificationCoordinator` or
  any UI flow — a real, tested, standalone capability, matching the same
  "not yet wired into every flow" pattern established for Software
  Cognition/Runtime Intelligence in prior milestones.
- World Model read-enrichment is scoped to capability familiarity only —
  "user preferences" and "learned patterns" beyond capability usage are
  not implemented; a genuinely bounded, real query would need to be
  designed per-signal, the same way this one was, not fabricated wholesale.
