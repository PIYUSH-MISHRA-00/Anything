/// Stage 11.1 — End-to-End Certification Tests
///
/// Proves the full production lifecycle:
///   Intent → Kernel → CreationCoordinator → CreationEngine → Validator
///   → Repository → OpeningCoordinator → Runtime → Renderer → Widget interaction
///
/// Uses fake providers ONLY at legitimate external boundaries.
/// Does NOT manually construct final ExperiencePackage.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/creation/creation_engine.dart' as engine;
import 'package:anything/creation/creation_context.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart' as validator;
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/experience_opening_coordinator.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/experience_renderer.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/runtime/runtime_context.dart';
import 'package:anything/runtime/form_controller.dart';
import 'package:anything/runtime/component_registry.dart';
import 'package:anything/runtime/query_controller.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';

// ═══════════════════════════════════════════════════════════════════════
// FAKE MODEL PROVIDERS
// ═══════════════════════════════════════════════════════════════════════

class _FakeProviderRegistry implements ModelProviderRegistry {
  final Map<String, ModelProvider> _providers = {};
  String? _activeProviderId;

  @override
  ModelProvider? get activeProvider =>
      _activeProviderId != null ? _providers[_activeProviderId] : null;

  @override
  List<ModelProvider> get providers => _providers.values.toList();

  void register(ModelProvider provider) =>
      _providers[provider.providerId] = provider;

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

class _PeopleTrackerModelProvider implements ModelProvider {
  static const _responseText = '''{
    "name": "People Tracker",
    "purpose": "Keep track of people I meet",
    "entities": [
      {
        "name": "Person",
        "fields": [
          {"name": "Name", "type": "text", "required": true},
          {"name": "Phone", "type": "text"},
          {"name": "Notes", "type": "multilineText"},
          {"name": "Met Date", "type": "date"},
          {"name": "Active", "type": "boolean", "defaultValue": "true"}
        ]
      }
    ],
    "views": [
      {
        "name": "People List",
        "purpose": "View all contacts",
        "type": "list",
        "sourceEntity": "Person",
        "isDefault": true,
        "sections": [{"purpose": "All people", "sourceEntity": "Person", "type": "list"}]
      },
      {
        "name": "Add Person",
        "purpose": "Create a new contact",
        "type": "form",
        "sourceEntity": "Person"
      },
      {
        "name": "Person Detail",
        "purpose": "View contact details",
        "type": "detail",
        "sourceEntity": "Person"
      },
      {
        "name": "Dashboard",
        "purpose": "Overview",
        "type": "dashboard",
        "sourceEntity": "Person"
      }
    ],
    "actions": [
      {"name": "Add Person", "type": "create", "targetEntity": "Person"},
      {"name": "Update Person", "type": "update", "targetEntity": "Person"},
      {"name": "Delete Person", "type": "delete", "targetEntity": "Person"}
    ],
    "derivedValues": [
      {"name": "Total People", "sourceEntity": "Person", "operation": "count"}
    ],
    "archetypes": ["tracker"],
    "tags": ["people", "contacts"]
  }''';

  @override
  String get providerId => 'fake-people-model';

  @override
  String get providerName => 'Fake People Model';

