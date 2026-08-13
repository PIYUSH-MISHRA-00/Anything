/// AppComposition â€” the ONE canonical production composition root
/// (Implementation Milestone R1).
///
/// Holds every shared, app-session-scoped instance that must have exactly
/// one owner per MIS-1 Part 2/4's Ownership Matrix: the single
/// `WorldModelCoordinator` every subsystem ingests into, the single
/// `CapabilityPlatform` the Runtime dispatches through, the single
/// `AnythingProviderRegistry`/`CredentialVault` pair, and the single
/// `AnythingKernel`. Not a new Kernel/Runtime/registry â€” a plain,
/// explainable holder object (Rule 8: no hidden magic) constructed once by
/// `AnythingAppShell` and threaded via constructor injection to every
/// screen that needs it, following this codebase's existing
/// "optional injectable dependency" convention (never a DI framework).
///
/// REALITY before R1: `HomeScreen.initState` independently constructed a
/// `WorldModelCoordinator()`-less `AnythingKernel`, and
/// `ExperienceModificationCoordinator` independently constructed its own
/// default `WorldModelCoordinator()` â€” two disconnected graphs, per MIS-1
/// Part 2's "Reachability Analysis". PROPOSED here: one shared instance,
/// reached from every wired subsystem.
library;

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;

import 'package:anything/app/autonomous_workspace_runtime.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/experience_activation_manager.dart';
import 'package:anything/app/experience_entry_pipeline.dart';
import 'package:anything/app/experience_opening_coordinator.dart';
import 'package:anything/app/experience_commit.dart';
import 'package:anything/app/experience_distribution.dart';
import 'package:anything/app/experience_installation.dart';
import 'package:anything/app/experience_provenance.dart';
import 'package:anything/app/experience_workspace_manager.dart';
import 'package:anything/app/governance_engine.dart';
import 'package:anything/app/intent_execution_pipeline.dart';
import 'package:anything/app/intent_session_manager.dart';
import 'package:anything/app/universal_intent_router.dart';
import 'package:anything/app/workspace_event_publisher.dart';
import 'package:anything/app/workspace_lifecycle_policy_engine.dart';
import 'package:anything/app/workspace_runtime_supervisor.dart';
import 'package:anything/app/workspace_scheduling_engine.dart';
import 'package:anything/capabilities/adapters/file_service_adapter.dart';
import 'package:anything/capabilities/adapters/http_transport_adapter.dart';
import 'package:anything/capabilities/adapters/knowledge_acquisition_provider_adapter.dart';
import 'package:anything/capabilities/adapters/model_provider_ai_adapter.dart';
import 'package:anything/capabilities/adapters/notification_service_adapter.dart';
import 'package:anything/capabilities/builtin/ai_capability.dart';
import 'package:anything/capabilities/builtin/clock_capability.dart';
import 'package:anything/capabilities/builtin/file_capability.dart';
import 'package:anything/capabilities/builtin/http_capability.dart';
import 'package:anything/capabilities/builtin/knowledge_capability.dart';
import 'package:anything/capabilities/builtin/notification_capability.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/events/events.dart';
import 'package:anything/diagnostics/structured_logger.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/runtime_intelligence/runtime_intelligence_coordinator.dart';
import 'package:anything/security/credential_vault.dart';
import 'package:anything/security/protection_service.dart';
import 'package:anything/services/provider_registry.dart';
import 'package:anything/software_cognition/software_cognition_coordinator.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/intent_repository.dart';
import 'package:anything/storage/knowledge_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/world_model_repository.dart';
import 'package:anything/synthesis/composite_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';

/// Every HTTPS host a generated Experience's `httpClient`/`http` capability
/// declaration may reach through the wired Capability Platform. Empty by
/// default (REALITY: no generated Experience has ever declared a specific
/// host yet, since HttpCapability was unreachable before R1) â€” a real
/// per-Experience allow-list belongs to a future milestone; this stays
/// conservative (deny-all-by-default) rather than fabricating a permissive
/// list.
const List<String> _defaultHttpAllowedHosts = [];

