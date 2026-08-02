/// Vision V3 AEE — novel domain proof: a domain with zero footprint
/// anywhere in lib/ flows through the full Kernel (Architecture ->
/// Engineering -> Refinement) to an approved EngineeringPlan whose state
/// machines use only the generic vocabulary — never a domain-specific
/// state name ("NotesState", "CalculatorState", etc.).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/engineering_plan.dart';
import 'package:anything/application_engineering/engineering_types.dart';
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

/// "Lighthouse Maintenance Log" — never referenced anywhere else in lib/
/// or test/, used solely to prove AEE plans structurally, not by domain name.
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
        fields: [
          SemanticField(id: 'name', name: 'Name', type: BlueprintFieldType.text, required: true),
        ],
      ),
    ],
    views: [
      const SemanticView(
        id: 'visits_list',
        name: 'Visits',
        purpose: 'list',
        sourceEntityId: 'visit',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: [
      const SemanticAction(id: 'log_visit', name: 'Log Visit', targetEntityId: 'visit'),
      const SemanticAction(
        id: 'remove_visit',
        name: 'Remove Visit',
        targetEntityId: 'visit',
        actionType: BlueprintActionType.delete,
      ),
    ],
  );
}

void main() {
  test('a never-before-seen domain reaches an approved EngineeringPlan using only GenericState', () async {
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: _FixedReasoner(_lighthouseApp()),
    );

    final outcome = await kernel.processIntent(Intent.create(expression: 'log lighthouse maintenance visits'));

    expect(outcome, isA<ExecutionPlanReady>());
    final ready = outcome as ExecutionPlanReady;
    expect(ready.engineeringPlan, isNotNull);
    expect(ready.engineeringPlan!.outcome, EngineeringRefinementOutcome.approved);

    final candidate = ready.engineeringPlan!.finalCandidate;
    expect(candidate.behaviors, hasLength(2));
    for (final behavior in candidate.behaviors) {
      for (final transition in behavior.stateMachine.transitions) {
        expect(GenericState.values, contains(transition.from));
        expect(GenericState.values, contains(transition.to));
      }
      // No entity/domain-specific identifier ever leaks into a state name —
      // GenericState is a fixed enum, so this is true by construction, but
      // asserted explicitly against the domain vocabulary as a regression
      // guard against ever adding a per-entity state in the future.
      final domainWords = ['visit', 'lighthouse', 'Visit', 'Lighthouse', 'Maintenance'];
      for (final state in GenericState.values) {
        expect(domainWords.any((w) => state.name.contains(w)), isFalse);
      }
    }
  });
}
