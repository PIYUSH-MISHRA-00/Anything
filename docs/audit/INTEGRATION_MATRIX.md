# Integration Matrix — IS-R46

How canonical subsystems integrate: who depends on whom, through which
contract, and which integration points are mechanically certified.

## 1. Composition-root integrations

`AppComposition` is the single composition root. Every edge below is
constructed exactly once and threaded by reference — certified by identity
assertions on the live graph (I-23…I-27).

| Consumer | Depends on | Via | Certified |
|---|---|---|---|
| `ExperienceEntryPipeline` | `IntentExecutionPipeline` | constructor | I-01 |
| `ExperienceEntryPipeline` | `ExperienceOpeningCoordinator` | constructor | I-10 |
| `ExperienceEntryPipeline` | `ExperienceActivationManager` | constructor | I-27 (`identical`) |
| `ExperienceEntryPipeline` | `ExperienceWorkspaceManager` | constructor | I-27 (`identical`) |
| `ExperienceEntryPipeline` | `WorkspaceSchedulingEngine` | constructor | I-27 (`identical`) |
| `ExperienceEntryPipeline` | `WorkspaceRuntimeSupervisor` | constructor | I-27 (`identical`) |
| `ExperienceActivationManager` | `WorkspaceSchedulingEngine` | constructor | I-26 (`identical`) |
| `WorkspaceSchedulingEngine` | `WorkspaceRuntimeSupervisor` | constructor | I-24 (`identical`) |
| `WorkspaceSchedulingEngine` | `ExperienceWorkspaceManager` | constructor | I-25 (`identical`) |
| `WorkspaceSchedulingEngine` | `WorkspaceLifecyclePolicyEngine` | constructor | — |
| `IntentExecutionPipeline` | `UniversalIntentRouter` | constructor | I-06, I-07 |
| `UniversalIntentRouter` | `ExperienceWorkspaceManager` | constructor | I-08 |
| `ExperienceWorkspaceManager` | `IntentSessionManager` | constructor | I-09 |
| `AnythingKernel` | `ModelProviderRegistry` | constructor | I-11 |
| `AnythingKernel` | `KnowledgeAcquisitionEngine` | constructor | I-21b/c |
| `KnowledgeAcquisitionEngine` | `WebWeaveXAdapter`, `SearchProvider` | constructor | I-21b |
| `CapabilityPlatform` | `AiCapability`, `KnowledgeCapability`, `HttpCapability`, … | registry | I-18 |

## 2. UI → operating-system integrations

| Surface | Integrates with | Through | Certified |
|---|---|---|---|
| `HomeScreen` | entry pipeline (local instance, IS-R45) | `submitIntent`, `activateExperience`, `activateProtectedExperience` | I-01, I-22 |
| `ExperiencesScreen` | entry pipeline (shared instance) | `activateExperience`, `activateProtectedExperience` | I-16 |
| `WorkspaceSwitcherSheet` | entry pipeline (shared instance) | `activateRunningSession` | I-16 |
| `ExperienceHostScreen` | runtime, supervisor, scheduler, protection | constructor injection from the pipeline | I-02, I-12, I-13 |
| `ActivityScreen`, `PreferencesScreen` | none (no Experience entry) | — | I-16 (absence certified) |

**Certified negative:** no UI file imports `package:kaalka` or
`package:webweavex` directly (I-21c). UI reaches both only through adapters.

## 3. Cross-boundary integrations (external packages)

| Boundary | Owner | Consumers | Certified |
|---|---|---|---|
| `package:kaalka` | `security/kaalka_service.dart` | `KaalkaProtectionProvider` (K-A), `EncryptionManager` (K-B) | I-21a — one importer |
| `package:webweavex` | `knowledge/webweavex_adapter.dart` + 3 `software_cognition/` analyzers | `KnowledgeAcquisitionEngine`, `SoftwareCognitionCoordinator` | I-21b — four importers |
| `package:http` | `capabilities/adapters/http_transport_adapter.dart`, `legacy/groq_adapter.dart` | `HttpCapability`, `GroqModelProvider` | not certified (pre-existing allowlist) |
| Model providers (LLM) | `services/provider_registry.dart` → `GroqModelProvider` | 4 pinned call sites | I-18 |

## 4. Event integration

All workspace transitions publish through **one** publisher; R45 added no new
event hierarchy and R46 adds none.

| Publisher construction site | Source tag | Publishes |
|---|---|---|
| `AppComposition` | `workspace` | scheduler/activation/workspace transitions |
| `HomeScreen` (override case) | `workspace` | same, consistent local graph |
| `ExperienceHostScreen` | `experience-host-screen` | `runtime_loaded`, host-level transitions |

Event types remain the pre-existing `AnythingEvent` hierarchy
(`WorkspaceUpdated` and siblings). No new subtype was introduced by R45 or
R46.

## 5. Integration invariants certified by R46

| Invariant | Mechanism |
|---|---|
| The whole OS graph is coherent — no service references a *different* instance of a peer than the composition holds | DYNAMIC `identical()` chain, I-23…I-27 |
| Experience entry integrates through exactly one seam | I-02, I-16, I-17 |
| Reasoning integrates through exactly one mandatory seam | I-18, I-19, I-20 |
| External cognition/protection integrate only through adapters | I-21a, I-21b, I-21c |
| Runtime supervision has no back door | I-12, I-13, I-28 |

## 6. The integration risk R46 exists to prevent

Before R46, an integration could be added that *looked* correct locally and
silently bypassed the canonical seam. That is exactly what happened in R45:
`ExperiencesScreen` integrated directly with `ExperienceOpeningCoordinator`
and `Navigator`, skipping the pipeline, the scheduler, the supervisor and the
activation manager — while remaining perfectly readable, compiling cleanly,
and passing every test then in existence.

The certification layer closes that class of failure: a new integration that
bypasses a canonical seam now fails CI and names the file. This was verified
by mutation test, not assumed — see
`docs/architecture/ARCHITECTURAL_INTEGRITY_CERTIFICATION.md`.