/// What the Kernel is allowed to plan against — Implementation Specification
/// IS-P07.
///
/// THE DEFECT THIS FIXES. `AnythingKernel` defaults its `capabilityRegistry`
/// to an EMPTY `CapabilityRegistry()`, and `AppComposition` never passed one.
/// Kernel Step 8 resolves the spec's required capabilities against that
/// registry and returns `UnsupportedIntent` for anything unresolved, so in
/// production EVERY requirement was unresolvable. `BlueprintToSpecConverter`
/// requires `storage` for any blueprint that declares an entity — which is
/// every useful application — so every creation ended as
/// "Required capabilities not available: storage", after the model call had
/// already been paid for.
///
/// It was invisible because roughly forty test files register these
/// descriptors themselves before exercising the Kernel (see
/// `test/r31_intent_session_manager_test.dart`, which states the consequence
/// outright), and `CertificationRunner` builds its own full registry. Only
/// the real composition root went without.
///
/// This list is the six capabilities `capabilityPlatform` below actually
/// registers, plus `storage`, which the runtime provides intrinsically
/// through an Experience's own state schema rather than as a dispatchable
/// capability. `test/p07_ai_runtime_integration_test.dart` fails if the two
/// lists drift apart.
const List<CapabilityDescriptor> _platformCapabilityDescriptors = [
  CapabilityDescriptor(
    id: 'storage',
    version: '1.0.0',
    name: 'Storage',
    description: 'Durable local storage for an Experience\'s own state.',
    category: CapabilityCategory.storage,
    inputContract: 'state values',
    outputContract: 'persisted state',
  ),
  CapabilityDescriptor(
    id: 'clock',
    version: '1.0.0',
    name: 'Clock',
    description: 'Trusted time source for timestamps and date arithmetic.',
    category: CapabilityCategory.computation,
    inputContract: 'none',
    outputContract: 'timestamp',
  ),
  CapabilityDescriptor(
    id: 'http',
    version: '1.0.0',
    name: 'HTTP',
    description: 'HTTPS access to declared, allow-listed hosts.',
    category: CapabilityCategory.integration,
    inputContract: 'request',
    outputContract: 'response',
    requiredPermissions: ['internet'],
    networkRequired: true,
  ),
  CapabilityDescriptor(
    id: 'ai',
    version: '1.0.0',
    name: 'AI',
    description: 'Generation through the configured model provider.',
    category: CapabilityCategory.integration,
    inputContract: 'prompt',
    outputContract: 'completion',
    networkRequired: true,
  ),
  CapabilityDescriptor(
    id: 'knowledge',
    version: '1.0.0',
    name: 'Knowledge',
    description: 'Reference lookups, treated as untrusted data.',
    category: CapabilityCategory.knowledge,
    inputContract: 'query',
    outputContract: 'resources',
    networkRequired: true,
  ),
  CapabilityDescriptor(
    id: 'notifications',
    version: '1.0.0',
    name: 'Notifications',
    description: 'Per-Experience scheduled reminders, delivered in-app.',
    category: CapabilityCategory.integration,
    inputContract: 'schedule',
    outputContract: 'notification',
    requiredPermissions: ['notifications'],
  ),
  CapabilityDescriptor(
    id: 'files',
    version: '1.0.0',
    name: 'Files',
    description: 'Sandboxed file picking, import and export.',
    category: CapabilityCategory.data,
    inputContract: 'file reference',
    outputContract: 'file contents',
    requiredPermissions: ['storage'],
  ),
];

/// The one production composition root.
class AppComposition {
  /// The process-wide graph, built on first use.
  ///
  /// IS-P07 — THE DEFECT THIS FIELD FIXES.
  ///
  /// `production()` was a plain factory, so EVERY caller got a different
  /// graph: a different `AnythingProviderRegistry`, a different
  /// `SqliteExperienceRepository`, a different `EventBus`, a different
  /// Kernel. Five call sites did so independently — `AnythingAppShell`,
  /// `HomeScreen`, `ExperiencesScreen`, `ProviderPreferencesScreen`,
  /// `DeveloperScreen` — plus `_AnythingRoot`, which built a whole graph
  /// purely to call `providerRegistry.initialize()` on it and then dropped
  /// it on the floor.
  ///
  /// The user-visible consequence: configuring a provider wrote to the
  /// Settings screen's OWN registry, while the Kernel read the shell's,
  /// whose `_activeProviderId` was never resolved by anybody. A valid,
  /// verified key therefore still produced "Connect an AI provider to
  /// create new things", and no restart could fix it, because the next
  /// launch built fresh unrelated graphs again.
  ///
  /// Every doc in `docs/architecture/` already described this class as
  /// constructed exactly once; the certification invariant only asserted
  /// that reads OF ONE INSTANCE were stable, which was true and beside the
  /// point. This makes the claim real.
  static AppComposition? _production;
  final SqliteExperienceRepository experienceRepository;
  final WorldModelCoordinator worldModel;
  final AnythingProviderRegistry providerRegistry;
  final CredentialVault credentialVault;
  final CapabilityPlatform capabilityPlatform;

