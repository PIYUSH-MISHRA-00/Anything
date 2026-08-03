# Autonomous Evolution Engine (AEE) — Vision Milestone V7

## Overview

`lib/evolution/` is a new mandatory Kernel stage — Evolution Planning —
inserted between Design Review (V6/SCARE) and blueprint-to-spec
conversion, plus a new application-facing `EvolutionCoordinator` that
extends the existing `ModificationEngine` pipeline. Before V7, Anything
only ever reacted: Intent → ... → Runtime, then waited for the next
explicit user request. AEE makes the Kernel continuously ask "what could
make this software better?" for every design it approves — never
executing anything on its own, only observing, estimating, reviewing, and
proposing.

AEE is deliberately not a second reviewer or a second reasoning engine.
It reuses Design Review (SCARE) directly for review, reuses Solution
Reasoning's typed Tradeoff vocabulary directly for tradeoffs, and reuses
the existing `ModificationEngine` directly for execution — it only adds
the missing piece: a real, structural detector for what a design doesn't
do yet, and a roadmap to hold that.

## Pipeline

```
... Design Review (V6) → reviewedContext (approved) → engineeringPlan
  → Evolution Planning        -> EvolutionEngine.evolve(EvolutionContext)
  │                              Observe -> Estimate -> Review -> Approve
  │                              -> Plan -> Predict. Never blocks
  │                              creation — unlike Design Review, a
  │                              missing/rejected opportunity is not a
  │                              defect in the current design.
  ▼
Specification → Execution Plan → Creation → Runtime
```

