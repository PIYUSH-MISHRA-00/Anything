# ASAE Pipeline Performance — Vision Milestone V2

Measured 2026-08-02 via `test/software_architect/performance_test.dart`,
one real timed run for a two-entity, two-view, two-action novel-domain app
("Home Inventory Tracker" — zero footprint elsewhere in `lib/`).

Not a formal benchmark (single run, no fixed hardware, no repeated-trial
statistics) — recorded as evidence the pipeline is fast enough not to be a
product concern, per the "measure and document" requirement. No per-stage
regression thresholds are asserted in CI; only a generous total-time
sanity bound (2s) to catch a genuine performance regression without being
flaky.

| Stage | Measured | Notes |
|---|---|---|
| Requirement Extraction | ~3.0 ms | SemanticApp -> RequirementGraph, purely in-memory graph construction |
| Architecture Planning | ~16.0 ms | All 13 sub-planners (entity/field/relationship/state/navigation/interaction/capability/permission/security/offline/sync/validation) + ConfidenceAnalyzer |
| Self-Critique + Refinement | ~1.8 ms (0 iterations) | Clean candidate — SelfCritic found nothing to fix, RefinementPlanner approved on the first pass |
| Architecture -> Blueprint conversion | ~6.0 ms | Reuses SynthesisPlanner.convertToBlueprint (certified, unmodified) plus correction pass |
| Package generation (GenericPackageBuilder) | ~19.2 ms | Unrelated to ASAE itself — included to show the full intent-to-package pipeline's total cost |
| **Total** | **~47 ms** | Well within interactive latency for a one-time app-creation flow |

## Interpretation

- Architecture planning is the single largest ASAE-specific cost
  (~16 ms), proportional to entity/field/view/action count — dominated by
  in-memory list operations, no I/O.
- Refinement adds negligible cost (~2 ms) when the candidate is already
  clean, which is the expected common case for a well-formed reasoner
  output; each additional refinement iteration re-runs SelfCritic (a
  linear scan over the candidate), so cost scales with
  `iterations × candidate size`, bounded by `RefinementPlanner.maxIterations`
  (default 3).
- The entire ASAE pipeline (~27 ms: extraction + planning + refinement +
  conversion) is a small fraction of total package-generation time and an
  even smaller fraction of the real end-to-end creation flow once model
  reasoning latency (a network round-trip, typically hundreds of ms to a
  few seconds) is included — ASAE does not become the bottleneck.

## Where this fits in the budget model

Architecture planning runs exactly once per successful `ReasoningReady`
result (i.e., once per knowledge-refinement-loop round that produces a
semantic app, bounded the same way as before —
`AnythingKernel._maxKnowledgeRounds + 1` = 3 attempts at most). Refinement
iterations are separately bounded by `RefinementPlanner.maxIterations`
(default 3), so worst-case ASAE cost per `processIntent` call is bounded
by design, not just by observation, consistent with the trusted-limits
approach already documented in `docs/security/RUNTIME_LIMITS.md`.
