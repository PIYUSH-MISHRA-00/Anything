# Architecture

The map. Deep-dives live in [`docs/architecture/`](docs/architecture/) (81
documents); this page is the index and the shape.

> **Where the detail is.** This file deliberately does not restate what
> `docs/architecture/*.md` already says. Every section links to the canonical
> document for that subsystem.

---

## The one-paragraph version

An intent goes into the **Kernel**, which runs it through nine reasoning engines
and produces an **ExperiencePackage** — a validated, versioned structure
describing an application. The package is committed to SQLite through a
transactional commit framework, then opened through a single certified entry
pipeline, orchestrated, scheduled, and executed by a runtime that renders its
interface and interprets its behaviour graph. Every one of those verbs has
exactly one owner, and each owner's singularity is enforced by a test.

## Layers

```
main.dart ──▶ AnythingApp ──▶ AppComposition        the one composition root
                                    │
    ┌───────────┬───────────┬───────┴────┬────────────┬───────────┐
    ▼           ▼           ▼            ▼            ▼           ▼
 Kernel     Capability   Storage    Experience    Workspace   Knowledge
            Platform                frameworks     runtime
```

| Layer | Directory | Canonical doc |
|---|---|---|
| Composition root | `lib/app/app_composition.dart` | [REPOSITORY_COMPOSITION_CERTIFICATION](docs/audit/REPOSITORY_COMPOSITION_CERTIFICATION.md) |
| Kernel | `lib/kernel/` | [UNIVERSAL_INTENT_ROUTER](docs/architecture/UNIVERSAL_INTENT_ROUTER.md) |
| Experience model | `lib/creation/` | [EXPERIENCE_GUIDE](docs/EXPERIENCE_GUIDE.md) |
| Runtime | `lib/runtime/` | [UNIVERSAL_EXPERIENCE_RUNTIME](docs/architecture/UNIVERSAL_EXPERIENCE_RUNTIME.md) |
| Entry | `lib/app/experience_entry_pipeline.dart` | [UNIFIED_EXPERIENCE_ENTRY_PIPELINE](docs/architecture/UNIFIED_EXPERIENCE_ENTRY_PIPELINE.md) |
| Orchestration | `lib/app/experience_orchestrator.dart` | [EXPERIENCE_ORCHESTRATION](docs/architecture/EXPERIENCE_ORCHESTRATION.md) |
| Execution contract | `lib/app/experience_execution_contract.dart` | [EXPERIENCE_EXECUTION_CONTRACT](docs/architecture/EXPERIENCE_EXECUTION_CONTRACT.md) |
| Scheduling | `lib/app/workspace_scheduling_engine.dart` | [WORKSPACE_SCHEDULING_ENGINE](docs/architecture/WORKSPACE_SCHEDULING_ENGINE.md) |
| Lifecycle | `lib/app/workspace_lifecycle_policy_engine.dart` | [WORKSPACE_LIFECYCLE_POLICY_ENGINE](docs/architecture/WORKSPACE_LIFECYCLE_POLICY_ENGINE.md) |
| Supervision | `lib/app/workspace_runtime_supervisor.dart` | [WORKSPACE_RUNTIME_SUPERVISOR](docs/architecture/WORKSPACE_RUNTIME_SUPERVISOR.md) |
| Capabilities | `lib/capabilities/` | [CAPABILITY_SECURITY_MATRIX](docs/security/CAPABILITY_SECURITY_MATRIX.md) |
| Storage | `lib/storage/` | [ADR_R56](docs/architecture/ADR_R56_DURABLE_COLLECTION_STORE.md) · [ADR_R57](docs/architecture/ADR_R57_CANONICAL_REPOSITORY_COMPOSITION.md) |
| Knowledge | `lib/knowledge/` | [KNOWLEDGE_ENGINE](docs/architecture/KNOWLEDGE_ENGINE.md) |
| Protection | `lib/security/` | [KAALKA_GUIDE](docs/KAALKA_GUIDE.md) · [TRUST_BOUNDARIES](docs/security/TRUST_BOUNDARIES.md) |
| UI | `lib/features/`, `lib/design_system/` | [UX_REVIEW](docs/audit/) |

## The nine intelligence engines

Each inserts a typed, reviewable stage into the creation pipeline. Together
~20,000 LOC, and mostly reachable from `main()`.

