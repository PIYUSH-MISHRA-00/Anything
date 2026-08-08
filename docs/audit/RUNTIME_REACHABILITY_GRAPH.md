# Runtime Reachability Graph — IS-R59 Phase 2

Computed by transitive import closure from the single canonical entry point.
Reproducible: `python tool/reachability.py` and `python tool/classify_reachability.py`.

## The canonical runtime graph

```
lib/main.dart                    <- the ONLY void main() in lib/  (certified I-85)
  └─ AnythingApp  (lib/app/app.dart)
       └─ MaterialApp            <- the ONLY app widget            (certified I-85)
            └─ AppComposition.production()
                 ├─ SqliteExperienceRepository ─ ExperienceCommitFramework (R55)
                 │                                 └─ Installation (R54) ─ Distribution (R53)
                 ├─ ActivityRepository / IntentRepository (R57) ─ DurableCollectionStore (R56)
                 ├─ KnowledgeRepository ─ KnowledgeCache ─ RetentionPolicyEngine (R50)
                 ├─ CapabilityPlatform ← GovernanceEngine (R51) ← TrustClassifier (R52)
                 ├─ ExperienceEntryPipeline (R45) ─ ActivationManager ─ SchedulingEngine
                 ├─ AnythingKernel ─ ApplicationReasoner ─ ModelProvider   (one AI boundary)
                 └─ EventBus
            └─ lib/features/**    <- the canonical UI surface, 100% REACHABLE
                 └─ ExperienceHostScreen ─ AnythingRuntime (one construction site)
```

## The disconnected graph

```
lib/screens/app_shell.dart        <- a SECOND app shell, imported by nothing outside lib/screens/
  ├─ 10 Riverpod ConsumerStatefulWidget screens
  ├─ lib/agents/**        (5 files)
  ├─ lib/tools/**         (6 files)
  ├─ lib/memory/**        (2 files)   ─ SQLiteService (anything_memory.db)
  ├─ lib/core/context_engine, intent_engine, reasoning_engine
  ├─ lib/services/groq_service, web_search_service, file_context_service
  └─ lib/ui_engine/**     (4 files)

NO ProviderScope EXISTS ANYWHERE  ->  every provider above is unresolvable
NOTHING in lib/features/, lib/app/ or main.dart references any of it
```

## Classification totals

| Class | Count | Meaning |
|---|---|---|
| REACHABLE | 356 | an import chain from `main()` reaches it |
| DORMANT | 43 | unreachable from `main()`, but a test imports it |
| EXPERIMENTAL | 50 | unreachable and untested, but another `lib/` file imports it |
| DEPRECATED | 0 | carries an explicit deprecation marker |
| DEAD | 2 | unreachable, untested, imported by nothing |
| **TOTAL** | **451** | **no UNKNOWN state remains** (certified I-86) |

## By directory

| Directory | REACHABLE | DORMANT | EXPERIMENTAL | DEAD |
|---|---|---|---|---|
| `lib/world_model` | 34 | 6 | 0 | 1 |
| `lib/runtime_intelligence` | 29 | 4 | 0 | 0 |
| `lib/evolution` | 19 | 5 | 0 | 0 |
| `lib/software_cognition` | 16 | 3 | 4 | 0 |
| `lib/design_system` | 18 | 0 | 0 | 1 |
| `lib/runtime` | 15 | 4 | 0 | 0 |
| `lib/core` | 4 | 2 | 7 | 0 |
| `lib/screens` | 0 | 0 | 11 | 0 |
| `lib/storage` | 8 | 3 | 0 | 0 |
| `lib/synthesis` | 10 | 1 | 0 | 0 |
| `lib/generator_framework` | 7 | 1 | 0 | 0 |
| `lib/tools` | 0 | 0 | 6 | 0 |
| `lib/agents` | 0 | 0 | 5 | 0 |
| `lib/security` | 4 | 0 | 1 | 0 |
| `lib/services` | 2 | 0 | 3 | 0 |
| `lib/compiler_certification` | 0 | 4 | 0 | 0 |
| `lib/diagnostics` | 0 | 4 | 0 | 0 |
| `lib/ui_engine` | 0 | 0 | 4 | 0 |
| `lib/widgets` | 0 | 0 | 4 | 0 |
| `lib/build_graph` | 2 | 1 | 0 | 0 |
| `lib/compiler_integration` | 1 | 2 | 0 | 0 |
| `lib/engineering_intelligence` | 2 | 1 | 0 | 0 |
| `lib/solution_architecture` | 2 | 1 | 0 | 0 |
| `lib/memory` | 0 | 0 | 2 | 0 |
| `lib/workflow` | 0 | 0 | 2 | 0 |
| `lib/experience_identity` | 0 | 1 | 0 | 0 |
| `lib/models` | 0 | 0 | 1 | 0 |

Directories not listed are 100% REACHABLE.

