/// AppComposition — the ONE canonical production composition root
/// (Implementation Milestone R1).
///
/// Holds every shared, app-session-scoped instance that must have exactly
/// one owner per MIS-1 Part 2/4's Ownership Matrix: the single
/// `WorldModelCoordinator` every subsystem ingests into, the single
/// `CapabilityPlatform` the Runtime dispatches through, the single
/// `AnythingProviderRegistry`/`CredentialVault` pair, and the single
/// `AnythingKernel`. Not a new Kernel/Runtime/registry — a plain,
/// explainable holder object (Rule 8: no hidden magic) constructed once by
/// `AnythingAppShell` and threaded via constructor injection to every
/// screen that needs it, following this codebase's existing
/// "optional injectable dependency" convention (never a DI framework).
///
/// REALITY before R1: `HomeScreen.initState` independently constructed a
/// `WorldModelCoordinator()`-less `AnythingKernel`, and
/// `ExperienceModificationCoordinator` independently constructed its own
/// default `WorldModelCoordinator()` — two disconnected graphs, per MIS-1
/// Part 2's "Reachability Analysis". PROPOSED here: one shared instance,
/// reached from every wired subsystem.
library;

import 'package:anything/app/autonomous_workspace_runtime.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/experience_workspace_manager.dart';
import 'package:anything/app/intent_execution_pipeline.dart';
import 'package:anything/app/intent_session_manager.dart';
import 'package:anything/app/universal_intent_router.dart';
import 'package:anything/app/workspace_event_publisher.dart';
import 'package:anything/capabilities/adapters/http_transport_adapter.dart';
import 'package:anything/capabilities/adapters/knowledge_acquisition_provider_adapter.dart';
import 'package:anything/capabilities/adapters/model_provider_ai_adapter.dart';
import 'package:anything/capabilities/builtin/ai_capability.dart';
import 'package:anything/capabilities/builtin/clock_capability.dart';
import 'package:anything/capabilities/builtin/file_capability.dart';
import 'package:anything/capabilities/builtin/http_capability.dart';
import 'package:anything/capabilities/builtin/knowledge_capability.dart';
import 'package:anything/capabilities/builtin/notification_capability.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/core/events/events.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/runtime_intelligence/runtime_intelligence_coordinator.dart';
import 'package:anything/security/credential_vault.dart';
import 'package:anything/services/provider_registry.dart';
import 'package:anything/software_cognition/software_cognition_coordinator.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/world_model_repository.dart';
import 'package:anything/world_model/world_model_coordinator.dart';

/// Every HTTPS host a generated Experience's `httpClient`/`http` capability
/// declaration may reach through the wired Capability Platform. Empty by
/// default (REALITY: no generated Experience has ever declared a specific
/// host yet, since HttpCapability was unreachable before R1) — a real
/// per-Experience allow-list belongs to a future milestone; this stays
/// conservative (deny-all-by-default) rather than fabricating a permissive
/// list.
const List<String> _defaultHttpAllowedHosts = [];

/// The one production composition root. Construct exactly once (in
/// `AnythingAppShell`), never per-screen.
class AppComposition {
  final SqliteExperienceRepository experienceRepository;
  final WorldModelCoordinator worldModel;
  final AnythingProviderRegistry providerRegistry;
  final CredentialVault credentialVault;
  final CapabilityPlatform capabilityPlatform;
  final KnowledgeAcquisitionEngine knowledgeEngine;
  final SoftwareCognitionCoordinator softwareCognition;
  final RuntimeIntelligenceCoordinator runtimeIntelligence;
  final AnythingKernel kernel;

  /// The shared engineering-memory repository (Implementation Milestone
  /// R5) — same physical database connection as [experienceRepository]/
  /// [worldModel]'s own persistence, per the established
  /// `WorldModelRepository` sharing pattern.
  final EngineeringMemoryRepository engineeringMemory;

  /// The shared Experience Creation Coordinator (Implementation
  /// Specification IS-R36) — REALITY before R36: `HomeScreen.initState()`
  /// constructed its own, local `ExperienceCreationCoordinator`, never
  /// reachable from `AppComposition` (confirmed by grep before this
  /// milestone). Moved here so the SAME instance composes into
  /// [intentSessionManager] below, matching R1's own original precedent of
  /// fixing an "independently constructed, disconnected graph" problem.
  final ExperienceCreationCoordinator experienceCreationCoordinator;

  /// The shared Engineering Lifecycle Coordinator (Implementation
  /// Specification IS-R30/R36) — newly constructed here; R30 itself never
  /// had a shared composition-root instance (its own production callers,
  /// where any existed, constructed one locally).
  final EngineeringLifecycleCoordinator engineeringLifecycleCoordinator;

  /// The shared Intent Session Manager (Implementation Specification
  /// IS-R31/R36), composed from [experienceCreationCoordinator] and
  /// [engineeringLifecycleCoordinator] above — never a second, independent
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
  /// IS-R35/R36), bound to [eventBus] above — never a second, independent
  /// bus.
  final WorkspaceEventPublisher eventPublisher;