| Engine | Directory | Doc |
|---|---|---|
| Knowledge acquisition | `lib/knowledge` | [KNOWLEDGE_ENGINE](docs/architecture/KNOWLEDGE_ENGINE.md) |
| Software architecture | `lib/software_architect` | [SOFTWARE_ARCHITECT_ENGINE](docs/architecture/SOFTWARE_ARCHITECT_ENGINE.md) |
| Application engineering | `lib/application_engineering` | [APPLICATION_ENGINEERING_ENGINE](docs/architecture/APPLICATION_ENGINEERING_ENGINE.md) |
| Feature discovery | `lib/feature_discovery` | [FEATURE_DISCOVERY_ENGINE](docs/architecture/FEATURE_DISCOVERY_ENGINE.md) |
| Solution reasoning | `lib/solution_reasoning` | [SOLUTION_REASONING_ENGINE](docs/architecture/SOLUTION_REASONING_ENGINE.md) |
| Design review | `lib/design_review` | [DESIGN_REVIEW_ENGINE](docs/architecture/DESIGN_REVIEW_ENGINE.md) |
| Evolution | `lib/evolution` | [EVOLUTION_ENGINE](docs/architecture/EVOLUTION_ENGINE.md) |
| Runtime intelligence | `lib/runtime_intelligence` | [RUNTIME_INTELLIGENCE_LAYER](docs/architecture/RUNTIME_INTELLIGENCE_LAYER.md) |
| World model | `lib/world_model` | [WORLD_MODEL_AND_SEMANTIC_GRAPH](docs/architecture/WORLD_MODEL_AND_SEMANTIC_GRAPH.md) |

## The rule that holds it together

**One owner per verb, mechanically certified.**

| Verb | Owner |
|---|---|
| DECIDES governance | `OperatingSystemGovernanceEngine` |
| COMPUTES trust | `ExperienceTrustClassifier` |
| ENFORCES capabilities | `CapabilityPlatform` |
| DECIDES execution | `ExperienceOrchestrator` |
| SCHEDULES | `WorkspaceSchedulingEngine` |
| EXECUTES | `AnythingRuntime` |
| ENTERS / navigates | `ExperienceEntryPipeline` |
| STORES | `SqliteExperienceRepository` |
| COMMITS | `ExperienceCommitFramework` |
| SERIALISES | `ExperiencePackageWriter` / `Reader` |
| DECLARES | `ExperienceExecutionContract` |
| PROTECTS | `ExperienceProtectionService` |

Full table: [OWNERSHIP_MATRIX](docs/audit/OWNERSHIP_MATRIX.md).

## Certification

101 invariants run on every commit from a single suite,
`test/r46_architectural_integrity_certification_test.dart`. Each was
**mutation-proven**: deliberately broken, and the check confirmed to fail.

Examples of what they enforce:

- exactly one construction path for `ExperienceHostScreen` (I-02/I-16/I-17)
- exactly one crypto importer, one WebWeaveX importer (I-21a–e)
- governance imports nothing (I-49); one trust model (I-50)
- every commit-framework write runs in a transaction (I-70)
- exactly one manifest, one validator, one package format (I-59/I-60/I-87)
- the execution contract declares and never decides (I-90)
- nothing reaches the scheduler except through the orchestrator (I-91)

Registry: [ARCHITECTURE_INVARIANT_MATRIX](docs/audit/ARCHITECTURE_INVARIANT_MATRIX.md) ·
[INVARIANT_TRACEABILITY](docs/audit/INVARIANT_TRACEABILITY.md).

## Decision records

ADRs live in [`docs/architecture/`](docs/architecture/): R56 (durable collection
store), R57 (repository composition), R59 (runtime reachability), R60 (package
format), R61 (execution contract), R62 (orchestration).

## Known architectural debt

Stated plainly rather than buried:

| Item | Detail |
|---|---|
| ~50 unreachable v1 files | A complete parallel application (`lib/screens`, `lib/agents`, `lib/tools`, `lib/ui_engine`, `lib/widgets`) that cannot run because nothing creates a `ProviderScope`. Kept, not deleted, because the files import each other and none is individually provably dead. |
| Import/export unreachable | The package codec, installer and distribution framework are built and certified but have no UI entry point. |
| Reachability analysis is pinned | `tool/reachability.py` produces the classification; the invariant checks a pinned list rather than recomputing. |

Tracked in [REMAINING_GAP_MATRIX](docs/audit/REMAINING_GAP_MATRIX.md).
