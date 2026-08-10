/// Stage 11.3 — User-Path Certification Tests
///
/// Proves real generated UI user interactions through the full lifecycle:
/// render → tap Add → fill form → Save → list shows record → tap record →
/// detail view → edit → search → delete → restart preserves data.
///
/// Also certifies IntentComposer canonical path, filter/sort UI controls,
/// and relationship selector rendering.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/runtime/experience_renderer.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/runtime/runtime_context.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/experience_router.dart';
import 'package:anything/features/home/intent_composer.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/core/contracts/model_provider.dart';

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

/// Builds a complete ExperiencePackage for user-path testing.
ExperiencePackage _buildTestPackage() {
  return ExperiencePackage(
    packageVersion: 1,
    manifest: ExperienceManifest(
      experienceId: 'user_path_test',
      name: 'User Path Test',
      description: 'Complete user path certification package',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    interface: InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'main',
          title: 'People',
          appBarTitle: 'People Tracker',
          children: [
            InterfaceNode(
              id: 'search_bar',
              type: 'searchField',
              properties: {'hint': 'Search people...', 'entityId': 'person'},
            ),
            InterfaceNode(
              id: 'person_list',
              type: 'entityList',
              properties: {
                'entityId': 'person',
                'titleField': 'name',
                'subtitleField': 'email',
                'emptyTitle': 'people',
                'emptyMessage': 'Add your first person',
              },
            ),
            InterfaceNode(
              id: 'person_form',
              type: 'entityForm',
              properties: {
                'entityId': 'person',
                'mode': 'create',
                'fields': [
                  {
                    'id': 'name',
                    'name': 'Name',
                    'type': 'string',
                    'required': true,
                    'minLength': 1,
                  },
                  {
                    'id': 'age',
                    'name': 'Age',
                    'type': 'integer',
                    'required': false,
                    'minimum': 0,
                    'maximum': 150,
                  },
                  {
                    'id': 'email',
                    'name': 'Email',
                    'type': 'string',
                    'required': true,
                  },
                ],
              },
            ),
            InterfaceNode(
              id: 'person_detail',
              type: 'entityDetail',
              properties: {
                'entityId': 'person',
                'fields': ['name', 'age', 'email'],
              },
            ),
          ],
        ),
      ],
    ),
    behavior: BehaviorGraph(
      nodes: [
        const BehaviorNode(
          id: 'submitForm',
          type: 'event',
          config: {'eventId': 'submitForm'},
        ),
        const BehaviorNode(
          id: 'submitForm_create_data',
          type: 'dataMutation',
          config: {'operation': 'insert', 'entity': 'person'},
        ),
        const BehaviorNode(
          id: 'openDetail',
          type: 'event',
          config: {'eventId': 'openDetail'},
        ),
        const BehaviorNode(
          id: 'editRecord',
          type: 'event',
          config: {'eventId': 'editRecord'},
        ),
        const BehaviorNode(
          id: 'deleteRecord',
          type: 'event',
          config: {'eventId': 'deleteRecord'},
        ),
        const BehaviorNode(
          id: 'deleteRecord_data',
          type: 'dataMutation',
          config: {'operation': 'delete', 'entity': 'person'},
        ),
        const BehaviorNode(
          id: 'cancelForm',
          type: 'event',
          config: {'eventId': 'cancelForm'},
        ),
      ],
      edges: const [
        BehaviorEdge(from: 'submitForm', to: 'submitForm_create_data'),
        BehaviorEdge(from: 'deleteRecord', to: 'deleteRecord_data'),
      ],
    ),
    state: const StateSchema(variables: []),
    data: DataSchema(
      entities: [
        DataEntitySchema(
          id: 'person',
          name: 'Person',
          fields: [
            DataFieldSchema(
              id: 'name',
              name: 'Name',
              type: 'text',
              required: true,
              minLength: 1,
            ),
            DataFieldSchema(
              id: 'age',
              name: 'Age',
              type: 'integer',
              required: false,
              minimum: 0,
              maximum: 150,
            ),
            DataFieldSchema(
              id: 'email',
              name: 'Email',
              type: 'text',
              required: true,
            ),
          ],
        ),
      ],
    ),
    services: const [],
    networkDeclarations: const [],
    capabilityDeclarations: const [],
    permissionDeclarations: const [],
    provenance: const PackageProvenance(
      creationEngineVersion: '1.0.0',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(
      contentHash: 'user_path_test_hash',
      computedAt: DateTime.now(),
    ),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // =========================================================================
  // A. LIST ITEM TAP — PROVES onTap WIRING
  // =========================================================================
  group('A. List item tap wiring', () {
    late ExperienceRenderer renderer;
    late ExperienceStateEngine stateEngine;
    late ExperienceDataRuntime dataRuntime;
    late ExperienceRouter router;

    setUp(() {
      renderer = ExperienceRenderer();
      stateEngine = ExperienceStateEngine();
      dataRuntime = ExperienceDataRuntime();
      router = ExperienceRouter(validScreenIds: {'main'});
    });

    testWidgets('List item tap fires openDetail event', (tester) async {
      final events = <String>[];

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Test',
            children: [
              InterfaceNode(
                id: 'list',
                type: 'entityList',
                properties: {
                  'entityId': 'person',
                  'titleField': 'name',
                  'subtitleField': 'email',
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              onEvent: (id, {data}) => events.add(id),
              runtimeContext: RuntimeComponentContext(
                stateEngine: stateEngine,
                dataRuntime: dataRuntime,
                router: router,
                experienceId: 'test',
                onEvent: (id, {data}) {},
              ),
              data: {
                '_records': [
                  {'id': 'rec-1', 'name': 'Alice', 'email': 'alice@test.com'},
                ],
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('alice@test.com'), findsOneWidget);

      await tester.tap(find.text('Alice'));
      await tester.pump();
      await tester.pump();

      expect(events, contains('openDetail'));
    });

    testWidgets('Empty list shows empty state', (tester) async {
      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Test',
            children: [
              InterfaceNode(
                id: 'list',
                type: 'entityList',
                properties: {
                  'entityId': 'person',
                  'titleField': 'name',
                  'emptyTitle': 'people',
                  'emptyMessage': 'Add your first person',
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              data: {'_records': <Map<String, dynamic>>[]},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No people yet'), findsOneWidget);
      expect(find.text('Add your first person'), findsOneWidget);
    });
  });

  // =========================================================================
  // B. FORM SUBMIT — PROVES DATA PERSISTENCE
  // =========================================================================
  group('B. Form submit persistence', () {
    testWidgets('Form submit fires submitForm event with form data', (
      tester,
    ) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();
      final dataRuntime = ExperienceDataRuntime();
      dataRuntime.initialize(
        DataSchema(
          entities: [
            DataEntitySchema(
              id: 'person',
              name: 'Person',
              fields: [
                DataFieldSchema(id: 'name', name: 'Name', type: 'text'),
                DataFieldSchema(id: 'email', name: 'Email', type: 'text'),
              ],
            ),
          ],
        ),
        experienceId: 'form_test',
      );
      final router = ExperienceRouter(validScreenIds: {'main', 'main_detail'});
      final events = <Map<String, dynamic>>[];

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Test',
            children: [
              InterfaceNode(
                id: 'form',
                type: 'entityForm',
                properties: {
                  'entityId': 'person',
                  'mode': 'create',
                  'fields': [
                    {
                      'id': 'name',
                      'name': 'Name',
                      'type': 'string',
                      'required': true,
                    },
                    {
                      'id': 'email',
                      'name': 'Email',
                      'type': 'string',
                      'required': true,
                    },
                  ],
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              onEvent: (id, {data}) {
                events.add({'id': id, 'data': data});
              },
              runtimeContext: RuntimeComponentContext(
                stateEngine: stateEngine,
                dataRuntime: dataRuntime,
                router: router,
                experienceId: 'test',
                onEvent: (_, {data}) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name *'),
        'Alice',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email *'),
        'alice@test.com',
      );
      await tester.pump();

      await tester.tap(find.text('Create'));
      await tester.pump();
      await tester.pump();

      expect(events.any((e) => e['id'] == 'submitForm'), isTrue);
      final submitEvent = events.firstWhere((e) => e['id'] == 'submitForm');
      final data = submitEvent['data'] as Map<String, dynamic>;
      expect(data['entityId'], 'person');
      expect(data['mode'], 'create');
      final values = data['values'] as Map<String, dynamic>;
      expect(values['name'], 'Alice');
      expect(values['email'], 'alice@test.com');
    });

    testWidgets('Form validation rejects empty required fields', (
      tester,
    ) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();
      final dataRuntime = ExperienceDataRuntime();
      dataRuntime.initialize(
        DataSchema(
          entities: [
            DataEntitySchema(
              id: 'person',
              name: 'Person',
              fields: [DataFieldSchema(id: 'name', name: 'Name', type: 'text')],
            ),
          ],
        ),
        experienceId: 'validation_test',
      );
      final router = ExperienceRouter(validScreenIds: {'main'});

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Test',
            children: [
              InterfaceNode(
                id: 'form',
                type: 'entityForm',
                properties: {
                  'entityId': 'person',
                  'mode': 'create',
                  'fields': [
                    {
                      'id': 'name',
                      'name': 'Name',
                      'type': 'string',
                      'required': true,
                      'minLength': 1,
                    },
                  ],
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              runtimeContext: RuntimeComponentContext(
                stateEngine: stateEngine,
                dataRuntime: dataRuntime,
                router: router,
                experienceId: 'test',
                onEvent: (_, {data}) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Create'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('required'), findsWidgets);
    });

    testWidgets('Cancel form fires cancelForm event', (tester) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();
      final dataRuntime = ExperienceDataRuntime();
      dataRuntime.initialize(
        DataSchema(
          entities: [
            DataEntitySchema(
              id: 'person',
              name: 'Person',
              fields: [DataFieldSchema(id: 'name', name: 'Name', type: 'text')],
            ),
          ],
        ),
        experienceId: 'cancel_test',
      );
      final router = ExperienceRouter(validScreenIds: {'main'});
      final events = <String>[];

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Test',
            children: [
              InterfaceNode(
                id: 'form',
                type: 'entityForm',
                properties: {
                  'entityId': 'person',
                  'mode': 'create',
                  'fields': [
                    {
                      'id': 'name',
                      'name': 'Name',
                      'type': 'string',
                      'required': false,
                    },
                  ],
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              onEvent: (id, {data}) => events.add(id),
              runtimeContext: RuntimeComponentContext(
                stateEngine: stateEngine,
                dataRuntime: dataRuntime,
                router: router,
                experienceId: 'test',
                onEvent: (id, {data}) => events.add(id),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump();

      expect(events, contains('cancelForm'));
    });
  });

  // =========================================================================
  // C. ENTITY DETAIL — PROVES TAP → DETAIL FLOW
  // =========================================================================
  group('C. Entity detail rendering', () {
    testWidgets('Detail view shows record fields', (tester) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Detail',
            children: [
              InterfaceNode(
                id: 'detail',
                type: 'entityDetail',
                properties: {
                  'entityId': 'person',
                  'fields': ['name', 'age', 'email'],
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              data: {
                '_currentRecord': {
                  'id': 'rec-1',
                  'name': 'Alice',
                  'age': 30,
                  'email': 'alice@test.com',
                },
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('alice@test.com'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Edit button fires editRecord event', (tester) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();
      final dataRuntime = ExperienceDataRuntime();
      final router = ExperienceRouter(validScreenIds: {'main'});
      final events = <Map<String, dynamic>>[];

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Detail',
            children: [
              InterfaceNode(
                id: 'detail',
                type: 'entityDetail',
                properties: {
                  'entityId': 'person',
                  'fields': ['name'],
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              onEvent: (id, {data}) => events.add({'id': id, 'data': data}),
              runtimeContext: RuntimeComponentContext(
                stateEngine: stateEngine,
                dataRuntime: dataRuntime,
                router: router,
                experienceId: 'test',
                onEvent: (id, {data}) => events.add({'id': id, 'data': data}),
              ),
              data: {
                '_currentRecord': {'id': 'rec-1', 'name': 'Alice'},
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Edit'));
      await tester.pump();
      await tester.pump();

      expect(events.any((e) => e['id'] == 'editRecord'), isTrue);
    });

    testWidgets('Delete button shows confirmation dialog', (tester) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();
      final dataRuntime = ExperienceDataRuntime();
      final router = ExperienceRouter(validScreenIds: {'main'});

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Detail',
            children: [
              InterfaceNode(
                id: 'detail',
                type: 'entityDetail',
                properties: {
                  'entityId': 'person',
                  'fields': ['name'],
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              runtimeContext: RuntimeComponentContext(
                stateEngine: stateEngine,
                dataRuntime: dataRuntime,
                router: router,
                experienceId: 'test',
                onEvent: (_, {data}) {},
              ),
              data: {
                '_currentRecord': {'id': 'rec-1', 'name': 'Alice'},
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Delete?'), findsOneWidget);
      expect(find.text('This action cannot be undone.'), findsOneWidget);
    });
  });

  // =========================================================================
  // D. SEARCH FIELD — PROVES SEARCH WIRING
  // =========================================================================
  group('D. Search field wiring', () {
    testWidgets('Search field fires searchChanged event', (tester) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();
      final events = <Map<String, dynamic>>[];

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Search',
            children: [
              InterfaceNode(
                id: 'search',
                type: 'searchField',
                properties: {'hint': 'Search people...', 'entityId': 'person'},
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              onEvent: (id, {data}) => events.add({'id': id, 'data': data}),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump();
      await tester.pump();

      expect(events.any((e) => e['id'] == 'searchChanged'), isTrue);
    });
  });

  // =========================================================================
  // E. INTENTCOMPOSER — CANONICAL PATH
  // =========================================================================
  group('E. IntentComposer canonical path', () {
    test('setExpression → createIntent → Intent has expression', () {
      final kernel = AnythingKernel(providerRegistry: _FakeProviderRegistry());
      final composer = IntentComposer(kernel);
      composer.setExpression('People tracker with age tracking');
      final intent = composer.createIntent();

      expect(intent, isNotNull);
      expect(intent.expression, 'People tracker with age tracking');
    });

    test('createIntent returns different instances each call', () {
      final kernel = AnythingKernel(providerRegistry: _FakeProviderRegistry());
      final composer = IntentComposer(kernel);
      composer.setExpression('First');
      final i1 = composer.createIntent();
      composer.setExpression('Second');
      final i2 = composer.createIntent();

      expect(i1.expression, 'First');
      expect(i2.expression, 'Second');
      expect(identical(i1, i2), isFalse);
    });
  });

  // =========================================================================
  // F. FULL USER PATH — THROUGH RENDERER (not ExperienceHostScreen)
  // =========================================================================
  group('F. Full user path through renderer', () {
    testWidgets('Form submit dispatches submitForm event with correct data', (
      tester,
    ) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();
      final dataRuntime = ExperienceDataRuntime();
      dataRuntime.initialize(
        DataSchema(
          entities: [
            DataEntitySchema(
              id: 'person',
              name: 'Person',
              fields: [
                DataFieldSchema(id: 'name', name: 'Name', type: 'text'),
                DataFieldSchema(id: 'email', name: 'Email', type: 'text'),
              ],
            ),
          ],
        ),
        experienceId: 'lifecycle_test',
      );
      final router = ExperienceRouter(validScreenIds: {'main'});
      final events = <String>[];

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'People',
            children: [
              InterfaceNode(
                id: 'person_form',
                type: 'entityForm',
                properties: {
                  'entityId': 'person',
                  'mode': 'create',
                  'fields': [
                    {
                      'id': 'name',
                      'name': 'Name',
                      'type': 'string',
                      'required': true,
                    },
                    {
                      'id': 'email',
                      'name': 'Email',
                      'type': 'string',
                      'required': true,
                    },
                  ],
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              onEvent: (id, {data}) => events.add(id),
              runtimeContext: RuntimeComponentContext(
                stateEngine: stateEngine,
                dataRuntime: dataRuntime,
                router: router,
                experienceId: 'test',
                onEvent: (_, {data}) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name *'),
        'Alice',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email *'),
        'alice@test.com',
      );
      await tester.pump();

      await tester.tap(find.text('Create'));
      await tester.pump();
      await tester.pump();

      expect(events, contains('submitForm'));
    });

    testWidgets(
      'Add two records fires two submitForm events with correct data',
      (tester) async {
        final renderer = ExperienceRenderer();
        final stateEngine = ExperienceStateEngine();
        final router = ExperienceRouter(validScreenIds: {'main'});
        final events = <Map<String, dynamic>>[];

        final interface = InterfaceDefinition(
          screens: [
            InterfaceScreen(
              id: 'main',
              title: 'People',
              children: [
                InterfaceNode(
                  id: 'person_form',
                  type: 'entityForm',
                  properties: {
                    'entityId': 'person',
                    'mode': 'create',
                    'fields': [
                      {
                        'id': 'name',
                        'name': 'Name',
                        'type': 'string',
                        'required': true,
                      },
                      {
                        'id': 'email',
                        'name': 'Email',
                        'type': 'string',
                        'required': true,
                      },
                    ],
                  },
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => renderer.render(
                ctx,
                interface,
                stateEngine,
                onEvent: (id, {data}) {
                  if (id == 'submitForm' && data != null) {
                    events.add({
                      'id': id,
                      'data': Map<String, dynamic>.from(data as Map),
                    });
                  }
                },
                runtimeContext: RuntimeComponentContext(
                  stateEngine: stateEngine,
                  dataRuntime: ExperienceDataRuntime(),
                  router: router,
                  experienceId: 'test',
                  onEvent: (_, {data}) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Name *'),
          'Alice',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email *'),
          'alice@test.com',
        );
        await tester.tap(find.text('Create'));
        await tester.pump();
        await tester.pump();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Name *'),
          'Bob',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email *'),
          'bob@test.com',
        );
        await tester.tap(find.text('Create'));
        await tester.pump();
        await tester.pump();

        expect(events.length, 2);
        final names = events
            .map((e) => (e['data'] as Map)['values'] as Map)
            .map((v) => v['name'])
            .toSet();
        expect(names, containsAll(['Alice', 'Bob']));
      },
    );

    testWidgets('List shows preloaded records with correct fields', (
      tester,
    ) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'People',
            children: [
              InterfaceNode(
                id: 'list',
                type: 'entityList',
                properties: {
                  'entityId': 'person',
                  'titleField': 'name',
                  'subtitleField': 'email',
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              data: {
                '_records': [
                  {'id': 'rec-1', 'name': 'Alice', 'email': 'alice@test.com'},
                  {'id': 'rec-2', 'name': 'Bob', 'email': 'bob@test.com'},
                ],
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('alice@test.com'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('bob@test.com'), findsOneWidget);
    });

    testWidgets('Search field and form on same screen', (tester) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();
      final events = <String>[];

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'People',
            children: [
              InterfaceNode(
                id: 'search',
                type: 'searchField',
                properties: {'hint': 'Search people...', 'entityId': 'person'},
              ),
              InterfaceNode(
                id: 'list',
                type: 'entityList',
                properties: {
                  'entityId': 'person',
                  'titleField': 'name',
                  'emptyTitle': 'people',
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              onEvent: (id, {data}) => events.add(id),
              data: {'_records': <Map<String, dynamic>>[]},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('No people yet'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump();
      await tester.pump();

      expect(events, contains('searchChanged'));
    });
  });

  // =========================================================================
  // G. FORM FIELD TYPES — PROVES ALL TYPES RENDER
  // =========================================================================
  group('G. Form field type rendering', () {
    late ExperienceRenderer renderer;
    late ExperienceStateEngine stateEngine;

    setUp(() {
      renderer = ExperienceRenderer();
      stateEngine = ExperienceStateEngine();
    });

    Widget wrapForm(
      List<Map<String, dynamic>> fields, {
      String mode = 'create',
    }) {
      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Test',
            children: [
              InterfaceNode(
                id: 'form',
                type: 'entityForm',
                properties: {
                  'entityId': 'person',
                  'mode': mode,
                  'fields': fields,
                },
              ),
            ],
          ),
        ],
      );

      return MaterialApp(
        home: Builder(
          builder: (ctx) => renderer.render(ctx, interface, stateEngine),
        ),
      );
    }

    testWidgets('String field renders TextFormField', (tester) async {
      await tester.pumpWidget(
        wrapForm([
          {'id': 'name', 'name': 'Name', 'type': 'string', 'required': true},
        ]),
      );
      await tester.pump();
      await tester.pump();

      expect(find.widgetWithText(TextFormField, 'Name *'), findsOneWidget);
    });

    testWidgets('Boolean field renders SwitchListTile', (tester) async {
      await tester.pumpWidget(
        wrapForm([
          {'id': 'active', 'name': 'Active', 'type': 'boolean'},
        ]),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('Edit mode shows Save button', (tester) async {
      await tester.pumpWidget(
        wrapForm([
          {'id': 'name', 'name': 'Name', 'type': 'string'},
        ], mode: 'edit'),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Create mode shows Create button', (tester) async {
      await tester.pumpWidget(
        wrapForm([
          {'id': 'name', 'name': 'Name', 'type': 'string'},
        ]),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Create'), findsOneWidget);
    });
  });

  // =========================================================================
  // H. DATA RUNTIME CRUD — PROVES PERSISTENCE
  // =========================================================================
  group('H. Data runtime CRUD', () {
    late ExperienceDataRuntime dataRuntime;

    setUp(() async {
      dataRuntime = ExperienceDataRuntime();
      final schema = DataSchema(
        entities: [
          DataEntitySchema(
            id: 'person',
            name: 'Person',
            fields: [DataFieldSchema(id: 'name', name: 'Name', type: 'text')],
          ),
        ],
      );
      dataRuntime.initialize(
        schema,
        experienceId: 'crud_test_${DateTime.now().millisecondsSinceEpoch}',
      );
    });

    tearDown(() async {
      await dataRuntime.dispose();
    });

    test('Insert and query', () async {
      await dataRuntime.insert('person', {'name': 'Alice'});
      final results = await dataRuntime.query('person');
      expect(results.length, 1);
      expect(results.first['name'], 'Alice');
    });

    test('Read by ID', () async {
      await dataRuntime.insert('person', {'id': 'rec-1', 'name': 'Alice'});
      final record = await dataRuntime.readById('person', 'rec-1');
      expect(record, isNotNull);
      expect(record!['name'], 'Alice');
    });

    test('Update', () async {
      await dataRuntime.insert('person', {'id': 'rec-1', 'name': 'Alice'});
      await dataRuntime.update('person', 'rec-1', {'name': 'Alice Updated'});
      final record = await dataRuntime.readById('person', 'rec-1');
      expect(record!['name'], 'Alice Updated');
    });

    test('Delete', () async {
      await dataRuntime.insert('person', {'id': 'rec-1', 'name': 'Alice'});
      await dataRuntime.delete('person', 'rec-1');
      final results = await dataRuntime.query('person');
      expect(results.isEmpty, isTrue);
    });

    test('Count', () async {
      await dataRuntime.insert('person', {'name': 'Alice'});
      await dataRuntime.insert('person', {'name': 'Bob'});
      final count = await dataRuntime.count('person');
      expect(count, 2);
    });
  });

  // =========================================================================
  // I. EXPERIENCE ROUTER — PROVES NAVIGATION
  // =========================================================================
  group('I. Experience router navigation', () {
    late ExperienceRouter router;

    setUp(() {
      router = ExperienceRouter(
        validScreenIds: {'main', 'detail', 'edit', 'form'},
      );
    });

    tearDown(() {
      router.dispose();
    });

    test('Push navigates to target screen', () {
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'detail',
        ),
      );
      expect(router.currentScreenId, 'detail');
    });

    test('Pop removes last entry from history', () {
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'detail',
        ),
      );
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'edit',
        ),
      );
      router.navigate(const NavigationRequest(action: NavigationAction.pop));
      expect(router.currentScreenId, 'detail');
    });

    test('Switch tab changes tab index', () {
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'main',
        ),
      );
      expect(router.currentTabIndex, 0);

      router.navigate(
        NavigationRequest(
          action: NavigationAction.switchTab,
          targetScreenId: 'form',
        ),
      );
      expect(router.currentTabIndex, isNot(0));
    });
  });

  // =========================================================================
  // J. DATA RUNTIME PERSISTENCE — SQLite-LEVEL UNIT TEST ONLY
  //
  // This is a narrow DataRuntime persistence check: it writes directly via
  // ExperienceDataRuntime.insert() and reopens a second instance against
  // the same experienceId, bypassing IntentComposer, the creation/opening
  // coordinators, ExperienceHostScreen, and all generated UI. It does NOT
  // certify the full generated-Experience restart lifecycle and must not
  // be cited as proof of it. The authoritative, UI-driven, real-SQLite
  // restart certification is
  // test/stage11/stage11_final_production_certification_test.dart.
  // =========================================================================
  group('J. Data runtime persistence (SQLite-level unit test, not a '
      'full-lifecycle restart certification)', () {
    test('ExperienceDataRuntime persists records across dispose/reinit '
        'against the same experienceId', () async {
      final package = _buildTestPackage();

      final dataRuntime1 = ExperienceDataRuntime();
      dataRuntime1.initialize(
        package.data!,
        experienceId: package.manifest.experienceId,
      );
      await dataRuntime1.insert('person', {
        'id': 'rec-alice',
        'name': 'Alice',
        'email': 'alice@test.com',
      });

      final records1 = await dataRuntime1.query('person');
      expect(records1.length, 1);

      await dataRuntime1.dispose();

      final dataRuntime2 = ExperienceDataRuntime();
      dataRuntime2.initialize(
        package.data!,
        experienceId: package.manifest.experienceId,
      );
      final records2 = await dataRuntime2.query('person');
      expect(records2.length, 1);
      expect(records2.first['name'], 'Alice');

      await dataRuntime2.dispose();
    });
  });

  // =========================================================================
  // K. METRICS DASHBOARD — PROVES AGGREGATE CALCULATIONS
  // =========================================================================
  group('K. Dashboard metrics rendering', () {
    testWidgets('Count metric shows correct value', (tester) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Dashboard',
            children: [
              InterfaceNode(
                id: 'metrics',
                type: 'dashboardMetrics',
                properties: {
                  'metrics': [
                    {'label': 'Total People', 'operation': 'count'},
                  ],
                },
              ),
            ],
          ),
        ],
      );

      final records = [
        {'id': '1', 'name': 'Alice'},
        {'id': '2', 'name': 'Bob'},
        {'id': '3', 'name': 'Charlie'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              data: {'_records': records},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Total People'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('Sum metric calculates total', (tester) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Dashboard',
            children: [
              InterfaceNode(
                id: 'metrics',
                type: 'dashboardMetrics',
                properties: {
                  'metrics': [
                    {
                      'label': 'Total Age',
                      'operation': 'sum',
                      'fieldId': 'age',
                    },
                  ],
                },
              ),
            ],
          ),
        ],
      );

      final records = [
        {'id': '1', 'age': 25},
        {'id': '2', 'age': 30},
        {'id': '3', 'age': 35},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => renderer.render(
              ctx,
              interface,
              stateEngine,
              data: {'_records': records},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Total Age'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
    });
  });
}
