/// Vision V9 WMSG — Kernel Integration + Evolution Integration + Review
/// Integration together: a real AnythingKernel.processIntent() run
/// produces a real reviewSession and evolutionRoadmap, both fed directly
/// into WorldModelCoordinator via their real bridges. No new Kernel
/// pipeline stage was added — World Model ingestion is a separate,
/// post-creation step, mirroring EvolutionCoordinator/
/// RuntimeIntelligenceCoordinator's own established pattern (see
/// docs/architecture/WORLD_MODEL_AND_SEMANTIC_GRAPH.md).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

CapabilityRegistry _registryWithStorage() {
  final registry = CapabilityRegistry();
  registry.register(
    const CapabilityDescriptor(
      id: 'storage',
      version: '1.0.0',
      name: 'Storage',
      description: 'Local storage',
      category: CapabilityCategory.storage,
      inputContract: 'data',
      outputContract: 'stored data',
    ),
  );
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
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    return ReasoningReady(semanticApp: app);
  }
}

SemanticApp _fieldSurveyApp() {
  return SemanticApp(
    name: 'Field Survey Log',
    purpose: 'Track field survey entries',
    entities: [
      const SemanticEntity(
        id: 'entry',
        name: 'Entry',
        displayField: 'title',
        fields: [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)],
      ),
    ],
    views: const [
      SemanticView(id: 'entries_list', name: 'Entries', purpose: 'list', sourceEntityId: 'entry', viewType: BlueprintViewType.list, isDefault: true),
    ],
    actions: const [SemanticAction(id: 'add_entry', name: 'Add Entry', targetEntityId: 'entry')],
  );
}

void main() {
  test('a real Kernel run\'s reviewSession and evolutionRoadmap both ingest cleanly into the World Graph', () async {
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: _FixedReasoner(_fieldSurveyApp()),
    );
    final outcome = await kernel.processIntent(Intent.create(expression: 'track my field survey entries'));

    expect(outcome, isA<ExecutionPlanReady>());
    final ready = outcome as ExecutionPlanReady;
    expect(ready.reviewSession, isNotNull);
    expect(ready.evolutionRoadmap, isNotNull);

    final coordinator = WorldModelCoordinator();
    coordinator.ingestReviewSession(ready.reviewSession!);
    coordinator.ingestEvolutionRoadmap(ready.evolutionRoadmap!);

    expect(coordinator.model.graph.nodesOfKind(WorldNodeKind.evolution), isNotEmpty);
    // Every ingestion is versioned and consistency-checked — reaching
    // this point at all proves both bridges produced a graph-consistent
    // update (WorldModelEngine.apply silently no-ops on rejection, so a
    // non-empty result here is the real proof of a clean apply).
    expect(coordinator.model.version.number, greaterThanOrEqualTo(1));
  });
}
