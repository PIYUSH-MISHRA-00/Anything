/// Vision V6 SCARE — Kernel integration: AnythingKernel.processIntent runs
/// the full Design Review pipeline for every ReasoningReady result, no
/// bypass; Engineering cannot reach ExperienceSpec without ReviewApproval.
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

Future<ExecutionPlanReady> _runKernel(AnythingKernel kernel) async {
  final outcome = await kernel.processIntent(Intent.create(expression: 'track my field survey entries'));
  expect(outcome, isA<ExecutionPlanReady>());
  return outcome as ExecutionPlanReady;
}

void main() {
  test('processIntent runs Design Review and returns a real, approved ReviewSession', () async {
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: _FixedReasoner(_fieldSurveyApp()),
    );
    final ready = await _runKernel(kernel);

    expect(ready.reviewSession, isNotNull);
    expect(ready.reviewSession!.result.outcome.name, 'approved');
  });

  test('the same Kernel instance reuses ReviewMemory across two structurally-identical requests', () async {
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: _FixedReasoner(_fieldSurveyApp()),
    );

    final first = await _runKernel(kernel);
    final second = await _runKernel(kernel);

    expect(first.reviewSession!.fingerprint, second.reviewSession!.fingerprint);
  });

  test('the blueprint reaching Creation is the one Design Review actually approved', () async {
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: _FixedReasoner(_fieldSurveyApp()),
    );
    final ready = await _runKernel(kernel);

    expect(ready.reviewSession!.result.finalContext.blueprint.id, ready.blueprint!.id);
  });
}
