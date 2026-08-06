# Canonical Flow Matrix — IS-R46

Every real production flow, the canonical path it must take, and the
mechanism that proves it still takes it.

## 1. Experience entry — all sources

Every entry source converges on `ExperienceEntryPipeline`, which is the ONLY
construction site of `ExperienceHostScreen` in `lib/` (certified: I-02/I-16).

| Source | Surface | Pipeline method | Certified by |
|---|---|---|---|
| Create New Experience | `HomeScreen` | `submitIntent()` | I-01, R45 suite |
| Birth completion | `HomeScreen` | `activateExperience()` | I-01, R45 suite |
| `CreationOpened` reopen | `HomeScreen` | `activateExperience()` | I-01, R45 suite |
| Recent list | `HomeScreen` | `activateExperience()` | I-01, R45 suite |
| Protection resume (×2) | `HomeScreen` | `activateProtectedExperience()` | I-01, R45 suite |
| My Apps library tap | `ExperiencesScreen` | `activateExperience()` | I-16, R45 suite |
| My Apps protection resume (×2) | `ExperiencesScreen` | `activateProtectedExperience()` | I-16, R45 suite |
| Workspace switch | `WorkspaceSwitcherSheet` | `activateRunningSession()` | I-16 |
| Restore session | — | `activateExperience()` by known id | I-16 |
| Deep links / notifications | not built | would call `activateExperience()` | n/a |

### The canonical entry flow

```
entry source
  -> ExperienceEntryPipeline.activateExperience() / activateProtectedExperience()
  -> ExperienceOpeningCoordinator          load + validate + unprotect
  -> OpenReady
  -> sessionForExperience() ?? openExistingExperience()   register (Kernel-free)
  -> ExperienceActivationManager.activate()
       -> WorkspaceSchedulingEngine.scheduleForeground()
            -> WorkspaceLifecyclePolicyEngine   pauses the inactive runtime
            -> WorkspaceRuntimeSupervisor       supervises the transition
       -> Route tracked by sessionId
       -> Navigator.push(ExperienceHostScreen)
            -> AnythingRuntime + ExperienceRuntimeController  (one per session)
  -> WorkspaceEventPublisher publishes WorkspaceUpdated
  -> on pop: route untracked
```

Graph coherence at every arrow is certified dynamically on live objects
(I-24…I-27): the scheduler's supervisor **is** the composition's supervisor,
the activation manager's scheduler **is** the composition's scheduler, and the
pipeline's collaborators **are** all the composition's singletons.

## 2. Intent / creation flow

```
HomeScreen submit
  -> ExperienceEntryPipeline.submitIntent()
  -> IntentExecutionPipeline.execute()
  -> UniversalIntentRouter
  -> ExperienceWorkspaceManager.openExperience(Intent)
  -> IntentSessionManager.startSession()
  -> ExperienceCreationCoordinator
  -> AnythingKernel.processIntent()
       -> IntentClassifier                       deterministic
       -> ExperienceResolver                     deterministic
       -> ModelUnderstandingService.understand() OPTIONAL LLM, heuristic fallback
       -> KnowledgeAcquisitionEngine.acquire()   optional, WebWeaveX-backed
       -> CompositeApplicationReasoner.reason()
            -> DeterministicReasoner              deterministic, tried first
            -> ModelApplicationReasoner           ** THE ONE mandatory LLM boundary **
       -> ExperienceSpec / ExecutionPlan          deterministic
  -> CreationEngine / runCompilerPipeline         deterministic
  -> ExperiencePackage
```

Certified: exactly four files may reach a model (I-18), exactly one reasoner
implementation may (I-19), and the understanding call keeps both deterministic
fallbacks (I-20). Everything after `reason()` is deterministic engineering.

## 3. Runtime supervision flow

```
ExperienceHostScreen
  -> AnythingRuntime                  one per session (I-12)
  -> ExperienceRuntimeController      one per session (I-13)
  -> WorkspaceRuntimeSupervisor.register(sessionId, controller)
       -> duplicate sessionId => StateError (pre-existing guard)
  -> WorkspaceSchedulingEngine.scheduleForeground/Background
       -> WorkspaceLifecyclePolicyEngine decides pause/resume
       -> supervisor applies it to the registered controller
```

A freshly composed production graph supervises zero runtimes (I-28) — any
pre-registered runtime would mean something built a runtime outside the entry
pipeline.

## 4. Protection (Kaalka) flow — canonical path

```
ExperienceHostScreen.protectWithCurrentTime/CustomTime
  -> ExperienceProtectionService
  -> ProtectionProvider (KaalkaProtectionProvider)
  -> KaalkaService                      ** sole importer of package:kaalka **
  -> package:kaalka
  -> SqliteExperienceRepository.saveProtectedEnvelope()

ExperienceEntryPipeline.activateProtectedExperience
  -> ExperienceOpeningCoordinator.openProtectedExperienceWithSeed()
  -> repository.getProtectedEnvelope()
  -> ExperienceProtectionService.unprotect()
  -> ... -> package:kaalka
```

Certified: I-21a (sole importer), I-21c (Kernel/UI never import it directly).
A second, parallel Kaalka path exists — see `KAALKA_USAGE_MATRIX.md`.

## 5. Knowledge acquisition (WebWeaveX) flow

```
AnythingKernel.processIntent()
  -> KnowledgeAcquisitionEngine.acquire()        (2 call sites, both in the Kernel)
  -> SearchProvider (DuckDuckGo)                 query -> URLs
  -> WebWeaveXAdapter.extract()                  URL -> KnowledgeResource
  -> package:webweavex renderPage/extractSemantic*
```

Certified: I-21b (only 4 files import it), I-21c (Kernel never imports it
directly — it goes through the adapter). See `WEBWEAVEX_USAGE_MATRIX.md`.

## 6. Flow invariants summary

| Flow | Single canonical path? | Mechanically certified? |
|---|---|---|
| Experience entry | YES — `ExperienceEntryPipeline` | YES (I-02, I-16, I-17) |
| Runtime creation | YES — `ExperienceHostScreen` | YES (I-12, I-13) |
| Runtime supervision | YES — supervisor via scheduler | YES (I-24, I-28) |
| Activation | YES — one activation manager | YES (I-05, I-26) |
| Intent routing | YES — one router, one pipeline | YES (I-06, I-07) |
| Reasoning | YES — one mandatory boundary | YES (I-18, I-19, I-20) |
| Protection crypto | YES — `KaalkaService` | YES (I-21a) — but two callers, see gap matrix |
| Knowledge acquisition | YES — adapter boundary | YES (I-21b, I-21c) |
