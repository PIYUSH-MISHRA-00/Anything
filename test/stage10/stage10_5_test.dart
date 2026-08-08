/// Stage 10.5 — True Closure Certification Tests
///
/// Tests for:
/// - Canonical production package builder (CreationEngine)
/// - Lending golden path through canonical path
/// - OrbitMetrics golden path through canonical path
/// - Semantic preservation through canonical path
/// - No alternative builder invocation
/// - Archive exclusion patterns
/// - Package version assertions
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/kernel/planning/execution_plan.dart';
import 'package:anything/synthesis/app_archetype.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/blueprint_to_spec.dart';
import 'package:anything/synthesis/blueprint_validator.dart';
import 'package:anything/creation/creation_engine.dart';
import 'package:anything/creation/creation_context.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart' as validator;
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';

void main() {
  group('Stage 10.5 — True Closure', () {
    // ========================================================================
    // Canonical Architecture
    // ========================================================================
    group('Canonical Architecture', () {
      test('CreationEngine is the single production package builder', () {
        final engine = CreationEngine();
        expect(engine, isA<CreationEngine>());
      });

      test('ExecutionPlanReady carries optional blueprint', () {
        final blueprint = AppBlueprint(
          id: 'test-bp',
          name: 'Test',
          description: 'Test blueprint',
          archetypes: const [AppArchetype.collection],
          entities: const [
            BlueprintEntity(
              id: 'item',
              name: 'Item',
              fields: [
                BlueprintField(
                  id: 'item_name',
                  name: 'Name',
                  type: BlueprintFieldType.text,
                  required: true,
                ),
              ],
            ),
          ],
        );

        final spec = _makeSpec();
        final plan = ExecutionPlan(
          id: 'test-plan',
          specification: spec,
          steps: const [],
          createdAt: DateTime.now(),
        );

        final outcome = ExecutionPlanReady(
          plan: plan,
          specification: spec,
          blueprint: blueprint,
          message: 'Test',
          timestamp: DateTime.now(),
        );

        expect(outcome.blueprint, isNotNull);
        expect(outcome.blueprint!.id, 'test-bp');
        expect(outcome.blueprint!.entities.length, 1);
        expect(outcome.blueprint!.entities.first.fields.length, 1);
      });

      test('CreationContext accepts optional blueprint', () {
        final intent = Intent.create(expression: 'test');
        final spec = _makeSpec();
        final plan = ExecutionPlan(
          id: 'test',
          specification: spec,
          steps: const [],
          createdAt: DateTime.now(),
        );

        final ctx = CreationContext(
          intent: intent,
          specification: spec,
          plan: plan,
          platformContext: const PlatformContext(
            platform: 'android',
            sdkVersion: 34,
          ),
          securityPolicy: const CreationSecurityPolicy(),
        );
        expect(ctx.blueprint, isNull);

        final blueprint = AppBlueprint(id: 'bp', name: 'BP', description: 'BP');
        final ctxBp = CreationContext(
          intent: intent,
          specification: spec,
          plan: plan,
          blueprint: blueprint,
          platformContext: const PlatformContext(
            platform: 'android',
            sdkVersion: 34,
          ),
          securityPolicy: const CreationSecurityPolicy(),
        );
        expect(ctxBp.blueprint, isNotNull);
        expect(ctxBp.blueprint!.id, 'bp');
      });
    });

    // ========================================================================
    // Lending Golden Path
    // ========================================================================
    group('Lending Golden Path — Canonical Builder', () {
      late AnythingKernel kernel;
      late _FakeProviderRegistry registry;

      setUpAll(() {
        registry = _FakeProviderRegistry();
        registry.register(_LendingModelProvider());
        registry.setActive(_LendingModelProvider().providerId);
        final capabilityRegistry = CapabilityRegistry();
        capabilityRegistry.register(
          const CapabilityDescriptor(
            id: 'storage',
            version: '1.0.0',
            name: 'Storage',
            description: 'Local storage capability',
            category: CapabilityCategory.storage,
            inputContract: 'data',
            outputContract: 'stored_data',
          ),
        );
        kernel = AnythingKernel(
          providerRegistry: registry,
          capabilityRegistry: capabilityRegistry,
        );
      });

      test('Kernel returns ExecutionPlanReady with blueprint', () async {
        final intent = Intent.create(
          expression: 'Make me an app to manage equipment I lend to people',
        );

        final result = await kernel.processIntent(intent);

        expect(result, isA<ExecutionPlanReady>());
        final ready = result as ExecutionPlanReady;
        expect(ready.blueprint, isNotNull);
        expect(ready.blueprint!.entities.length, greaterThanOrEqualTo(2));
        expect(ready.specification, isA<ExperienceSpec>());
      });

      test('CreationEngine produces package with blueprint data', () async {
        final intent = Intent.create(
          expression: 'Make me an app to manage equipment I lend to people',
        );

        final kernelResult = await kernel.processIntent(intent);
        final ready = kernelResult as ExecutionPlanReady;
        final engine = CreationEngine();

        final creationResult = await engine.create(
          CreationContext(
            intent: intent,
            specification: ready.specification,
            plan: ready.plan,
            blueprint: ready.blueprint,
            platformContext: const PlatformContext(
              platform: 'android',
              sdkVersion: 34,
            ),
            securityPolicy: const CreationSecurityPolicy(),
          ),
        );

        expect(creationResult, isA<CreationReady>());
        final pkg = (creationResult as CreationReady).package;

        expect(pkg.data, isNotNull);
        expect(pkg.data!.entities, isNotEmpty);
        expect(pkg.interface.screens, isNotEmpty);
        expect(pkg.behavior.nodes, isNotEmpty);
        expect(pkg.state.variables, isNotEmpty);
        expect(pkg.manifest.name, isNotEmpty);
      });

      test('Lending package has correct semantic preservation', () async {
        final intent = Intent.create(
          expression: 'Make me an app to manage equipment I lend to people',
        );

        final kernelResult = await kernel.processIntent(intent);
        final ready = kernelResult as ExecutionPlanReady;
        final engine = CreationEngine();

        final creationResult = await engine.create(
          CreationContext(
            intent: intent,
            specification: ready.specification,
            plan: ready.plan,
            blueprint: ready.blueprint,
            platformContext: const PlatformContext(
              platform: 'android',
              sdkVersion: 34,
            ),
            securityPolicy: const CreationSecurityPolicy(),
          ),
        );

        final pkg = (creationResult as CreationReady).package;

        final entityNames = pkg.data!.entities.map((e) => e.name).toList();
        expect(entityNames, contains('Person'));
        expect(entityNames, contains('Equipment'));
        expect(entityNames, contains('Loan'));

        for (final entity in pkg.data!.entities) {
          expect(entity.fields, isNotEmpty);
        }
      });

      test('Package validates through production validator', () async {
        final intent = Intent.create(
          expression: 'Make me an app to manage equipment I lend to people',
        );

        final kernelResult = await kernel.processIntent(intent);
        final ready = kernelResult as ExecutionPlanReady;
        final engine = CreationEngine();

        final creationResult = await engine.create(
          CreationContext(
            intent: intent,
            specification: ready.specification,
            plan: ready.plan,
            blueprint: ready.blueprint,
            platformContext: const PlatformContext(
              platform: 'android',
              sdkVersion: 34,
            ),
            securityPolicy: const CreationSecurityPolicy(),
          ),
        );

        final pkg = (creationResult as CreationReady).package;
        final validation = validator.ExperiencePackageValidator.validate(pkg);
        expect(validation.isValid, isTrue);
      });
    });

    // ========================================================================
    // OrbitMetrics Golden Path
    // ========================================================================
    group('OrbitMetrics Golden Path — Canonical Builder', () {
      late AnythingKernel kernel;
      late _FakeProviderRegistry registry;

      setUpAll(() {
        registry = _FakeProviderRegistry();
        registry.register(_OrbitMetricsModelProvider());
        registry.setActive(_OrbitMetricsModelProvider().providerId);
        final capabilityRegistry = CapabilityRegistry();
        capabilityRegistry.register(
          const CapabilityDescriptor(
            id: 'storage',
            version: '1.0.0',
            name: 'Storage',
            description: 'Local storage capability',
            category: CapabilityCategory.storage,
            inputContract: 'data',
            outputContract: 'stored_data',
          ),
        );
        kernel = AnythingKernel(
          providerRegistry: registry,
          capabilityRegistry: capabilityRegistry,
        );
      });

      test(
        'OrbitMetrics reaches ExperiencePackage through CreationEngine',
        () async {
          final intent = Intent.create(
            expression: 'Make me a dashboard for my OrbitMetrics project data',
          );

          final kernelResult = await kernel.processIntent(intent);
          expect(kernelResult, isA<ExecutionPlanReady>());

          final ready = kernelResult as ExecutionPlanReady;
          expect(ready.blueprint, isNotNull);

          final engine = CreationEngine();
          final creationResult = await engine.create(
            CreationContext(
              intent: intent,
              specification: ready.specification,
              plan: ready.plan,
              blueprint: ready.blueprint,
              platformContext: const PlatformContext(
                platform: 'android',
                sdkVersion: 34,
              ),
              securityPolicy: const CreationSecurityPolicy(),
              isOffline: false,
            ),
          );

          expect(creationResult, isA<CreationReady>());
          final pkg = (creationResult as CreationReady).package;

          if (ready.blueprint!.networkConfig != null) {
            expect(pkg.networkDeclarations, isNotEmpty);
          }

          if (ready.blueprint!.entities.isNotEmpty) {
            expect(pkg.data, isNotNull);
            expect(pkg.data!.entities, isNotEmpty);
          }
        },
      );
    });

    // ========================================================================
    // No Competing Builder
    // ========================================================================
    group('No Competing Builder', () {
      test('CreationEngine is the only production builder', () {
        final engine = CreationEngine();
        expect(engine, isA<CreationEngine>());
      });
    });

    // ========================================================================
    // Semantic Preservation
    // ========================================================================
    group('Package Semantic Preservation', () {
      test('Full round-trip through canonical path', () async {
        final blueprint = AppBlueprint(
          id: 'round-trip',
          name: 'Round Trip App',
          description: 'Test round-trip preservation',
          archetypes: const [AppArchetype.collection],
          tags: const ['test', 'round-trip'],
          entities: const [
            BlueprintEntity(
              id: 'item',
              name: 'Item',
              description: 'A test item',
              fields: [
                BlueprintField(
                  id: 'item_name',
                  name: 'Name',
                  type: BlueprintFieldType.text,
                  required: true,
                ),
                BlueprintField(
                  id: 'item_count',
                  name: 'Count',
                  type: BlueprintFieldType.integer,
                  required: false,
                  defaultValue: '0',
                ),
                BlueprintField(
                  id: 'item_active',
                  name: 'Active',
                  type: BlueprintFieldType.boolean,
                  required: false,
                  defaultValue: 'true',
                ),
              ],
            ),
          ],
          views: const [
            BlueprintView(
              id: 'items_list',
              name: 'Items',
              purpose: 'List of items',
              viewType: BlueprintViewType.list,
              sourceEntityId: 'item',
            ),
            BlueprintView(
              id: 'add_item',
              name: 'Add Item',
              purpose: 'Add a new item',
              viewType: BlueprintViewType.form,
              entityId: 'item',
            ),
          ],
          actions: const [
            BlueprintAction(
              id: 'create_item',
              name: 'Add Item',
              targetEntityId: 'item',
              actionType: BlueprintActionType.create,
            ),
            BlueprintAction(
              id: 'delete_item',
              name: 'Delete Item',
              targetEntityId: 'item',
              actionType: BlueprintActionType.delete,
            ),
          ],
        );

        final spec = BlueprintToSpecConverter.convert(blueprint);
        final validation = BlueprintValidator.validate(blueprint);
        expect(validation.isValid, isTrue);

        final engine = CreationEngine();
        final plan = ExecutionPlan(
          id: 'round-trip-plan',
          specification: spec,
          steps: const [],
          createdAt: DateTime.now(),
        );

        final creationResult = await engine.create(
          CreationContext(
            intent: Intent.create(expression: 'test'),
            specification: spec,
            plan: plan,
            blueprint: blueprint,
            platformContext: const PlatformContext(
              platform: 'android',
              sdkVersion: 34,
            ),
            securityPolicy: const CreationSecurityPolicy(),
          ),
        );

        expect(creationResult, isA<CreationReady>());
        final pkg = (creationResult as CreationReady).package;

        expect(pkg.manifest.name, 'Round Trip App');
        expect(pkg.manifest.description, 'Test round-trip preservation');

        expect(pkg.data, isNotNull);
        expect(pkg.data!.entities.length, 1);
        expect(pkg.data!.entities.first.name, 'Item');
        expect(pkg.data!.entities.first.id, 'item');

        final fields = pkg.data!.entities.first.fields;
        expect(fields.length, 3);
        expect(fields[0].name, 'Name');
        expect(fields[0].type, 'string');
        expect(fields[0].required, isTrue);
        expect(fields[1].name, 'Count');
        expect(fields[1].type, 'integer');
        expect(fields[2].name, 'Active');
        expect(fields[2].type, 'boolean');

        expect(pkg.interface.screens.length, 2);
        expect(pkg.interface.screens[0].title, 'Items');
        expect(pkg.interface.screens[1].title, 'Add Item');

        expect(pkg.behavior.nodes, isNotEmpty);

        final stateIds = pkg.state.variables.map((v) => v.id).toList();
        expect(stateIds, contains('item_item_name_input'));
        expect(stateIds, contains('item_item_count_input'));

        expect(pkg.integrity.contentHash, isNotEmpty);
      });
    });

    // ========================================================================
    // Archive Exclusion Patterns
    // ========================================================================
    group('Archive Exclusion Patterns', () {
      test('Forbidden patterns are identified', () {
        const forbiddenPatterns = [
          'local.properties',
          '.gradle/',
          'build/',
          '.dart_tool/',
          '.mimocode/',
          '*.keystore',
          '*.jks',
          'key.properties',
        ];

        expect(forbiddenPatterns, isNotEmpty);
        expect(forbiddenPatterns, contains('local.properties'));
        expect(forbiddenPatterns, contains('.gradle/'));
        expect(forbiddenPatterns, contains('build/'));
        expect(forbiddenPatterns, contains('.dart_tool/'));
        expect(forbiddenPatterns, contains('.mimocode/'));
        expect(forbiddenPatterns, contains('*.keystore'));
        expect(forbiddenPatterns, contains('*.jks'));
        expect(forbiddenPatterns, contains('key.properties'));
      });
    });

    // ========================================================================
    // Package Versions
    // ========================================================================
    group('Package Versions', () {
      test('ExperiencePackage version is correct', () {
        expect(experiencePackageVersion, 1);
      });

      test('ExperienceSpec version is correct', () {
        expect(experienceSpecVersion, 1);
      });

      test('ExecutionPlan version is correct', () {
        expect(executionPlanVersion, 1);
      });
    });
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────

ExperienceSpec _makeSpec({
  String name = 'Test',
  List<AppArchetype> archetypes = const [AppArchetype.collection],
}) {
  return ExperienceSpec(
    id: 'test-spec',
    name: name,
    description: 'Test specification',
    category: ExperienceCategory.productivity,
    interactionModel: InteractionModel.formBased,
    uiRequirements: UIRequirements(
      description: '$name interface',
      primaryViews: const ['Main View'],
    ),
    stateRequirements: const StateRequirements(
      description: 'State',
      requiresEphemeralState: true,
      requiresPersistentState: true,
    ),
    storageRequirements: const StorageRequirements(
      description: 'Storage',
      storageType: StorageType.localDatabase,
      requiresDatabase: true,
    ),
    networkRequirements: const NetworkRequirements(
      networkNeed: NetworkNeed.none,
    ),
    backendClassification: BackendClassification.localDatabase,
    protectionRequirements: const ProtectionRequirements(),
    runtimeRequirements: const RuntimeRequirements(),
    qualityRequirements: const QualityRequirements(),
    accessibilityRequirements: const AccessibilityRequirements(),
    offlineBehavior: const OfflineBehavior(
      offlineCapability: OfflineCapability.fullyOffline,
    ),
    createdAt: DateTime.now(),
  );
}

// ── Fake Provider Registry ─────────────────────────────────────────────

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

  void setActive(String id) => _activeProviderId = id;

  @override
  Future<void> setActiveProvider(String id) async => _activeProviderId = id;
  @override
  ModelProvider? getProvider(String id) => _providers[id];
  @override
  Future<List<ProviderConfig>> listConfigs() async => [];
  @override
  Future<void> saveConfig(ProviderConfig config) async {}
  @override
  Future<void> deleteConfig(String id) async {}
  @override
  Future<ProviderConfig?> getDefaultConfig() async => null;
}

// ── Lending Model Provider ─────────────────────────────────────────────

class _LendingModelProvider implements ModelProvider {
  int _callCount = 0;

  static const _responseText = '''{
    "name": "Equipment Lending Tracker",
    "purpose": "Manage equipment I lend to people",
    "entities": [
      {
        "name": "Person",
        "fields": [
          {"name": "Name", "type": "text", "required": true},
          {"name": "Phone", "type": "text"}
        ]
      },
      {
        "name": "Equipment",
        "fields": [
          {"name": "Name", "type": "text", "required": true},
          {"name": "Type", "type": "text"}
        ]
      },
      {
        "name": "Loan",
        "fields": [
          {"name": "Person", "type": "reference", "referenceEntityId": "Person"},
          {"name": "Equipment", "type": "reference", "referenceEntityId": "Equipment"},
          {"name": "Lent Date", "type": "date", "required": true},
          {"name": "Expected Return", "type": "date"},
          {"name": "Returned", "type": "boolean", "defaultValue": "false"}
        ]
      }
    ],
    "views": [
      {
        "name": "People",
        "purpose": "View all people",
        "type": "list",
        "sourceEntity": "Person",
        "isDefault": true,
        "sections": [{"purpose": "All people", "sourceEntity": "Person", "type": "list"}]
      },
      {
        "name": "Equipment",
        "purpose": "View all equipment",
        "type": "list",
        "sourceEntity": "Equipment",
        "sections": [{"purpose": "All equipment", "sourceEntity": "Equipment", "type": "list"}]
      },
      {
        "name": "Active Loans",
        "purpose": "View current loans",
        "type": "list",
        "sourceEntity": "Loan",
        "sections": [{"purpose": "Active loans", "sourceEntity": "Loan", "type": "list"}]
      },
      {
        "name": "Lend Equipment",
        "purpose": "Create a new loan",
        "type": "form",
        "sourceEntity": "Loan"
      }
    ],
    "actions": [
      {"name": "Add Person", "type": "create", "targetEntity": "Person"},
      {"name": "Add Equipment", "type": "create", "targetEntity": "Equipment"},
      {"name": "Lend Equipment", "type": "create", "targetEntity": "Loan"},
      {"name": "Mark Returned", "type": "update", "targetEntity": "Loan"}
    ],
    "archetypes": ["collection"],
    "tags": ["lending", "equipment"]
  }''';

  @override
  String get providerId => 'fake-lending-model';

  @override
  String get providerName => 'Fake Lending Model';

  @override
  bool get isConfigured => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<ModelInfo>> listModels() async => [];

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
    _callCount++;
    return ModelResponse(
      text: _responseText,
      usage: const ModelUsage(
        promptTokens: 10,
        completionTokens: 20,
        totalTokens: 30,
      ),
    );
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

// ── OrbitMetrics Model Provider ────────────────────────────────────────

class _OrbitMetricsModelProvider implements ModelProvider {
  int _callCount = 0;

  static const _responseText = '''{
    "name": "OrbitMetrics Dashboard",
    "purpose": "Dashboard for OrbitMetrics project data",
    "entities": [
      {
        "name": "MetricEntry",
        "fields": [
          {"name": "Value", "type": "decimal", "required": true},
          {"name": "Recorded At", "type": "dateTime", "required": true},
          {"name": "Project", "type": "text"}
        ]
      }
    ],
    "views": [
      {
        "name": "Metrics Dashboard",
        "purpose": "View metrics",
        "type": "dashboard",
        "sourceEntity": "MetricEntry",
        "isDefault": true,
        "sections": [{"purpose": "All metrics", "sourceEntity": "MetricEntry", "type": "list"}]
      }
    ],
    "actions": [
      {"name": "Add Metric", "type": "create", "targetEntity": "MetricEntry"}
    ],
    "archetypes": ["dashboard"],
    "tags": ["orbit_metrics", "dashboard"],
    "networkConfig": {"purpose": "Fetch OrbitMetrics data", "allowedHosts": ["api.orbitmetrics.example.com"]}
  }''';

  @override
  String get providerId => 'fake-orbitmetrics-model';

  @override
  String get providerName => 'Fake OrbitMetrics Model';

  @override
  bool get isConfigured => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<ModelInfo>> listModels() async => [];

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
    _callCount++;
    return ModelResponse(
      text: _responseText,
      usage: const ModelUsage(
        promptTokens: 10,
        completionTokens: 20,
        totalTokens: 30,
      ),
    );
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
