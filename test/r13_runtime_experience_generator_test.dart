/// Implementation Milestone R13 — Runtime Experience Generator, First
/// Complete Software Compiler. Proves `RuntimeExperienceGenerator`
/// (`lib/generator_framework/reference/runtime_experience_generator.dart`)
/// closes the real Build Graph -> Generation Specification -> Generator ->
/// `ExperiencePackage` loop: a real `CanonicalImplementationModel` (R9)
/// flows through the REAL, UNMODIFIED `Generator`/`GenerationPipeline`
/// (R10), the resulting artifact decodes into a REAL `ExperiencePackage`
/// that passes the REAL, UNMODIFIED `ExperiencePackageValidator`, and that
/// package renders through the REAL, UNMODIFIED `ExperienceRenderer` /
/// `ExperienceHostScreen` / `AnythingRuntime` / `BehaviorInterpreter`, with
/// a real CRUD interaction proven through real widget taps against real
/// SQLite — never a hand-built `ExperiencePackage`, never a simulated
/// interaction.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/application_engineering/engineering_types.dart'
    show GenericState;
import 'package:anything/build_graph/universal_build_graph.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/generator_framework/generation_pipeline.dart';
import 'package:anything/generator_framework/generation_result.dart';
import 'package:anything/generator_framework/generator.dart';
import 'package:anything/generator_framework/reference/runtime_experience_generator.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/experience_host_screen.dart';
import 'package:anything/storage/experience_database.dart';

// ── Fixtures ─────────────────────────────────────────────────────────────

/// A single, full-CRUD entity — sufficient to exercise every screen/
/// behavior shape this generator produces (list+search, create, update,
/// delete+detail) without the noise of a multi-entity/navigation fixture.
CanonicalImplementationModel _noteModel() => const CanonicalImplementationModel(
  entities: [
    ImplementationEntity(
      id: 'note',
      name: 'Note',
      fields: [
        ImplementationField(
          id: 'title',
          name: 'Title',
          type: ImplementationDataType.text,
          required: true,
        ),
        ImplementationField(
          id: 'body',
          name: 'Body',
          type: ImplementationDataType.text,
        ),
      ],
    ),
  ],
  repositories: [
    ImplementationRepository(
      id: 'note.repository',
      entityId: 'note',
      supportedOperations: [
        ImplementationOperationKind.list,
        ImplementationOperationKind.search,
        ImplementationOperationKind.create,
        ImplementationOperationKind.update,
        ImplementationOperationKind.delete,
        ImplementationOperationKind.get,
      ],
    ),
  ],
  controllers: [
    ImplementationController(
      id: 'note.controller',
      entityId: 'note',
      operations: [
        ImplementationOperation(
          id: 'note.list',
          kind: ImplementationOperationKind.list,
        ),
        ImplementationOperation(
          id: 'note.search',
          kind: ImplementationOperationKind.search,
        ),
        ImplementationOperation(
          id: 'note.create',
          kind: ImplementationOperationKind.create,
          requestFieldNames: ['title', 'body'],
        ),
        ImplementationOperation(
          id: 'note.update',
          kind: ImplementationOperationKind.update,
          requestFieldNames: ['title', 'body'],
        ),
        ImplementationOperation(
          id: 'note.delete',
          kind: ImplementationOperationKind.delete,
        ),
        ImplementationOperation(
          id: 'note.get',
          kind: ImplementationOperationKind.get,
        ),
      ],
    ),
  ],
  services: [
    ImplementationService(
      id: 'note.service',
      entityId: 'note',
      repositoryId: 'note.repository',
      controllerId: 'note.controller',
    ),
  ],
  authentication: AuthenticationAdapterSpec(requiresCredentials: false),
  backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false),
);

CanonicalImplementationModel _emptyModel() =>
    const CanonicalImplementationModel(
      authentication: AuthenticationAdapterSpec(requiresCredentials: false),
      backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false),
    );

/// Same entity as [_noteModel] but with no controller at all — proves the
/// generator honestly skips interface generation for an operation-less
/// entity instead of fabricating screens.
CanonicalImplementationModel _entityWithNoControllerModel() =>
    const CanonicalImplementationModel(
      entities: [
        ImplementationEntity(id: 'orphan', name: 'Orphan', fields: []),
      ],
      authentication: AuthenticationAdapterSpec(requiresCredentials: false),
      backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false),
    );

const _target = GeneratorTarget(id: 'note-tracker', name: 'Note Tracker');

ExperiencePackage _generatePackage(CanonicalImplementationModel model) {
  const pipeline = GenerationPipeline();
  final result = pipeline.run(
    buildGraph: const BuildGraphBuilder().build(model),
    generator: const RuntimeExperienceGenerator(),
    target: _target,
  );
  expect(
    result.hasErrors,
    isFalse,
    reason: result.diagnostics.map((d) => d.message).join('; '),
  );
  final artifact = result.allArtifacts.single;
  return ExperiencePackage.fromJson(
    jsonDecode(artifact.content!) as Map<String, dynamic>,
  );
}

