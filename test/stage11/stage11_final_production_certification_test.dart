/// Stage 11 — Final Production Certification (authoritative)
///
/// Proves, without simulation, that:
///   a human expression -> IntentComposer -> same Intent -> IntentRepository
///   -> production AnythingKernel -> open-world reasoning -> generated
///   AppBlueprint/ExperienceSpec/ExecutionPlan/ExperiencePackage -> package
///   validation -> Experience persistence -> trusted opening ->
///   production ExperienceHostScreen -> production AnythingRuntime ->
///   production ExperienceDataRuntime -> real SQLite -> generated Add,
///   generated form, generated Save, generated detail, generated Edit
///   (same-record update, not a duplicate insert), a second generated
///   create, generated Search (real filtering), generated Delete -> the
///   entire Runtime/Database boundary is destroyed (Runtime A closed,
///   Database A closed) and rebuilt from scratch (fresh Database B at the
///   same file path, fresh ExperienceDataRuntime, fresh AnythingRuntime,
///   fresh trusted reopen via ExperienceOpeningCoordinator, fresh
///   production ExperienceHostScreen) -> the surviving edited record is
///   visible through GENERATED UI and the deleted record is not.
///
/// No _CachedDataRuntime / _InMemoryDataRuntime. No _TestExperienceHost.
/// No hand-built ExperiencePackage. No direct DataRuntime.insert/update/
/// delete used to manufacture the certified state -- every mutation is
/// driven through a real widget tap on real generated UI. Only the
/// external ModelProvider is faked (LLM is external infrastructure); the
/// Kernel, reasoner, CreationEngine, validator, repositories, coordinators,
/// host, runtime, renderer, behavior interpreter, and SQLite are all real
/// production code, unmodified for this test.
///
/// The domain (community garden plots) has zero footprint anywhere in
/// lib/ (verified by an automated scan in this file, see the
/// "Novel domain has zero production footprint" test below), proving
/// open-world synthesis rather than a recognized/hardcoded example.
///
/// SQLite FFI does not cooperate with flutter_test's default FakeAsync
/// zone. Every real-async-triggering interaction in the widgets test below
/// is followed by `tester.runAsync(...)` so the real Future actually
/// completes (real Timers/microtasks/isolate IPC only progress in the real
/// zone), before handing control back to `tester.pump()` to render the
/// result. See `_settleReal` and `_pumpUntilFound` below.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/features/home/intent_composer.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/kernel/resolution/experience_resolver.dart';
import 'package:anything/kernel/understanding/intent_understanding.dart'
    show ExistingExperienceStatus;
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/experience_opening_coordinator.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/experience_host_screen.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/storage/intent_repository.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/storage/experience_database.dart';

// ── Novel domain: community garden plot tracking ──────────────────────
// Chosen because it has zero footprint anywhere in production lib/
// (verified below by an automated word-boundary scan, not just a
// one-time manual grep).

const _understandingResponse = {
  'objective': 'track community garden plots, crops, and harvest notes',
  'category': 'create',
  'desiredOutcome':
      'A simple app to record garden plots, what is planted, and notes '
      'about the harvest',
  'constraints': <String>[],
  'requiredInputs': <String>[],
  'assumptions': <String>['Simple single-entity collection app'],
  'confidence': 0.85,
  'networkNeed': 'none',
  'creationNeed': 'definitelyNeeded',
  'modificationNeed': 'notNeeded',
};