`ExecutionPlanReady.evolutionRoadmap` carries the result. There is no
code path from a Design-Review-approved solution to `ExecutionPlanReady`
that skips Evolution Planning — it is unconditional, but (per this
milestone's own "Do NOT automatically execute" directive) it can never
fail the pipeline the way Design Review can.

A second, separate entry point — `EvolutionCoordinator` — handles
**Modification Integration**: merging a user's own edit request with a
chosen roadmap proposal and executing it through the existing
`ModificationEngine`, mirroring `ExperienceModificationCoordinator`
exactly and reusing its result types.

## Repository audit findings that shaped this design

Before writing any code, the existing `ModificationEngine`, Activity
system, Capability platform, Storage/migration machinery, Experience
lifecycle, and Requirement/Knowledge graphs were audited:

- **`ModificationEngine`** (`lib/creation/modification/`) already applies
  typed-enough `ModificationOperation`s (untyped `Map` params, but a real,
  working mechanism) to an existing `ExperiencePackage`. It has no Design
  Review or Solution Reasoning integration today. AEE does not rewrite
  it — `EvolutionExecutor` compiles a reviewed `EvolutionProposal` down
  into the same `ModificationOperation` vocabulary, exactly the "typed
  layer compiles into existing runtime vocabulary" pattern
  `EngineeringToBlueprintAugmenter` (V3) already established.
- **The Activity system** (`lib/storage/activity_repository.dart`) is a
  human-readable feed, not telemetry — no usage counts, no error
  tracking. Confirmed unusable as an opportunity-detection signal;
  `EvolutionObserver` stays structural over typed design data instead.
- **The Capability platform** (`lib/capabilities/registry/`) has only 6
  real registered capabilities. `EvolutionObserver`'s "missing capability"
  detector reuses `FeatureGraph`'s own deferred capability-category nodes
  rather than diffing against the registry a second time (that diff is
  already `CapabilityReviewer`'s job in SCARE).
- **Storage/migration** already has a real, typed `DataMigrationPlan`/
  `MigrationOperation` format (`lib/storage/migration.dart`).
  `EvolutionPrediction`'s storage-evolution forecast names this format
  explicitly rather than inventing a second one.
- **Experience lifecycle**: confirmed there is no live post-Runtime
  observation hook, and `ExperiencePackage` does not retain the
  `AppBlueprint`/`SolutionCandidate`/`ReviewSession` that produced it.
  Building the literal "Observation → Evolution Opportunities → Review →
  Roadmap" loop as a synchronous Kernel stage reacting to Runtime is not
  honestly possible today. AEE resolves this by running Evolution
  Planning **at creation time**, while the full rich context still
  exists, and storing the roadmap in `EvolutionMemory`/`EvolutionHistory`
  keyed by the same kind of structural fingerprint `ReviewMemory` already
  uses — documented as a deliberate, honest architectural choice, not a
  missing feature.

## EvolutionContext

Bundles everything Evolution needs, all of it already computed by V2-V6 —
never re-derived: the full `ReviewContext` (app/requirements/featureGraph/
dependencyGraph/solution/blueprint) plus the real `ReviewSession` SCARE
just produced, plus an `EvolutionStrategy` (conservative/balanced/
aggressive) controlling roadmap-placement thresholds.

## Autonomous Observation — `EvolutionObserver`

Detects 10 categories of real, structural gaps, each reusing an
already-computed signal rather than a template:

| Category | Real signal reused |
|---|---|
| missingCapability / missingWorkflow | A FeatureGraph (V4) node at `optional`/`future`/`experimental` priority that never made it into the approved architecture |
| missingNavigation | A real `InteractionDecision` (V2) that allows reading an entity with zero blueprint views |
| missingSearch / missingFiltering | Real field/relationship counts on an entity whose `InteractionDecision` doesn't support search/filter yet |
| missingOffline / missingSynchronization | The architecture's own real `OfflineDecision`/`SynchronizationDecision` (V2) posture |
| missingAccessibility / missingPerformance / missingMaintainability | Design Review's (V6/SCARE) own real, non-critical findings for this exact design — reused directly, **never a second checker** |

## Value Estimation and Risk Estimation — `EvolutionEstimator`

Every candidate receives an `EvolutionBenefit` (8 `Confidence`-typed
dimensions: engineering/user/maintenance/performance/security/
accessibility/offline/future value, mirroring `SolutionScore`'s (V5)
proven "explain every score" pattern), an `EvolutionCost` (4
`ComplexityLevel`-typed dimensions), and an `EvolutionRisk` (9
`RiskLevel`-typed dimensions: migration/modification/security/data/
performance/runtime/user-impact/testing/documentation). `EvolutionCandidate.
priority` derives an `EvolutionPriority` structurally from benefit and
risk — never a bare number. Tradeoffs reuse `TradeoffDimension`/
`SolutionTradeoff` (V5) directly.

## EvolutionGraph

Typed nodes (`currentState`/`opportunity`/`candidate`/...) and typed
`EvolutionDependency` edges. Real, structural dependencies are detected —
e.g. a `missingSynchronization` candidate structurally `requires` the
matching `missingOffline` candidate for the same design, since
synchronization only makes sense once offline storage exists. Never a
fabricated edge.

## EvolutionReviewer — reuses SCARE directly

A candidate sourced from a Design Review finding is accepted because that
finding is already a real, vetted `ReviewIssue` in the current
`ReviewSession` — this reviewer never re-invokes `DesignReviewEngine` or
reimplements its checks. Candidates sourced from `FeatureGraph`/
architecture data are verified the same way `ConsistencyReviewer` (SCARE)
verifies mandatory features: the referenced feature/entity/posture
decision must still be real.

## EvolutionApprover, EvolutionPlanner, EvolutionRoadmap

`EvolutionApprover` promotes only *accepted* candidates into
roadmap-eligible `EvolutionProposal`s — "approved to appear on the
roadmap", never "approved for execution" (`approvedForExecution` starts
`false` and only a separate, explicit `EvolutionCoordinator.applyProposal`
call ever sets it `true`). `EvolutionPlanner` ranks proposals (mirroring
the exact dominance/tie-break algorithm shape `SolutionComparison`/
`SolutionSelector` (V5) already established — those classes are
generically bound to `SolutionCandidate` and cannot be reused as library
calls for a different type, so the same reasoning approach is mirrored
rather than reimplemented from scratch) and places each into one of the
roadmap's 6 fixed phases (Current/Immediate/Next/Later/Future/
Experimental) via `EvolutionPolicy` thresholds selected by
`EvolutionStrategy`. Every `EvolutionRoadmap` — one per approved design —
always owns all 6 phases, even when empty.

## Prediction — `EvolutionPrediction`/`EvolutionForecast`