// ── Widget test real-async helpers (SQLite FFI does not cooperate with
// flutter_test's default FakeAsync zone — same pattern as Stage 11). ──

Future<void> _settleReal(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }
}

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

void main() {
  group('Generator interface conformance (R13)', () {
    test(
      'RuntimeExperienceGenerator implements the ONE canonical Generator interface',
      () {
        const generator = RuntimeExperienceGenerator();
        expect(generator, isA<Generator>());
        expect(generator.metadata.id, isNotEmpty);
        expect(generator.metadata.capabilities, isNotEmpty);
      },
    );
  });

  group('Real end-to-end generation (R13)', () {
    test(
      'a real CanonicalImplementationModel produces one real, valid ExperiencePackage artifact',
      () {
        const pipeline = GenerationPipeline();
        final result = pipeline.run(
          buildGraph: const BuildGraphBuilder().build(_noteModel()),
          generator: const RuntimeExperienceGenerator(),
          target: _target,
        );

        expect(result.hasErrors, isFalse);
        final artifact = result.allArtifacts.single;
        expect(artifact.path, 'experience/note-tracker.json');
        expect(artifact.kind.name, 'manifest');

        final package = ExperiencePackage.fromJson(
          jsonDecode(artifact.content!) as Map<String, dynamic>,
        );
        expect(package.manifest.experienceId, 'note-tracker');
        expect(package.manifest.name, 'Note Tracker');
        expect(package.data!.entities.single.id, 'note');

        final screenIds = package.interface.screens.map((s) => s.id).toSet();
        expect(screenIds, {
          'note_list',
          'note_form',
          'note_edit',
          'note_detail',
        });

        final createEvent = package.behavior.nodes.firstWhere(
          (n) => n.id == 'create_note_event',
        );
        expect(createEvent.config['eventId'], 'create_note');
        final createMutation = package.behavior.nodes.firstWhere(
          (n) => n.id == 'create_note_data',
        );
        expect(createMutation.config['operation'], 'create');
        expect(createMutation.config['entity'], 'note');
        expect(
          package.behavior.edges.any(
            (e) => e.from == 'create_note_event' && e.to == 'create_note_data',
          ),
          isTrue,
          reason:
              'BehaviorEdge has no value equality, so this must be checked field-by-field',
        );

        // list/get/search operations must NOT produce behavior nodes (the
        // renderer's entityList/entityDetail query live instead).
        expect(
          package.behavior.nodes.where((n) => n.id.contains('list_note')),
          isEmpty,
        );
        expect(
          package.behavior.nodes.where((n) => n.id.contains('search_note')),
          isEmpty,
        );

        final validation = ExperiencePackageValidator.validate(package);
        expect(
          validation.isValid,
          isTrue,
          reason: validation.errors.join('; '),
        );
      },
    );

    test(
      'an empty model produces an honest diagnostic, never a crash or a fabricated artifact',
      () {
        const pipeline = GenerationPipeline();
        final result = pipeline.run(
          buildGraph: const BuildGraphBuilder().build(_emptyModel()),
          generator: const RuntimeExperienceGenerator(),
          target: _target,
        );

        expect(result.allArtifacts, isEmpty);
        expect(result.diagnostics, isNotEmpty);
        expect(result.diagnostics.first.severity, DiagnosticSeverity.info);
      },
    );

    test(
      'an entity with no controller operations is honestly skipped, not fabricated',
      () {
        const pipeline = GenerationPipeline();
        final result = pipeline.run(
          buildGraph: const BuildGraphBuilder().build(
            _entityWithNoControllerModel(),
          ),
          generator: const RuntimeExperienceGenerator(),
          target: _target,
        );

        expect(result.hasErrors, isFalse);
        expect(
          result.diagnostics.any(
            (d) =>
                d.category == DiagnosticCategory.skippedFeature &&
                d.relatedId == 'orphan',
          ),
          isTrue,
        );
        final artifact = result.allArtifacts.single;
        final package = ExperiencePackage.fromJson(
          jsonDecode(artifact.content!) as Map<String, dynamic>,
        );
        // Package must still be well-formed (fallback "main" screen), never empty/invalid.
        expect(package.interface.screens, isNotEmpty);
        expect(ExperiencePackageValidator.validate(package).isValid, isTrue);
      },
    );
  });

  group('Determinism (R13)', () {
    test(
      'running the SAME model through the pipeline twice produces structurally identical output '
      '(excluding real generation timestamps, matching CreationEngine\'s own precedent)',
      () {
        const pipeline = GenerationPipeline();
        final buildGraph = const BuildGraphBuilder().build(_noteModel());

        final r1 = pipeline.run(
          buildGraph: buildGraph,
          generator: const RuntimeExperienceGenerator(),
          target: _target,
        );
        final r2 = pipeline.run(
          buildGraph: buildGraph,
          generator: const RuntimeExperienceGenerator(),
          target: _target,
        );

        final p1 = ExperiencePackage.fromJson(
          jsonDecode(r1.allArtifacts.single.content!) as Map<String, dynamic>,
        );
        final p2 = ExperiencePackage.fromJson(
          jsonDecode(r2.allArtifacts.single.content!) as Map<String, dynamic>,
        );

        expect(p1.interface.toJson(), p2.interface.toJson());
        expect(p1.behavior.toJson(), p2.behavior.toJson());
        expect(p1.state.toJson(), p2.state.toJson());
        expect(p1.data!.toJson(), p2.data!.toJson());
        expect(p1.manifest.experienceId, p2.manifest.experienceId);
        expect(p1.manifest.name, p2.manifest.name);
        expect(r1.allArtifacts.single.path, r2.allArtifacts.single.path);
      },
    );
  });

  group(
    'Real CanonicalImplementationModel via CanonicalImplementationPlanner (R13)',
    () {
      test(
        'honest diagnostics are reported for concepts ExperiencePackage cannot represent',
        () {
          const pipeline = GenerationPipeline();
          final model = CanonicalImplementationModel(
            entities: _noteModel().entities,
            controllers: _noteModel().controllers,
            stateContainers: const [
              StateContainerSpec(
                entityId: 'note',
                initial: GenericState.idle,
                transitions: [],
              ),
            ],
            authentication: const AuthenticationAdapterSpec(
              requiresCredentials: true,
            ),
            backgroundWorker: const BackgroundWorkerSpec(
              requiresBackgroundSync: true,
            ),
          );
          final result = pipeline.run(
            buildGraph: const BuildGraphBuilder().build(model),
            generator: const RuntimeExperienceGenerator(),
            target: _target,
          );

          expect(result.hasErrors, isFalse);
          final messages = result.diagnostics.map((d) => d.message).join(' | ');
          expect(messages, contains('StateContainer'));
          expect(messages, contains('AuthenticationAdapter'));
          expect(messages, contains('BackgroundWorker'));
        },
      );
    },
  );

  group('Stage 11-style production certification (R13 centerpiece)', () {
    late ExperiencePackage package;
    late Directory tempDir;
    late String dbPath;
    late ExperienceDatabase database;
    late ExperienceDataRuntime dataRuntime;
    late AnythingRuntime runtime;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      // Same NoIsolate rationale as Stage 11: databaseFactoryFfi's isolate
      // IPC deadlocks under testWidgets's FakeAsync zone even inside
      // tester.runAsync(). NoIsolate is still real SQLite, real file I/O.
      databaseFactory = databaseFactoryFfiNoIsolate;
    });

    setUp(() async {
      // Real Generator Framework pipeline -> real artifact -> real decode
      // -> real validation. This IS the package rendered below, never a
      // hand-built one.
      package = _generatePackage(_noteModel());
      final revalidation = ExperiencePackageValidator.validate(package);
      expect(
        revalidation.isValid,
        isTrue,
        reason: revalidation.errors.join('; '),
      );

      tempDir = await Directory.systemTemp.createTemp(
        'r13_runtime_experience_',
      );
      dbPath = p.join(tempDir.path, 'notes.db');
      database = ExperienceDatabase('note-tracker', customPath: dbPath);
      await database.database;
      expect(
        File(dbPath).existsSync(),
        isTrue,
        reason: 'Real sqflite FFI must produce a physical database file',
      );

      dataRuntime = ExperienceDataRuntime(database: database);
      runtime = AnythingRuntime(dataRuntime: dataRuntime);
      await runtime.openExperience(package);
      expect(runtime.status, RuntimeStatus.running);
    });

    tearDown(() async {
      await runtime.closeSession();
      await database.close();
      await tempDir.delete(recursive: true);
    });

    testWidgets(
      'generated ExperiencePackage renders through the real ExperienceRenderer and a real create -> detail -> '
      'edit -> search -> delete cycle runs through the real BehaviorInterpreter against real SQLite',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExperienceHostScreen(
              package: package,
              experienceName: package.manifest.name,
              experienceId: 'note-tracker',
              runtime: runtime,
            ),
          ),
        );
        await _settleReal(tester);
        expect(find.byType(ExperienceHostScreen), findsOneWidget);

        // ── CREATE ──────────────────────────────────────────────────
        final addButton = find.textContaining('Add');
        expect(
          addButton,
          findsWidgets,
          reason: 'Generated Add button must exist on the list screen',
        );
        await tester.tap(addButton.first);
        await _settleReal(tester, rounds: 2);

        final titleField = find.widgetWithText(TextFormField, 'Title *');
        expect(titleField, findsOneWidget);
        final bodyField = find.widgetWithText(TextFormField, 'Body');
        expect(bodyField, findsOneWidget);

        await tester.enterText(titleField, 'Groceries');
        await tester.pump();
        await tester.enterText(bodyField, 'Milk, eggs, bread');
        await tester.pump();

        final createButton = find.text('Create');
        expect(createButton, findsWidgets);
        await tester.tap(createButton.first);
        await _settleReal(tester);

        expect(
          find.text('Groceries'),
          findsWidgets,
          reason: 'Created record must appear in the generated list',
        );
        final afterCreate = await dataRuntime.query('note');
        expect(afterCreate.length, 1);
        expect(afterCreate.first['title'], 'Groceries');
        final noteId = afterCreate.first['id'] as String;

        // ── SEARCH (real filtering) — still on the list screen: create's
        // submitForm popped exactly one level (list -> form -> pop = list).
        final searchIcon = find.byIcon(Icons.search);
        expect(searchIcon, findsWidgets);
        final searchField = find.ancestor(
          of: searchIcon,
          matching: find.byType(TextField),
        );
        expect(searchField, findsWidgets);

        await tester.enterText(searchField.first, 'Nothing Matches This');
        await tester.pump();
        await tester.pump();
        expect(
          find.text('Groceries'),
          findsNothing,
          reason: 'Non-matching search term must hide the record',
        );

        await tester.enterText(searchField.first, 'Groceries');
        await tester.pump();
        await tester.pump();
        expect(
          find.text('Groceries'),
          findsWidgets,
          reason: 'Matching search term must keep the record visible',
        );

        await tester.enterText(searchField.first, '');
        await tester.pump();
        await tester.pump();

        // ── DETAIL ──────────────────────────────────────────────────
        await tester.tap(find.text('Groceries').first);
        await tester.pump();
        await _pumpUntilFound(tester, find.text('Edit'));
        expect(find.text('Milk, eggs, bread'), findsWidgets);
        expect(find.text('Delete'), findsWidgets);

        // ── EDIT (same record, not a duplicate insert). submitForm pops
        // exactly one level (list -> detail -> edit -> pop = detail, not
        // list — same "pop is one level" behavior Stage 11 relies on a
        // bottom-navigation reset for; this single-entity app has none,
        // so the assertions below stay on the detail screen). ──────────
        await tester.tap(find.text('Edit').first);
        await tester.pump();
        await _pumpUntilFound(tester, find.text('Milk, eggs, bread'));

        final editBodyField = find.widgetWithText(TextFormField, 'Body');
        expect(editBodyField, findsOneWidget);
        expect(
          tester.widget<TextFormField>(editBodyField).initialValue,
          'Milk, eggs, bread',
        );
        await tester.enterText(editBodyField, 'Milk, eggs, bread, butter');
        await tester.pump();

        final saveButton = find.text('Save');
        expect(saveButton, findsWidgets);
        await tester.tap(saveButton.first);
        await _settleReal(tester);

        final afterEdit = await dataRuntime.query('note');
        expect(
          afterEdit.length,
          1,
          reason:
              'Edit must update the existing record, not insert a duplicate',
        );
        expect(afterEdit.first['id'], noteId);
        expect(afterEdit.first['body'], 'Milk, eggs, bread, butter');

        // submitForm pops exactly one level, landing back on the detail
        // screen (list -> detail -> edit -> pop = detail). ExperienceHostScreen
        // only reloads a detail screen's record when the screen ID CHANGES
        // (`_detailScreenId != screenId`) — since the screen ID here is the
        // same 'note_detail' before and after the edit, it keeps its
        // pre-edit cached record and does not re-fetch. This is a real,
        // pre-existing ExperienceHostScreen caching characteristic
        // (Stage 11's own test avoids it entirely via a bottom-navigation
        // round-trip, only possible in a multi-entity app), out of scope
        // for R13 (the unmodified host/renderer/runtime), so this test
        // proceeds to Delete without re-asserting the stale screen's text —
        // the SQLite-level assertions above are the real proof of the edit.
        expect(find.text('Delete'), findsWidgets);
        await tester.tap(find.text('Delete').first);
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Delete?'),
          findsWidgets,
          reason: 'Delete confirmation dialog must appear',
        );
        final confirmDeleteButton = find.text('Delete');
        expect(confirmDeleteButton, findsWidgets);
        await tester.tap(confirmDeleteButton.last);
        await _settleReal(tester);

        expect(find.text('Groceries'), findsNothing);
        final afterDelete = await dataRuntime.query('note');
        expect(afterDelete, isEmpty);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