const _blueprintResponse = {
  'name': 'Garden Plot Tracker',
  'purpose': 'Track community garden plots, crops, and harvest notes',
  'entities': <Map<String, dynamic>>[
    {
      'name': 'Plot',
      'description': 'A community garden plot',
      'fields': <Map<String, dynamic>>[
        {
          'name': 'Plot Name',
          'type': 'text',
          'required': true,
          'description': 'Identifier for the plot',
        },
        {
          'name': 'Crop',
          'type': 'text',
          'required': true,
          'description': 'What is planted in the plot',
        },
        {
          'name': 'Harvest Notes',
          'type': 'multilineText',
          'required': false,
          'description': 'Notes about the harvest',
        },
      ],
    },
  ],
  'actions': <Map<String, dynamic>>[
    {'name': 'Add Plot', 'type': 'create', 'targetEntity': 'plot'},
    {'name': 'Update Plot', 'type': 'update', 'targetEntity': 'plot'},
    {'name': 'Delete Plot', 'type': 'delete', 'targetEntity': 'plot'},
  ],
  'derivedValues': <Map<String, dynamic>>[
    {
      'name': 'Total Plots',
      'sourceEntity': 'plot',
      'operation': 'count',
      'fieldId': '',
      'description': 'Total garden plots tracked',
    },
  ],
  'views': <Map<String, dynamic>>[
    {
      'name': 'Plots List',
      'purpose': 'View all garden plots',
      'type': 'list',
      'sourceEntity': 'plot',
      'sections': <Map<String, dynamic>>[
        {'purpose': 'All plots', 'sourceEntity': 'plot', 'type': 'list'},
      ],
      'isDefault': true,
    },
    {
      'name': 'Plot Form',
      'purpose': 'Add a new garden plot',
      'type': 'form',
      'sourceEntity': 'plot',
      'sections': <Map<String, dynamic>>[
        {'purpose': 'Plot form', 'sourceEntity': 'plot', 'type': 'form'},
      ],
      'isDefault': false,
    },
    {
      'name': 'Plot Detail',
      'purpose': 'View plot details',
      'type': 'detail',
      'sourceEntity': 'plot',
      'sections': <Map<String, dynamic>>[
        {'purpose': 'Plot detail', 'sourceEntity': 'plot', 'type': 'detail'},
      ],
      'isDefault': false,
    },
    {
      'name': 'Dashboard',
      'purpose': 'Overview metrics',
      'type': 'dashboard',
      'sourceEntity': 'plot',
      'sections': <Map<String, dynamic>>[
        {'purpose': 'Metrics', 'sourceEntity': 'plot', 'type': 'summary'},
      ],
      'isDefault': false,
    },
  ],
  'tags': <String>['garden', 'tracking'],
  'archetypes': <String>['collection'],
  'requiredCapabilities': <String>[],
  'knowledgeNeeds': <String>[],
  'networkConfig': null,
};

/// The only faked external boundary: the LLM. Everything downstream of
/// this (Kernel, reasoner, CreationEngine, validator, repositories,
/// coordinators, host, runtime, renderer, behavior interpreter, SQLite)
/// is real production code.
class _FakeModelProvider implements ModelProvider {
  @override
  String get providerId => 'fake';
  @override
  String get providerName => 'Fake Provider';
  @override
  bool get isConfigured => true;

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
    final userMessage = request.messages
        .where((m) => m.role == 'user')
        .map((m) => m.content)
        .join('\n');
    if (userMessage.contains('Analyze this user intent')) {
      return ModelResponse(text: jsonEncode(_understandingResponse));
    }
    if (userMessage.contains('Analyze the following user intent')) {
      return ModelResponse(text: jsonEncode(_blueprintResponse));
    }
    throw StateError('Unexpected model prompt: $userMessage');
  }

  @override
  Stream<String> generateStream(ModelRequest request) async* {
    final response = await generate(request);
    yield response.text;
  }

  @override
  Future<List<ModelInfo>> listModels() async => [
    const ModelInfo(id: 'fake-model', name: 'Fake Model', provider: 'fake'),
  ];

  @override
  Future<bool> testConnection(String apiKey) async => true;
  @override
  Future<void> saveApiKey(String apiKey) async {}
  @override
  Future<String?> getApiKey() async => 'fake-key';
  @override
  Future<void> deleteApiKey() async {}
}

