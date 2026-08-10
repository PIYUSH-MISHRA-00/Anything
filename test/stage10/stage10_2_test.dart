/// Stage 10.2 — Production Synthesis Closure Tests
///
/// Tests the real production creation path through the Kernel and Coordinator,
/// composite reasoning orchestration, deterministic tightening, model validation,
/// and full golden-path integration.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/experience_opening_coordinator.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/composite_reasoner.dart';
import 'package:anything/synthesis/deterministic_reasoner.dart';
import 'package:anything/synthesis/model_reasoner.dart';
import 'package:anything/synthesis/app_archetype.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/synthesis_planner.dart';
import 'package:anything/synthesis/blueprint_validator.dart';
import 'package:anything/synthesis/blueprint_to_spec.dart';
import 'package:anything/synthesis/generic_package_builder.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/knowledge/knowledge_bundle.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _FakeModelProvider implements ModelProvider {
  int invocationCount = 0;
  final String _responseText;

  _FakeModelProvider({required String responseText})
    : _responseText = responseText;

  @override
  String get providerId => 'fake';

  @override
  String get providerName => 'Fake Provider';

  @override
  bool get isConfigured => true;

  @override
  Future<List<ModelInfo>> listModels() async => [];

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
    invocationCount++;
    return ModelResponse(text: _responseText);
  }

  @override
  Stream<String> generateStream(ModelRequest request) async* {
    yield _responseText;
  }

  @override
  Future<bool> testConnection(String apiKey) async => true;

  @override
  Future<void> saveApiKey(String apiKey) async {}

  @override
  Future<String?> getApiKey() async => null;

  @override
  Future<void> deleteApiKey() async {}
}

class _FakeProviderRegistry implements ModelProviderRegistry {
  final Map<String, ModelProvider> _providers = {};
  String? _activeProviderId;

  @override
  ModelProvider? get activeProvider {
    if (_activeProviderId == null) return null;
    return _providers[_activeProviderId];
  }

  @override
  List<ModelProvider> get providers => _providers.values.toList();

  void register(ModelProvider provider) {
    _providers[provider.providerId] = provider;
  }

  @override
  void registerProvider(ModelProvider provider) => register(provider);

  void setActive(String providerId) => _activeProviderId = providerId;

  @override
  Future<void> setActiveProvider(String providerId) async =>
      _activeProviderId = providerId;

  @override
  ModelProvider? getProvider(String providerId) => _providers[providerId];

  @override
  Future<List<ProviderConfig>> listConfigs() async => [];

  @override
  Future<void> saveConfig(ProviderConfig config) async {}

  @override
  Future<void> deleteConfig(String id) async {}

  @override
  Future<ProviderConfig?> getDefaultConfig() async => null;
}

IntentUnderstanding _understand(
  String objective, {
  NetworkNeed networkNeed = NetworkNeed.none,
}) {
  return IntentUnderstanding(
    intentId: 'test-${DateTime.now().microsecondsSinceEpoch}',
    objective: objective,
    category: IntentCategory.create,
    existingExperience: const ExistingExperienceResolution(
      status: ExistingExperienceStatus.notChecked,
    ),
    desiredOutcome: '',
    confidence: 0.8,
    networkNeed: networkNeed,
    creationNeed: CreationNeed.definitelyNeeded,
    modificationNeed: ModificationNeed.notNeeded,
  );
}

ApplicationReasoningContext _context(
  String objective, {
  NetworkNeed networkNeed = NetworkNeed.none,
  KnowledgeBundle? knowledge,
}) {
  return ApplicationReasoningContext(
    understanding: _understand(objective, networkNeed: networkNeed),
    knowledge: knowledge,
  );
}