  /// What the Kernel plans against (IS-P07), as distinct from
  /// [capabilityPlatform], which DISPATCHES at runtime. Exposed so the two
  /// can be compared — they described different worlds until IS-P07.
  final CapabilityRegistry capabilityRegistry;

  /// The one structured logger (IS-P07). Its ring buffer is what Developer
  /// Mode reads, so recent AI activity is inspectable on the device itself
  /// rather than only through `adb logcat`.
  final StructuredLogger logger;
  final KnowledgeAcquisitionEngine knowledgeEngine;
  final SoftwareCognitionCoordinator softwareCognition;
  final RuntimeIntelligenceCoordinator runtimeIntelligence;
  final AnythingKernel kernel;

  /// The shared engineering-memory repository (Implementation Milestone
  /// R5) â€” same physical database connection as [experienceRepository]/
  /// [worldModel]'s own persistence, per the established
  /// `WorldModelRepository` sharing pattern.
  final EngineeringMemoryRepository engineeringMemory;

  /// The shared Experience Creation Coordinator (Implementation
  /// Specification IS-R36) â€” REALITY before R36: `HomeScreen.initState()`
  /// constructed its own, local `ExperienceCreationCoordinator`, never
  /// reachable from `AppComposition` (confirmed by grep before this
  /// milestone). Moved here so the SAME instance composes into
  /// [intentSessionManager] below, matching R1's own original precedent of
  /// fixing an "independently constructed, disconnected graph" problem.
  final ExperienceCreationCoordinator experienceCreationCoordinator;

  /// The shared Engineering Lifecycle Coordinator (Implementation
  /// Specification IS-R30/R36) â€” newly constructed here; R30 itself never
  /// had a shared composition-root instance (its own production callers,
  /// where any existed, constructed one locally).
  final EngineeringLifecycleCoordinator engineeringLifecycleCoordinator;

  /// The shared Intent Session Manager (Implementation Specification
  /// IS-R31/R36), composed from [experienceCreationCoordinator] and
  /// [engineeringLifecycleCoordinator] above â€” never a second, independent
  /// pair of coordinators.
  final IntentSessionManager intentSessionManager;

  /// The shared Experience Workspace Manager (Implementation Specification
  /// IS-R32/R36). Reuses the exact `workspaceManager` name already used on
  /// `HomeScreen`/`ExperienceHostScreen`'s optional constructor parameters.
  final ExperienceWorkspaceManager workspaceManager;

  /// The shared Universal Intent Router (Implementation Specification
  /// IS-R33/R36). Reuses the exact `intentRouter` name already used on
  /// `HomeScreen`'s optional constructor parameter.
  final UniversalIntentRouter intentRouter;

  /// The shared Autonomous Workspace Runtime (Implementation Specification
  /// IS-R34/R36). Reuses the exact `workspaceRuntime` name already used on
  /// `HomeScreen`/`ExperienceHostScreen`'s optional constructor parameters.
  final AutonomousWorkspaceRuntime workspaceRuntime;

  /// The shared Event Bus (Implementation Specification IS-R35/R36).
  /// Reuses the exact `eventBus` name already used on `HomeScreen`/
  /// `ExperienceHostScreen`'s optional constructor parameters.
  final EventBus eventBus;

  /// The shared Workspace Event Publisher (Implementation Specification
  /// IS-R35/R36), bound to [eventBus] above â€” never a second, independent
  /// bus.
  final WorkspaceEventPublisher eventPublisher;

  /// The shared Intent Execution Pipeline (Implementation Specification
  /// IS-R37) â€” the ONE canonical production path from an `Intent` to
  /// engineering execution, composed from [intentRouter]/[eventPublisher]
  /// above. See `docs/architecture/INTENT_EXECUTION_PIPELINE.md`.
  final IntentExecutionPipeline intentExecutionPipeline;

