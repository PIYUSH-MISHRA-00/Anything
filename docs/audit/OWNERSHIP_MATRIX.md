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

## Governance ownership (IS-R51)

THREE policy engines, three **disjoint** domains. A fourth, or any overlap,
fails certification (I-48).

| Engine | Owns | Vocabulary | Acts on |
|---|---|---|---|
| `WorkspaceLifecyclePolicyEngine` (R39) | runtime lifecycle | pause/resume/terminate/restore | `ExperienceRuntimeController` |
| `RetentionPolicyEngine` (R50) | data retention | retain/evict/expire | nothing — decides only |
| `OperatingSystemGovernanceEngine` (R51) | system governance | allow/deny/requireApproval | nothing — decides only |

**Governance imports nothing** (I-49). Composition wires decision to enforcer;
governance never reaches across.

### Decision vs enforcement

| Decision (governance) | Enforcement (unchanged owner) |
|---|---|
| may this Experience use this capability | `CapabilityPlatform.invoke()` |
| is this host reachable | `HttpCapability` |
| may this Experience reach a model | `AnythingKernel` still owns reasoning |
| may this Experience run in background | `WorkspaceSchedulingEngine` still owns scheduling |
| may this Experience be auto-restored | (decision surface; no consumer yet) |
| what is retained, for how long | `RetentionPolicyEngine` (R50), unchanged |
| when a runtime pauses/resumes | `WorkspaceLifecyclePolicyEngine` (R39), unchanged |
| protection (Kaalka) | `ExperienceProtectionService` — governance has a `security` hook, no rule |

### Experience trust model

`untrusted < experimental < imported < local < verified < trusted`, ordered so
`atLeast()` is meaningful. Governance decides; `CapabilityPlatform` enforces.

**Not yet assigned in production:** every Experience is `local` (the default)
because nothing computes provenance yet. The model, rules and enforcement are
real and tested; the classifier is future work. See
`docs/audit/GOVERNANCE_USAGE_MATRIX.md` §6.

## Distribution ownership (IS-R53)

The producer layer R50–R52 were waiting for.

| Owner | Verb | Notes |
|---|---|---|
| `ExperienceCreationCoordinator` | CREATES | pre-R53, unchanged |
| `ExperienceDistributionFramework` | MOVES | import, export, packaging, preparation |
| `ExperiencePackageVerifier` | VERIFIES | delegates structure/integrity to `ExperiencePackageValidator` |
| `ExperienceTrustClassifier` | COMPUTES trust | R52 |
| `OperatingSystemGovernanceEngine` | CONSUMES trust | R51 |
| `CapabilityPlatform` | ENFORCES | R49/R51 |
| `SqliteExperienceRepository` | STORES | canonical |
| `ExperienceEntryPipeline` | ACTIVATES | R45 |
| `ExperienceProtectionService` | PROTECTS | Kaalka |

**Distribution touches none of the last five.** Certified (I-58).

### Two canonical types EXTENDED, not duplicated

IS-R53 asked to "introduce" `ExperienceManifest` and
`ExperiencePackageVerifier`; both already existed. R53 embedded the first in a
transport envelope and delegated to the existing validator from the second —
because the same specification forbids a second manifest and a second
verifier. Certified by I-59 and I-60.

### Import never activates

`import()` returns a persisted, provenance-bearing Experience and stops.
Importing something must not run it — activation requires a deliberate user
action through `ExperienceEntryPipeline`.

### Protection is not carried across

The envelope records whether the source was protected; an imported Experience
is persisted unprotected. Distribution must not fabricate a protected state it
cannot honour.

## IS-R54 — Installation

| Verb | Owner | Added |
|---|---|---|
| MOVES | `ExperienceDistributionFramework` | R53 |
| **COMMITS** | **`ExperienceInstallationFramework`** | **R54** |
| EVALUATES compatibility | `ExperienceCompatibilityEvaluator` | R54 |
| PLANS dependencies | `ExperienceDependencyPlanner` | R54 |
| VALIDATES structure | `ExperiencePackageValidator` | canonical, delegated to |
| MIGRATES | `MigrationExecutor` | canonical, untouched |
| STORES | `SqliteExperienceRepository` | canonical |
| PROTECTS | `ExperienceProtectionService` | Kaalka |
| ACTIVATES | `ExperienceEntryPipeline` | R45 |

### Distribution no longer commits

R53's `import()` wrote both repository rows itself. It now delegates to the ONE
installer. Signatures, return types and observable behaviour are unchanged —
the ownership moved, the behaviour did not, and every R53 test passes
untouched. The installer takes `ExperiencePackage` + `ExperienceProvenance`
rather than a distribution package, so it knows nothing about transport and the
dependency runs one way: distribution -> installer -> repository.

