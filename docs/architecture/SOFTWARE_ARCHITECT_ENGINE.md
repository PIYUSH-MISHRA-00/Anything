# Autonomous Software Architecture Engine (ASAE) — Vision Milestone V2

## Overview

`lib/software_architect/` sits between the existing reasoning layer
(`ApplicationReasoner` -> `SemanticApp`) and blueprint conversion. Before
V2, the Kernel converted a `SemanticApp` straight to an `AppBlueprint` via
`SynthesisPlanner.convertToBlueprint()` with no explicit, inspectable
record of *why* any structural decision was made. ASAE makes every such
decision a real, typed, justified `ArchitectureDecision`, subjects the
whole assembly to self-critique, and runs a bounded, deterministic
refinement loop before the (possibly corrected) result is converted to
the same `AppBlueprint` type everything downstream already consumes
unchanged.

Nothing about the reasoning layer itself changed — `CompositeApplicationReasoner`,
`DeterministicReasoner`, and `ModelApplicationReasoner` are untouched and
remain the source of the `SemanticApp`. ASAE is a genuine, mandatory
additional stage, not a replacement for reasoning.

## Pipeline

```
SemanticApp (from the existing, certified reasoning layer)
  │
  ▼
RequirementExtractor          -> RequirementGraph (+ NonFunctionalRequirement list)
  │                               entity/field/relationship/view/action/
  │                               capability/constraint/storage/state/
  │                               navigation nodes, typed relations
  ▼
ConstraintPlanner             -> platform-limit compliance decisions
  │                               (RuntimeSecurityLimits/RuntimeComponentRegistry)
  ▼
KnowledgeGraphBuilder          -> KnowledgeGraph (if knowledge was acquired
  │                               this round) — provenance/license/trust
  │                               preserved 1:1 from KnowledgeBundle
  ▼
ArchitecturePlanner           -> ArchitectureCandidate, via 13 sub-planners:
  │   EntityPlanner / FieldPlanner / RelationshipPlanner (data)
  │   StatePlanner (local/shared/persistent/derived/computed/reactive)
  │   NavigationPlanner (real graph inferred from view types + shared entities)
  │   InteractionPlanner (CRUD + search/filter/sort/pagination per entity)
  │   CapabilityPlanner (only real, implemented capabilities are "resolved")
  │   PermissionPlanner (derived from resolved capabilities' requirements)
  │   SecurityPlanner (network mode, vault requirement)
  │   OfflinePlanner (fully-offline vs cache-then-online)
  │   SynchronizationPlanner (derived from the offline decision)
  │   ValidationPlanner (typed rules traced to explicit field bounds)
  │   ConfidenceAnalyzer (real mean of every decision's own confidence)
  ▼
SelfCritic                    -> ArchitectureReview (typed issues: duplicate
  │                               entities, dangling relationships, empty
  │                               entities, disconnected navigation,
  │                               unresolved capabilities, low confidence)
  ▼
RefinementPlanner             -> ArchitectureReport (loops: fix auto-fixable
  │                               critical issues, re-critique, up to
  │                               maxIterations; terminates the moment
  │                               nothing fixable remains or the budget is
  │                               exhausted — never spins indefinitely)
  ▼
ArchitectureToBlueprintConverter -> AppBlueprint (reuses
  │                               SynthesisPlanner.convertToBlueprint —
  │                               not reimplemented — then applies exactly
  │                               the corrections refinement actually made)
  ▼
(unchanged) ExperienceSpec -> ExecutionPlan -> CreationEngine -> Runtime
```

## No bypass

`AnythingKernel.processIntent` calls `_planArchitecture()` for every
`ReasoningReady` result; there is no code path from a `SemanticApp` to a
blueprint that skips it (verified in
`test/software_architect/kernel_integration_test.dart`, and by the fact
that `test/stage11/stage11_final_production_certification_test.dart` —
M1's real, novel-domain, real-SQLite certification — passes unchanged
with ASAE now mandatory in that exact path).

If refinement exhausts its iteration budget while critical issues remain,
`processIntent` returns `PlanningFailed` rather than shipping an
architecture ASAE itself flagged as unsound — fail-closed, matching the
Kernel's existing philosophy for knowledge-loop exhaustion.

## Why this doesn't reinvent reasoning

Extracting "what app does the user want" from natural language is
already reasoning's job (deterministic pattern-matching or a real model
call), and it is already certified by M1/M2. ASAE's RequirementExtractor
does not re-derive intent from text — it derives a structural
RequirementGraph from the *shape* of the `SemanticApp` the reasoner
already produced (its entities, fields, views, actions, capabilities).
This is why a "Fossil Catalog" and a "Telescope Observation Log" —
neither of which appears anywhere in `lib/` — produce identically-shaped
requirement graphs and go through the identical planner code paths (see
`test/software_architect/requirement_extractor_test.dart`,
"never inspects entity/field names").

## Strong typing

Every class in `lib/software_architect/` uses real typed fields —
`List<T>`, enums, nested value classes — never `Map<String, dynamic>` or
`dynamic` in its public data model. Internal lookups (e.g. matching an
entity ID) may use a `Map` as a local implementation detail; the
persisted/returned architecture data never does.

## Capability honesty

`CapabilityPlanner`'s metadata table only covers capabilities that are
actually implemented in this codebase today (Clock, Notifications, HTTP,
AI, Knowledge, Files — see `docs/security/CAPABILITY_SECURITY_MATRIX.md`).
A request for anything else (camera, OAuth, bluetooth, sensors, location,
...) is reported as `resolved: false` at confidence `0.0`, with an
honest rationale ("no CapabilityDescriptor/PlatformCapability exists"),
never fabricated as working.

## Relationship delete policy — now a real per-relationship decision

`RelationshipPlanner` chooses `restrict` for a required reference field
and `setNull` for an optional one — a real, structural policy (not a
domain guess), refining M2's blanket "no cascade enforced" finding into
an explicit per-relationship decision recorded in the architecture
report. The *runtime* enforcement of this policy is unchanged and remains
the documented limitation from `docs/audit/V2_SECURITY_AUDIT.md` §12
(no automatic cascade/restrict is enforced at the data layer yet); ASAE
records the *intended* policy, it does not yet wire enforcement.

## WebWeaveX and Kaalka

Unchanged, canonical, not duplicated. `KnowledgeGraphBuilder` consumes
the real `KnowledgeBundle` V1 already produces via `package:webweavex`
(see `docs/architecture/KNOWLEDGE_ENGINE.md`) — ASAE adds no new
extraction logic, only a typed projection preserving every provenance/
license/trust field. `package:kaalka` is untouched; ASAE's architecture
decisions do not currently model credential/vault strategy beyond
`SecurityDecision.requiresCredentialVault` (always `false` today, since
no capability resolves credentials yet — see
`docs/security/TRUST_BOUNDARIES.md`).

## Known limitations

- `NavigationPlanner`'s edge inference is heuristic (shared
  `sourceEntityId` + view type), not a full semantic understanding of
  user flow — sufficient for the generated CRUD navigation pattern every
  Experience already uses, not a general-purpose UX planner.
- `RefinementPlanner` can only auto-fix issues it has an explicit fix for
  (currently: duplicate entity names, dangling relationships). Other
  critical issues (e.g. persistently low confidence) cause a fail-closed
  `PlanningFailed` rather than a fabricated fix.
- `ConfidenceAnalyzer`'s score is a real, computed mean — not calibrated
  against real-world outcome data (there is none yet); treat the
  threshold (0.4 critical / 0.6 marginal in `SelfCritic`) as a v2 default,
  not a validated statistical cutoff.
