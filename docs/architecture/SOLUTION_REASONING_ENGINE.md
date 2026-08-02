# Multi-Solution Reasoning & Architecture Selection Engine (MSRA) — Vision Milestone V5

## Overview

`lib/solution_reasoning/` sits between Feature Discovery (V4) and
Engineering (V3). Before V5, an approved architecture was the single,
deterministic output of `ArchitecturePlanner` + `RefinementPlanner` — there
was exactly one design, and Engineering had no alternative to compare it
against. MSRA makes the Kernel behave like a senior engineer: it proposes
multiple real, structurally distinct architecture variants, explains each
one's tradeoffs across 15 dimensions, scores them, reviews them for
defects, refines the set, and only then selects — via an explicit, ordered
tie-break cascade, never "first candidate wins" — the one Engineering
actually builds against.

Nothing about `ArchitecturePlanner`, `RefinementPlanner`, or
`EngineeringPlanner`'s core logic changed. MSRA reuses both unchanged: the
former runs exactly once per request to produce a self-critiqued baseline;
the latter runs once per *candidate* (inside Solution Generation) rather
than once per request.

## Pipeline

```
FeatureGraph (V4, unchanged) + SemanticApp
  │
  ▼
Architecture Exploration       -> ArchitecturePlanner.plan() +
  │                                RefinementPlanner.refine() (reused,
  │                                unchanged) produce ONE self-critiqued
  │                                baseline ArchitectureCandidate.
  ▼
Multi-Solution Generation      -> SolutionExplorer proposes 2-4 real
  │                                ArchitectureVariations as honest,
  │                                structurally-real overlays on the SAME
  │                                baseline (never a second architecture-
  │                                planning implementation):
  │                                  Balanced   — the baseline as planned
  │                                  Minimal    — search/filter/sort
  │                                               deliberately omitted
  │                                  Flat Navigation — every screen reachable
  │                                               directly from the entry
  │                                               screen (only proposed when
  │                                               there are >=3 screens)
  │                                  Offline First — fullyOffline/no-sync
  │                                               posture (only proposed
  │                                               when the baseline assumes
  │                                               network use)
  │                                SolutionGenerator materializes each into
  │                                a full SolutionCandidate: applies the
  │                                variation via ArchitectureCandidate.copyWith
  │                                (interactions/navigation/offline/
  │                                synchronization only — nothing else),
  │                                then runs EngineeringPlanner.plan() +
  │                                EngineeringRefinement.refine() ONCE for
  │                                that exact architecture.
  ▼
Tradeoff Analysis + Scoring    -> SolutionScorer computes a real, deterministic
  │                                SolutionScore (11 Confidence-typed
  │                                dimensions, each self-explaining via its
  │                                own `reason`) and a complete 15-dimension
  │                                SolutionTradeoff table per candidate —
  │                                every value traces to a real property
  │                                (ArchitectureVariation choice, Feature-
  │                                Complexity level, real Engineering/
  │                                Architecture confidence).
  ▼
Solution Review                -> SolutionReviewer detects duplicate/
  │                                equivalent/impossible/contradictory/
  │                                weak/over-engineered/incomplete
  │                                candidates, structurally.
  ▼
Solution Refinement            -> SolutionRefinement drops auto-fixable
  │                                critical candidates (duplicate/
  │                                impossible/contradictory/incomplete),
  │                                re-reviews, up to maxIterations=3 —
  │                                mirrors ASAE/AEE/FDI's proven-terminating
  │                                design, operating on a candidate *list*.
  ▼
Solution Selection              -> SolutionComparison builds a typed
  │                                SolutionGraph of pairwise dominates/
  │                                equivalentTo/alternativeTo edges;
  │                                SolutionSelector picks from the
  │                                Pareto-optimal frontier via an ordered
  │                                tie-break cascade (overall score ->
  │                                complexity -> security ->
  │                                maintainability -> offline -> user
  │                                experience -> engineering cost ->
  │                                confidence) — never "first candidate
  │                                wins."
  ▼
Engineering (unchanged) -> ExperienceSpec -> ExecutionPlan -> Creation -> Runtime
```

## Engineering consumes the SolutionGraph, not Architecture directly

The selected `SolutionCandidate.architecture` — never an independently
re-derived `ArchitecturePlanner.plan(app)` call — is the only architecture
that ever reaches `ArchitectureToBlueprintConverter`. There is no code path
in `AnythingKernel.processIntent` that bypasses Solution Reasoning to reach
a blueprint. `EngineeringPlanner`/`EngineeringRefinement` are likewise only
ever invoked from inside `SolutionGenerator`, as part of materializing a
candidate — the Kernel never calls them independently after selection.

## Architectural improvement: EngineeringPlan reuse, not recomputation

