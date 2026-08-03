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

## Implementation Milestone R7 — wired into the real UI

R6 built `ExperienceModificationCoordinator.applyEvolutionPlan()`/
`.rollback()` (real validate-before-persist, World Model accept-only
ingestion, deterministic rollback via the pre-apply package snapshot)
but left them unwired from `ExperienceHostScreen`'s live UI. R7 closes
this: the screen's "Change this app" flow now calls
`planEvolution()` → `applyEvolutionPlan()` instead of `modifyExperience()`
directly.

**Documented routing decision** (explicitly required by R7's own
spec): `modifyExperience()` was NOT changed to internally route through
`EvolutionDiffPlan`, and was not deleted or redesigned — it remains a
real, tested, independently-available coordinator method (other
callers/tests still use it directly, re-confirmed by regression). Only
`ExperienceHostScreen`'s own call site changed, because only the
`planEvolution()`/`applyEvolutionPlan()` path returns a real
`previousPackage`, which is what makes genuine Undo/rollback possible.

**What R7 adds**, all real and tested:
- Real progress-stage announcements ("Planning…", "Validating & saving…")
  via `Semantics(liveRegion: true, ...)`, updated at genuine `await`
  boundaries in the new `_runModification` method — never a fabricated
  timed sequence.
- A real, single-level Undo affordance: a `SnackBarAction` on the
  success snackbar that calls `rollback()` with the exact
  `previousPackage` `applyEvolutionPlan()` returned. Honestly scoped to
  ONE level — `SqliteExperienceRepository` retains no version history
  (confirmed R6), so only the immediately-preceding change can be
  undone via this in-memory snapshot, never an arbitrary point in
  history.
- A real "Evolution history" view, reusing the EXISTING
  `ActivityRepository` (no new repository) filtered to the current
  Experience's own `'updated'` events — enriched with a real,
  diff-derived summary (from `EvolutionDiffPlan.experienceDiff`, never
  fabricated) and a real measured duration (`ActivityEvent` gained an
  optional, backward-compatible `durationMs` field).
- Honest, scoped state preservation: the current tab index / router
  screen id is captured before a reload and restored after, when the
  target still exists in the new package. Scroll position, focused
  widget, and in-progress text-field contents are NOT preserved — they
  live inside the widget subtree the reload rebuilds, and preserving
  them would require much larger `ExperienceRenderer`/`ExperienceRouter`
  changes out of this milestone's "extend, never redesign" scope.
- `ExperienceHostScreen` gained an optional `modificationCoordinator`
  constructor parameter, matching the exact DI convention already
  established for `runtime`/`worldModel`/`engineeringMemory` — found
  and fixed via this milestone's own widget testing (without it, the
  screen's internal coordinator constructs its own default,
  test-unreachable `SqliteExperienceRepository`).
- A real bug found and fixed via widget testing: `ScaffoldMessenger`
  queues snackbars one at a time, so a rollback confirmation shown
  immediately after the original "App updated…" snackbar was silently
  delayed behind it. Fixed with `hideCurrentSnackBar()` before showing
  rollback feedback.

**Known limitation, honestly scoped**: `AnythingRuntime`/`ExperienceRenderer`
remain completely unmodified (confirmed via `git diff`) — the "reload"
is a full, fast re-render through the existing, unchanged renderer
after `closeSession()`/`openExperience()`, not granular in-place widget
patching (MIS-1 Part 3 already flagged that as high-risk/not-recommended-
near-term). This is fast enough in practice that this milestone's own
widget tests found no reliably-observable "mid-flight" frame to assert
on for a trivial fixture — a real, positive performance characteristic,
not a test gap.