### Install never activates

`install()` commits and stops. The installer may not name the entry pipeline,
the host screen, the activation manager, `Navigator`, `AnythingRuntime` or
`ExperienceRenderer`. Installing something must not run it — the property R53
established for import, enforced one layer lower where the temptation is
stronger.

### The installer requests protection; it never performs it

Task 7 wires `ExperienceProtectionService` INTO the installer, so this is a
"must not reach past it" rule rather than the usual "must not reference" rule.
`isProtected` commits as `false` and only the protection service can make it
true. A protection request with no service wired is REPORTED, never silently
ignored.

### Committing is NOT yet unified — stated plainly

Four sites still commit directly: creation, modification, evolution and
protection. R54 established the owner and moved the one path Task 8 names.
Rerouting the rest would have redesigned four coordinators in a milestone
forbidden from replacing architecture. Recorded as gap G-30.

## IS-R55 — Commit

| Verb | Owner | Added |
|---|---|---|
| **COMMITS / ROLLS BACK / REPAIRS** | **`ExperienceCommitFramework`** | **R55** |
| RUNS TRANSACTIONS | `RepositoryTransactionCoordinator` | R55 |
| STORES | `SqliteExperienceRepository` | canonical, unchanged |
| INSTALLS | `ExperienceInstallationFramework` | R54 |
| MOVES | `ExperienceDistributionFramework` | R53 |
| ENCRYPTS | `ExperienceProtectionService` | canonical, unchanged |

### One writer, enforced

```
creation \ modification \ evolution \ protection \ installation \ removal
                              |
                  ExperienceCommitFramework
                              |
                   SqliteExperienceRepository
```

The audit found SIX pre-R55 writers, not the four R54 listed — a UI screen was
deleting Experiences directly. All six now terminate here, and certification
forbids every other file in `lib/` from naming a repository write method.

### What each subsystem kept, and what it gave up

Creation kept package construction, provenance, World Model and engineering
memory; it gave up ALL persistence — the analyzer then reported its repository
field as unused, which is the cleanest evidence that it is decoupled rather
than merely routed around, so the field was deleted.

Modification kept diffing, validation and the modification engine; it gave up
persistence and rollback. Evolution kept proposals, executor and validator.
Protection kept **all crypto** — it is still the only thing that encrypts — and
gave up persistence only. Installation kept compatibility, dependencies,
migrations, kind derivation and the protection request; it gave up persistence,
rollback and repair.

### Atomicity, precisely scoped

Package + metadata, and envelope + flag + plaintext removal, are now each ONE
SQLite transaction. Repository writes paired with World Model ingestion,
engineering-memory persistence or activity records are still separate and
best-effort — cross-store, never in scope, and unchanged since before R55.
G-28 is closed for repository commits and only for those.

## IS-R56 — Durable collections

| Verb | Owner | Added |
|---|---|---|
| **READ-MODIFY-WRITE on a durable key, with no yield between** | **`DurableCollectionStore`** | **R56** |
| Notification semantics | `RealNotificationService` | R49, unchanged |
| Activity / intent history semantics | their repositories | canonical, unchanged |
| Retention bounds | `RetentionPolicyEngine` | R50, unchanged |
| Theme preference (one scalar key) | `ThemeProvider` | canonical, PINNED |

### One critical section, three collections

```
RealNotificationService ─┐
ActivityRepository      ─┼──> DurableCollectionStore ──> SharedPreferences
IntentRepository        ─┘
```

The store owns ONLY the critical section. Each repository keeps its own types,
its own JSON and its own semantics; the store knows nothing about what any
collection means.

### No lock — the yield is removed instead

`update` resolves `SharedPreferences` first, then runs the mutation and the
write with NO `await` between them. Dart is single-threaded, so with no yield
point inside the critical section concurrent callers cannot interleave. The
callback is a plain SYNCHRONOUS function, so an await inside it does not
compile — the type system is the enforcement.

An earlier design used a static per-key future chain and DEADLOCKED across
`flutter_test` zones; it is recorded in the store's doc comment and in the ADR
so it is not retried. The lock existed only to survive a yield that its own
async callback reintroduced. The store is stateless and `const`-constructible,
so existing `const` call sites are untouched.

### Claim first, present second

`deliverDue` removes the due set INSIDE the critical section and presents
OUTSIDE it. R49 did the reverse, and two concurrent callers delivered the same
notification twice. The trade is that delivery is now at-most-once rather than
at-least-once — correct for a contract that promises exactly once, and recorded
as G-38.
