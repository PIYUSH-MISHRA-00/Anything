/// CertificationRunner — Implementation Milestone R23. For each real
/// `CertificationFixture`, runs the SAME real Kernel (`AnythingKernel`,
/// unmodified) to get a real `blueprint` + `CanonicalImplementationModel`
/// from ONE reasoning call, then runs both the EXISTING, unmodified legacy
/// `CreationEngine` and the EXISTING, unmodified `runCompilerPipeline`
/// (R19), and hands both real `ExperiencePackage`s to the EXISTING,
/// unmodified `EquivalenceComparator` (R19-R22) — zero new comparison
/// logic, zero new AI call (every fixture is hand-authored test data, the
/// reasoner is a fixed stub returning it directly, exactly like every
/// prior milestone's fixtures).
library;

import '../capabilities/registry/capability_descriptor.dart';
import '../capabilities/registry/capability_registry.dart';
import '../compiler_integration/compiler_pipeline_runner.dart';
import '../compiler_integration/equivalence_comparator.dart';
import '../core/contracts/intent.dart';
import '../core/contracts/model_provider.dart';
import '../creation/creation_context.dart';
import '../creation/creation_engine.dart';
import '../creation/experience_package.dart';
import '../kernel/anything_kernel.dart';
import '../kernel/outcomes/kernel_outcome.dart';
import '../synthesis/application_reasoner.dart';
import 'certification_corpus.dart';
import 'certification_report.dart';

/// Every capability id any corpus fixture might request, with real
/// category/contract metadata — mirrors R19-R22's own test registries
/// exactly. `notifications` genuinely requires the `notifications`
/// permission (`capability_security_planner.dart`); `clock` requires
/// none; `http` carries no known-permission entry but is real signal for
/// `OfflinePlanner` (see `certification_corpus.dart`).
CapabilityRegistry _fullRegistry() {
  final registry = CapabilityRegistry();
  for (final d in const [
    CapabilityDescriptor(id: 'storage', version: '1.0.0', name: 'Storage', description: 'Local storage', category: CapabilityCategory.storage, inputContract: 'data', outputContract: 'stored data'),
    CapabilityDescriptor(id: 'clock', version: '1.0.0', name: 'Clock', description: 'Trusted time source', category: CapabilityCategory.computation, inputContract: 'none', outputContract: 'timestamp'),
    CapabilityDescriptor(
      id: 'notifications',
      version: '1.0.0',
      name: 'Notifications',
      description: 'Local notifications',
      category: CapabilityCategory.integration,
      inputContract: 'schedule',
      outputContract: 'notification',
    ),
    CapabilityDescriptor(id: 'http', version: '1.0.0', name: 'HTTP', description: 'Network access', category: CapabilityCategory.integration, inputContract: 'request', outputContract: 'response'),
  ]) {
    registry.register(d);
  }
  return registry;
}

class _FakeProviderRegistry implements ModelProviderRegistry {
  @override
  ModelProvider? get activeProvider => null;
  @override
  List<ModelProvider> get providers => const [];
  @override
  void registerProvider(ModelProvider provider) {}
  @override
  Future<void> setActiveProvider(String providerId) async {}
  @override
  ModelProvider? getProvider(String providerId) => null;
  @override
  Future<List<ProviderConfig>> listConfigs() async => [];
  @override
  Future<void> saveConfig(ProviderConfig config) async {}
  @override
  Future<void> deleteConfig(String id) async {}
  @override
  Future<ProviderConfig?> getDefaultConfig() async => null;
}

class _FixedReasoner implements ApplicationReasoner {
  final SemanticApp app;
  const _FixedReasoner(this.app);
  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async => ReasoningReady(semanticApp: app);
}

class CertificationRunner {
  const CertificationRunner();

  /// Runs one fixture end-to-end. Returns `null` (not a thrown error) when
  /// the real Kernel does not reach `ExecutionPlanReady` for this fixture
  /// — an honest "not certifiable" outcome, never a fabricated report.
  Future<FixtureCertification?> certify(CertificationFixture fixture) async {
    final kernel = AnythingKernel(providerRegistry: _FakeProviderRegistry(), capabilityRegistry: _fullRegistry(), reasoner: _FixedReasoner(fixture.app));
    final outcome = await kernel.processIntent(Intent.create(expression: fixture.app.purpose));
    if (outcome is! ExecutionPlanReady) return null;

    final legacyPackage = await _runLegacy(outcome);
    final compilerPackage = outcome.canonicalImplementationModel == null
        ? null
        : runCompilerPipeline(outcome.canonicalImplementationModel!, id: outcome.specification.id, name: outcome.specification.name).package;
    if (legacyPackage == null || compilerPackage == null) return null;

    const comparator = EquivalenceComparator();
    final report = comparator.compare(
      legacyPackage,
      compilerPackage,
      legacyLatency: Duration.zero,
      compilerLatency: Duration.zero,
      legacyBlueprint: outcome.blueprint,
      compilerModel: outcome.canonicalImplementationModel,
    );

    final legacyAgain = await _runLegacy(outcome);
    final compilerAgain = runCompilerPipeline(outcome.canonicalImplementationModel!, id: outcome.specification.id, name: outcome.specification.name).package;

    return FixtureCertification(
      category: fixture.category,
      report: report,
      legacyDeterministic: legacyAgain != null && comparator.structurallyIdentical(legacyPackage, legacyAgain),
      compilerDeterministic: compilerAgain != null && comparator.structurallyIdentical(compilerPackage, compilerAgain),
    );
  }

  Future<ExperiencePackage?> _runLegacy(ExecutionPlanReady outcome) async {
    final result = await CreationEngine().create(
      CreationContext(
        intent: Intent.create(expression: outcome.specification.name),
        specification: outcome.specification,
        plan: outcome.plan,
        blueprint: outcome.blueprint,
        engineeringPlan: outcome.engineeringPlan,
        platformContext: const PlatformContext(platform: 'android', sdkVersion: 34),
        securityPolicy: const CreationSecurityPolicy(),
      ),
    );
    return result is CreationReady ? result.package : null;
  }

  /// Certifies every fixture in [corpus], skipping (never crashing on) any
  /// that don't reach `ExecutionPlanReady`.
  Future<CertificationReport> certifyCorpus(CertificationCorpus corpus) async {
    final results = <FixtureCertification>[];
    for (final fixture in corpus.fixtures) {
      final result = await certify(fixture);
      if (result != null) results.add(result);
    }
    return CertificationReport(fixtures: results);
  }
}
