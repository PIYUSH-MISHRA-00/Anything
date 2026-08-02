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
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/runtime_intelligence/runtime_intelligence_coordinator.dart';
import 'package:anything/security/credential_vault.dart';
import 'package:anything/services/provider_registry.dart';
import 'package:anything/software_cognition/software_cognition_coordinator.dart';
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

    final kernel = AnythingKernel(providerRegistry: providerRegistry, knowledgeEngine: knowledgeEngine, worldModel: worldModel);

    return AppComposition._(
      experienceRepository: experienceRepository,
      worldModel: worldModel,
      providerRegistry: providerRegistry,
      credentialVault: credentialVault,
      capabilityPlatform: capabilityPlatform,
      knowledgeEngine: knowledgeEngine,
      softwareCognition: SoftwareCognitionCoordinator(),
      runtimeIntelligence: RuntimeIntelligenceCoordinator(),
      kernel: kernel,
    );
  }
}