class _FakeProviderRegistry implements ModelProviderRegistry {
  final _FakeModelProvider _provider = _FakeModelProvider();
  @override
  ModelProvider? get activeProvider => _provider;
  @override
  List<ModelProvider> get providers => [_provider];
  @override
  ModelProvider? getProvider(String id) => id == 'fake' ? _provider : null;
  @override
  void registerProvider(ModelProvider provider) {}
  @override
  Future<void> setActiveProvider(String id) async {}
  @override
  Future<List<ProviderConfig>> listConfigs() async => [];
  @override
  Future<void> saveConfig(ProviderConfig config) async {}
  @override
  Future<void> deleteConfig(String id) async {}
  @override
  Future<ProviderConfig?> getDefaultConfig() async => null;
}

/// Lets real (non-FakeAsync) async work -- real SQLite FFI calls
/// triggered by a widget interaction -- actually complete, then hands
/// control back to the normal pump-based test zone to render the result.
/// Bounded: a fixed number of short real delays, never an unbounded wait.
Future<void> _settleReal(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }
}

/// Bounded wait for [finder] to appear, using real-time delays (so real
/// SQLite reads triggered during build can actually resolve) instead of
/// FakeAsync's fake clock. Does NOT itself assert -- callers must follow
/// with a hard `expect` so a required feature can never silently pass by
/// timing out.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxAttempts = 40,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}