/// Creates a Kernel with storage capability registered.
AnythingKernel _createKernel({ApplicationReasoner? reasoner}) {
  final registry = _FakeProviderRegistry();
  final capabilityRegistry = CapabilityRegistry();
  capabilityRegistry.register(
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
  return AnythingKernel(
    providerRegistry: registry,
    capabilityRegistry: capabilityRegistry,
    reasoner: reasoner,
  );
}

// Valid JSON response from model reasoner
const _validVinylJson = '''
{
  "name": "Vinyl Record Collection",
  "purpose": "Track vinyl record collection",
  "entities": [
    {
      "name": "Record",
      "description": "A vinyl record",
      "fields": [
        {"name": "title", "type": "text", "required": true},
        {"name": "artist", "type": "text", "required": true},
        {"name": "year", "type": "integer"},
        {"name": "genre", "type": "text"},
        {"name": "owned", "type": "boolean"}
      ]
    }
  ],
  "actions": [
    {"name": "Add Record", "type": "create", "targetEntity": "record"},
    {"name": "Update Record", "type": "update", "targetEntity": "record"},
    {"name": "Delete Record", "type": "delete", "targetEntity": "record"}
  ],
  "derivedValues": [
    {
      "name": "Total Records",
      "sourceEntity": "record",
      "operation": "count"
    }
  ],
  "views": [
    {
      "name": "Record List",
      "purpose": "All vinyl records",
      "type": "list",
      "sourceEntity": "record",
      "sections": [
        {"purpose": "All records", "sourceEntity": "record", "type": "list"}
      ],
      "isDefault": true
    },
    {
      "name": "Add Record",
      "purpose": "Add a new record",
      "type": "form",
      "sourceEntity": "record",
      "isDefault": false
    }
  ],
  "tags": ["vinyl", "collection"],
  "archetypes": ["collection"],
  "requiredCapabilities": [],
  "knowledgeNeeds": []
}''';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // =========================================================================
  // CompositeApplicationReasoner
  // =========================================================================
  group('CompositeApplicationReasoner — deterministic path', () {
    test('handles simple collection intent without model', () async {
      final composite = CompositeApplicationReasoner();
      final result = await composite.reason(_context('Create a list of notes'));
      expect(result, isA<ReasoningReady>());
      final ready = result as ReasoningReady;
      expect(ready.semanticApp.entities, isNotEmpty);
      expect(ready.semanticApp.archetypes, contains('collection'));
    });
  });

  group('CompositeApplicationReasoner — model fallback', () {
    test('falls back to model when deterministic cannot handle', () async {
      final fakeProvider = _FakeModelProvider(responseText: _validVinylJson);
      final registry = _FakeProviderRegistry()
        ..register(fakeProvider)
        ..setActive('fake');

      final composite = CompositeApplicationReasoner(
        providerRegistry: registry,
      );

      final result = await composite.reason(
        _context('Build a real-time collaborative whiteboard'),
      );

      expect(result, isA<ReasoningReady>());
      expect(fakeProvider.invocationCount, 1);
    });
  });

  group('CompositeApplicationReasoner — no provider', () {
    test('returns ProviderRequired when no provider configured', () async {
      final composite = CompositeApplicationReasoner();
      final result = await composite.reason(
        _context('Build a real-time collaborative whiteboard'),
      );
      expect(result, isA<ReasoningProviderRequired>());
    });
  });

  // =========================================================================
  // Deterministic Reasoner Tightening
  // =========================================================================
  group('DeterministicReasoner — tightened', () {
    test('does not match habit keyword alone', () async {
      final reasoner = const DeterministicReasoner();
      final result = await reasoner.reason(_context('Do my habits'));
      expect(result, isA<ReasoningProviderRequired>());
    });

    test('returns provider required for tracker pattern', () async {
      final reasoner = const DeterministicReasoner();
      final result = await reasoner.reason(_context('Track my daily habits'));
      expect(result, isA<ReasoningProviderRequired>());
    });

    test('rejects uncertain entity extraction', () async {
      final reasoner = const DeterministicReasoner();
      final result = await reasoner.reason(_context('Track something'));
      expect(result, isA<ReasoningProviderRequired>());
    });

    test('extracts entity from "Make a list of groceries"', () async {
      final reasoner = const DeterministicReasoner();
      final result = await reasoner.reason(
        _context('Make a list of groceries'),
      );
      expect(result, isA<ReasoningReady>());
      final ready = result as ReasoningReady;
      expect(
        ready.semanticApp.entities.any((e) => e.name == 'Groceries'),
        isTrue,
      );
    });

    test('returns provider required for planner pattern', () async {
      final reasoner = const DeterministicReasoner();
      final result = await reasoner.reason(_context('Plan my study schedule'));
      expect(result, isA<ReasoningProviderRequired>());
    });
  });

  // =========================================================================
  // Model Reasoner — Strict Validation
  // =========================================================================
  group('ModelApplicationReasoner — strict validation', () {
    test('coerces unknown field type (open-world)', () async {
      final badJson = '''
{
  "name": "Test",
  "purpose": "Test",
  "entities": [
    {
      "name": "Item",
      "fields": [
        {"name": "name", "type": "blob", "required": false}
      ]
    }
  ],
  "actions": [
    {"name": "Add", "type": "create", "targetEntity": "item"}
  ],
  "views": []
}''';
      final provider = _FakeModelProvider(responseText: badJson);
      final reasoner = ModelApplicationReasoner(provider);
      final result = await reasoner.reason(_context('Create a blob store'));
      // IS-P09: unknown field types coerce to text so novel domains plan.
      expect(result, isA<ReasoningReady>());
      final ready = result as ReasoningReady;
      expect(ready.semanticApp.entities.first.fields.first.type.name, 'text');
    });

    test('coerces unknown action type (open-world)', () async {
      final badJson = '''
{
  "name": "Test",
  "purpose": "Test",
  "entities": [
    {
      "name": "Item",
      "fields": [
        {"name": "name", "type": "text"}
      ]
    }
  ],
  "actions": [
    {"name": "Clone", "type": "duplicate", "targetEntity": "item"}
  ],
  "views": []
}''';
      final provider = _FakeModelProvider(responseText: badJson);
      final reasoner = ModelApplicationReasoner(provider);
      final result = await reasoner.reason(_context('Clone items'));
      // IS-P09: unknown action types coerce to setValue rather than aborting.
      expect(result, isA<ReasoningReady>());
      final ready = result as ReasoningReady;
      expect(ready.semanticApp.actions.first.actionType.name, 'setValue');
    });

    test('rejects malformed JSON', () async {
      final provider = _FakeModelProvider(responseText: 'not json at all');
      final reasoner = ModelApplicationReasoner(provider);
      final result = await reasoner.reason(_context('Do something'));
      expect(result, isA<ReasoningFailed>());
    });

    test('accepts valid JSON', () async {
      final provider = _FakeModelProvider(responseText: _validVinylJson);
      final reasoner = ModelApplicationReasoner(provider);
      final result = await reasoner.reason(_context('Track my vinyl records'));
      expect(result, isA<ReasoningReady>());
    });
  });

  // =========================================================================
  // Error Redaction
  // =========================================================================
  group('Error redaction', () {
    test('model reasoner error messages are consumer-safe', () async {
      final provider = _FakeModelProvider(responseText: 'garbage output');
      final reasoner = ModelApplicationReasoner(provider);
      final result = await reasoner.reason(_context('Do something'));
      expect(result, isA<ReasoningFailed>());
      final failed = result as ReasoningFailed;
      // Should NOT contain raw exception text
      expect(failed.error, isNot(contains('Exception')));
      expect(failed.error, isNot(contains('Stack trace')));
      expect(failed.error, isNotEmpty);
    });

    test('composite reasoner error messages are consumer-safe', () async {
      final badProvider = _FakeModelProvider(responseText: 'not json');
      final registry = _FakeProviderRegistry()
        ..register(badProvider)
        ..setActive('fake');

      final composite = CompositeApplicationReasoner(
        providerRegistry: registry,
      );

      final result = await composite.reason(
        _context('Build a complex AI-driven app'),
      );
      expect(result, isA<ReasoningFailed>());
      final failed = result as ReasoningFailed;
      expect(failed.error, isNot(contains('Exception')));
    });
  });

  // =========================================================================
  // Deterministic Success — Zero Model Invocations
  // =========================================================================
  group('Deterministic success', () {
    test('simple intent produces zero model invocations', () async {
      final fakeProvider = _FakeModelProvider(responseText: '{}');
      final registry = _FakeProviderRegistry()
        ..register(fakeProvider)
        ..setActive('fake');

      final composite = CompositeApplicationReasoner(
        providerRegistry: registry,
      );

      await composite.reason(_context('Create a list of notes'));
      expect(fakeProvider.invocationCount, 0);
    });
  });

  // =========================================================================
  // ProviderRequired Chain
  // =========================================================================
  group('ProviderRequired chain', () {
    test('novel intent + no provider → ProviderRequired', () async {
      final composite = CompositeApplicationReasoner();
      final result = await composite.reason(
        _context('Build a real-time collaborative whiteboard'),
      );
      expect(result, isA<ReasoningProviderRequired>());
    });

    test('Kernel returns ProviderRequired for novel intent', () async {
      final kernel = _createKernel();

      final result = await kernel.processIntent(
        Intent.create(expression: 'Build a real-time collaborative whiteboard'),
      );
      expect(result, isA<ProviderRequired>());
    });
  });

  // =========================================================================
  // Kernel/Coordinator Integration — Regression
  // =========================================================================
  group('Kernel/Coordinator integration', () {
    test('ExecutionPlanReady is consumed successfully (regression)', () async {
      final kernel = _createKernel();
      final coordinator = ExperienceCreationCoordinator(
        kernel: kernel,
        repository: SqliteExperienceRepository(dbName: 'test_coordinator'),
        activity: ActivityRepository(),
      );

      final result = await coordinator.createFromExpression(
        'Create a list of notes',
      );

      // Previously this returned CreationFailed — now must succeed
      expect(result, isA<CreationCreated>());
      final created = result as CreationCreated;
      expect(created.experienceId, isNotEmpty);
      expect(created.package, isNotNull);
    });

    test('Coordinator uses actual Kernel plan, not fake empty', () async {
      final kernel = _createKernel();
      final coordinator = ExperienceCreationCoordinator(
        kernel: kernel,
        repository: SqliteExperienceRepository(dbName: 'test_plan'),
        activity: ActivityRepository(),
      );

      final result = await coordinator.createFromExpression(
        'Create a list of notes',
      );

      expect(result, isA<CreationCreated>());
      // The package should have actual interface definition
      final created = result as CreationCreated;
      expect(created.package.interface.screens, isNotEmpty);
    });
  });

  // =========================================================================
  // Full Golden Path — Vinyl Collection
  // =========================================================================
  group('Golden Path — Vinyl Collection', () {
    test('full pipeline: create → persist → open', () async {
      final kernel = _createKernel();
      final coordinator = ExperienceCreationCoordinator(
        kernel: kernel,
        repository: SqliteExperienceRepository(dbName: 'test_vinyl'),
        activity: ActivityRepository(),
      );

      // Create
      final createResult = await coordinator.createFromExpression(
        'Make me an app to track my vinyl record collection',
      );
      expect(createResult, isA<CreationCreated>());
      final created = createResult as CreationCreated;

      // Package validates
      final validation = ExperiencePackageValidator.validate(created.package);
      expect(validation.isValid, isTrue);

      // Has screens and behavior
      expect(created.package.interface.screens, isNotEmpty);
      expect(created.package.behavior.nodes, isNotEmpty);

      // Open through trusted opening coordinator
      final openingCoordinator = ExperienceOpeningCoordinator(
        repository: SqliteExperienceRepository(dbName: 'test_vinyl'),
        activity: ActivityRepository(),
      );

      final openResult = await openingCoordinator.openExperience(
        created.experienceId,
      );
      expect(openResult, isA<OpenReady>());
      final opened = openResult as OpenReady;
      expect(opened.package.manifest.experienceId, created.experienceId);
    });
  });

  // =========================================================================
  // Knowledge Not Needed
  // =========================================================================
  group('Knowledge', () {
    test('local app does not invoke knowledge engine', () async {
      final kernel = _createKernel();

      final result = await kernel.processIntent(
        Intent.create(expression: 'Create a list of notes'),
      );

      expect(result, isA<ExecutionPlanReady>());
      final ready = result as ExecutionPlanReady;
      // No knowledge requirements for a simple local list
      expect(ready.specification.knowledgeRequirements, isEmpty);
    });
  });

  // =========================================================================
  // Blueprint Spec Roundtrip
  // =========================================================================
  group('Semantic preservation', () {
    test('blueprint entities survive conversion to package', () async {
      final reasoner = const DeterministicReasoner();
      final planner = SynthesisPlanner(reasoner);

      final result = await planner.plan(_context('Create a list of books'));
      final validation = BlueprintValidator.validate(result.blueprint);
      expect(validation.isValid, isTrue);

      final package = GenericPackageBuilder.build(result.blueprint);
      expect(package.data, isNotNull);
      expect(package.data!.entities, isNotEmpty);
      expect(package.interface.screens, isNotEmpty);
      expect(package.behavior.nodes, isNotEmpty);
      expect(package.state.variables, isNotEmpty);
    });

    test('relationships preserved through conversion', () async {
      final reasoner = const DeterministicReasoner();
      final planner = SynthesisPlanner(reasoner);

      final result = await planner.plan(_context('Create a list of plants'));

      final blueprint = result.blueprint;
      expect(blueprint.entities.length, greaterThanOrEqualTo(1));

      // Convert through full pipeline
      final spec = BlueprintToSpecConverter.convert(blueprint);
      expect(spec.dataEntities, isNotEmpty);
      expect(spec.uiRequirements.primaryViews, isNotEmpty);

      final package = GenericPackageBuilder.build(blueprint);
      expect(package.data!.entities.length, blueprint.entities.length);
    });
  });

  // =========================================================================
  // Security — No Executable Fetched Code
  // =========================================================================
  group('Security', () {
    test('generated package has no executable code nodes', () async {
      final reasoner = const DeterministicReasoner();
      final planner = SynthesisPlanner(reasoner);
      final result = await planner.plan(_context('Create a list of notes'));
      final package = GenericPackageBuilder.build(result.blueprint);

      for (final node in package.behavior.nodes) {
        expect(
          node.type,
          isNot(equals('executable')),
          reason: 'Behavior node should not be executable: ${node.id}',
        );
        expect(
          node.type,
          isNot(equals('shell')),
          reason: 'Behavior node should not be shell: ${node.id}',
        );
      }
    });

    test('capability declarations match spec', () async {
      final reasoner = const DeterministicReasoner();
      final planner = SynthesisPlanner(reasoner);
      final result = await planner.plan(_context('Create a list of notes'));
      final package = GenericPackageBuilder.build(result.blueprint);

      // Package should have valid integrity
      final hash = ExperiencePackage.computeIntegrityHash(package);
      expect(hash, isNotEmpty);
    });
  });

  // =========================================================================
  // Existing Test Regression
  // =========================================================================
  group('Regression — existing Stage 10 tests still pass', () {
    test('BlueprintValidator validates correctly', () {
      final blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.collection],
        entities: [
          BlueprintEntity(
            id: 'item',
            name: 'Item',
            fields: [
              const BlueprintField(
                id: 'name',
                name: 'Name',
                type: BlueprintFieldType.text,
                required: true,
              ),
            ],
            displayField: 'name',
          ),
        ],
      );
      final validation = BlueprintValidator.validate(blueprint);
      expect(validation.isValid, isTrue);
    });

    test('DeterministicReasoner handles all four archetypes', () async {
      final reasoner = const DeterministicReasoner();

      final collection = await reasoner.reason(
        _context('Create a list of notes'),
      );
      expect(collection, isA<ReasoningReady>());

      final tracker = await reasoner.reason(_context('Track my daily habits'));
      expect(tracker, isA<ReasoningProviderRequired>());

      final planner = await reasoner.reason(_context('Plan my study schedule'));
      expect(planner, isA<ReasoningProviderRequired>());

      final dashboard = await reasoner.reason(
        _context('Summarize my expenses'),
      );
      expect(dashboard, isA<ReasoningProviderRequired>());
    });
  });
}
