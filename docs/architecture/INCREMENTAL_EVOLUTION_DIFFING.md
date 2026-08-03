# Incremental Software Evolution & Deterministic Graph Differencing — Implementation Milestone R4

## Overview

R4 completes the diff-chain infrastructure R3 deliberately deferred:
real, typed, deterministic structural diffs for `ArchitectureCandidate`,
`EngineeringCandidate`, and `ExperiencePackage` (`RequirementGraph`'s
diff already shipped in R3 and is unchanged here), composed into a new
`EvolutionDiffPlan` and wired into `ExperienceModificationCoordinator`
as a real, planning-only capability. No runtime patching — applying a
plan to a live, running Experience remains explicitly out of scope
(deferred, per this milestone's own instruction, to a later milestone).

## Why not extend `EvolutionProposal`/`EvolutionRoadmap`?

This was the milestone's central architectural question, investigated
before any code was written. Vision Milestone V7's `EvolutionCandidate`/
`EvolutionProposal` chain requires an `EvolutionOpportunity` (something
`EvolutionObserver` itself detected) plus `EvolutionCost`/`EvolutionRisk`/
`EvolutionBenefit` *estimates* — it answers "what SHOULD change and is it
worth it." Forcing an already-diffed, explicitly-requested modification
into that shape would mean fabricating an opportunity and cost/benefit
scores for something that isn't a proactive suggestion at all — a
violation of "no fabricated data," not a service to "never build a
parallel Planner." `EvolutionDiffPlan` (`lib/evolution/evolution_diff_plan.dart`)
answers a genuinely different, complementary question: "given a change
that's already been decided, what is the exact, ordered, deterministic
sequence of structural mutations, with real rollback data." It reuses
`RiskLevel` (`lib/software_architect/confidence.dart`) directly for
`EvolutionMutation.expectedImpact` rather than inventing a parallel
severity scale, and is deliberately NOT named `EvolutionPlan` to avoid
implying it replaces or duplicates `EvolutionRoadmap`.

## The four diff types

All four follow the identical structural comparison pattern
`RequirementGraphDiffer` (R3) established: list-shaped items are
compared by their own real identity field; a same-identity content
mismatch is surfaced as an explicit remove+add pair, never a silent
overwrite (matching `GraphMerge`'s V9 philosophy).

- `RequirementGraphDiff`/`RequirementGraphDiffer` — R3, unchanged.
- `ArchitectureDiff`/`ArchitectureDiffer` (`lib/software_architect/architecture_candidate_diff.dart`)
  — diffs `ArchitectureCandidate`'s list-shaped decisions (entities,
  fields, relationships, capabilities, permissions) by identity; its
  three singular decisions (security/offline/synchronization) are
  represented as a real before/after pair only when genuinely different.
- `EngineeringDiff`/`EngineeringDiffer` (`lib/application_engineering/engineering_candidate_diff.dart`)
  — `EngineeringCandidate` is shaped differently: most dimensions are ONE
  singular result each (no independent identity), so each is represented
  as a real "changed: yes/no" pair via its own `EngineeringDecision.decision`
  string; the two genuinely list-shaped dimensions (`validations`,
  `bindingGraph.edges`) get the real id-keyed add/remove treatment.
- `ExperienceDiff`/`ExperienceDiffer` (`lib/creation/experience_package_diff.dart`)
  — operates on `ExperiencePackage` (the real, persisted artifact), not
  `ExperienceSpec` (a transient, Kernel-internal type) — this is what
  `ExperienceModificationCoordinator` actually has a real before/after
  instance of. Diffs screens/components (flattened, by id) and
  capability/service declarations; behavior/state/data-schema changes
  are a coarse but real, deterministic `toJson()`-content comparison.

## `ExperienceModificationCoordinator` integration

Two additive changes, both backward-compatible:

1. **`planEvolution(experienceId, modificationExpression)`** — a new,
   planning-only method reusing the exact same `_parseOperations`/
   `ModificationEngine.modify()` pure-function path `modifyExperience`
   already uses, but stopping before persistence: no `savePackage`, no
   activity record, no World Model ingestion. Returns a real
   `EvolutionDiffPlan` built from the real `ExperienceDiff` between the
   current and candidate package.
2. **World Model ingestion on acceptance** — `modifyExperience`'s
   success branch now calls `_worldModel.ingestExperience(metadata,
   result.updatedPackage)`, closing MIS-1 Part 2's finding that this
   ingest method (outside the bulk-load helper) had zero real call
   sites. Best-effort and defensive, mirroring R1/R2/R3's
   `_ingestIntoWorldModelSafely` contract exactly — an ingestion failure
   never surfaces as a modification failure. A rejected modification
   returns before this line is ever reached, so the World Graph is
   never mutated on rejection (proven directly by test).

## Known limitations

- `planEvolution` only populates `ExperienceDiff`. `RequirementGraph`/
  `ArchitectureCandidate`/`EngineeringCandidate` are transient,
  Kernel-internal, per-request artifacts — never persisted per
  Experience — so `ExperienceModificationCoordinator` has no real
  "before" instance of them to diff against without re-running
  Kernel-level planning, which is out of this milestone's scope.
  `EvolutionDiffPlanBuilder.build()` accepts these three diffs as
  optional parameters for a future caller that does have both instances
  (e.g., a re-run Kernel planning pass).
- No runtime patching exists or is implied — a computed `EvolutionDiffPlan`
  is inspectable data only; applying it to a live Experience remains a
  future milestone's scope.
- `EngineeringDiff`'s coarse "changed: yes/no" representation for
  singular dimensions (data/navigation/interaction/persistence/offline/
  synchronization/security) does not enumerate exactly which nested
  field changed — a real, honest scope boundary given
  `EngineeringCandidate`'s shape has no independent identity for these
  dimensions to diff more granularly.