Per this milestone's own "prefer a cleaner, more general architecture"
directive: since every `SolutionCandidate` already carries its own real,
approved `EngineeringPlan` (computed once during Multi-Solution
Generation), `AnythingKernel` now **reuses**
`solutionDecision.selected.engineeringVariation.plan` directly rather than
calling `EngineeringPlanner.plan()` a second time after selection.
`EngineeringPlanner.plan()` is a pure function of its `EngineeringContext`,
so recomputing it for the already-selected candidate would have produced
byte-for-byte the same result at the cost of doing the work twice — this
change removes that redundancy without changing behavior, verified by
`test/solution_reasoning/kernel_integration_test.dart`'s `identical()`
check between `ExecutionPlanReady.engineeringPlan` and
`ExecutionPlanReady.solutionDecision!.selected.engineeringVariation.plan`.
As a direct consequence, `AnythingKernel` no longer holds its own
`ArchitecturePlanner`/`RefinementPlanner` fields at all — both now live
solely inside `SolutionExplorer`, which is the only place in the codebase
that ever plans or critiques a single architecture.

## Tradeoff Engine

Every `SolutionCandidate` carries exactly 15 `SolutionTradeoff` entries —
one per `TradeoffDimension` (complexity, maintainability, battery,
performance, memory, storage, network, offline, modificationCost,
testingCost, security, privacy, scalability, accessibility,
futureEvolution) — each with a real `direction` (advantage/disadvantage/
neutral) and a `rationale` naming the specific variation choice that
produced it. Nothing is arbitrary: a dimension that genuinely doesn't
differ between candidates today (storage, accessibility) is honestly
`neutral` with a rationale explaining why, rather than a fabricated
advantage.

## Solution Scoring

`SolutionScore` reuses `Confidence` (score + reason + risk) for every one
of its 11 dimensions (overall, engineering, architecture, maintainability,
runtime, performance, security, offline, userExperience, accessibility,
futureEvolution) — "explain every score" is enforced by the type itself,
not a convention every caller has to remember. `overall` is the real,
equal-weighted mean of the other 10; every other dimension traces to a
concrete property (a `FeatureComplexity` level, an `OfflineCapability`
choice, a real `ArchitectureCandidate`/`EngineeringCandidate` confidence).

## Solution Review — honest about dormant checks

Two of the seven review checks (`impossible`, `contradictory`) can never
actually fire against `SolutionGenerator`'s real output today — no
generated variation ever proposes `onlineRequired` without a network
capability, and "full" richness never strips interactions (only "minimal"
does). Both checks remain real, independently tested code guarding against
a hypothetical future generator defect, exactly the same "dormant but
real" pattern already established for V2's `StorageKind.credentialVault`,
V3/V4's `SecurityDecision.requiresCredentialVault`, and V4's
`conflictsWith` feature-relation check.

## Solution Selection — never "first candidate wins"

`SolutionSelector` first restricts to the Pareto-optimal frontier (no
candidate that is dominated — scores no better at no less complexity —
by another survives), then breaks ties with a fixed, ordered cascade.
`test/solution_reasoning/solution_selector_test.dart` proves this directly
by placing the objectively worse candidate first in the input list and
confirming it is never selected.

## No bypass

`AnythingKernel.processIntent` runs the full `SolutionExplorer.explore()`
pipeline for every `ReasoningReady` result, immediately after Feature
Discovery and before blueprint conversion; there is no path from a
`SemanticApp` to an `ExecutionPlanReady` outcome that skips it (verified in
`test/solution_reasoning/kernel_integration_test.dart`, and by the fact
that `test/stage10` + `test/stage11` — M1's real, novel-domain,
real-SQLite certification, 388 tests — pass unchanged with MSRA now
mandatory in that exact path). If solution refinement exhausts its budget
while critical issues remain (or, defensively, if every candidate were
somehow pruned), `processIntent` returns `PlanningFailed` — fail-closed,
matching every prior milestone's philosophy.

## WebWeaveX and Kaalka

Unchanged, canonical, not duplicated. MSRA introduces no extraction or
protection logic of any kind.

## Strong typing

Every class in `lib/solution_reasoning/` uses real typed fields —
`List<T>`, enums, nested value classes, `Confidence`/`FeatureComplexity`
reused directly from earlier milestones rather than reinvented — never
`Map<String, dynamic>` or `dynamic` in its public data model.

## Known limitations

- Storage and State are intentionally single-valued today (`StorageVariation`/
  `StateVariation` document this honestly): only one real storage backend
  and one deterministic, correct-by-construction state-assignment strategy
  exist in this codebase — there is no second real implementation to
  choose between yet.
- The four generated variations are a fixed, curated set (not a full
  combinatorial cross-product) — a deliberate choice matching how a senior
  engineer proposes "a few solid options," not an exhaustive grid.
- `SolutionRefinement` can only auto-fix issues it has an explicit fix for
  (duplicate/impossible/contradictory/incomplete); `weak` and
  `overEngineered` are warnings surfaced for visibility, not pruned.
- `SolutionScore.accessibility` is invariant across every candidate today
  (Flutter Material defaults apply equally regardless of architecture
  choice) — recorded honestly rather than fabricating a distinction.
