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
| `KnowledgeCache` | `knowledge/knowledge_acquisition_engine.dart` | `AppComposition` | THE single cache (I-35) |
| `KnowledgeRepository` | `storage/knowledge_repository.dart` | `AppComposition` | durable store for the cache only (I-36) |

## Policy ownership (IS-R50)

Two policy engines, two **disjoint** domains. A third of either kind, or any
overlap between these two, fails certification (I-44).

| Engine | Owns | Inputs | Output vocabulary | Acts on |
|---|---|---|---|---|
| `WorkspaceLifecyclePolicyEngine` (R39) | **runtime** lifecycle | `AppLifecycleState`, `WorkspaceRuntimeSnapshot` | `RuntimePolicyAction` (pause/resume/terminate/restore/noAction) | `ExperienceRuntimeController` |
| `RetentionPolicyEngine` (R50) | **data** retention | record count, age, size | `LifecycleAction` (retain/evict/expire) | nothing — it decides, callers apply |

### Retention delegation — who applies, and when

| Domain | Applied by | When | Bound |
|---|---|---|---|
| `intents` | `IntentRepository.save()` | on write | 100 entries |
| `activity` | `ActivityRepository.record()` | on write | 200 entries |
| `notifications` | `RealNotificationService.schedule()` | on write | 200 entries |
| `knowledge` | `KnowledgeCache.applyRetention()` | after `put()`, or on demand | 500 / 20 MB / 30 d |
| `temporary_files` | `RealFileService.applyRetention()` | on demand | 1 d |
| `exports` | `RealFileService.applyRetention()` | on demand | 7 d |

Before R50 the first three bounds were `static const int` fields invented
independently inside those three files, and `knowledge` had no bound at all
(gap G-18). The values did not change; the **ownership** did. No repository or
capability service may hold a retention rule any more (I-46).

**`KnowledgeRepository` remains storage only.** It gained `keySummaries()` — a
plain SQL aggregate reporting per-key count, bytes and recency. It reports
facts; `KnowledgeCache` asks the engine and tells the repository which keys to
remove. The repository evaluates nothing and reclaims nothing on its own
initiative (I-47).

**Not retention, deliberately excluded:** `CredentialVault.delete()`,
`SqliteExperienceRepository.delete()`, `MemoryManager.deleteConversation()`,
`IntentComposer.clear()` and `RealFileService.clearTemporaryFiles()` are
explicit user or caller actions. Retention decides what happens *without*
anyone asking; deletion someone asked for is not a policy outcome. Adopted
Experience assets are likewise never reclaimed by policy.

## Platform capabilities (IS-R49)

Every capability the runtime exposes to Experiences, and the ONE service
backing it in production. Registered exactly once each, in `AppComposition`.

| Capability | Production service | Owner of | Notes |
|---|---|---|---|
| `clock` | `ClockCapability` | time | — |
| `http` | `RealHttpTransport` | outbound HTTP | host allowlist enforced by the capability |
| `ai` | `ModelProviderAiAdapter` | runtime model access | not the creation-path reasoning boundary |
| `knowledge` | `KnowledgeAcquisitionProviderAdapter` | knowledge retrieval | real WebWeaveX path |
| `notifications` | **`RealNotificationService`** (IS-R49) | durable notification schedules | delivery seam: `NotificationPresenter`; default publishes R35's `NotificationGenerated` on the existing `EventBus` |
| `files` | **`RealFileService`** (IS-R49) | user-imported files only | sandboxed under `anything_files/`; owns no other persistence (I-43) |

Before IS-R49 the last two rows read `FakeNotificationService` and
`FakeFileService` — both registered in the REAL production graph. No `Fake*`
implementation is constructed in the composition root any more (I-39).

**Ownership boundary that matters most here:** `RealFileService` owns exactly
one thing — files a user imported. It does not persist Experiences (that is
`SqliteExperienceRepository`), knowledge (`KnowledgeRepository`), memory,
activity or intents, and I-43 certifies it never reaches for any of them.
Per-Experience ownership is the directory path itself: an adopted file lives
under `experiences/<experienceId>/`, so another Experience's file is not
merely forbidden, it is not addressable.
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
