/// Vision V4 FDI — novel domain proof: a domain with zero footprint
/// anywhere in lib/ or test/ flows through the full Kernel (Requirement
/// Graph -> Feature Discovery -> Refinement -> Architecture -> Engineering)
/// to an approved FeaturePlan built entirely from structural signals.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/feature_discovery/feature_plan.dart';
import 'package:anything/feature_discovery/feature_types.dart';
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

/// "Lighthouse Maintenance Log" — never referenced anywhere else in lib/
/// or test/, used solely to prove Feature Discovery plans structurally,
/// not by domain name.
SemanticApp _lighthouseApp() {
  return SemanticApp(
    name: 'Lighthouse Maintenance Log',
    purpose: 'Track lighthouse maintenance visits',
    entities: [
      SemanticEntity(
        id: 'visit',
        name: 'MaintenanceVisit',
        displayField: 'summary',
        fields: [
          const SemanticField(id: 'summary', name: 'Summary', type: BlueprintFieldType.text, required: true),
          const SemanticField(
            id: 'lighthouseId',
            name: 'Lighthouse',
            type: BlueprintFieldType.reference,
            referenceEntityId: 'lighthouse',
            required: false,
          ),
        ],
      ),
      const SemanticEntity(
        id: 'lighthouse',
        name: 'Lighthouse',
        fields: [SemanticField(id: 'name', name: 'Name', type: BlueprintFieldType.text, required: true)],
      ),
    ],
    views: const [
      SemanticView(
        id: 'visits_list',
        name: 'Visits',
        purpose: 'list',
        sourceEntityId: 'visit',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [
      SemanticAction(id: 'log_visit', name: 'Log Visit', targetEntityId: 'visit'),
      SemanticAction(id: 'remove_visit', name: 'Remove Visit', targetEntityId: 'visit', actionType: BlueprintActionType.delete),
    ],
  );
}

void main() {
  test('a never-before-seen domain reaches an approved FeaturePlan built from structure alone', () async {
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: _FixedReasoner(_lighthouseApp()),
    );

    final outcome = await kernel.processIntent(Intent.create(expression: 'log lighthouse maintenance visits'));

    expect(outcome, isA<ExecutionPlanReady>());
    final ready = outcome as ExecutionPlanReady;
    expect(ready.featurePlan, isNotNull);
    expect(ready.featurePlan!.outcome, FeatureRefinementOutcome.approved);

    final graph = ready.featurePlan!.finalGraph;
    // Relational feature discovered from the reference field, search+index
    // from the list view, persistence from both entities — all structural.
    expect(graph.nodesOfCategory(FeatureCategory.relational), hasLength(1));
    expect(graph.nodesOfCategory(FeatureCategory.search), hasLength(1));
    expect(graph.nodesOfCategory(FeatureCategory.persistence), hasLength(2));
  });
}