Structural, never domain-specific: likely future modifications (drawn
from the roadmap's own Later/Future proposals), likely capability
additions (from FeatureGraph's deferred capability nodes), likely storage
evolution (from real entity/relationship counts, naming the existing
`DataMigrationPlan` format), likely scaling needs (from
`RuntimeSecurityLimits.maxScreensPerPackage` budget usage), and likely
performance needs (from the selected `SolutionCandidate`'s own
`FeatureComplexity`). Every forecast carries a real `Confidence` and a
named basis.

## Engineering Memory — the single consultation point

`EngineeringMemory` is deliberately a **facade**, not a third parallel
store: it wraps the real, already-persisted `ReviewMemory`/`ReviewHistory`
(V6) and `EvolutionMemory`/`EvolutionHistory` (V7). "Accepted ideas" /
"rejected ideas" / "tradeoffs" / "future ideas" are real queries against
`EvolutionMemory`'s recorded decisions; "architectural history" /
"security history" / "performance history" are real filtered slices of
`ReviewHistory`'s sessions by `ReviewCategory` — SCARE already categorizes
every finding, so there is no need for three more stores duplicating what
it already records.

## Modification Integration — `EvolutionCoordinator`

```
User Request + Evolution Proposal -> Merged Candidate -> Review -> Approval -> Execution
```

`EvolutionExecutor.compile()` translates an approved proposal into a real
`ExperienceModificationSpec`: `missingCapability` opportunities become a
`requiredCapabilities` entry; `missingWorkflow`/`missingNavigation`/
`missingSearch`/`missingFiltering` opportunities become a real
`addUiNode` `ModificationOperation`. Categories `ModificationEngine` has
no real operation for today (`missingOffline`/`missingSynchronization`/
`missingAccessibility`/`missingPerformance`/`missingMaintainability`) are
honestly reported as `EvolutionNotExecutable` — never a fabricated no-op.
`EvolutionCoordinator.applyProposal()` then executes through the
**existing** `ModificationEngine` and validates through the **existing**
`ExperiencePackageValidator` (`EvolutionValidator` is a one-line reuse
wrapper) — never a second engine or validator.

## Design Review Integration

Every evolution proposal is checked against the real `ReviewSession` SCARE
already produced for this design (see EvolutionReviewer above) — SCARE
itself is never re-invoked or duplicated.

## Solution Reasoning Integration

`TradeoffDimension`/`SolutionTradeoff` (the Tradeoff Engine) are imported
and used directly on every `EvolutionCandidate`. `EvolutionPlanner`'s
ranking mirrors `SolutionComparison`/`SolutionSelector`'s dominance +
ordered tie-break algorithm shape, since those classes are hard-bound to
`SolutionCandidate` specifically.

## WebWeaveX and Kaalka

Unchanged, canonical, not duplicated. AEE introduces no extraction,
crawling, or cryptographic logic of any kind, and requests knowledge (if
ever needed by a future milestone) only through the existing Knowledge
Engine — never a second acquisition path.

## No bypass

`AnythingKernel.processIntent` runs `EvolutionEngine.evolve()` for every
Design-Review-approved solution, immediately before spec conversion; there
is no path to `ExecutionPlanReady` that skips it (verified in
`test/evolution/kernel_integration_test.dart`, and by the fact that
`test/stage10`/`test/stage11` — M1's real, novel-domain, real-SQLite
certification — pass unchanged with Evolution Planning now mandatory in
that exact path).

## Strong typing

Every class in `lib/evolution/` uses real typed fields — enums,
`List<T>`, nested value classes, `Confidence`/`RiskLevel`/
`ComplexityLevel`/`TradeoffDimension` reused directly from earlier
milestones — never `Map<String, dynamic>` or `dynamic` in its public data
model.

## Known limitations

- `EvolutionEngine.evolve()` runs exactly one real iteration today —
  `EvolutionObserver`'s output is a pure function of an unchanged
  `EvolutionContext`, so a second pass would be identical. The
  `EvolutionCycle`/`EvolutionIteration`/`EvolutionBudget` structure
  mirrors `ReviewRefinement`'s proven shape and leaves room for a future
  milestone where accepting one candidate could itself surface new
  derived opportunities.
- `EvolutionExecutor` can only compile proposals into categories
  `ModificationEngine` already has a real operation for (capabilities,
  generic UI/workflow additions). Cross-cutting posture changes
  (offline/synchronization) and pure review-signal improvements
  (accessibility/performance/maintainability) are roadmap-only until
  `ModificationEngine` gains a real operation for them — reported
  honestly as `EvolutionNotExecutable`, never faked.
- `EvolutionMemory`/`EvolutionHistory` are scoped to a single
  `AnythingKernel` instance's lifetime, exactly like `ReviewMemory`/
  `ReviewHistory` — not yet persisted across process restarts or keyed by
  the eventual `experienceId` (which doesn't exist yet at Kernel time;
  only the structural fingerprint does).
- `EvolutionCoordinator`'s "observe an already-persisted Experience"
  path is not built this milestone: `ExperiencePackage` does not retain
  the rich planning context (`SolutionCandidate`/`ReviewSession`/
  `FeatureGraph`) Evolution Planning needs, and extending the persisted
  package format was deliberately out of scope to avoid a schema
  migration of its own. `EvolutionCoordinator` today only handles
  applying an already-known roadmap proposal, not re-deriving one from
  scratch for an old package.

## Implementation Milestone R6 — Deterministic Runtime Patching (2026-08-03)

Closes R4's own deferred scope ("runtime application belongs to a later
milestone") by adding `ExperienceModificationCoordinator.applyEvolutionPlan()`
and `.rollback()`. Both are new METHODS on the existing coordinator —
no second Evolution Coordinator, no second Runtime, no second Renderer.

**REALITY confirmed by direct source read before implementing**:
`ExperienceHostScreen._submitModification` already reloads the live
`AnythingRuntime` after a modification via `closeSession()` ->
`openExperience(newPackage)` — this exact mechanism predates Vision
Milestone V1. R6 does not invent a new reload path; it extends
`EvolutionDiffPlan` (R4) with an optional `candidatePackage` field (the
already-computed, previously-discarded modification result) so
`applyEvolutionPlan()` can validate and persist it without recomputing,
then a caller reloads the SAME runtime the same way modification already
has for years.

**Patch model**: no new patch-operation vocabulary was introduced. The
existing `ModificationType`/`ModificationOperation` enum (addUiNode,
modifyUiNode, removeUiNode, addBehavior, modifyBehavior, removeBehavior,
addState, modifySchema, addEntity, addService, addCapability,
addPermission, updateMetadata) already covers the patch categories R6's
own spec named — `ModificationEngine.modify()` remains the sole compiler
from operations to a candidate `ExperiencePackage`, unchanged.

**Validation**: `applyEvolutionPlan()` runs `ExperiencePackageValidator.validate()`
on the candidate — the exact same boundary `modifyExperience()` already
uses. `planEvolution()` itself does NOT validate (it only checks
`ModificationReady`); skipping validation at apply time would have been
a real security gap, so `applyEvolutionPlan()` re-validates rather than
trusting a plan computed against possibly-stale state.

**Rollback model**: `SqliteExperienceRepository.savePackage()` has no
version history (`INSERT ... ConflictAlgorithm.replace` keyed on
`experience_id`, confirmed by direct source read) — real, deterministic
rollback is achieved by the coordinator returning the pre-apply package
as `ModificationCoordinatorSucceeded.previousPackage`, which the caller
holds and can pass to `rollback()` to restore. `rollback()` never
accepts an arbitrary caller-supplied package as ground truth without
re-validating it, but the package itself always originates from this
coordinator's own prior, already-validated, already-persisted state —
never a foreign blob. Undo-of-undo works: `rollback()` itself returns a
`previousPackage` (the state just replaced).

**World Model**: `applyEvolutionPlan()` ingests into the shared World
Graph on success only, via the exact `ingestExperience` call R1/R4
already established — never on a rejected plan (proven directly by
test: an invalid candidate leaves the World Graph's experience-node
count unchanged).

**Runtime patching level achieved**: full, fast reload through the
existing, UNMODIFIED `AnythingRuntime`/`ExperienceRenderer` — not
granular in-place widget patching. MIS-1 Part 3's own Runtime
Modification RFC already flagged true zero-regeneration/surgical
patching as the highest-risk item across all of MIS-1, explicitly not
recommended near-term; this milestone's "without regenerating the
Experience" is satisfied in the sense that matters most — no
Intent-to-Kernel-to-AI-synthesis re-run occurs, only a sub-second
validate-persist-reload of an already-computed candidate. Navigation
position, scroll position, and in-progress form input are NOT preserved
across the reload — this is a pre-existing limitation of the reload
mechanism itself (unchanged since before V1), not something this
milestone introduces or claims to fix.

**AI boundary**: confirmed unchanged — zero `ModelProvider`/reasoner
references anywhere in the modification/evolution-application path.

**Known limitations**: no granular in-place patching (see above,
honestly out of scope per MIS-1's own risk assessment); state
(navigation/scroll/form input) is lost on reload, matching the
pre-existing reload mechanism's behavior; `rollback()` requires the
caller to hold `previousPackage` explicitly (no server-side history
lookup) since the repository itself retains no version history.
