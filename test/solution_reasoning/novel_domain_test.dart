/// Vision V5 MSRA — novel domain proof: a domain with zero footprint
/// anywhere in lib/ or test/ flows through the full Kernel to a genuinely
/// multi-candidate, structurally-selected SolutionDecision.
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
  registry.register(
    const CapabilityDescriptor(
      id: 'knowledge',
      version: '1.0.0',
      name: 'Knowledge',
      description: 'Knowledge acquisition',
      category: CapabilityCategory.knowledge,
      inputContract: 'query',
      outputContract: 'knowledge bundle',
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

/// "Beekeeper's Apiary Rotation Log" — never referenced anywhere else in
/// lib/ or test/, used solely to prove Multi-Solution Reasoning plans
/// structurally, not by domain name.
SemanticApp _apiaryApp() {
  return SemanticApp(
    name: "Beekeeper's Apiary Rotation Log",
    purpose: 'Track hive rotations between apiary sites',
    entities: [
      SemanticEntity(
        id: 'rotation',
        name: 'Rotation',
        displayField: 'summary',
        fields: [
          const SemanticField(id: 'summary', name: 'Summary', type: BlueprintFieldType.text, required: true),
          const SemanticField(
            id: 'siteId',
            name: 'Site',
            type: BlueprintFieldType.reference,
            referenceEntityId: 'site',
            required: false,
          ),
        ],
      ),
      const SemanticEntity(
        id: 'site',
        name: 'Site',
        fields: [SemanticField(id: 'name', name: 'Name', type: BlueprintFieldType.text, required: true)],
      ),
    ],
    views: const [
      SemanticView(id: 'rotations_list', name: 'Rotations', purpose: 'list', sourceEntityId: 'rotation', viewType: BlueprintViewType.list, isDefault: true),
      SemanticView(id: 'rotations_form', name: 'Add Rotation', purpose: 'form', sourceEntityId: 'rotation', viewType: BlueprintViewType.form),
      SemanticView(id: 'rotations_detail', name: 'Rotation Detail', purpose: 'detail', sourceEntityId: 'rotation', viewType: BlueprintViewType.detail),
    ],
    actions: const [SemanticAction(id: 'add_rotation', name: 'Add Rotation', targetEntityId: 'rotation')],
    requiredCapabilities: const ['knowledge'],
  );
}

void main() {
  test('a never-before-seen domain reaches a genuinely multi-candidate, structurally-selected decision', () async {
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: _FixedReasoner(_apiaryApp()),
    );

    final outcome = await kernel.processIntent(Intent.create(expression: 'track my apiary hive rotations'));

    expect(outcome, isA<ExecutionPlanReady>());
    final ready = outcome as ExecutionPlanReady;
    final decision = ready.solutionDecision!;

    // http/ai/knowledge capability -> cacheThenOnline baseline -> Offline
    // First applies; 3 views -> Flat Navigation applies. Balanced + Minimal
    // always apply. Four real, structurally distinct candidates.
    final labels = [decision.selected, ...decision.rejected.map((r) => r.candidate)].map((c) => c.label).toSet();
    expect(labels, {'Balanced', 'Minimal', 'Flat Navigation', 'Offline First'});

    expect(decision.selected.tradeoffs, hasLength(15));
    expect(decision.rationale, isNotEmpty);
  });
}