  /// The shared Workspace Runtime Supervisor (Implementation Specification
  /// IS-R40/R41) â€” the ONE registry every `ExperienceHostScreen` registers
  /// its `ExperienceRuntimeController` with, constructed here so every real
  /// navigation call site (`HomeScreen`) threads the SAME instance. REALITY
  /// before R41: `WorkspaceRuntimeSupervisor` (R40) had no shared,
  /// composition-root instance â€” each screen either got `null` or, if ever
  /// supplied, an independent one; workspace-wide policy application had no
  /// real multi-screen reach. See `docs/architecture/SHARED_RUNTIME_SUPERVISION.md`.
  final WorkspaceRuntimeSupervisor workspaceRuntimeSupervisor;

  /// The shared Workspace Scheduling Engine (Implementation Specification
  /// IS-R42/R43) â€” the ONE coordinator that makes real, registered runtimes
  /// in [workspaceRuntimeSupervisor] match [workspaceManager]'s real
  /// active/background state, constructed here so every real navigation
  /// call site (`HomeScreen`) threads the SAME instance, matching
  /// [workspaceRuntimeSupervisor]'s own R41 precedent. See
  /// `docs/architecture/WORKSPACE_EXPERIENCE_SWITCHER.md`.
  final WorkspaceSchedulingEngine workspaceSchedulingEngine;

  /// The shared Experience Activation Manager (Implementation Specification
  /// IS-R44) â€” the ONE coordinator of runtime + navigation activation for an
  /// already-running Experience, composed from [workspaceSchedulingEngine]/
  /// [eventPublisher] above. See
  /// `docs/architecture/EXPERIENCE_ACTIVATION_MANAGER.md`.
  final ExperienceActivationManager experienceActivationManager;

  /// The shared Unified Experience Entry Pipeline (Implementation
  /// Specification IS-R45) â€” the ONE canonical entry mechanism every real
  /// production Experience-opening path (create, Recent list, birth
  /// completion, protection resume, Workspace Switcher) flows through,
  /// composed from [intentExecutionPipeline]/[experienceActivationManager]/
  /// [workspaceManager]/the other already-shared services above, plus a
  /// dedicated, real `ExperienceOpeningCoordinator`. See
  /// `docs/architecture/UNIFIED_EXPERIENCE_ENTRY_PIPELINE.md`.
  final ExperienceEntryPipeline experienceEntryPipeline;

  /// The shared Experience Distribution Framework (IS-R53) â€” the ONE owner of
  /// Experience movement (import, export, packaging, verification). It starts
  /// the R52/R51/R49 chain by assigning provenance; it never classifies trust,
  /// enforces policy or activates a runtime.
  final ExperienceDistributionFramework experienceDistribution;

  /// The shared Activity Repository (IS-R57).
  ///
  /// Before R57 this was the ONE repository with no composition owner: nine
  /// separate call sites each built their own, and it appeared nowhere here.
  /// R56 proved that was not a correctness defect — the class is stateless
  /// with a `const` constructor and `SharedPreferences` is a process singleton
  /// — so this is ownership canonicalisation, not a bug fix, and behaviour is
  /// unchanged.
  final ActivityRepository activityRepository;

  /// The shared Intent Repository (IS-R57).
  ///
  /// Like [activityRepository], this had no composition owner before R57 — it
  /// was constructed once, directly, inside `HomeScreen`. Stateless and
  /// `const`, so this is ownership only and behaviour is unchanged.
  final IntentRepository intentRepository;

  /// The shared Experience Commit Framework (IS-R55) — the ONE owner of
  /// writing Experience state. Creation, modification, evolution, protection,
  /// installation and removal all terminate here; nothing else writes.
  final ExperienceCommitFramework experienceCommit;

  /// The shared Experience Installation Framework (IS-R54) — the ONE owner of
  /// COMMITTING an Experience to this device: install, upgrade, downgrade,
  /// repair, rollback, dependency preparation and compatibility validation.
  /// It never activates, never classifies trust, never enforces policy and
  /// never encrypts — it asks `ExperienceProtectionService` to protect.
  final ExperienceInstallationFramework experienceInstallation;

  /// IS-P09: canonical My Apps invalidation signal. Incremented whenever the
  /// shared [experienceCommit] successfully mutates the library. Screens that
  /// list Experiences listen here so newly created apps appear immediately
  /// without restart or manual refresh.
  final ValueNotifier<int> experienceLibraryRevision;

