# Self-Critique & Autonomous Design Review Engine (SCARE) — Vision Milestone V6

## Overview

`lib/design_review/` is a new mandatory Kernel stage inserted between
Solution Reasoning (V5) and blueprint conversion. Before V6, the selected
`SolutionCandidate` — already self-critiqued by V2's `SelfCritic`, V3's
`EngineeringReview`, V4's `FeatureReviewer`, and V5's `SolutionReviewer` —
flowed straight into `ArchitectureToBlueprintConverter`. Each of those
reviewers only ever saw its own slice of the design in isolation. SCARE is
the first stage that reviews the *combined*, fully-selected
Architecture + Engineering + Blueprint together, and it is a hard gate:
`AnythingKernel.processIntent` returns `PlanningFailed` if Design Review
does not reach `ReviewOutcome.approved`.

SCARE is deliberately not a second planner. It never proposes an
alternative design (that is Solution Reasoning's job) and never re-derives
requirements or features. It only inspects what earlier stages already
decided, flags structural defects, applies a narrow set of safe automatic
fixes, and either approves or fails closed.

## Pipeline

```
Intent → Requirements → Knowledge → Feature Discovery → Solution Exploration
  → Engineering (produced as part of Solution Exploration, V5)
  → Design Review          -> DesignReviewEngine.review(ReviewContext)
  │                            DesignReviewer runs 15 sub-reviewers over the
  │                            SAME ReviewContext (SemanticApp + Requirement
  │                            Graph + FeatureGraph + DependencyGraph +
  │                            SolutionCandidate + AppBlueprint).
  ▼
  Review Refinement        -> ReviewRefinement re-runs the reviewers after
  │                            applying every autoFixable issue found,
  │                            up to ReviewBudget.maxIterations=3.
  ▼
  Review Approval           -> ReviewApproval.isApproved(result). Not
  │                            approved -> PlanningFailed (fail-closed,
  │                            no bypass).
  ▼
Specification (blueprint, already computed) → Execution Plan → Creation → Runtime
```

`AnythingKernel` builds the `ReviewContext` from data every earlier stage
already produced — it does not re-run any earlier stage. The blueprint that
reaches `CreationEngine` is exactly the one Design Review approved
(`ExecutionPlanReady.reviewSession.result.finalContext.blueprint`), proven
by `test/design_review/kernel_integration_test.dart`.

## The 15 sub-reviewers

`DesignReviewer` (`lib/design_review/design_reviewer.dart`) owns one const
instance of each:

| Reviewer | Category | Catches |
|---|---|---|
| `ArchitectureReviewer` | architecture | missing/duplicate/unused/contradictory/circular/dead/over-engineered entities, relationships, permissions |
| `DependencyReviewer` | dependency | missing/redundant/conflicting/cyclic dependency edges |
| `EngineeringReviewer` | engineering | dead behavior plans, unused bindings, duplicate bindings, offline/sync inconsistency, unsafe persistence |
| `SpecificationReviewer` (+ `StateReviewer`, `NavigationReviewer`, `BindingReviewer`, `BehaviorReviewer`) | specification, state, navigation, binding, behavior | orphan entities, missing CRUD, dead actions, dead reactive state, unreachable screens, dead bindings, untriggered actions |
| `CapabilityReviewer` | capability | orphaned capability declarations, missing required permissions |
| `SecurityReviewer` + `IntegrityReviewer` | security, integrity | network-mode inconsistency, vault-without-credential-capability, missing security aspects, Kaalka regression |
| `AccessibilityReviewer` | accessibility | missing accessibility aspects, unverified/fabricated accessibility claims |
| `PerformanceReviewer` + `MaintainabilityReviewer` | performance, maintainability | high-cost complexity dimensions, high issue volume |
| `OfflineReviewer` | offline | conflicting sync/offline posture, empty persistence decisions |
| `RuntimeReviewer` | runtime | screen/behavior/binding counts approaching or exceeding `RuntimeSecurityLimits` budgets |
| `MigrationReviewer` | migration | empty/missing migration rationale |
| `ModificationReviewer` | modification | missing future-modification non-functional requirement |
| `ConsistencyReviewer` | consistency | a *mandatory* Feature Discovery (V4) finding whose entity/capability didn't survive into the final architecture |

Every `ReviewIssue` carries a `ReviewSeverity` (info/warning/critical), a
`ReviewEvidence` (affected graph + node id), a `ReviewRecommendation`, and a
`Confidence`. `ReviewExplanation.forIssue()` derives a human-readable
explanation from any issue — nothing is ever surfaced without a reason.

## Review Refinement — conservative automatic improvement

`ReviewRefinement` re-reviews after applying every `autoFixableIssue`
(regardless of severity — a warning-level duplicate binding is still worth
auto-removing), up to `ReviewBudget.maxIterations` (3), mirroring the
proven-terminating loop design already established by V2/V3/V4/V5's own
refinement stages. It only ever touches `BindingGraph`/`DependencyGraph`
edges — duplicate edges, dead edges pointing at entities/fields that no
longer exist. It never touches entities, permissions, or state: anything
with a wider blast radius is surfaced for review only, per the milestone's
"never silently modify" directive. Every applied fix is recorded in the
resulting `ReviewSession.decisions` (kind: `fixed`) — nothing is silent.

## Review Memory and Review History

`ReviewMemory` and `ReviewHistory` (`lib/design_review/review_memory.dart`,
`review_history.dart`) both store every `ReviewSession` — the full
iteration history, the decisions made (accepted/rejected/fixed), and any
non-critical findings' recommendations as `futureImprovements`. Sessions
are keyed by a deterministic structural fingerprint
(`DesignReviewEngine.fingerprintOf`: sorted entity ids + sorted capability
ids + screen count). `AnythingKernel` holds one `ReviewHistory` and one
`ReviewMemory` per Kernel instance (not reset per call), so two
structurally-identical requests processed by the same Kernel instance
share a fingerprint and reuse the same memory (`test/design_review/
review_memory_history_test.dart`, `kernel_integration_test.dart`).

Honest limitation: `ModificationEngine` (M2's separate natural-language-edit
pipeline, operating on already-persisted packages) is architecturally
distinct from `AnythingKernel.processIntent`'s creation-from-scratch flow
and does not yet construct or consult a `ReviewContext`. `ReviewMemory`'s
reuse contract is real and tested for every request the same Kernel
instance processes, but is not yet wired into that separate pipeline.

## Autonomous Improvement

Per the milestone's own directive ("Review Engine may automatically fix...
Everything logged. Never silently modify"), `ReviewRefinement` is the only
component that autonomously mutates a design, and only for the narrow,
zero-cascading-risk edge classes listed above. Nothing else — not an
entity, not a permission, not a navigation edge — is ever removed or added
without a human-visible `ReviewIssue` surfacing it first.

## WebWeaveX and Kaalka

Unchanged, canonical, not duplicated. SCARE introduces no extraction,
crawling, or cryptographic logic of any kind. `IntegrityReviewer` actively
*guards* this: it fails critical if the engineered security decision's
rationale for Kaalka ever stops naming `package:kaalka` and `canonical`
(`test/design_review/capability_security_accessibility_reviewer_test.dart`
— "a Kaalka decision that stops confirming canonical package:kaalka usage
fails review").

## No bypass

`AnythingKernel.processIntent` runs `DesignReviewEngine.review()` for every
`SolutionCandidate` selected by V5, immediately before blueprint
consumption; there is no code path from a selected solution to an
`ExecutionPlanReady` outcome that skips it. If review does not approve,
`processIntent` returns `PlanningFailed` — fail-closed, matching every
prior milestone's philosophy — with a concrete reason
(`ReviewApproval.denialReason`) naming the outcome and the number of
unresolved critical issues.

## Four real bugs found by this milestone's own regression run

Writing reviewers that inspect the *combined* output of four independent
prior milestones for the first time inherently risks false positives
against real, valid designs the narrow initial test fixtures didn't
anticipate. Running the full `stage10`/`stage11` regression suite (862
tests, spanning novel domains this reviewer code had never seen) caught
four such defects before certification, all now permanently guarded by
regression tests:

1. **EngineeringReviewer / search bindings** — `BindingEngineering`
   produces two differently-shaped `viewToState` edges (per-field form
   bindings, and a per-entity search binding with a bare `fromId`). The
   "unused binding" check assumed every edge was field-shaped, flagging
   every search-enabled app. Fixed by excluding edges whose `toId` isn't
   `form_<fieldId>`-shaped.
2. **ReviewRefinement / severity gating** — the refinement loop only kept
   iterating `while (iteration.hasCriticalIssues)`, so warning-severity
   autoFixable issues (e.g. duplicate bindings) were found but never
   actually fixed. Fixed by decoupling "keep fixing" (`autoFixableIssues.
   isNotEmpty`) from "is approval blocked" (`hasCriticalIssues`).
3. **NavigationReviewer / multi-entity reachability** — `NavigationPlanner`
   (V2) only infers edges within one entity's own list/detail/form views;
   a second entity's independent top-level list screen has no graph edge
   at all, yet `CreationEngine` makes it genuinely reachable via a real
   bottom-navigation bar once there is more than one view. Fixed by
   cross-referencing `context.blueprint.views` and only flagging **form**
   screens with no anchor, since non-form screens are always reachable via
   bottom navigation. Regression: `multiEntityApp()`.
4. **NavigationReviewer / dashboard-type entry views** — `CreationEngine`
   only wired a real "Add \<entity\>" button (the click-path to a form
   screen) on `list`-type views, never on `dashboard`-type views, leaving
   a dashboard-only entity's form screen genuinely unreachable in the
   generated app (caught by the pre-existing "OrbitMetrics" certification
   fixture in `stage11_end_to_end_certification_test.dart`). This was a
   real, pre-existing gap in `CreationEngine`, not a review-heuristic
   overreach — fixed at the root by adding the same create-button wiring
   to the `dashboard` case in `CreationEngine._buildInterfaceFromBlueprint`
   (mirroring the `list` case exactly), and teaching `NavigationReviewer`
   that both `list` and `dashboard` views anchor their entity's form.
   Regression: `dashboardApp()`.

## Strong typing

Every class in `lib/design_review/` uses real typed fields — enums,
`List<T>`, nested value classes, `Confidence`/`FeatureComplexity` reused
directly from earlier milestones — never `Map<String, dynamic>` or
`dynamic` in its public data model.

## Known limitations

- `ReviewRefinement`'s auto-fix set is intentionally narrow (duplicate/dead
  `BindingGraph`/`DependencyGraph` edges only). Orphan entities, unsafe
  permissions, and unused state/navigation are always surfaced for human
  or upstream-planner attention, never silently removed.
- Several checks (`architecture:circular`, `architecture:missing`,
  `dependency:cycle`) are honestly dormant against this codebase's real
  generators today — upstream planners already prevent the conditions they
  guard against by construction. They remain real, independently tested
  code guarding against a hypothetical future regression, matching the
  same "dormant but real" pattern established by V2-V5.
- `ReviewMemory`/`ReviewHistory` are scoped to a single `AnythingKernel`
  instance's lifetime and are not (yet) persisted across process restarts
  or shared with `ModificationEngine`'s separate edit pipeline.
