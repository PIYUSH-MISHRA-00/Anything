# Subsystem Matrix — IS-R46

Every top-level subsystem directory under `lib/` (462 `.dart` files, 45
top-level directories), its canonical status, and whether R46 certifies it.

Status: **CANONICAL** = live, owned, on a certified path.
**LIVE** = real and used, not directly certified by R46.
**DEAD** = present but unreachable/unreferenced.
**RESIDUE** = v1-era parallel architecture (MIS-1 Part 1 finding).

## Operating-system core — all certified

| Directory | Status | Role | R46 certification |
|---|---|---|---|
| `app/` | CANONICAL | Composition root, entry pipeline, workspace/scheduling/activation, routing | I-01…I-11, I-16, I-23…I-28 |
| `kernel/` | CANONICAL | Reasoning boundary, understanding, classification, planning, specification | I-11, I-18…I-20, I-21c |
| `runtime/` | CANONICAL | Experience hosting, runtime controller, renderer | I-02, I-12, I-13, I-16 |
| `synthesis/` | CANONICAL | Application reasoners — the one LLM boundary | I-18, I-19 |
| `security/` | CANONICAL | Kaalka boundary, protection service | I-21a, I-21c |
| `storage/` | CANONICAL | SQLite persistence, engineering memory | Kaalka persistence audit |
| `core/` | CANONICAL (1 dead file) | Contracts, events, result types | I-15 (dead `contracts/runtime.dart`) |
| `capabilities/` | CANONICAL | Capability platform, registry, adapters, builtins | I-18 (2 AI sites) |
| `features/` | CANONICAL | Real production UI (home, experiences, workspace, activity, preferences) | I-01, I-16, I-17, I-21c, I-22 |

## Cognition / engineering pipeline — live

| Directory | Status | Role |
|---|---|---|
| `knowledge/` | LIVE | Knowledge acquisition, WebWeaveX adapter, search provider (I-21b) |
| `software_cognition/` | LIVE | Repository/package/component analyzers (V11) (I-21b) |
| `world_model/` | LIVE | World model, semantic graph, knowledge bridges |
| `creation/` | LIVE | Creation engine, experience package, modification |
| `evolution/` | LIVE | Evolution engine |
| `engineering_intelligence/` | LIVE | Incremental compiler synthesis |
| `compiler_integration/` | LIVE | `runCompilerPipeline` (R19) |
| `compiler_certification/` | LIVE | Legacy-vs-compiler equivalence (R23) — owns the 2nd Kernel instance (I-11) |
| `implementation_model/` | LIVE | Canonical implementation model |
| `generation_specification/` | LIVE | Generation specs |
| `generator_framework/` | LIVE | Generator pipeline |
| `execution_planning/` | LIVE | Execution plans |
| `solution_architecture/` | LIVE | Semantic solution architecture |
| `solution_reasoning/` | LIVE | Solution reasoning engine |
| `solution_orchestration/` | LIVE | Solution execution orchestrator |
| `solution_evolution/` | LIVE | Solution evolution |
| `software_architect/` | LIVE | Requirement extraction, architecture |
| `application_engineering/` | LIVE | Accessibility/performance/security engineering |
| `backend_engineering/` | LIVE | Backend service generation |
| `design_review/` | LIVE | Design review engine + reviewers (incl. the Kaalka-canonical guard) |
| `feature_discovery/` | LIVE | Feature discovery, priority analysis |
| `artifact_intelligence/` | LIVE | Artifact intelligence |
| `runtime_intelligence/` | LIVE | Runtime intelligence layer |
| `experience_identity/` | LIVE | Experience identity |
| `build_graph/` | LIVE | Build graph |
| `memory/` | LIVE | Memory manager (Kaalka path K-B) |
| `workflow/` | LIVE | Workflow execution |
| `agents/` | LIVE | Agent definitions |
| `knowledge/`, `models/`, `platform/`, `services/`, `tools/`, `diagnostics/` | LIVE | Supporting infrastructure |
| `design_system/`, `ui_engine/`, `widgets/` | LIVE | Design system, component registry, widgets |

## Residue and dead code

| Directory / file | Status | Evidence | Gap |
|---|---|---|---|
| `screens/` | RESIDUE | Riverpod `ConsumerStatefulWidget` v1 screens; `AnythingAppShell` builds only `features/*`. Construct **no** `ExperienceHostScreen` (certified I-16). | MIS-1 Part 1 finding |
| `legacy/` | RESIDUE (partly live) | Contains `kaalka_adapter.dart` (**live**, canonical protection provider) and `groq_adapter.dart` (**live**, `GroqModelProvider`). Directory name is misleading. | — |
| `core/contracts/runtime.dart` | DEAD | Zero importers, zero implementors (I-15) | G-01 |
| `kernel/minimal_kernel.dart` | DEAD | Never constructed | G-02 |
| `capabilities/builtin/knowledge_capability.dart` → `FakeKnowledgeProvider` | DEAD (in production) | Real adapter wired at `app_composition.dart:220` | G-09 |

## Subsystem count summary

| Category | Count |
|---|---|
| Top-level directories under `lib/` | 45 |
| `.dart` files under `lib/` | 462 |
| Canonical OS-core subsystems (directly certified) | 9 |
| Canonical types with pinned construction ownership | 13 |
| Confirmed dead files | 2 (`core/contracts/runtime.dart`, `kernel/minimal_kernel.dart`) |
| Confirmed residue directories | 1 (`screens/`) |

**Note on `legacy/`:** despite the name, two of its files are live and
canonical (`KaalkaProtectionProvider`, `GroqModelProvider`). Renaming is not
proposed — it would touch import paths across the repository for no
behavioural gain — but the misleading name is recorded here so no future
audit mistakes it for dead code and deletes a live protection provider.