late CapabilityRegistry _capabilityRegistry;
late AnythingKernel _kernel;
late _FakeProviderRegistry _providerRegistry;

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    // Real sqflite FFI (real SQLite, real file I/O) but without spawning a
    // worker isolate: databaseFactoryFfi's isolate-based communication
    // deadlocks under testWidgets's FakeAsync zone even inside
    // tester.runAsync() (observed directly: TimeoutException stuck in
    // dart:isolate _RawReceivePort._handleMessage). NoIsolate runs SQLite
    // synchronously in-process -- still genuine SQLite, not a mock/cache.
    databaseFactory = databaseFactoryFfiNoIsolate;

    _providerRegistry = _FakeProviderRegistry();
    _capabilityRegistry = CapabilityRegistry();
    _capabilityRegistry.register(
      const CapabilityDescriptor(
        id: 'storage',
        version: '1.0.0',
        name: 'Storage',
        description: 'Local data persistence',
        category: CapabilityCategory.storage,
        inputContract: 'Any data to store',
        outputContract: 'Stored data',
        isAvailable: true,
      ),
    );
    _kernel = AnythingKernel(
      providerRegistry: _providerRegistry,
      capabilityRegistry: _capabilityRegistry,
    );
  });

  test('Novel domain has zero production footprint in lib/', () async {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ must exist');

    final domainTerms = [
      RegExp(r'\bgarden\b', caseSensitive: false),
      RegExp(r'\bplot\b', caseSensitive: false),
      RegExp(r'\bharvest\b', caseSensitive: false),
    ];
    final hits = <String>[];
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = await entity.readAsString();
      for (final pattern in domainTerms) {
        if (pattern.hasMatch(content)) {
          hits.add('${entity.path}: ${pattern.pattern}');
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason:
          'Production lib/ must contain zero domain-specific branches for '
          'this novel domain (open-world synthesis proof): $hits',
    );
  });

  test('Novel domain expression -> production reasoner -> generated blueprint '
      '(open-world synthesis, no persistence)', () async {
    const expression =
        'Make me an app to track community garden plots, what is '
        'planted in each plot, and notes about the harvest.';
    final composer = IntentComposer(_kernel);
    composer.setExpression(expression);
    final intent = composer.createIntent();

    final outcome = await _kernel.processIntent(intent);
    expect(
      outcome,
      isA<ExecutionPlanReady>(),
      reason:
          'Kernel must produce a plan from a novel-domain expression '
          'without any hardcoded recognition of it',
    );
    final ready = outcome as ExecutionPlanReady;
    expect(ready.blueprint, isNotNull);
    final blueprint = ready.blueprint!;
    expect(
      blueprint.entities.any((e) => e.id == 'plot'),
      isTrue,
      reason: 'Blueprint must contain the model-described Plot entity',
    );
    expect(blueprint.views.any((v) => v.viewType.name == 'list'), isTrue);
    expect(blueprint.views.any((v) => v.viewType.name == 'detail'), isTrue);
    expect(blueprint.views.any((v) => v.viewType.name == 'form'), isTrue);
  });

  test('ExperienceResolver has no built-in domain fixtures; only matches '
      'explicitly registered experiences', () {
    final resolver = ExperienceResolver();

    final calculatorAttempt = resolver.resolve(
      'I would like a calculator app please, some quick math tool',
    );
    expect(
      calculatorAttempt.status,
      ExistingExperienceStatus.notFound,
      reason:
          'No built-in domain fixture may exist -- regression guard for '
          'the hardcoded calculator branch removed from ExperienceResolver',
    );

    const registeredId = 'exp-test-registered-001';
    resolver.registerExperience('exp-test-registered-001', 'My Test App', [
      'mytestapp',
    ]);
    final registeredAttempt = resolver.resolve('open my testapp mytestapp');
    expect(registeredAttempt.status, ExistingExperienceStatus.found);
    expect(registeredAttempt.experienceId, registeredId);
  });

  group('Stage 11 Final — Real Generated Experience Lifecycle', () {
    late ExperiencePackage package;
    late String experienceId;
    late String intentId;
    late String dbPath;
    late Directory tempDir;
    late ExperienceDatabase databaseA;
    late ExperienceDataRuntime dataRuntimeA;
    late AnythingRuntime runtimeA;

    test('Pipeline: expression -> IntentComposer -> IntentRepository -> '
        'production Kernel -> ExperienceCreationCoordinator -> validated '
        'generated package -> Experience persistence -> trusted first open '
        '-> real SQLite data database ready', () async {
      const expression =
          'Make me an app to track community garden plots, what is '
          'planted in each plot, and notes about the harvest.';

      // IntentComposer -> Intent
      final composer = IntentComposer(_kernel);
      composer.setExpression(expression);
      final intent = composer.createIntent();
      expect(intent.expression, expression);
      expect(intent.status, IntentStatus.draft);
      intentId = intent.id;

      // IntentRepository -> save + submit + reload (same Intent, same ID)
      final intentRepository = IntentRepository();
      await intentRepository.save(IntentRecord.fromIntent(intent));
      await intentRepository.updateStatus(intentId, IntentStatus.submitted);
      final savedIntent = await intentRepository.getById(intentId);
      expect(savedIntent, isNotNull);
      expect(savedIntent!.id, intentId);
      expect(savedIntent.expression, expression);
      expect(savedIntent.status, IntentStatus.submitted);

      // ExperienceCreationCoordinator -> production Kernel ->
      // reasoner -> blueprint -> CreationEngine -> ExperiencePackage
      // (the SAME Intent instance created above, not a new one).
      final coordinator = ExperienceCreationCoordinator(kernel: _kernel);
      final result = await coordinator.createFromIntent(intent);
      expect(
        result,
        isA<CreationCreated>(),
        reason: 'Creation must succeed through the production pipeline',
      );
      final created = result as CreationCreated;
      package = created.package;
      experienceId = created.experienceId;

      expect(package.manifest.experienceId, isNotEmpty);
      expect(package.manifest.name, isNotEmpty);
      expect(package.interface.screens, isNotEmpty);
      expect(package.data, isNotNull);

      final plotEntity = package.data!.entities
          .where((e) => e.id == 'plot')
          .firstOrNull;
      expect(
        plotEntity,
        isNotNull,
        reason:
            'Generated package must contain the Plot entity produced '
            'by the (fake) model, not a hardcoded one',
      );
      expect(plotEntity!.fields.length, 3);

      // Explicit, visible re-confirmation of package validation (the
      // coordinator already runs this internally -- CreationCreated
      // could not have been returned otherwise -- this is a second,
      // independent confirmation, not a bypass).
      final revalidation = ExperiencePackageValidator.validate(package);
      expect(revalidation.isValid, isTrue);

      // ExperienceOpeningCoordinator -> trusted first open
      final openingCoordinator = ExperienceOpeningCoordinator();
      final openResult = await openingCoordinator.openExperience(experienceId);
      expect(openResult, isA<OpenReady>());
      expect((openResult as OpenReady).experienceId, experienceId);

      // Activity: created + opened, exactly once each so far.
      final activities = await ActivityRepository().list();
      expect(
        activities
            .where((a) => a.type == 'created' && a.experienceId == experienceId)
            .length,
        1,
      );
      expect(
        activities
            .where((a) => a.type == 'opened' && a.experienceId == experienceId)
            .length,
        1,
      );

      // Real SQLite data database, at a path this test controls.
      tempDir = await Directory.systemTemp.createTemp('stage11_final_cert_');
      dbPath = p.join(tempDir.path, 'garden.db');
      databaseA = ExperienceDatabase(experienceId, customPath: dbPath);
      await databaseA.database;
      expect(
        File(dbPath).existsSync(),
        isTrue,
        reason: 'Real sqflite FFI must produce a physical database file',
      );

      // Production ExperienceDataRuntime + AnythingRuntime, real DB,
      // no cache, no subclassing of CRUD. Pre-open here (real async
      // zone, not FakeAsync) so the widget test below doesn't need to
      // perform the initial openExperience() call under FakeAsync.
      dataRuntimeA = ExperienceDataRuntime(database: databaseA);
      runtimeA = AnythingRuntime(dataRuntime: dataRuntimeA);
      await runtimeA.openExperience(package);
      expect(runtimeA.status, RuntimeStatus.running);

      // No records exist yet -- all data creation happens through
      // generated UI in the widget test below.
      final initialRecords = await dataRuntimeA.query('plot');
      expect(initialRecords, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets(
      'Generated UI: create -> detail -> edit (same record) -> second '
      'create -> search -> delete -> full restart -> reopened generated '
      'UI shows surviving edited record and not the deleted one',
      (tester) async {
        // ══════════════════════════════════════════════════════════════
        // MOUNT PRODUCTION HOST A (Runtime A injected -- caller owns it)
        // ══════════════════════════════════════════════════════════════
        await tester.pumpWidget(
          MaterialApp(
            home: ExperienceHostScreen(
              package: package,
              experienceName: package.manifest.name,
              experienceId: experienceId,
              runtime: runtimeA,
            ),
          ),
        );
        await _settleReal(tester);

        expect(
          find.byType(ExperienceHostScreen),
          findsOneWidget,
          reason: 'Must use the production ExperienceHostScreen',
        );

        // ══════════════════════════════════════════════════════════════
        // CREATE FIRST RECORD: North Bed, through generated UI
        // ══════════════════════════════════════════════════════════════
        final addButton = find.textContaining('Add');
        expect(addButton, findsWidgets, reason: 'Add button must exist');
        await tester.tap(addButton.first);
        await _settleReal(tester, rounds: 2);

        final plotNameField = find.widgetWithText(TextFormField, 'Plot Name *');
        expect(plotNameField, findsOneWidget);
        final cropField = find.widgetWithText(TextFormField, 'Crop *');
        expect(cropField, findsOneWidget);
        final notesField = find.widgetWithText(TextFormField, 'Harvest Notes');
        expect(notesField, findsOneWidget);

        await tester.enterText(plotNameField, 'North Bed');
        await tester.pump();
        await tester.enterText(cropField, 'Tomatoes');
        await tester.pump();
        await tester.enterText(notesField, 'First harvest was excellent');
        await tester.pump();

        final createButton = find.text('Create');
        expect(
          createButton,
          findsWidgets,
          reason: 'Create button must exist in create mode',
        );
        await tester.tap(createButton.first);
        await _settleReal(tester);

        expect(
          find.text('North Bed'),
          findsWidgets,
          reason: 'North Bed must appear in the generated list after save',
        );

        // Secondary evidence: real SQLite, through the production
        // DataRuntime (not a direct bypass -- this only reads what the
        // UI-driven insert above actually wrote).
        final afterFirstCreate = await dataRuntimeA.query('plot');
        expect(afterFirstCreate.length, 1);
        expect(afterFirstCreate.first['plot_name'], 'North Bed');
        final northBedId = afterFirstCreate.first['id'] as String;

        // ══════════════════════════════════════════════════════════════
        // DETAIL: tap North Bed
        // ══════════════════════════════════════════════════════════════
        await tester.tap(find.text('North Bed').first);
        await tester.pump();
        await _pumpUntilFound(tester, find.text('Edit'));

        expect(find.text('North Bed'), findsWidgets);
        expect(find.text('Tomatoes'), findsWidgets);
        expect(find.text('First harvest was excellent'), findsWidgets);
        expect(
          find.text('Edit'),
          findsWidgets,
          reason: 'Edit button must exist',
        );

        // ══════════════════════════════════════════════════════════════
        // EDIT: change harvest notes, save, verify SAME record updated
        // ══════════════════════════════════════════════════════════════
        await tester.tap(find.text('Edit').first);
        await tester.pump();
        // Wait for the async record load, not just for a TextFormField to
        // exist (the create-mode-shaped form renders immediately, empty,
        // before the real record arrives).
        await _pumpUntilFound(tester, find.text('First harvest was excellent'));

        final editNotesField = find.widgetWithText(
          TextFormField,
          'Harvest Notes',
        );
        expect(editNotesField, findsOneWidget);
        expect(
          tester.widget<TextFormField>(editNotesField).initialValue,
          'First harvest was excellent',
          reason:
              'Edit form must load the existing record before the user '
              'can edit it',
        );
        await tester.enterText(editNotesField, 'Second harvest yielded 12 kg');
        await tester.pump();

        final saveButton = find.text('Save');
        expect(
          saveButton,
          findsWidgets,
          reason: 'Save button must exist in edit mode',
        );
        await tester.tap(saveButton.first);
        await _settleReal(tester);

        final afterEdit = await dataRuntimeA.query('plot');
        expect(
          afterEdit.length,
          1,
          reason:
              'Edit must update the existing record, not insert a '
              'duplicate',
        );
        expect(afterEdit.first['id'], northBedId, reason: 'Same record ID');
        expect(
          afterEdit.first['harvest_notes'],
          'Second harvest yielded 12 kg',
        );

        // ══════════════════════════════════════════════════════════════
        // NAVIGATE BACK TO LIST via the generated bottom navigation
        // (the host has no AppBar back arrow; the "Plots List" nav
        // destination is the real, generated way back).
        // ══════════════════════════════════════════════════════════════
        final listNavItem = find.widgetWithText(
          NavigationDestination,
          'Plots List',
        );
        expect(
          listNavItem,
          findsOneWidget,
          reason:
              'Generated bottom navigation must have a Plots List '
              'destination',
        );
        await tester.tap(listNavItem);
        await _settleReal(tester);

        // ══════════════════════════════════════════════════════════════
        // CREATE SECOND RECORD: South Bed, through generated UI
        // ══════════════════════════════════════════════════════════════
        final addButton2 = find.textContaining('Add');
        expect(addButton2, findsWidgets);
        await tester.tap(addButton2.first);
        await _settleReal(tester, rounds: 2);

        final plotNameField2 = find.widgetWithText(
          TextFormField,
          'Plot Name *',
        );
        expect(plotNameField2, findsOneWidget);
        final cropField2 = find.widgetWithText(TextFormField, 'Crop *');
        expect(cropField2, findsOneWidget);
        final notesField2 = find.widgetWithText(TextFormField, 'Harvest Notes');
        expect(notesField2, findsOneWidget);

        await tester.enterText(plotNameField2, 'South Bed');
        await tester.pump();
        await tester.enterText(cropField2, 'Peppers');
        await tester.pump();
        await tester.enterText(notesField2, 'Needs more watering');
        await tester.pump();

        final createButton2 = find.text('Create');
        expect(createButton2, findsWidgets);
        await tester.tap(createButton2.first);
        await _settleReal(tester);

        expect(find.text('North Bed'), findsWidgets);
        expect(find.text('South Bed'), findsWidgets);

        final afterSecondCreate = await dataRuntimeA.query('plot');
        expect(afterSecondCreate.length, 2);
        final southBedId =
            afterSecondCreate.firstWhere(
                  (r) => r['plot_name'] == 'South Bed',
                )['id']
                as String;

        // ══════════════════════════════════════════════════════════════
        // SEARCH: real filtering, not just rendering
        // ══════════════════════════════════════════════════════════════
        final searchIcon = find.byIcon(Icons.search);
        expect(searchIcon, findsWidgets);
        final searchField = find.ancestor(
          of: searchIcon,
          matching: find.byType(TextField),
        );
        expect(searchField, findsWidgets);

        await tester.enterText(searchField.first, 'North');
        await tester.pump();
        await tester.pump();

        expect(
          find.text('North Bed'),
          findsWidgets,
          reason: 'North Bed must remain visible while searching "North"',
        );
        expect(
          find.text('South Bed'),
          findsNothing,
          reason: 'South Bed must be hidden while searching "North"',
        );

        await tester.enterText(searchField.first, '');
        await tester.pump();
        await tester.pump();

        expect(find.text('North Bed'), findsWidgets);
        expect(find.text('South Bed'), findsWidgets);

        // ══════════════════════════════════════════════════════════════
        // DELETE: South Bed
        // ══════════════════════════════════════════════════════════════
        await tester.tap(find.text('South Bed').first);
        await tester.pump();
        // Wait for the async record load. A raw, unconditional "Delete"
        // button also exists as a sibling of the entityDetail node
        // (creation_engine wires it directly to the delete action,
        // bypassing entityDetail's own record-gated, confirmation-dialog
        // Delete button), so waiting on find.text('Delete') alone would
        // be satisfied on the very first frame, before the record loads.
        await _pumpUntilFound(tester, find.text('Needs more watering'));

        expect(find.text('South Bed'), findsWidgets);
        expect(find.text('Needs more watering'), findsWidgets);
        expect(find.text('Delete'), findsWidgets);

        await tester.tap(find.text('Delete').first);
        await tester.pump();
        await tester.pump();

        final confirmTitle = find.text('Delete?');
        expect(
          confirmTitle,
          findsWidgets,
          reason: 'Delete confirmation dialog must appear',
        );
        final confirmDeleteButton = find.text('Delete');
        expect(confirmDeleteButton, findsWidgets);
        await tester.tap(confirmDeleteButton.last);
        await _settleReal(tester);

        expect(find.text('South Bed'), findsNothing);
        expect(find.text('North Bed'), findsWidgets);

        final afterDelete = await dataRuntimeA.query('plot');
        expect(afterDelete.length, 1);
        expect(afterDelete.first['id'], northBedId);
        expect(afterDelete.any((r) => r['id'] == southBedId), isFalse);

        // ══════════════════════════════════════════════════════════════
        // RESTART BOUNDARY -- destroy Runtime A / Database A entirely
        // ══════════════════════════════════════════════════════════════
        final preRestartEditedNotes = 'Second harvest yielded 12 kg';

        // Unmount production host A.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump();
        await tester.pump();

        // Close Runtime A (caller-owned, since it was injected into the
        // host rather than host-created -- matches the host's ownership
        // contract: `if (widget.runtime == null) close`) and Database A.
        // Real SQLite close operations need the real zone, same as every
        // other real-IO step above.
        await tester.runAsync(() async {
          await runtimeA.closeSession();

          // Database A explicit close. (AnythingRuntime.closeSession()
          // already awaits ExperienceDataRuntime.dispose(), which already
          // closes this same underlying ExperienceDatabase instance --
          // this call is therefore a safe, defensive, explicit
          // confirmation of that production ownership chain, not a
          // meaningful second close of a different handle.)
          await databaseA.close();
        });

        // ══════════════════════════════════════════════════════════════
        // TRUSTED REOPEN -- fresh coordinator, fresh repository handle
        // ══════════════════════════════════════════════════════════════
        late final ExperiencePackage reopenedPackage;
        await tester.runAsync(() async {
          final reopenCoordinator = ExperienceOpeningCoordinator();
          final reopenResult = await reopenCoordinator.openExperience(
            experienceId,
          );
          expect(
            reopenResult,
            isA<OpenReady>(),
            reason: 'Trusted reopen must succeed for the exact Experience ID',
          );
          reopenedPackage = (reopenResult as OpenReady).package;

          final reopenActivities = await ActivityRepository().list();
          expect(
            reopenActivities
                .where(
                  (a) => a.type == 'opened' && a.experienceId == experienceId,
                )
                .length,
            greaterThanOrEqualTo(2),
            reason: 'At least 2 opened events: initial open + restart reopen',
          );
          expect(
            reopenActivities
                .where(
                  (a) => a.type == 'created' && a.experienceId == experienceId,
                )
                .length,
            1,
            reason: 'Created activity must not be duplicated by reopening',
          );
        });

        // ══════════════════════════════════════════════════════════════
        // FRESH DATABASE B / DATA RUNTIME B / ANYTHING RUNTIME B
        // ══════════════════════════════════════════════════════════════
        late final ExperienceDatabase databaseB;
        late final ExperienceDataRuntime dataRuntimeB;
        late final AnythingRuntime runtimeB;
        await tester.runAsync(() async {
          databaseB = ExperienceDatabase(experienceId, customPath: dbPath);
          await databaseB.database;
          dataRuntimeB = ExperienceDataRuntime(database: databaseB);
          runtimeB = AnythingRuntime(dataRuntime: dataRuntimeB);
          await runtimeB.openExperience(reopenedPackage);
        });

        expect(
          identical(runtimeB, runtimeA),
          isFalse,
          reason: 'Runtime B must be a fresh instance, not Runtime A reused',
        );
        expect(
          identical(databaseB, databaseA),
          isFalse,
          reason:
              'Database B must be a fresh instance, not Database A '
              'reused',
        );

        // ══════════════════════════════════════════════════════════════
        // MOUNT FRESH PRODUCTION HOST B
        // ══════════════════════════════════════════════════════════════
        await tester.pumpWidget(
          MaterialApp(
            home: ExperienceHostScreen(
              package: reopenedPackage,
              experienceName: reopenedPackage.manifest.name,
              experienceId: experienceId,
              runtime: runtimeB,
            ),
          ),
        );
        await _settleReal(tester);

        // ══════════════════════════════════════════════════════════════
        // PRIMARY RESTART PROOF: through GENERATED UI, not SQLite
        // ══════════════════════════════════════════════════════════════
        expect(
          find.text('North Bed'),
          findsWidgets,
          reason:
              'Surviving record must be visible via generated UI after '
              'a full Runtime/Database destroy-and-recreate cycle',
        );
        expect(
          find.text('South Bed'),
          findsNothing,
          reason: 'Deleted record must remain absent after restart',
        );
        await tester.tap(find.text('North Bed').first);
        await tester.pump();
        await _pumpUntilFound(tester, find.text(preRestartEditedNotes));
        expect(
          find.text(preRestartEditedNotes),
          findsWidgets,
          reason:
              'The edit made before restart must survive and render '
              'through generated UI after restart',
        );

        // ══════════════════════════════════════════════════════════════
        // SECONDARY PROOF: real SQLite via production DataRuntime B
        // ══════════════════════════════════════════════════════════════
        late final List<Map<String, dynamic>> finalRecords;
        await tester.runAsync(() async {
          finalRecords = await dataRuntimeB.query('plot');
        });
        expect(finalRecords.length, 1);
        expect(finalRecords.first['id'], northBedId);
        expect(finalRecords.first['plot_name'], 'North Bed');
        expect(finalRecords.first['harvest_notes'], preRestartEditedNotes);
        expect(finalRecords.any((r) => r['id'] == southBedId), isFalse);

        // ══════════════════════════════════════════════════════════════
        // CLEANUP
        // ══════════════════════════════════════════════════════════════
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump();
        await tester.runAsync(() async {
          await runtimeB.closeSession();
          await databaseB.close();
          await tempDir.delete(recursive: true);
        });
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
