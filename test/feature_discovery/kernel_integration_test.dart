/// Vision V4 FDI — Kernel integration: AnythingKernel.processIntent runs
/// Feature Discovery + Review + Refinement for every ReasoningReady result,
/// before Architecture, with no bypass; the resulting FeaturePlan reaches
/// ExecutionPlanReady and genuinely shapes Engineering's decisions.
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

SemanticApp _hiveApp() {
  return SemanticApp(
    name: 'Hive Inspection Log',
    purpose: 'Track beehive inspections',
    entities: [
      const SemanticEntity(
        id: 'inspection',
        name: 'Inspection',
        displayField: 'notes',
        fields: [
          SemanticField(
            id: 'notes',
            name: 'Notes',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'inspections_list',
        name: 'Inspections',
        purpose: 'list',
        sourceEntityId: 'inspection',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_inspection',
        name: 'Add Inspection',
        targetEntityId: 'inspection',
      ),
    ],
  );
}

Future<ExecutionPlanReady> _runKernel() async {
  final kernel = AnythingKernel(
    providerRegistry: _FakeProviderRegistry(),
    capabilityRegistry: _registryWithStorage(),
    reasoner: _FixedReasoner(_hiveApp()),
  );
  final outcome = await kernel.processIntent(
    Intent.create(expression: 'track my hive inspections'),
  );
  expect(outcome, isA<ExecutionPlanReady>());
  return outcome as ExecutionPlanReady;
}

void main() {
  test(
    'processIntent runs FeatureDiscoveryEngine+Refinement and returns an approved plan',
    () async {
      final ready = await _runKernel();
      expect(ready.featurePlan, isNotNull);
      expect(ready.featurePlan!.outcome, FeatureRefinementOutcome.approved);
    },
  );

  test(
    'the discovered FeatureGraph contains the expected structural features',
    () {
      // Re-derive from the same fixed app via a second run for a focused
      // shape assertion (kept separate from the plan-object identity test
      // above for clarity).
      return _runKernel().then((ready) {
        final graph = ready.featurePlan!.finalGraph;
        expect(graph.nodesOfCategory(FeatureCategory.persistence), isNotEmpty);
        expect(graph.nodesOfCategory(FeatureCategory.search), isNotEmpty);
        expect(graph.nodesOfCategory(FeatureCategory.indexing), isNotEmpty);
      });
    },
  );

  test(
    'Engineering genuinely consumes the FeatureGraph — index decision is corroborated end-to-end',
    () async {
      final ready = await _runKernel();
      final indexDecision = ready.engineeringPlan!.finalCandidate.data.indexes
          .firstWhere((i) => i.entityId == 'inspection')
          .decision;
      expect(
        indexDecision.rationale,
        contains('Confirmed by Feature Discovery'),
      );
    },
  );

  test(
    'Engineering genuinely consumes the FeatureGraph — offline decision cites it end-to-end',
    () async {
      final ready = await _runKernel();
      expect(
        ready.engineeringPlan!.finalCandidate.offline.decision.rationale,
        contains("Feature Discovery's Offline Strategy feature"),
      );
    },
  );
}
