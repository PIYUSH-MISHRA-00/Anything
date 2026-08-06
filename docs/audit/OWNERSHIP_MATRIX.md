# Ownership Matrix — IS-R46

Canonical owner of every architectural subsystem, derived from repository-wide
evidence (`test/r46_architectural_integrity_certification_test.dart`), never
inferred. "Constructed by" is mechanically enforced; a new constructor
anywhere in `lib/` fails CI.

## Core operating-system subsystems

| Subsystem | Declared in | Constructed by | Mutation owner | Lifecycle |
|---|---|---|---|---|
| `AppComposition` | `app/app_composition.dart` | `AnythingAppShell` (once per shell) | itself (all fields `final`) | app lifetime |
| `ExperienceEntryPipeline` | `app/experience_entry_pipeline.dart` | `AppComposition`; `HomeScreen` (local, IS-R45) | stateless (`const`) | per composition |
| `ExperienceActivationManager` | `app/experience_activation_manager.dart` | `AppComposition`; `HomeScreen` (override case only) | itself (`_activeRoutes`) | app lifetime |
| `WorkspaceSchedulingEngine` | `app/workspace_scheduling_engine.dart` | `AppComposition`; `HomeScreen` (override case only) | stateless (`const`) | app lifetime |
| `WorkspaceRuntimeSupervisor` | `app/workspace_runtime_supervisor.dart` | `AppComposition` | itself (`_registrations`) | app lifetime |
| `ExperienceWorkspaceManager` | `app/experience_workspace_manager.dart` | `AppComposition` | itself (session state) | app lifetime |
| `IntentSessionManager` | `app/intent_session_manager.dart` | `AppComposition` | itself | app lifetime |
| `UniversalIntentRouter` | `app/universal_intent_router.dart` | `AppComposition` | stateless (`const`) | app lifetime |
| `IntentExecutionPipeline` | `app/intent_execution_pipeline.dart` | `AppComposition` | stateless (`const`) | app lifetime |
| `ExperienceOpeningCoordinator` | `app/experience_opening_coordinator.dart` | `AppComposition`; `HomeScreen` (local) | stateless | per use |
| `WorkspaceLifecyclePolicyEngine` | `app/workspace_lifecycle_policy_engine.dart` | `AppComposition`, `HomeScreen`, `ExperienceHostScreen` | stateless (`const`) | per use |
| `WorkspaceEventPublisher` | `app/workspace_event_publisher.dart` | `AppComposition`, `HomeScreen`, `ExperienceHostScreen` | stateless | per use |

## Kernel and reasoning

| Subsystem | Declared in | Constructed by | Notes |
|---|---|---|---|
| `AnythingKernel` | `kernel/anything_kernel.dart` | `AppComposition` (production); `CertificationRunner` (fake reasoner, R23) | THE reasoning boundary owner |
| `ModelUnderstandingService` | `kernel/understanding/model_understanding_service.dart` | `AnythingKernel` (internal) | optional, degradable |
| `CompositeApplicationReasoner` | `synthesis/composite_reasoner.dart` | `AnythingKernel` default | deterministic-first delegator |
| `DeterministicReasoner` | `synthesis/deterministic_reasoner.dart` | `CompositeApplicationReasoner` | never reaches a provider |
| `ModelApplicationReasoner` | `synthesis/model_reasoner.dart` | `CompositeApplicationReasoner` | **the ONE mandatory LLM boundary** |
| `MinimalKernel` | `kernel/minimal_kernel.dart` | **nothing** | dead — see gap matrix |

## Runtime

| Subsystem | Declared in | Constructed by | Cardinality |
|---|---|---|---|
| `ExperienceHostScreen` | `runtime/experience_host_screen.dart` | `ExperienceEntryPipeline` **only** | one route per active session |
| `AnythingRuntime` (live) | `runtime/anything_runtime.dart` | `ExperienceHostScreen` | one per session |
| `ExperienceRuntimeController` | `runtime/experience_runtime_controller.dart` | `ExperienceHostScreen` | **one per session** |
| `AnythingRuntime` (v1 contract) | `core/contracts/runtime.dart` | **nothing** | dead, name-colliding — see gap matrix |

## Security / protection

| Subsystem | Declared in | Constructed by | Boundary |
|---|---|---|---|
| `KaalkaService` | `security/kaalka_service.dart` | `KaalkaProtectionProvider`, `EncryptionManager` | **only file importing `package:kaalka`** |
| `KaalkaProtectionProvider` | `legacy/kaalka_adapter.dart` | `ExperienceProtectionService` | implements `ProtectionProvider` |
| `ExperienceProtectionService` | `security/protection_service.dart` | `ExperienceOpeningCoordinator`, `ExperienceHostScreen` | canonical Experience protection |
| `EncryptionManager` | `security/encryption_manager.dart` | Riverpod provider | **parallel path** — see Kaalka matrix |

## Knowledge / cognition

| Subsystem | Declared in | Constructed by | Boundary |
|---|---|---|---|
| `KnowledgeAcquisitionEngine` | `knowledge/knowledge_acquisition_engine.dart` | `AppComposition` | called only by `AnythingKernel` |
| `WebWeaveXAdapter` | `knowledge/webweavex_adapter.dart` | `AppComposition` | imports `package:webweavex` |
| `DuckDuckGoSearchProvider` | `knowledge/search_provider.dart` | `AppComposition` | query → URLs |
| `SoftwareCognition` analyzers | `software_cognition/{repository,package,component}_analyzer.dart` | `SoftwareCognitionCoordinator` | import `package:webweavex` |

## Ownership rules certified

1. **`AppComposition` is the single composition root.** Every long-lived
   operating-system service is constructed there exactly once and threaded by
   reference. Certified by I-01…I-11 plus the dynamic identity assertions
   I-23…I-27.
2. **`ExperienceEntryPipeline` exclusively owns Experience entry.** No other
   file in `lib/` may construct `ExperienceHostScreen` (I-02, I-16, I-17).
3. **`ExperienceHostScreen` exclusively owns per-session runtime.** It is the
   only constructor of `AnythingRuntime` and `ExperienceRuntimeController`
   (I-12, I-13).
4. **`AnythingKernel` exclusively owns reasoning.** Exactly one mandatory LLM
   boundary reachable through it (I-18…I-20).
5. **`KaalkaService` exclusively owns protection crypto.** Sole importer of
   `package:kaalka` (I-21a).
6. **Adapters exclusively own external cognition.** Kernel and UI never import
   `package:webweavex` or `package:kaalka` (I-21b, I-21c).