  /// The shared Intent Execution Pipeline (Implementation Specification
  /// IS-R37) — the ONE canonical production path from an `Intent` to
  /// engineering execution, composed from [intentRouter]/[eventPublisher]
  /// above. See `docs/architecture/INTENT_EXECUTION_PIPELINE.md`.
  final IntentExecutionPipeline intentExecutionPipeline;

  AppComposition._({
    required this.experienceRepository,
    required this.worldModel,
    required this.providerRegistry,
    required this.credentialVault,
    required this.capabilityPlatform,
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
  });

  /// Builds the real, production composition graph. Every dependency below
  /// is the SAME canonical implementation MIS-1 Part 1/2 already identified
  /// — this constructor wires them together, it does not invent any of
  /// them.
  factory AppComposition.production() {
    final experienceRepository = SqliteExperienceRepository();
    final credentialVault = CredentialVault();
    final providerRegistry = AnythingProviderRegistry(credentialVault: credentialVault);

    final worldModel = WorldModelCoordinator(persistence: WorldModelRepository(experienceRepository: experienceRepository));

    final knowledgeEngine = KnowledgeAcquisitionEngine(searchProvider: DuckDuckGoSearchProvider(), webweavexAdapter: WebWeaveXAdapter());

    final capabilityPlatform = CapabilityPlatform()
      ..register(ClockCapability())
      ..register(HttpCapability(transport: RealHttpTransport(), allowedHosts: _defaultHttpAllowedHosts))
      ..register(AiCapability(provider: ModelProviderAiAdapter(providerRegistry), experienceId: ''))
      ..register(KnowledgeCapability(provider: KnowledgeAcquisitionProviderAdapter(knowledgeEngine)))
      // REALITY (documented, not papered over): no real OS-level
      // notification delivery or file-picker-backed FileService exists in
      // this codebase yet (no flutter_local_notifications wiring; adopting
      // package:file_picker into a real, ownership-tracked FileService is
      // real feature work, not "wiring," per R1's own scope). Registering
      // the Fake* implementations keeps the dispatch path structurally
      // real and testable without claiming a production capability that
      // does not exist.
      ..register(NotificationCapability(service: FakeNotificationService(), experienceId: ''))
      ..register(FileCapability(service: FakeFileService(), experienceId: ''));

    // Implementation Milestone R16: built before `kernel` so the SAME
    // instance is shared with `AnythingKernel`'s autonomous discovery step
    // AND `ExperienceCreationCoordinator`'s manual-reference path below —
    // never a second Software Cognition Engine.
    final softwareCognition = SoftwareCognitionCoordinator();
    final kernel = AnythingKernel(
      providerRegistry: providerRegistry,
      knowledgeEngine: knowledgeEngine,
      worldModel: worldModel,
      softwareCognition: softwareCognition,
    );

    final engineeringMemory = EngineeringMemoryRepository(experienceRepository: experienceRepository);

    // Implementation Specification IS-R36: the real "AI Operating System"
    // service graph (R31-R35), constructed here — the single production
    // composition root — in real dependency order. REALITY before R36:
    // none of these 8 services was reachable from `AppComposition`;
    // `ExperienceCreationCoordinator` was instead constructed locally,
    // disconnected, inside `HomeScreen.initState()` (confirmed by grep
    // before this milestone). See `docs/architecture/OPERATING_SYSTEM_COMPOSITION.md`
    // for the full real service graph and dependency-lifetime analysis.
    final experienceCreationCoordinator = ExperienceCreationCoordinator(
      kernel: kernel,
      worldModel: worldModel,
      softwareCognition: softwareCognition,
      engineeringMemory: engineeringMemory,
    );
    final engineeringLifecycleCoordinator = EngineeringLifecycleCoordinator(kernel: kernel, engineeringMemory: engineeringMemory);
    final intentSessionManager = IntentSessionManager(
      creationCoordinator: experienceCreationCoordinator,
      lifecycleCoordinator: engineeringLifecycleCoordinator,
      engineeringMemory: engineeringMemory,
    );
    final workspaceManager = ExperienceWorkspaceManager(sessionManager: intentSessionManager);
    final intentRouter = UniversalIntentRouter(workspace: workspaceManager);
    final workspaceRuntime = AutonomousWorkspaceRuntime(workspace: workspaceManager);
    final eventBus = EventBus();
    final eventPublisher = WorkspaceEventPublisher(bus: eventBus);

    // Implementation Specification IS-R37: the one canonical production
    // path from an Intent to engineering execution — composed from
    // [intentRouter]/[eventPublisher] above, never a second router.
    final intentExecutionPipeline = IntentExecutionPipeline(router: intentRouter, eventPublisher: eventPublisher);

    return AppComposition._(
      experienceRepository: experienceRepository,
      worldModel: worldModel,
      providerRegistry: providerRegistry,
      credentialVault: credentialVault,
      capabilityPlatform: capabilityPlatform,
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
    );
  }
}