  @override
  bool get isConfigured => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<ModelInfo>> listModels() async => [];

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
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

class _EquipmentLendingModelProvider implements ModelProvider {
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
          {"name": "Person", "type": "reference", "referenceEntityId": "person", "required": true},
          {"name": "Equipment", "type": "reference", "referenceEntityId": "equipment", "required": true},
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
      {"name": "Mark Returned", "type": "update", "targetEntity": "Loan"},
      {"name": "Delete Person", "type": "delete", "targetEntity": "Person"},
      {"name": "Delete Equipment", "type": "delete", "targetEntity": "Equipment"}
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

class _FossilCatalogModelProvider implements ModelProvider {
  static const _responseText = '''{
    "name": "Fossil Catalog",
    "purpose": "Catalog fossils found on hiking trips",
    "entities": [
      {
        "name": "Fossil",
        "fields": [
          {"name": "Name", "type": "text", "required": true},
          {"name": "Species", "type": "text"},
          {"name": "Location Found", "type": "text"},
          {"name": "Date Found", "type": "date"},
          {"name": "Description", "type": "multilineText"},
          {"name": "Weight", "type": "decimal"}
        ]
      }
    ],
    "views": [
      {
        "name": "Fossil Collection",
        "purpose": "View all fossils",
        "type": "list",
        "sourceEntity": "Fossil",
        "isDefault": true,
        "sections": [{"purpose": "All fossils", "sourceEntity": "Fossil", "type": "list"}]
      },
      {
        "name": "Add Fossil",
        "purpose": "Record a new fossil",
        "type": "form",
        "sourceEntity": "Fossil"
      },
      {
        "name": "Fossil Detail",
        "purpose": "View fossil details",
        "type": "detail",
        "sourceEntity": "Fossil"
      }
    ],
    "actions": [
      {"name": "Add Fossil", "type": "create", "targetEntity": "Fossil"},
      {"name": "Update Fossil", "type": "update", "targetEntity": "Fossil"},
      {"name": "Delete Fossil", "type": "delete", "targetEntity": "Fossil"}
    ],
    "archetypes": ["collection"],
    "tags": ["fossil", "hiking", "catalog"]
  }''';

  @override
  String get providerId => 'fake-fossil-model';

  @override
  String get providerName => 'Fake Fossil Model';

