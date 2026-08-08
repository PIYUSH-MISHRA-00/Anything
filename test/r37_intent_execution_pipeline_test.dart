/// Implementation Specification IS-R37 — Intent Execution Pipeline, AI
/// Operating System Execution Path.
///
/// REALITY before R37 (confirmed by reading source): `HomeScreen
/// ._createExperience()` (`lib/features/home/home_screen.dart`) called
/// `ExperienceCreationCoordinator.createFromIntent()` directly — the ONE
/// real, live production intent-entry point in the whole app, bypassing
/// `UniversalIntentRouter` (R33) entirely. Every session it created was
/// never registered in `ExperienceWorkspaceManager` (R32), despite
/// R32-R36 wiring `workspaceManager`/`intentRouter`/`workspaceRuntime`/
/// `eventBus` as optional `HomeScreen` fields (all accept-and-store-only
/// until now).
///
/// This file proves, with real objects (never mocks of the subsystems
/// under test): `IntentExecutionPipeline.execute()` reaches
/// `ExperienceCreationCoordinator`/`EngineeringLifecycleCoordinator` via
/// the SAME real `UniversalIntentRouter` dispatch R33 already built,
/// registers sessions in the real `ExperienceWorkspaceManager` (the real
/// bug fix over today's bypass), publishes a real `IntentRouted` event,
/// and that `HomeScreen`'s real, live `_createExperience()` flow — not
/// just the pipeline in isolation — now goes through it too.
library;

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/experience_workspace_manager.dart';
import 'package:anything/app/intent_execution_pipeline.dart';
import 'package:anything/app/intent_session_manager.dart';
import 'package:anything/app/universal_intent_router.dart';
import 'package:anything/app/workspace_event_publisher.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/core/events/events.dart';
import 'package:anything/features/home/home_screen.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r36_operating_system_composition_test.dart's
// established rig shape exactly, restricted to the R31-R37 chain this file
// needs. ─────────────────────────────────────────────────────────────────

SemanticApp _app(String name, {bool withGear = false}) => SemanticApp(
  name: name,
  purpose: 'Track $name',
  entities: [
    SemanticEntity(
      id: 'trip',
      name: 'Trip',
      displayField: 'title',
      fields: const [
        SemanticField(
          id: 'title',
          name: 'Title',
          type: BlueprintFieldType.text,
          required: true,
        ),
      ],
    ),
    if (withGear)
      const SemanticEntity(
        id: 'gear',
        name: 'Gear',
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
  requiredCapabilities: const ['storage'],
);

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

class _SequencedReasoner implements ApplicationReasoner {
  final List<SemanticApp> apps;
  int _calls = 0;
  _SequencedReasoner(this.apps);

  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    final app = apps[_calls < apps.length ? _calls : apps.length - 1];
    _calls++;
    return ReasoningReady(semanticApp: app);
  }
}

/// A full, real R31-R37 service chain, mirroring `AppComposition
/// .production()`'s exact real dependency order, with test doubles ONLY
/// for the pieces that would otherwise touch real AI provider network I/O.
class _Rig {
  final SqliteExperienceRepository repository;
  final EngineeringMemoryRepository engineeringMemory;
  final ExperienceCreationCoordinator creationCoordinator;
  final EngineeringLifecycleCoordinator lifecycleCoordinator;
  final IntentSessionManager sessionManager;
  final ExperienceWorkspaceManager workspace;
  final UniversalIntentRouter router;
  final EventBus bus;
  final WorkspaceEventPublisher publisher;
  final IntentExecutionPipeline pipeline;

  _Rig({
    required this.repository,
    required this.engineeringMemory,
    required this.creationCoordinator,
    required this.lifecycleCoordinator,
    required this.sessionManager,
    required this.workspace,
    required this.router,
    required this.bus,
    required this.publisher,
    required this.pipeline,
  });

  static _Rig create(List<SemanticApp> reasonerSequence, {String? dbName}) {
    final name =
        dbName ?? 'r37_pipeline_${DateTime.now().microsecondsSinceEpoch}.db';
    final repository = SqliteExperienceRepository(dbName: name);
    final engineeringMemory = EngineeringMemoryRepository(
      experienceRepository: repository,
    );
    final activity = ActivityRepository();
    final reasoner = _SequencedReasoner(reasonerSequence);
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: reasoner,
    );

    final creationCoordinator = ExperienceCreationCoordinator(
      kernel: kernel,
      repository: repository,
      engineeringMemory: engineeringMemory,
    );
    final lifecycleCoordinator = EngineeringLifecycleCoordinator(
      kernel: kernel,
      engineeringMemory: engineeringMemory,
      repository: repository,
    );
    final sessionManager = IntentSessionManager(
      creationCoordinator: creationCoordinator,
      lifecycleCoordinator: lifecycleCoordinator,
      engineeringMemory: engineeringMemory,
      activity: activity,
    );
    final workspace = ExperienceWorkspaceManager(
      sessionManager: sessionManager,
      activity: activity,
    );
    final router = UniversalIntentRouter(workspace: workspace);
    final bus = EventBus();
    final publisher = WorkspaceEventPublisher(bus: bus, source: 'test-rig');
    final pipeline = IntentExecutionPipeline(
      router: router,
      eventPublisher: publisher,
    );

    return _Rig(
      repository: repository,
      engineeringMemory: engineeringMemory,
      creationCoordinator: creationCoordinator,
      lifecycleCoordinator: lifecycleCoordinator,
      sessionManager: sessionManager,
      workspace: workspace,
      router: router,
      bus: bus,
      publisher: publisher,
      pipeline: pipeline,
    );
  }
}