  AppComposition._({
    required this.experienceRepository,
    required this.worldModel,
    required this.providerRegistry,
    required this.credentialVault,
    required this.capabilityPlatform,
    required this.capabilityRegistry,
    required this.logger,
    required this.knowledgeEngine,
    required this.softwareCognition,
    required this.runtimeIntelligence,
    required this.kernel,
    required this.engineeringMemory,
    required this.experienceCreationCoordinator,
    required this.engineeringLifecycleCoordinator,
    required this.intentSessionManager,
    required this.workspaceManager,
    required this.intentRouter,
    required this.workspaceRuntime,
    required this.eventBus,
    required this.eventPublisher,
    required this.intentExecutionPipeline,
    required this.workspaceRuntimeSupervisor,
    required this.workspaceSchedulingEngine,
    required this.experienceActivationManager,
    required this.experienceEntryPipeline,
    required this.experienceDistribution,
    required this.experienceInstallation,
    required this.experienceCommit,
    required this.experienceLibraryRevision,
    required this.activityRepository,
    required this.intentRepository,
  });

  /// The ONE canonical production graph, shared by every caller.
  ///
  /// Built on first call and returned unchanged thereafter, so a screen that
  /// resolves a service from here gets the same object the Kernel is using.
  /// Constructor injection remains the way to supply a different graph — see
  /// [freshForTesting].
  factory AppComposition.production() =>
      _production ??= AppComposition._build(requireProviderForGeneration: true);

  /// A brand-new, independent graph that the caller owns and must close.
  ///
  /// Tests that construct a composition and then `close()` its repository
  /// need their own; closing the shared one would leave every later caller
  /// in the same isolate holding a closed database.
  @visibleForTesting
  factory AppComposition.freshForTesting() =>
      AppComposition._build(requireProviderForGeneration: false);

  /// Forgets the shared graph so the next [production] call builds a new one.
  ///
  /// Needed by any test that launches the real application more than once in
  /// one file. The graph caches in-flight futures (the provider registry's
  /// storage load), and `flutter_test` tears down a zone between tests, so a
  /// future completed in the first test is awaited forever by the second —
  /// the same trap `DurableCollectionStore`'s own doc comment records.
  @visibleForTesting
  static void resetForTesting() => _production = null;

