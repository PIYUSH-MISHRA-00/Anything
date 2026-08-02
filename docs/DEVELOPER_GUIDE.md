# Developer Guide

Orientation to `lib/` across all ten Vision Milestones. For the full
narrative behind any one subsystem, see its own doc under
`docs/architecture/`.

## Pipeline overview

```
Intent (user text)
  → Knowledge (lib/knowledge/)                — real WebWeaveX retrieval
  → Reasoning (lib/synthesis/)                — SemanticApp
  → Feature Discovery (lib/feature_discovery/) — FeatureGraph
  → Architecture Planning (lib/software_architect/) — ArchitectureCandidate(s)
  → Solution Reasoning (lib/solution_reasoning/)    — selected SolutionCandidate
  → Application Engineering (lib/application_engineering/) — EngineeringPlan
  → Design Review / SCARE (lib/design_review/)      — fail-closed approval gate
  → Evolution Planning (lib/evolution/)             — roadmap (never blocks)
  → Blueprint → Spec → ExperiencePackage (lib/creation/)
  → Runtime (lib/runtime/)                          — renders, interprets behavior
  → [application-facing, not a Kernel stage:]
      Runtime Intelligence (lib/runtime_intelligence/) — observes, learns
      World Model (lib/world_model/)                   — unifies every graph
```

All of the above from Knowledge through Evolution Planning runs
synchronously inside `AnythingKernel.processIntent` — this is the one
mandatory, non-bypassable path every generated Experience goes through.
Runtime Intelligence and World Model are deliberately separate,
application-facing coordinators (`RuntimeIntelligenceCoordinator`,
`WorldModelCoordinator`) because observation is inherently post-Runtime
— there is no fabricated Kernel stage for them.

## Directory map

| Directory | What it is |
|---|---|
| `lib/kernel/` | `AnythingKernel.processIntent` — the orchestrator |
| `lib/knowledge/` | WebWeaveX adapter, search provider, knowledge cache |
| `lib/synthesis/` | Reasoning providers, blueprint/package builders |
| `lib/software_architect/` | Architecture planning (V2) |
| `lib/application_engineering/` | Behavior/state/binding engineering (V3) |
| `lib/feature_discovery/` | Feature/dependency discovery (V4) |
| `lib/solution_reasoning/` | Multi-solution generation/selection (V5) |
| `lib/design_review/` | SCARE — 15 sub-reviewers, fail-closed gate (V6) |
| `lib/evolution/` | Autonomous Evolution Engine (V7) |
| `lib/runtime_intelligence/` | Observation/learning/automation (V8) |
| `lib/world_model/` | Unified semantic graph, entity identity (V9) |
| `lib/diagnostics/` | Structured logging, error reports, health reports (V10) |
| `lib/creation/` | Blueprint → ExperiencePackage, validation, modification |
| `lib/runtime/` | `ExperienceRenderer`, `BehaviorInterpreter`, component registry |
| `lib/storage/` | `SqliteExperienceRepository`, `WorldModelRepository` (V10) |
| `lib/capabilities/` | Clock/Notification/HTTP/AI/Knowledge capability implementations |
| `lib/security/` | Runtime limits, credential vault, Kaalka service |
| `lib/legacy/` | Kaalka adapter (canonical, single integration point) |
| `lib/app/`, `lib/screens/`, `lib/features/` | Application UI |

## Where to add things

- **A new structural analysis over an existing graph** (e.g. "what
  entities would be affected by X"): extend `lib/world_model/`, reuse
  `EntityIdentity`/`GraphTraversal` — do not build a parallel graph type.
- **A new persisted record type**: extend `WorldModelRepository` if it's
  World Model/Runtime Intelligence data (shares the existing SQLite
  connection); extend `SqliteExperienceRepository` if it's core
  Experience data. Never open a second physical database file.
- **A new review check**: add a sub-reviewer under `lib/design_review/`
  if it should block creation, or an `EvolutionObserver` opportunity
  category under `lib/evolution/` if it should only be proposed, never
  block.
- **A new bulk SQLite write**: use `Database.batch()`, not a per-row
  loop — see `docs/PERFORMANCE_GUIDE.md`.

## Contributing

There is no `CONTRIBUTING.md`/`LICENSE`/issue-template scaffolding in
this repository yet (tracked as Roadmap M6, still open — see
`docs/roadmap/V2_COMPLETION_ROADMAP.md`). Until that lands: run `flutter
analyze` and `flutter test` before proposing a change, and follow the
existing pattern of pairing every new subsystem with its own
`docs/architecture/*.md` doc and a dedicated `test/<subsystem>/`
directory, as every Vision Milestone in this history has done.

## API / package boundaries

There is no published public package API surface (this is an
application, not a library) — "API documentation" in practice means:
each subsystem's own top-level coordinator (`AnythingKernel`,
`WorldModelCoordinator`, `RuntimeIntelligenceCoordinator`,
`EvolutionCoordinator`, `ExperienceModificationCoordinator`) is the
intended entry point; internal sub-planners/reviewers/bridges are
implementation detail and not meant to be called directly from
application code.

## Play Store / release readiness

See `docs/release/PLAY_STORE_READINESS.md` (Roadmap M5, not yet
started) for manifest/permissions/signing status, and
`docs/architecture/RELEASE_CANDIDATE_HARDENING.md` for the security/
performance/accessibility work Vision Milestone V10 completed toward a
release candidate.