/// The real production database file — see
/// `test/r36_operating_system_composition_test.dart`'s own doc comment for
/// why this file's seeding test uses `touchLastUsed` instead of resetting
/// the file (a leaked `HomeScreen`-internal repository connection from an
/// earlier test in this same file can hold it open).
const _defaultDbName = 'anything_experiences.db';

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Creation routing (R37)', () {
    test(
      'pipeline.execute(intent, target: RouteTarget.newExperience()) reaches ExperienceCreationCoordinator.createFromIntent() AND registers the session in the real ExperienceWorkspaceManager',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);

        final result = await rig.pipeline.execute(
          Intent.create(expression: 'track my camping trips'),
          target: const RouteTarget.newExperience(),
        );

        // A REAL AnythingKernel with no provider would return
        // CreationProviderRequired — this rig's injected FAKE reasoner always
        // succeeds, so reaching CreationCreated here is itself the proof the
        // real coordinator chain (not a stub) actually ran.
        expect(result.action, RoutingAction.newExperience);
        expect(result.creationResult, isA<CreationCreated>());
        expect(result.sessionId, isNotNull);

        // The real regression fix over today's HomeScreen bypass: the session
        // is genuinely open in the workspace, never true of the pre-R37
        // direct-coordinator call.
        expect(rig.workspace.openSessionIds, contains(result.sessionId));

        await rig.repository.close();
      },
    );
  });

  group('Modification routing (R37)', () {
    test(
      'pipeline.execute(intent, target: RouteTarget.session(...)) against an already-open session reaches EngineeringLifecycleCoordinator.evolveExperience() via modifyActiveExperience',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);

        final opened = await rig.pipeline.execute(
          Intent.create(expression: 'track my camping trips'),
          target: const RouteTarget.newExperience(),
        );
        expect(opened.creationResult, isA<CreationCreated>());

        final modified = await rig.pipeline.execute(
          Intent.create(expression: 'add a field'),
          target: RouteTarget.session(opened.sessionId),
        );

        expect(modified.action, RoutingAction.modifyActiveExperience);
        expect(modified.lifecycleResult, isA<LifecycleResult>());
        // A real, non-`noEngineeringMemory` outcome proves a genuine "before"
        // state was loaded and EngineeringLifecycleCoordinator actually ran a
        // fresh Kernel pass — never a fabricated/stubbed result (same real
        // check test/r33_universal_intent_router_test.dart's own "Session
        // continuation" group makes).
        expect(
          modified.lifecycleResult!.outcome,
          isNot(LifecycleOutcome.noEngineeringMemory),
        );

        await rig.repository.close();
      },
    );
  });

  group('Continuation routing (R37)', () {
    test(
      'pipeline.execute(intent, target: RouteTarget.experience(...)) naming a real, OPEN-but-NOT-active session reaches EngineeringLifecycleCoordinator via resumeBackgroundSession, real switch first',
      () async {
        final rig = _Rig.create([_app('Camp Log'), _app('Book Club')]);

        final first = await rig.pipeline.execute(
          Intent.create(expression: 'track my camping trips'),
          target: const RouteTarget.newExperience(),
        );
        final second = await rig.pipeline.execute(
          Intent.create(expression: 'track my book club'),
          target: const RouteTarget.newExperience(),
        );
        // REALITY: ExperienceWorkspaceManager.openExperience() uses
        // `_activeSessionId ??= result.sessionId` (real, unmodified R32 code)
        // — opening a second experience never steals active focus from the
        // first. `first` stays active; make `second` active via a real,
        // explicit switch so `first` genuinely becomes the background session
        // this test resumes (mirrors test/r33_universal_intent_router_test.dart's
        // own "Resume background session" group exactly).
        expect(rig.workspace.activeSessionId, first.sessionId);
        await rig.workspace.switchActiveExperience(second.sessionId!);

        final firstExperienceId =
            (first.creationResult as CreationCreated).experienceId;
        final resumed = await rig.pipeline.execute(
          Intent.create(expression: 'add a field'),
          target: RouteTarget.experience(firstExperienceId),
        );

        expect(resumed.action, RoutingAction.resumeBackgroundSession);
        expect(resumed.sessionId, first.sessionId);
        expect(
          rig.workspace.activeSessionId,
          first.sessionId,
          reason:
              'a real switchActiveExperience() must have run before continueExperience()',
        );
        expect(resumed.lifecycleResult, isA<LifecycleResult>());
        expect(
          resumed.lifecycleResult!.outcome,
          isNot(LifecycleOutcome.noEngineeringMemory),
        );

        await rig.repository.close();
      },
    );
  });

  group('Pipeline execution (R37) — real event publication', () {
    test(
      'a real IntentRouted event is published to the real EventBus for a call through the pipeline',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);

        final received = <IntentRouted>[];
        rig.bus.on<IntentRouted>().listen(received.add);

        final result = await rig.pipeline.execute(
          Intent.create(expression: 'track my camping trips'),
          target: const RouteTarget.newExperience(),
        );
        await Future.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.single.sessionId, result.sessionId);
        expect(received.single.action, result.action.name);

        await rig.repository.close();
      },
    );

    test(
      'correlationId is forwarded unmodified from execute() to the published event',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final received = <IntentRouted>[];
        rig.bus.on<IntentRouted>().listen(received.add);

        await rig.pipeline.execute(
          Intent.create(expression: 'track my camping trips'),
          target: const RouteTarget.newExperience(),
          correlationId: 'corr-1',
        );
        await Future.delayed(Duration.zero);

        expect(received.single.correlationId, 'corr-1');
        await rig.repository.close();
      },
    );
  });

  group('UI decoupling (R37) — HomeScreen no longer bypasses the router', () {
    testWidgets(
      'HomeScreen real, live _createExperience() flow, pumped with an injected pipeline/workspaceManager, registers the resulting session in workspaceManager.openSessionIds',
      (tester) async {
        final rig = _Rig.create([_app('Calculator')], dbName: _defaultDbName);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                pipeline: rig.pipeline,
                workspaceManager: rig.workspace,
              ),
            ),
          ),
        );
        await tester.pump();

        // Real UI affordance ("Try asking for -> Calculator" chip) instead of
        // driving TextField submission mechanics — calls the SAME real
        // `_createExperience()` the text field's `onSubmitted` also reaches.
        await tester.tap(find.text('Calculator'));
        await tester.pump();

        // Real Kernel work is in flight (BirthSequence showing) — drain it via
        // runAsync, same polling-pump pattern test/r36_operating_system_composition_test.dart
        // already uses for its own async Sqlite-backed widget test.
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();
        }

        expect(
          rig.workspace.openSessionIds,
          isNotEmpty,
          reason:
              'the LIVE HomeScreen._createExperience() flow must now register its session in the workspace — the real, load-bearing proof this milestone exists for',
        );

        await rig.repository.close();
      },
    );
  });

  group(
    'Regression (R37) — UniversalIntentRouter/ExperienceWorkspaceManager/IntentSessionManager/EngineeringLifecycleCoordinator/EventBus/WorkspaceEventPublisher behavior is completely unaffected by the pipeline',
    () {
      test(
        'UniversalIntentRouter.route() called directly (bypassing the pipeline entirely) still behaves exactly as R33 built it',
        () async {
          final rig = _Rig.create([_app('Camp Log')]);
          final result = await rig.router.route(
            Intent.create(expression: 'track my camping trips'),
            target: const RouteTarget.newExperience(),
          );
          expect(result.creationResult, isA<CreationCreated>());
          expect(rig.workspace.openSessionIds, contains(result.sessionId));
          await rig.repository.close();
        },
      );

      test(
        'ExperienceWorkspaceManager.openExperience() called directly (bypassing the router/pipeline entirely) still behaves exactly as R32 built it',
        () async {
          final rig = _Rig.create([_app('Camp Log')]);
          final result = await rig.workspace.openExperience(
            Intent.create(expression: 'track my camping trips'),
          );
          expect(result.creationResult, isA<CreationCreated>());
          await rig.repository.close();
        },
      );

      test(
        'EngineeringLifecycleCoordinator.evolveExperience() called directly still returns noEngineeringMemory honestly for an experience it never saw create — unaffected by R37',
        () async {
          final rig = _Rig.create([_app('Camp Log')]);
          final lifecycleResult = await rig.lifecycleCoordinator
              .evolveExperience(
                experienceId: 'never-created',
                intent: Intent.create(expression: 'add a field'),
              );
          expect(lifecycleResult.outcome, LifecycleOutcome.noEngineeringMemory);
          await rig.repository.close();
        },
      );
    },
  );

  group('Backward compatibility (R37) — HomeScreen', () {
    test(
      'HomeScreen() constructed WITHOUT any of the 6 optional fields — every field defaults to null, construction never throws (constructor byte-for-byte unchanged elsewhere)',
      () {
        const screen = HomeScreen();
        expect(screen.composition, isNull);
        expect(screen.workspaceManager, isNull);
        expect(screen.intentRouter, isNull);
        expect(screen.workspaceRuntime, isNull);
        expect(screen.eventBus, isNull);
        expect(screen.pipeline, isNull);
      },
    );

    testWidgets(
      'a bare HomeScreen() pumped with no injected pipeline renders without throwing — now sourcing its IntentExecutionPipeline from AppComposition.production()',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomeScreen())),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Performance (R37) — real Stopwatch measurements, never fabricated', () {
    test('pipeline.execute() routing/pipeline latency', () async {
      final rig = _Rig.create([_app('Camp Log')]);
      final stopwatch = Stopwatch()..start();
      await rig.pipeline.execute(
        Intent.create(expression: 'track my camping trips'),
        target: const RouteTarget.newExperience(),
      );
      stopwatch.stop();
      // ignore: avoid_print
      print(
        'R37 pipeline.execute() (new experience): ${stopwatch.elapsedMicroseconds}us',
      );
      await rig.repository.close();
    });

    test(
      'startup impact: AppComposition.production() construction latency with the new IntentExecutionPipeline field',
      () async {
        // Uses the real production composition root directly, matching
        // test/r36_operating_system_composition_test.dart's own established
        // "AppComposition.production() itself" exception — safe and honest
        // because no AI provider is ever configured in this test's
        // CredentialVault (see that file's own doc comment for the full
        // reasoning).
        final stopwatch = Stopwatch()..start();
        final composition = AppComposition.production();
        stopwatch.stop();
        // ignore: avoid_print
        print(
          'R37 AppComposition.production() construction: ${stopwatch.elapsedMicroseconds}us',
        );
        expect(
          composition.intentExecutionPipeline,
          isA<IntentExecutionPipeline>(),
        );
        await composition.experienceRepository.close();
      },
    );
  });
}