  /// Builds the real, production composition graph. Every dependency below
  /// is the SAME canonical implementation MIS-1 Part 1/2 already identified
  /// â€” this constructor wires them together, it does not invent any of
  /// them.
  factory AppComposition._build({bool requireProviderForGeneration = true}) {
    final experienceRepository = SqliteExperienceRepository();

    // IS-R57: the ONE activity repository. Every coordinator and screen that
    // records activity receives THIS instance.
    const activityRepository = ActivityRepository();
    const intentRepository = IntentRepository();
    final credentialVault = CredentialVault();

    // IS-P07: `StructuredLogger` has existed since V10 and, before this
    // milestone, no production code constructed one — the AI boundary, the
    // one subsystem that reaches the network and spends a user's quota,
    // reported nothing at all. This is the ONE logger; it is passed to the
    // provider registry, which passes it to every provider it builds.
    final logger = StructuredLogger();

    final providerRegistry = AnythingProviderRegistry(
      credentialVault: credentialVault,
      logger: logger,
    );

    final worldModel = WorldModelCoordinator(
      persistence: WorldModelRepository(
        experienceRepository: experienceRepository,
      ),
    );

    // Implementation Specification IS-R48: knowledge now survives restart.
    // The SAME `WebWeaveXAdapter` instance is threaded into both the engine
    // (extraction/normalization) and the cache (canonical representation for
    // persistence), so there is exactly one WebWeaveX boundary object in the
    // production graph â€” never two adapters that could canonicalize
    // differently. `KnowledgeCache` remains the single cache;
    // `KnowledgeRepository` is its durable backing store, not a second cache.
    final webweavexAdapter = WebWeaveXAdapter();
    final knowledgeEngine = KnowledgeAcquisitionEngine(
      searchProvider: DuckDuckGoSearchProvider(),
      webweavexAdapter: webweavexAdapter,
      cache: KnowledgeCache(
        repository: KnowledgeRepository(),
        canonicalizer: webweavexAdapter,
      ),
      logger: logger,
    );

    // IS-R49: constructed here rather than further down, because the real
    // notification presenter registered below delivers through it. Exactly
    // one EventBus still exists in the production graph.
    final eventBus = EventBus();

    // Implementation Specification IS-R51: the ONE governance engine. It
    // DECIDES; every existing owner keeps enforcing. Its canonical rule set
    // additionally carries the host allowlist below, so network policy is
    // stated once â€” `HttpCapability` continues to enforce it, unchanged.
    final governance = OperatingSystemGovernanceEngine(
      rules: [
        ...OperatingSystemGovernanceEngine.canonicalRules,
        const NetworkHostAllowlistRule(allowedHosts: _defaultHttpAllowedHosts),
      ],
    );

    // IS-R52: the ONE trust classifier. It COMPUTES trust from provenance;
    // governance CONSUMES it; the capability platform ENFORCES the resulting
    // decision. Four verbs, four owners â€” see docs/architecture/
    // EXPERIENCE_IDENTITY_ARCHITECTURE.md.
    const trustClassifier = ExperienceTrustClassifier();

    // IS-R53: the ONE distribution framework and the ONE package verifier.
    // Distribution MOVES experiences; it never classifies trust, never
    // enforces policy and never activates a runtime â€” each of those has an
    // owner already. See docs/architecture/EXPERIENCE_DISTRIBUTION_ARCHITECTURE.md.
    const packageVerifier = ExperiencePackageVerifier();

    // IS-R54: the ONE installation framework. Distribution MOVES, the
    // installer COMMITS, the repository STORES — see
    // docs/architecture/EXPERIENCE_INSTALLATION_ARCHITECTURE.md.
    //
    // The protection service is given the SAME repository rather than being
    // left to construct its own (its constructor defaults to a fresh
    // `SqliteExperienceRepository`), so protecting an installed Experience
    // writes through the one store this composition owns. The installer asks;
    // that service performs. There is still exactly one crypto importer.
    // IS-R55: the ONE commit framework. Every path that changes Experience
    // state — creation, modification, evolution, protection, installation and
    // removal — writes through this and nothing else. See
    // docs/architecture/EXPERIENCE_COMMIT_ARCHITECTURE.md.
    final experienceLibraryRevision = ValueNotifier<int>(0);
    final commitFramework = ExperienceCommitFramework(
      repository: experienceRepository,
      onLibraryMutation: () {
        experienceLibraryRevision.value = experienceLibraryRevision.value + 1;
      },
    );

    final installer = ExperienceInstallationFramework(
      repository: experienceRepository,
      protectionService: ExperienceProtectionService(
        repository: experienceRepository,
        commitFramework: commitFramework,
      ),
      commitFramework: commitFramework,
    );

    final distribution = ExperienceDistributionFramework(
      repository: experienceRepository,
      verifier: packageVerifier,
      installer: installer,
    );

    final capabilityPlatform =
        CapabilityPlatform(
            governance: governance,
            trustClassifier: trustClassifier,
          )
          ..register(ClockCapability())
          ..register(
            HttpCapability(
              transport: RealHttpTransport(),
              allowedHosts: _defaultHttpAllowedHosts,
            ),
          )
          ..register(
            AiCapability(
              provider: ModelProviderAiAdapter(providerRegistry),
              experienceId: '',
            ),
          )
          ..register(
            KnowledgeCapability(
              provider: KnowledgeAcquisitionProviderAdapter(knowledgeEngine),
            ),
          )
          // IS-P25: WeatherCapability/NewsCapability are gone. They were
          // domain-named 65-line near-duplicates that delegated to the same
          // WebWeaveX provider as `knowledge`, and no factory ever emitted
          // the service types that reached them. External data — weather,
          // news, anything else — flows through the ONE generic knowledge
          // capability, whose requirement carries topic + freshness
          // semantics instead of a domain name.
          // Implementation Specification IS-R49: the last two production Fake*
          // registrations are gone. Both now resolve to real services, each
          // constructed exactly once here â€” there is no alternate composition
          // root and no conditional production graph.
          //
          // RealNotificationService persists schedules durably (SharedPreferences,
          // the backend ActivityRepository already uses â€” no new storage system),
          // enforces per-Experience ownership, computes real due state, and
          // delivers in-app through the EXISTING EventBus as the EXISTING R35
          // `NotificationGenerated` event. No new event hierarchy, no second
          // notification framework: `NotificationPlanner`/`BackgroundCoordinator`
          // remain the canonical planning layer, untouched.
          //
          // HONEST SCOPE, unchanged from what background_coordinator.dart already
          // states about itself: OS-level BACKGROUND delivery still requires a
          // platform plugin plus native Android/iOS configuration that cannot be
          // exercised by `flutter test` and cannot be verified without a device.
          // It is left as one explicit seam (`NotificationPresenter`) rather than
          // shipped unverified â€” see IS-R49's report and gap G-20.
          ..register(
            NotificationCapability(
              service: RealNotificationService(
                presenter: EventBusNotificationPresenter(bus: eventBus),
              ),
              experienceId: '',
            ),
          )
          // RealFileService is genuinely complete: real picking via
          // package:file_picker (already a dependency), real sandboxed adoption,
          // export, temporary files and workspace/Experience assets via
          // path_provider + dart:io. Every path is resolved and verified to be
          // inside the sandbox root.
          ..register(
            FileCapability(service: RealFileService(), experienceId: ''),
          );

    // Implementation Milestone R16: built before `kernel` so the SAME
    // instance is shared with `AnythingKernel`'s autonomous discovery step
    // AND `ExperienceCreationCoordinator`'s manual-reference path below â€”
    // never a second Software Cognition Engine.
    final softwareCognition = SoftwareCognitionCoordinator();

    // IS-P07: without this the Kernel plans against an empty registry and
    // refuses every Experience at Step 8 — see
    // `_platformCapabilityDescriptors`.
    final capabilityRegistry = CapabilityRegistry();
    for (final descriptor in _platformCapabilityDescriptors) {
      capabilityRegistry.register(descriptor);
    }

    final kernel = AnythingKernel(
      providerRegistry: providerRegistry,
      capabilityRegistry: capabilityRegistry,
      knowledgeEngine: knowledgeEngine,
      worldModel: worldModel,
      softwareCognition: softwareCognition,
      // IS-P22: production requires an AI provider for app generation; the
      // testing composition stays lenient so pipeline-mechanics tests need no
      // live model.
      reasoner: CompositeApplicationReasoner(
        providerRegistry: providerRegistry,
        requireProviderForGeneration: requireProviderForGeneration,
      ),
    );

    final engineeringMemory = EngineeringMemoryRepository(
      experienceRepository: experienceRepository,
    );

    // Implementation Specification IS-R36: the real "AI Operating System"
    // service graph (R31-R35), constructed here â€” the single production
    // composition root â€” in real dependency order. REALITY before R36:
    // none of these 8 services was reachable from `AppComposition`;
    // `ExperienceCreationCoordinator` was instead constructed locally,
    // disconnected, inside `HomeScreen.initState()` (confirmed by grep
    // before this milestone). See `docs/architecture/OPERATING_SYSTEM_COMPOSITION.md`
    // for the full real service graph and dependency-lifetime analysis.
    final experienceCreationCoordinator = ExperienceCreationCoordinator(
      kernel: kernel,
      activity: activityRepository,
      // IS-R55: this previously took neither, so it built its OWN
      // SqliteExperienceRepository. Same database file, but a second instance
      // and — more importantly — a commit path outside the shared framework.
      // Both are now the composition's.
      repository: experienceRepository,
      commitFramework: commitFramework,
      worldModel: worldModel,
      softwareCognition: softwareCognition,
      engineeringMemory: engineeringMemory,
      logger: logger,
    );
    final engineeringLifecycleCoordinator = EngineeringLifecycleCoordinator(
      kernel: kernel,
      engineeringMemory: engineeringMemory,
    );
    final intentSessionManager = IntentSessionManager(
      activity: activityRepository,
      creationCoordinator: experienceCreationCoordinator,
      lifecycleCoordinator: engineeringLifecycleCoordinator,
      engineeringMemory: engineeringMemory,
    );
    final workspaceManager = ExperienceWorkspaceManager(
      sessionManager: intentSessionManager,
      activity: activityRepository,
    );
    final intentRouter = UniversalIntentRouter(workspace: workspaceManager);
    final workspaceRuntime = AutonomousWorkspaceRuntime(
      workspace: workspaceManager,
    );
    // `eventBus` itself is now constructed earlier (above `capabilityPlatform`),
    // because IS-R49's real notification presenter delivers through it. It is
    // still the SAME single instance every consumer below receives â€” moving
    // the construction point changes ordering, never cardinality.
    final eventPublisher = WorkspaceEventPublisher(bus: eventBus);

    // Implementation Specification IS-R37: the one canonical production
    // path from an Intent to engineering execution â€” composed from
    // [intentRouter]/[eventPublisher] above, never a second router.
    final intentExecutionPipeline = IntentExecutionPipeline(
      router: intentRouter,
      eventPublisher: eventPublisher,
    );

    // Implementation Specification IS-R41: the one shared runtime-controller
    // registry, composed from [eventPublisher] above â€” never a second
    // supervisor. `WorkspaceRuntimeSupervisor` itself is unmodified since R40.
    final workspaceRuntimeSupervisor = WorkspaceRuntimeSupervisor(
      eventPublisher: eventPublisher,
    );

    // Implementation Specification IS-R43: the one shared scheduling
    // coordinator, composed from [workspaceRuntime]/[workspaceRuntimeSupervisor]/
    // [workspaceManager]/[eventPublisher] above â€” never a second scheduler.
    // `WorkspaceLifecyclePolicyEngine` is genuinely stateless (a `const`
    // constructor with no mutable fields, R39) so constructing one here
    // inline is behaviorally identical to sharing a single instance.
    final workspaceSchedulingEngine = WorkspaceSchedulingEngine(
      workspaceRuntime: workspaceRuntime,
      supervisor: workspaceRuntimeSupervisor,
      policyEngine: const WorkspaceLifecyclePolicyEngine(),
      workspace: workspaceManager,
      eventPublisher: eventPublisher,
    );

    // Implementation Specification IS-R44: the one shared activation
    // coordinator, composed from [workspaceSchedulingEngine]/[eventPublisher]
    // above â€” never a second scheduler, never a second Navigator.
    final experienceActivationManager = ExperienceActivationManager(
      scheduler: workspaceSchedulingEngine,
      eventPublisher: eventPublisher,
    );

    // Implementation Specification IS-R45: the one shared entry pipeline,
    // composed from [intentExecutionPipeline]/[experienceActivationManager]/
    // the other already-shared services above, plus a dedicated, real
    // `ExperienceOpeningCoordinator` (stateless-ish, same reasoning as
    // `WorkspaceLifecyclePolicyEngine`'s own shared-inline-instance
    // precedent) â€” never a second scheduler, never a second Navigator.
    final experienceEntryPipeline = ExperienceEntryPipeline(
      intentExecutionPipeline: intentExecutionPipeline,
      openingCoordinator: ExperienceOpeningCoordinator(
        activity: activityRepository,
      ),
      activationManager: experienceActivationManager,
      workspaceManager: workspaceManager,
      worldModel: worldModel,
      capabilityPlatform: capabilityPlatform,
      engineeringMemory: engineeringMemory,
      workspaceRuntime: workspaceRuntime,
      eventBus: eventBus,
      runtimeSupervisor: workspaceRuntimeSupervisor,
      scheduler: workspaceSchedulingEngine,
    );

    return AppComposition._(
      experienceRepository: experienceRepository,
      worldModel: worldModel,
      providerRegistry: providerRegistry,
      credentialVault: credentialVault,
      capabilityPlatform: capabilityPlatform,
      capabilityRegistry: capabilityRegistry,
      logger: logger,
      knowledgeEngine: knowledgeEngine,
      softwareCognition: softwareCognition,
      runtimeIntelligence: RuntimeIntelligenceCoordinator(),
      kernel: kernel,
      engineeringMemory: engineeringMemory,
      experienceCreationCoordinator: experienceCreationCoordinator,
      engineeringLifecycleCoordinator: engineeringLifecycleCoordinator,
      intentSessionManager: intentSessionManager,
      workspaceManager: workspaceManager,
      intentRouter: intentRouter,
      workspaceRuntime: workspaceRuntime,
      eventBus: eventBus,
      eventPublisher: eventPublisher,
      intentExecutionPipeline: intentExecutionPipeline,
      workspaceRuntimeSupervisor: workspaceRuntimeSupervisor,
      workspaceSchedulingEngine: workspaceSchedulingEngine,
      experienceActivationManager: experienceActivationManager,
      experienceEntryPipeline: experienceEntryPipeline,
      experienceDistribution: distribution,
      experienceInstallation: installer,
      experienceCommit: commitFramework,
      experienceLibraryRevision: experienceLibraryRevision,
      activityRepository: activityRepository,
      intentRepository: intentRepository,
    );
  }
}