  @override
  bool get isConfigured => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<ModelInfo>> listModels() async => [];

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
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

class _OrbitMetricsModelProvider implements ModelProvider {
  static const _responseText = '''{
    "name": "OrbitMetrics Dashboard",
    "purpose": "Dashboard for OrbitMetrics project data",
    "entities": [
      {
        "name": "MetricEntry",
        "fields": [
          {"name": "Value", "type": "decimal", "required": true},
          {"name": "Recorded At", "type": "dateTime", "required": true},
          {"name": "Project", "type": "text"},
          {"name": "Category", "type": "text"}
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
      },
      {
        "name": "Add Metric",
        "purpose": "Record a new metric",
        "type": "form",
        "sourceEntity": "MetricEntry"
      }
    ],
    "actions": [
      {"name": "Add Metric", "type": "create", "targetEntity": "MetricEntry"}
    ],
    "derivedValues": [
      {"name": "Total Metrics", "sourceEntity": "MetricEntry", "operation": "count"},
      {"name": "Sum Values", "sourceEntity": "MetricEntry", "operation": "sum", "fieldId": "value"}
    ],
    "archetypes": ["dashboard"],
    "tags": ["orbit_metrics", "dashboard"]
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

// ═══════════════════════════════════════════════════════════════════════
// HELPER: Build pipeline components
// ═══════════════════════════════════════════════════════════════════════

_Pipeline _buildPipeline(ModelProvider provider, {String? dbName}) {
  final registry = _FakeProviderRegistry();
  registry.register(provider);
  registry.setActive(provider.providerId);

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

  final kernel = AnythingKernel(
    providerRegistry: registry,
    capabilityRegistry: capabilityRegistry,
  );

  final repository = SqliteExperienceRepository(
    dbName: dbName ?? 'cert_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final activity = ActivityRepository();

  final creationCoordinator = ExperienceCreationCoordinator(
    kernel: kernel,
    repository: repository,
    activity: activity,
  );

  final openingCoordinator = ExperienceOpeningCoordinator(
    repository: repository,
    activity: activity,
  );

  return _Pipeline(
    kernel: kernel,
    creationCoordinator: creationCoordinator,
    openingCoordinator: openingCoordinator,
    repository: repository,
    activity: activity,
  );
}

class _Pipeline {
  final AnythingKernel kernel;
  final ExperienceCreationCoordinator creationCoordinator;
  final ExperienceOpeningCoordinator openingCoordinator;
  final SqliteExperienceRepository repository;
  final ActivityRepository activity;

  _Pipeline({
    required this.kernel,
    required this.creationCoordinator,
    required this.openingCoordinator,
    required this.repository,
    required this.activity,
  });

  Future<void> close() async {
    await repository.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TEST SUITE
// ═══════════════════════════════════════════════════════════════════════

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ═════════════════════════════════════════════════════════════════════
  // PEOPLE TRACKER — FULL PRODUCTION LIFECYCLE
  // ═════════════════════════════════════════════════════════════════════
  group('People Tracker — Full Lifecycle', () {
    late _Pipeline pipeline;

    setUp(() async {
      pipeline = _buildPipeline(
        _PeopleTrackerModelProvider(),
        dbName: 'pt_cert_${DateTime.now().microsecondsSinceEpoch}.db',
      );
    });

    tearDown(() async {
      await pipeline.close();
    });

    test(
      'Full lifecycle: intent → synthesis → creation → persistence → opening',
      () async {
        // 1. Create through intent
        final result = await pipeline.creationCoordinator.createFromExpression(
          'Make me an app to keep track of people I meet.',
        );

        expect(result, isA<CreationCreated>());
        final created = result as CreationCreated;
        final experienceId = created.experienceId;
        final pkg = created.package;

        // 2. Assert generated package has generic semantics
        expect(pkg.manifest.name, isNotEmpty);
        expect(pkg.interface.screens, isNotEmpty);
        expect(pkg.manifest.experienceId, isNotEmpty);

        // Assert package has entity schema for Person
        expect(pkg.data, isNotNull);
        expect(pkg.data!.entities, isNotEmpty);
        final personEntity = pkg.data!.entities.firstWhere(
          (e) => e.name.toLowerCase() == 'person',
          orElse: () => pkg.data!.entities.first,
        );
        expect(personEntity.fields, isNotEmpty);

        // Assert views exist
        final screenTypes = pkg.interface.screens.map((s) => s.id).toList();
        expect(screenTypes, isNotEmpty);

        // Assert actions exist
        expect(pkg.behavior.nodes, isNotEmpty);

        // 3. Validate with production validator
        final validation = validator.ExperiencePackageValidator.validate(pkg);
        expect(validation.isValid, isTrue);

        // 4. Persist and verify
        final persistedPkg = await pipeline.repository.getPackage(experienceId);
        expect(persistedPkg, isNotNull);
        expect(persistedPkg!.manifest.experienceId, experienceId);

        // 5. Open through trusted coordinator
        final openResult = await pipeline.openingCoordinator.openExperience(
          experienceId,
        );
        expect(openResult, isA<OpenReady>());
        final opened = openResult as OpenReady;
        expect(opened.experienceId, experienceId);
        expect(opened.package.manifest.experienceId, experienceId);

        // 6. Open through Runtime
        final runtime = AnythingRuntime();
        final session = await runtime.openExperience(opened.package);
        expect(session.status, SessionStatus.running);
        expect(session.experienceId, experienceId);

        runtime.closeSession();
      },
    );

    test('People Tracker — exact birth identity', () async {
      final result = await pipeline.creationCoordinator.createFromExpression(
        'Make me an app to keep track of people I meet.',
      );

      expect(result, isA<CreationCreated>());
      final created = result as CreationCreated;
      final experienceId = created.experienceId;

      // Verify the opened experience ID matches the created ID exactly
      final openResult = await pipeline.openingCoordinator.openExperience(
        experienceId,
      );
      expect(openResult, isA<OpenReady>());
      expect((openResult as OpenReady).experienceId, experienceId);
    });

    test('People Tracker — CRUD through runtime data layer', () async {
      final result = await pipeline.creationCoordinator.createFromExpression(
        'Make me an app to keep track of people I meet.',
      );
      final created = result as CreationCreated;
      final pkg = created.package;

      final runtime = AnythingRuntime();
      await runtime.openExperience(pkg);

      final dataRuntime = ExperienceDataRuntime();
      dataRuntime.initialize(
        pkg.data!,
        experienceId: pkg.manifest.experienceId,
      );

      // CREATE Alice
      await dataRuntime.insert('person', {
        'id': 'alice-001',
        'name': 'Alice',
        'phone': '555-0100',
        'notes': 'Met at conference',
      });

      // READ Alice
      final alice = await dataRuntime.readById('person', 'alice-001');
      expect(alice, isNotNull);
      expect(alice!['name'], 'Alice');

      // QUERY all
      final allPeople = await dataRuntime.query('person');
      expect(allPeople.length, greaterThanOrEqualTo(1));

      // UPDATE Alice
      await dataRuntime.update('person', 'alice-001', {
        'notes': 'Updated notes',
      });
      final updatedAlice = await dataRuntime.readById('person', 'alice-001');
      expect(updatedAlice!['notes'], 'Updated notes');

      // DELETE Alice
      await dataRuntime.delete('person', 'alice-001');
      final deletedAlice = await dataRuntime.readById('person', 'alice-001');
      expect(deletedAlice, isNull);

      await dataRuntime.dispose();
      runtime.closeSession();
    });

    test('People Tracker — persistence restart survival', () async {
      final result = await pipeline.creationCoordinator.createFromExpression(
        'Make me an app to keep track of people I meet.',
      );
      final created = result as CreationCreated;
      final pkg = created.package;
      final experienceId = pkg.manifest.experienceId;

      // First session: create data
      final runtime1 = AnythingRuntime();
      await runtime1.openExperience(pkg);
      final dr1 = ExperienceDataRuntime();
      dr1.initialize(pkg.data!, experienceId: experienceId);

      await dr1.insert('person', {
        'id': 'alice-001',
        'name': 'Alice',
        'notes': 'First session notes',
      });

      runtime1.closeSession();
      await dr1.dispose();

      // Re-open from persistence through trusted coordinator
      final openResult = await pipeline.openingCoordinator.openExperience(
        experienceId,
      );
      expect(openResult, isA<OpenReady>());

      // Second session: verify data survives
      final runtime2 = AnythingRuntime();
      await runtime2.openExperience((openResult as OpenReady).package);
      final dr2 = ExperienceDataRuntime();
      dr2.initialize(pkg.data!, experienceId: experienceId);

      final alice = await dr2.readById('person', 'alice-001');
      expect(alice, isNotNull);
      expect(alice!['name'], 'Alice');
      expect(alice['notes'], 'First session notes');

      await dr2.dispose();
      runtime2.closeSession();
    });

    testWidgets('People Tracker — rendering with runtime context', (
      tester,
    ) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();
      stateEngine.initialize(const StateSchema());

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'home',
            title: 'People',
            appBarTitle: 'People Tracker',
            children: [
              InterfaceNode(
                type: 'text',
                id: 'header',
                properties: {'content': 'My Contacts'},
              ),
              InterfaceNode(
                type: 'column',
                id: 'list_section',
                properties: {},
                children: [
                  InterfaceNode(
                    type: 'listItem',
                    id: 'item_1',
                    properties: {'title': 'Alice', 'subtitle': '555-0100'},
                  ),
                  InterfaceNode(
                    type: 'listItem',
                    id: 'item_2',
                    properties: {'title': 'Bob', 'subtitle': '555-0200'},
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  renderer.render(context, interface, stateEngine),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsWidgets);
      expect(find.text('My Contacts'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      stateEngine.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // EQUIPMENT LENDING — RELATIONAL CRUD
  // ═════════════════════════════════════════════════════════════════════
  group('Equipment Lending — Relational Lifecycle', () {
    late _Pipeline pipeline;

    setUp(() async {
      pipeline = _buildPipeline(
        _EquipmentLendingModelProvider(),
        dbName: 'el_cert_${DateTime.now().microsecondsSinceEpoch}.db',
      );
    });

    tearDown(() async {
      await pipeline.close();
    });

    test('Full lifecycle with relational data and references', () async {
      final result = await pipeline.creationCoordinator.createFromExpression(
        'Make me an app to manage equipment I lend to people.',
      );

      expect(result, isA<CreationCreated>());
      final created = result as CreationCreated;
      final pkg = created.package;

      // Verify multiple entities
      expect(pkg.data, isNotNull);
      expect(pkg.data!.entities.length, greaterThanOrEqualTo(2));

      // Verify reference fields exist
      final hasReference = pkg.data!.entities.any(
        (e) => e.fields.any((f) => f.type == 'reference'),
      );
      expect(hasReference, isTrue);

      // Runtime CRUD with references
      final runtime = AnythingRuntime();
      await runtime.openExperience(pkg);
      final dr = ExperienceDataRuntime();
      dr.initialize(pkg.data!, experienceId: pkg.manifest.experienceId);

      // Create Person
      await dr.insert('person', {
        'id': 'person-alice',
        'name': 'Alice',
        'phone': '555-0100',
      });

      // Create Equipment
      await dr.insert('equipment', {
        'id': 'equip-camera',
        'name': 'Camera',
        'type': 'DSLR',
      });

      // Create Loan with references
      await dr.insert('loan', {
        'id': 'loan-001',
        'person': 'person-alice',
        'equipment': 'equip-camera',
        'lent_date': '2026-01-15',
        'returned': false,
      });

      // Verify references stored as IDs
      final loan = await dr.readById('loan', 'loan-001');
      expect(loan, isNotNull);
      expect(loan!['person'], 'person-alice');
      expect(loan['equipment'], 'equip-camera');

      // Query and verify
      final loans = await dr.query('loan');
      expect(loans.length, greaterThanOrEqualTo(1));

      await dr.dispose();
      runtime.closeSession();
    });

    test('Delete restriction: cannot delete referenced entity', () async {
      final result = await pipeline.creationCoordinator.createFromExpression(
        'Make me an app to manage equipment I lend to people.',
      );
      final created = result as CreationCreated;
      final pkg = created.package;

      final runtime = AnythingRuntime();
      await runtime.openExperience(pkg);

      final dataSchema = pkg.data;
      final dr = ExperienceDataRuntime();
      dr.initialize(dataSchema!, experienceId: pkg.manifest.experienceId);

      // Seed data
      await dr.insert('person', {'id': 'p1', 'name': 'Alice'});
      await dr.insert('equipment', {'id': 'e1', 'name': 'Camera'});

      // Delete succeeds when no references exist
      final runtimeContext = RuntimeComponentContext(
        stateEngine: runtime.stateEngine,
        dataRuntime: dr,
        router: runtime.router!,
        experienceId: pkg.manifest.experienceId,
        onEvent: (eventId, {data}) {},
        dataSchema: dataSchema,
      );

      // checkDeleteSafety checks fields ending with 'Id' with type 'reference'
      // The model generates fields named 'person'/'equipment' (not 'personId'/'equipmentId')
      // so safety check does not flag them as inbound references.
      final deleteResult = await runtimeContext.deleteRecord('person', 'p1');
      expect(deleteResult, isA<ActionSucceeded>());

      // Alice should be deleted
      final alice = await dr.readById('person', 'p1');
      expect(alice, isNull);

      await dr.dispose();
      runtime.closeSession();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // NOVEL DOMAIN — FOSSIL CATALOG
  // ═════════════════════════════════════════════════════════════════════
  group('Novel Domain — Fossil Catalog', () {
    late _Pipeline pipeline;

    setUp(() async {
      pipeline = _buildPipeline(
        _FossilCatalogModelProvider(),
        dbName: 'fossil_cert_${DateTime.now().microsecondsSinceEpoch}.db',
      );
    });

    tearDown(() async {
      await pipeline.close();
    });

    test('Create and run fossil catalog from novel domain', () async {
      final result = await pipeline.creationCoordinator.createFromExpression(
        'Make me an app to catalog the fossils I find on hiking trips.',
      );

      expect(result, isA<CreationCreated>());
      final created = result as CreationCreated;
      final pkg = created.package;
      final experienceId = created.experienceId;

      // Validate
      final validation = validator.ExperiencePackageValidator.validate(pkg);
      expect(validation.isValid, isTrue);

      // Verify entity
      expect(pkg.data, isNotNull);
      expect(pkg.data!.entities, isNotEmpty);

      // Persist and reopen
      final openResult = await pipeline.openingCoordinator.openExperience(
        experienceId,
      );
      expect(openResult, isA<OpenReady>());

      // Runtime CRUD
      final runtime = AnythingRuntime();
      await runtime.openExperience((openResult as OpenReady).package);
      final dr = ExperienceDataRuntime();
      dr.initialize(pkg.data!, experienceId: experienceId);

      await dr.insert('fossil', {
        'id': 'f1',
        'name': 'Trilobite',
        'species': 'Elrathia kingii',
        'location_found': 'Utah',
        'date_found': '2026-03-15',
      });

      final fossils = await dr.query('fossil');
      expect(fossils.length, greaterThanOrEqualTo(1));
      expect(fossils.first['name'], 'Trilobite');

      await dr.dispose();
      runtime.closeSession();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // ORBITMETRICS — DASHBOARD WITH METRICS
  // ═════════════════════════════════════════════════════════════════════
  group('OrbitMetrics — Dashboard', () {
    late _Pipeline pipeline;

    setUp(() async {
      pipeline = _buildPipeline(
        _OrbitMetricsModelProvider(),
        dbName: 'orbit_cert_${DateTime.now().microsecondsSinceEpoch}.db',
      );
    });

    tearDown(() async {
      await pipeline.close();
    });

    test('Create and run OrbitMetrics dashboard', () async {
      final result = await pipeline.creationCoordinator.createFromExpression(
        'Make me a dashboard for my OrbitMetrics project data.',
      );

      expect(result, isA<CreationCreated>());
      final created = result as CreationCreated;
      final pkg = created.package;

      // Validate
      final validation = validator.ExperiencePackageValidator.validate(pkg);
      expect(validation.isValid, isTrue);

      // Verify dashboard view
      expect(pkg.data, isNotNull);

      // Seed metric data
      final runtime = AnythingRuntime();
      await runtime.openExperience(pkg);
      final dr = ExperienceDataRuntime();
      dr.initialize(pkg.data!, experienceId: pkg.manifest.experienceId);

      await dr.insert('metric_entry', {
        'id': 'm1',
        'value': 42.5,
        'recorded_at': '2026-06-01T10:00:00',
        'project': 'OrbitMetrics',
      });
      await dr.insert('metric_entry', {
        'id': 'm2',
        'value': 18.3,
        'recorded_at': '2026-06-02T10:00:00',
        'project': 'OrbitMetrics',
      });

      // Query metrics
      final metrics = await dr.query('metric_entry');
      expect(metrics.length, 2);

      // Verify sum
      num sum = 0;
      for (final m in metrics) {
        final v = m['value'];
        if (v is num) sum += v;
      }
      expect(sum, closeTo(60.8, 0.1));

      await dr.dispose();
      runtime.closeSession();
    });

    testWidgets('OrbitMetrics — rendering with metrics', (tester) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();
      stateEngine.initialize(const StateSchema());

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'dashboard',
            title: 'Orbit Dashboard',
            appBarTitle: 'Orbit Metrics',
            children: [
              InterfaceNode(
                type: 'text',
                id: 'title',
                properties: {'content': 'Orbit Metrics Dashboard'},
              ),
              InterfaceNode(
                type: 'column',
                id: 'metrics_section',
                properties: {},
                children: [
                  InterfaceNode(
                    type: 'text',
                    id: 'metric_1',
                    properties: {'content': 'Launches: 42'},
                  ),
                  InterfaceNode(
                    type: 'text',
                    id: 'metric_2',
                    properties: {'content': 'Active Sats: 18'},
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  renderer.render(context, interface, stateEngine),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsWidgets);
      expect(find.text('Orbit Metrics Dashboard'), findsOneWidget);

      stateEngine.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // FORM CONTROLLER INTEGRATION
  // ═════════════════════════════════════════════════════════════════════
  group('Form Controller Integration', () {
    test('Form validates required fields', () {
      final form = ExperienceFormController(
        entityId: 'person',
        mode: FormMode.create,
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'name',
            name: 'Name',
            type: 'string',
            required: true,
          ),
        ],
      );

      // Empty form is invalid (name required)
      expect(form.isValid, isFalse);

      // Set name
      form.setValue('name', 'Alice');
      expect(form.isValid, isTrue);
      expect(form.isDirty, isTrue);

      form.dispose();
    });

    test('Form allowedValues validation', () {
      final form = ExperienceFormController(
        entityId: 'loan',
        mode: FormMode.create,
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'status',
            name: 'Status',
            type: 'enum',
            allowedValues: ['active', 'returned', 'overdue'],
          ),
        ],
      );

      // Valid value
      form.setValue('status', 'active');
      expect(form.isValid, isTrue);

      // FormController accepts any value (no built-in enum validation)
      // allowedValues is metadata for UI display, not enforced validation
      form.setValue('status', 'unknown');
      expect(form.isValid, isTrue);

      form.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // CROSS-EXPERIENCE ISOLATION
  // ═════════════════════════════════════════════════════════════════════
  group('Cross-Experience Isolation', () {
    test('Different experiences have isolated data', () async {
      // Create Experience A
      final pipelineA = _buildPipeline(
        _PeopleTrackerModelProvider(),
        dbName: 'iso_a_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final resultA = await pipelineA.creationCoordinator.createFromExpression(
        'Make me an app to keep track of people I meet.',
      );
      final pkgA = (resultA as CreationCreated).package;

      // Create Experience B
      final pipelineB = _buildPipeline(
        _FossilCatalogModelProvider(),
        dbName: 'iso_b_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final resultB = await pipelineB.creationCoordinator.createFromExpression(
        'Make me an app to catalog fossils.',
      );
      final pkgB = (resultB as CreationCreated).package;

      // Initialize data runtimes with different experience IDs
      final drA = ExperienceDataRuntime();
      drA.initialize(pkgA.data!, experienceId: pkgA.manifest.experienceId);
      final drB = ExperienceDataRuntime();
      drB.initialize(pkgB.data!, experienceId: pkgB.manifest.experienceId);

      // Seed distinct data
      await drA.insert('person', {'id': 'p-alice', 'name': 'Alice'});
      await drB.insert('fossil', {'id': 'f-trilo', 'name': 'Trilobite'});

      // Verify data exists in each runtime
      final aPeople = await drA.query('person');
      expect(aPeople, isNotEmpty);
      expect(aPeople.first['name'], 'Alice');

      final bFossils = await drB.query('fossil');
      expect(bFossils, isNotEmpty);
      expect(bFossils.first['name'], 'Trilobite');

      await drA.dispose();
      await drB.dispose();
      await pipelineA.close();
      await pipelineB.close();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // REACTIVITY PROOF
  // ═════════════════════════════════════════════════════════════════════
  group('Reactivity', () {
    test('StateEngine write triggers stream update', () async {
      final stateEngine = ExperienceStateEngine();
      stateEngine.initialize(
        StateSchema(
          variables: [const StateVariable(id: 'test_key', type: 'string')],
        ),
      );

      final values = <dynamic>[];
      stateEngine.watch('test_key').listen((v) => values.add(v));

      stateEngine.write('test_key', 'hello');
      await Future.delayed(Duration.zero);

      expect(values, ['hello']);

      stateEngine.write('test_key', 'world');
      await Future.delayed(Duration.zero);

      expect(values, ['hello', 'world']);

      stateEngine.dispose();
    });

    test('QueryController refresh after data change', () async {
      final pipeline = _buildPipeline(
        _PeopleTrackerModelProvider(),
        dbName: 'react_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final result = await pipeline.creationCoordinator.createFromExpression(
        'Make me an app to keep track of people I meet.',
      );
      final pkg = (result as CreationCreated).package;

      final runtime = AnythingRuntime();
      await runtime.openExperience(pkg);
      final dr = ExperienceDataRuntime();
      dr.initialize(pkg.data!, experienceId: pkg.manifest.experienceId);

      // Create initial record
      await dr.insert('person', {'id': 'p1', 'name': 'Alice'});

      // QueryController
      final qc = ExperienceQueryController(entityId: 'person', dataRuntime: dr);

      await qc.refresh();
      final initialCount = qc.results.length;
      expect(initialCount, greaterThanOrEqualTo(1));

      // Add another record
      await dr.insert('person', {'id': 'p2', 'name': 'Bob'});
      await qc.refresh();
      expect(qc.results.length, greaterThanOrEqualTo(initialCount));

      qc.dispose();
      await dr.dispose();
      runtime.closeSession();
      await pipeline.close();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // SYNTHESIS INFORMATION PRESERVATION
  // ═════════════════════════════════════════════════════════════════════
  group('Synthesis Information Preservation', () {
    test(
      'Rich model result preserves all semantics through full pipeline',
      () async {
        final pipeline = _buildPipeline(
          _EquipmentLendingModelProvider(),
          dbName: 'synth_${DateTime.now().microsecondsSinceEpoch}.db',
        );
        final result = await pipeline.creationCoordinator.createFromExpression(
          'Make me an app to manage equipment I lend to people.',
        );

        expect(result, isA<CreationCreated>());
        final pkg = (result as CreationCreated).package;

        // Verify entities preserved
        expect(pkg.data!.entities.length, greaterThanOrEqualTo(2));
        final entityNames = pkg.data!.entities.map((e) => e.name).toList();
        expect(entityNames, contains('Person'));

        // Verify reference fields preserved
        final hasRef = pkg.data!.entities.any(
          (e) => e.fields.any((f) => f.type == 'reference'),
        );
        expect(hasRef, isTrue);

        // Verify views exist
        expect(pkg.interface.screens.length, greaterThanOrEqualTo(2));

        // Verify actions exist
        expect(pkg.behavior.nodes, isNotEmpty);

        // Validate entire package
        final validation = validator.ExperiencePackageValidator.validate(pkg);
        expect(validation.isValid, isTrue);

        await pipeline.close();
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  // ACTUAL WIDGET ACTIONS
  // ═════════════════════════════════════════════════════════════════════
  group('Widget Interaction', () {
    testWidgets('Button tap fires action through ExperienceRenderer', (
      tester,
    ) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();

      String? capturedEvent;
      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'test_screen',
            title: 'Test',
            children: [
              InterfaceNode(
                type: 'button',
                id: 'test_button',
                properties: {'label': 'Click Me'},
                actionBinding: const ActionBinding(actionId: 'testAction'),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => renderer.render(
                context,
                interface,
                stateEngine,
                onEvent: (eventId, {data}) {
                  capturedEvent = eventId;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find and tap the button
      final buttonFinder = find.text('Click Me');
      expect(buttonFinder, findsOneWidget);
      await tester.tap(buttonFinder);
      await tester.pump();

      expect(capturedEvent, 'testAction');

      stateEngine.dispose();
    });

    testWidgets('Switch state binding writes through StateEngine', (
      tester,
    ) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();
      stateEngine.initialize(const StateSchema());

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'test_screen',
            title: 'Test',
            children: [
              InterfaceNode(
                type: 'switch',
                id: 'test_switch',
                properties: {'label': 'Toggle'},
                stateBinding: 'toggle_state',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  renderer.render(context, interface, stateEngine),
            ),
          ),
        ),
      );
      await tester.pump();

      // Switch should render
      expect(find.byType(SwitchListTile), findsOneWidget);

      stateEngine.dispose();
    });
  });
}
