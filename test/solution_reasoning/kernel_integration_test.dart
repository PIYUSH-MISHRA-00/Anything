/// Vision V5 MSRA — Kernel integration: AnythingKernel.processIntent runs
/// the full Multi-Solution Reasoning pipeline for every ReasoningReady
/// result, no bypass; the selected solution's architecture reaches the
/// blueprint, and its already-computed EngineeringPlan is reused (not
/// recomputed) by the time ExecutionPlanReady is returned.
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
        fields: [
          SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'entries_list',
        name: 'Entries',
        purpose: 'list',
        sourceEntityId: 'entry',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      SemanticView(
        id: 'entries_form',
        name: 'Add Entry',
        purpose: 'form',
        sourceEntityId: 'entry',
        viewType: BlueprintViewType.form,
      ),
      SemanticView(
        id: 'entries_detail',
        name: 'Entry Detail',
        purpose: 'detail',
        sourceEntityId: 'entry',
        viewType: BlueprintViewType.detail,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_entry',
        name: 'Add Entry',
        targetEntityId: 'entry',
      ),
    ],
  );
}

Future<ExecutionPlanReady> _runKernel() async {
  final kernel = AnythingKernel(
    providerRegistry: _FakeProviderRegistry(),
    capabilityRegistry: _registryWithStorage(),
    reasoner: _FixedReasoner(_fieldSurveyApp()),
  );
  final outcome = await kernel.processIntent(
    Intent.create(expression: 'track my field survey entries'),
  );
  expect(outcome, isA<ExecutionPlanReady>());
  return outcome as ExecutionPlanReady;
}

void main() {
  test(
    'processIntent runs SolutionExplorer and returns a real SolutionDecision',
    () async {
      final ready = await _runKernel();
      expect(ready.solutionDecision, isNotNull);
      expect(ready.solutionDecision!.selected, isNotNull);
      expect(ready.solutionDecision!.rejected, isNotEmpty);
    },
  );

  test(
    'at least two candidates were genuinely generated and compared',
    () async {
      final ready = await _runKernel();
      final decision = ready.solutionDecision!;
      expect(decision.rejected.length + 1, greaterThanOrEqualTo(2));
      expect(decision.graph.nodes.length, decision.rejected.length + 1);
    },
  );

  test(
    'the blueprint is derived from the SELECTED solution\'s architecture',
    () async {
      final ready = await _runKernel();
      final selectedEntityCount =
          ready.solutionDecision!.selected.architecture.entities.length;
      expect(ready.blueprint!.entities.length, selectedEntityCount);
    },
  );

  test(
    'the EngineeringPlan is reused from the selected solution, not recomputed',
    () async {
      final ready = await _runKernel();
      expect(
        identical(
          ready.engineeringPlan,
          ready.solutionDecision!.selected.engineeringVariation.plan,
        ),
        isTrue,
      );
    },
  );

  test(
    'selection is never simply "first candidate" — the selected id matches the scored winner',
    () async {
      final ready = await _runKernel();
      final decision = ready.solutionDecision!;
      final allCandidates = [
        decision.selected,
        ...decision.rejected.map((r) => r.candidate),
      ];
      final best = allCandidates.reduce(
        (a, b) => (a.score!.overall.score >= b.score!.overall.score) ? a : b,
      );
      // The selected candidate must be at least as good as every other by
      // overall score (allowing the tie-break cascade to pick among equals).
      expect(decision.selected.score!.overall.score, best.score!.overall.score);
    },
  );
}
