/// Vision V6 SCARE — novel domain proof: a domain with zero footprint
/// anywhere in lib/ or test/ flows through the full Kernel to a real,
/// approved Design Review session.
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

/// "Lighthouse Keeper's Fuel Log" — never referenced anywhere else in
/// lib/ or test/, used solely to prove Design Review reasons structurally.
SemanticApp _fuelLogApp() {
  return SemanticApp(
    name: "Lighthouse Keeper's Fuel Log",
    purpose: 'Track lighthouse generator fuel consumption',
    entities: [
      SemanticEntity(
        id: 'reading',
        name: 'FuelReading',
        displayField: 'notes',
        fields: [
          const SemanticField(id: 'notes', name: 'Notes', type: BlueprintFieldType.text, required: true),
          const SemanticField(
            id: 'generatorId',
            name: 'Generator',
            type: BlueprintFieldType.reference,
            referenceEntityId: 'generator',
            required: false,
          ),
        ],
      ),
      const SemanticEntity(
        id: 'generator',
        name: 'Generator',
        fields: [SemanticField(id: 'label', name: 'Label', type: BlueprintFieldType.text, required: true)],
      ),
    ],
    views: const [
      SemanticView(id: 'readings_list', name: 'Readings', purpose: 'list', sourceEntityId: 'reading', viewType: BlueprintViewType.list, isDefault: true),
      SemanticView(id: 'readings_form', name: 'Add Reading', purpose: 'form', sourceEntityId: 'reading', viewType: BlueprintViewType.form),
      SemanticView(id: 'readings_detail', name: 'Reading Detail', purpose: 'detail', sourceEntityId: 'reading', viewType: BlueprintViewType.detail),
    ],
    actions: const [SemanticAction(id: 'add_reading', name: 'Add Reading', targetEntityId: 'reading')],
  );
}

void main() {
  test('a never-before-seen domain reaches a real, approved Design Review session', () async {
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: _FixedReasoner(_fuelLogApp()),
    );

    final outcome = await kernel.processIntent(Intent.create(expression: 'track lighthouse generator fuel readings'));

    expect(outcome, isA<ExecutionPlanReady>());
    final ready = outcome as ExecutionPlanReady;
    final session = ready.reviewSession!;

    expect(session.result.outcome.name, 'approved');
    expect(session.decisions, isNotEmpty);
    expect(session.fingerprint, isNotEmpty);
  });
}
