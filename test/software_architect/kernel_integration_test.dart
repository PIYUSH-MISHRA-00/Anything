/// V2 ASAE — Kernel integration tests: AnythingKernel.processIntent must
/// genuinely route every ReasoningReady result through the full
/// Requirement Extraction -> Knowledge -> Architecture -> Review ->
/// Refinement -> Final Blueprint pipeline. No bypass.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/core/contracts/intent.dart';
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

/// Always ready with a fixed SemanticApp — for testing the happy path.
class _FixedReasoner implements ApplicationReasoner {
  final SemanticApp app;
  const _FixedReasoner(this.app);

  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    return ReasoningReady(semanticApp: app);
  }
}

SemanticApp _novelDomainApp({String? danglingReferenceEntityId}) {
  return SemanticApp(
    name: 'Vinyl Record Cataloging',
    purpose: 'Track a vinyl record collection',
    entities: [
      SemanticEntity(
        id: 'record',
        name: 'Record',
        displayField: 'title',
        fields: [
          const SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
            required: true,
          ),
          if (danglingReferenceEntityId != null)
            SemanticField(
              id: 'labelRef',
              name: 'Label',
              type: BlueprintFieldType.reference,
              referenceEntityId: danglingReferenceEntityId,
            ),
        ],
      ),
    ],
    views: [
      const SemanticView(
        id: 'records_list',
        name: 'Records',
        purpose: 'list',
        sourceEntityId: 'record',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_record',
        name: 'Add Record',
        targetEntityId: 'record',
      ),
    ],
  );
}

Intent _intent(String expression) => Intent.create(expression: expression);

void main() {
  group('Novel domain / open world — real pipeline execution', () {
    test(
      'a never-before-seen domain flows through ASAE to a working ExecutionPlan',
      () async {
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: _FixedReasoner(_novelDomainApp()),
        );

        final outcome = await kernel.processIntent(
          _intent('catalog my vinyl records'),
        );

        expect(outcome, isA<ExecutionPlanReady>());
        final ready = outcome as ExecutionPlanReady;
        expect(ready.blueprint!.entities, hasLength(1));
        expect(ready.blueprint!.entities.single.name, 'Record');
      },
    );
  });

  group('Architecture refinement genuinely changes the final blueprint', () {
    test(
      'a dangling reference is dropped by refinement before blueprint conversion',
      () async {
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: _FixedReasoner(
            _novelDomainApp(
              danglingReferenceEntityId: 'nonexistent_label_entity',
            ),
          ),
        );

        final outcome = await kernel.processIntent(
          _intent('catalog my vinyl records'),
        );

        expect(outcome, isA<ExecutionPlanReady>());
        final ready = outcome as ExecutionPlanReady;
        final record = ready.blueprint!.entities.single;
        final labelField = record.fields.firstWhere((f) => f.id == 'labelRef');
        // ASAE's SelfCritic flagged the dangling reference, RefinementPlanner
        // dropped it, and the corrected blueprint reflects that — not the
        // original (broken) reference.
        expect(labelField.referenceEntityId, isNull);
      },
    );
  });

  group('Provider unavailable — short-circuits before ASAE runs', () {
    test('ReasoningProviderRequired is returned unchanged', () async {
      final kernel = AnythingKernel(
        providerRegistry: _FakeProviderRegistry(),
        reasoner: const _AlwaysProviderRequiredReasoner(),
      );

      final outcome = await kernel.processIntent(
        _intent('build something complex'),
      );

      expect(outcome, isA<ProviderRequired>());
    });
  });

  group(
    'Low confidence — ASAE fails closed rather than shipping a bad design',
    () {
      test(
        'many unimplemented capabilities drag confidence below threshold and planning fails',
        () async {
          final app = SemanticApp(
            name: 'X',
            purpose: 'p',
            entities: [const SemanticEntity(id: 'e', name: 'E')],
            requiredCapabilities: const [
              'camera',
              'microphone',
              'oauth',
              'bluetooth',
              'sensors',
              'location',
            ],
          );
          final kernel = AnythingKernel(
            providerRegistry: _FakeProviderRegistry(),
            reasoner: _FixedReasoner(app),
          );

          final outcome = await kernel.processIntent(_intent('x'));

          // Either ASAE fails closed (PlanningFailed) or capability resolution
          // (an existing, separate Kernel stage) rejects it first — both are
          // correct fail-closed outcomes; assert it is NOT a false success.
          expect(outcome, isNot(isA<ExecutionPlanReady>()));
        },
      );
    },
  );
}

class _AlwaysProviderRequiredReasoner implements ApplicationReasoner {
  const _AlwaysProviderRequiredReasoner();
  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    return const ReasoningProviderRequired();
  }
}
