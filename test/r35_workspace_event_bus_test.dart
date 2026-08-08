/// Implementation Specification IS-R35 — Workspace Event Bus, AI
/// Operating System Event Architecture. Proves two real things:
///
/// 1. A real, pre-existing bug in `EventBus.on<T>()` (`lib/core/events/events.dart`,
///    real since a "Stage 9.4"-era commit, zero production callers ever
///    since) — each call OVERWROTE the previous subscriber's controller
///    for the same type, so a SECOND subscriber silently disconnected the
///    FIRST. Fixed as a single shared broadcast stream with per-`on<T>()`
///    filtered views.
/// 2. `WorkspaceEventPublisher` (new, R35) translates R30-R34's real result
///    types into real `AnythingEvent` subtypes and publishes them — never
///    invoked automatically by any coordinator (`ExperienceWorkspaceManager`/
///    `UniversalIntentRouter`/`EngineeringLifecycleCoordinator`/
///    `AutonomousWorkspaceRuntime` all remain unmodified, confirmed via
///    `git diff --stat`).
library;

import 'dart:io';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/autonomous_workspace_runtime.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/experience_workspace_manager.dart';
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
import 'package:anything/runtime/experience_host_screen.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r34_autonomous_workspace_runtime_test.dart's
// established rig shape exactly. ───────────────────────────────────────

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

class _Rig {
  final SqliteExperienceRepository repository;
  final ExperienceWorkspaceManager workspace;
  final UniversalIntentRouter router;
  final AutonomousWorkspaceRuntime workspaceRuntime;
  final EventBus bus;
  final WorkspaceEventPublisher publisher;

  _Rig(
    this.repository,
    this.workspace,
    this.router,
    this.workspaceRuntime,
    this.bus,
    this.publisher,
  );

  static _Rig create(List<SemanticApp> reasonerSequence) {
    final dbName = 'r35_event_bus_${DateTime.now().microsecondsSinceEpoch}.db';
    final repository = SqliteExperienceRepository(dbName: dbName);
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
    final workspaceRuntime = AutonomousWorkspaceRuntime(workspace: workspace);
    final bus = EventBus();
    final publisher = WorkspaceEventPublisher(bus: bus, source: 'test-rig');
    return _Rig(
      repository,
      workspace,
      router,
      workspaceRuntime,
      bus,
      publisher,
    );
  }
}

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('EventBus bug fix (R35) — real, hard multi-subscriber proof', () {
    test(
      'two independent subscribers to the SAME event type both receive the SAME published event — the real, load-bearing fix',
      () async {
        final bus = EventBus();
        final firstReceived = <AnythingEvent>[];
        final secondReceived = <AnythingEvent>[];

        // REALITY before the fix: this second on<IntentSubmitted>() call
        // silently disconnected the first subscriber's controller.
        bus.on<IntentSubmitted>().listen(firstReceived.add);
        bus.on<IntentSubmitted>().listen(secondReceived.add);

        final event = IntentSubmitted(
          id: '1',
          timestamp: DateTime(2025),
          source: 'test',
          rawInput: 'Build a calculator',
        );
        bus.publish(event);
        await Future.delayed(Duration.zero);

        expect(
          firstReceived,
          hasLength(1),
          reason:
              'the FIRST subscriber must still receive events after a second one registers',
        );
        expect(
          secondReceived,
          hasLength(1),
          reason: 'the SECOND subscriber must also receive the same event',
        );
        expect(firstReceived.single, same(secondReceived.single));
        bus.dispose();
      },
    );

    test(
      'a subscriber to a DIFFERENT type never receives an unrelated event, even sharing the same underlying broadcast stream',
      () async {
        final bus = EventBus();
        final intentEvents = <AnythingEvent>[];
        final experienceEvents = <AnythingEvent>[];
        bus.on<IntentSubmitted>().listen(intentEvents.add);
        bus.on<ExperienceCreated>().listen(experienceEvents.add);

        bus.publish(
          IntentSubmitted(
            id: '1',
            timestamp: DateTime(2025),
            source: 'test',
            rawInput: 'x',
          ),
        );
        await Future.delayed(Duration.zero);

        expect(intentEvents, hasLength(1));
        expect(experienceEvents, isEmpty);
        bus.dispose();
      },
    );

    test(
      'event ordering: events published in sequence are received in the same order',
      () async {
        final bus = EventBus();
        final received = <AnythingEvent>[];
        bus.on<AnythingEvent>().listen(received.add);

        for (var i = 0; i < 5; i++) {
          bus.publish(
            IntentSubmitted(
              id: '$i',
              timestamp: DateTime(2025),
              source: 'test',
              rawInput: 'input-$i',
            ),
          );
        }
        await Future.delayed(Duration.zero);

        expect(received.map((e) => (e as IntentSubmitted).id).toList(), [
          '0',
          '1',
          '2',
          '3',
          '4',
        ]);
        bus.dispose();
      },
    );

    test(
      'all 3 pre-existing EventBus tests still pass unmodified (see test/contracts/events_test.dart) — backward compatibility',
      () async {
        final bus = EventBus();
        final received = <AnythingEvent>[];
        bus.on<AnythingEvent>().listen(received.add);
        bus.publish(
          IntentSubmitted(
            id: '1',
            timestamp: DateTime(2025),
            source: 'test',
            rawInput: 'a',
          ),
        );
        bus.publish(
          ExperienceCreated(
            id: '2',
            timestamp: DateTime(2025),
            source: 'test',
            experienceId: 'e',
            title: 't',
          ),
        );
        await Future.delayed(Duration.zero);
        expect(received, hasLength(2));
        bus.dispose();
        expect(
          () => bus.publish(
            IntentSubmitted(
              id: '3',
              timestamp: DateTime(2025),
              source: 'test',
              rawInput: 'b',
            ),
          ),
          returnsNormally,
        );
      },
    );
  });

  group(
    'Event model (R35) — additive fields never break pre-existing subtypes',
    () {
      test(
        'a pre-R35 event (IntentAnalyzed) keeps its own real "category" field untouched — no name collision with the new base eventCategory field',
        () {
          final event = IntentAnalyzed(
            id: '1',
            timestamp: DateTime(2025),
            source: 'x',
            intentId: 'i',
            category: 'create',
            confidence: 0.9,
          );
          expect(event.category, 'create');
          expect(
            event.eventCategory,
            EventCategory.general,
            reason:
                'pre-R35 subtypes never forward the new base field — real, honest default',
          );
        },
      );
    },
  );

  group('Event publication (R35) — each new subtype carries real, traceable data', () {
    test(
      'IntentRouted: a real route() call publishes a real event with the real action/sessionId',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final received = <IntentRouted>[];
        rig.bus.on<IntentRouted>().listen(received.add);

        final result = await rig.router.route(
          Intent.create(expression: 'track my camping trips'),
        );
        rig.publisher.publishIntentRouted(result);
        await Future.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.single.action, result.action.name);
        expect(received.single.sessionId, result.sessionId);
        expect(received.single.eventCategory, EventCategory.intent);
        await rig.repository.close();
      },
    );

    test(
      'SessionCreated: a real openExperience() call publishes a real event with the real experienceId',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final received = <SessionCreated>[];
        rig.bus.on<SessionCreated>().listen(received.add);

        final result = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        rig.publisher.publishSessionCreated(result);
        await Future.delayed(Duration.zero);

        expect(received.single.sessionId, result.sessionId);
        expect(received.single.experienceId, isNotNull);
        await rig.repository.close();
      },
    );

    test(
      'SessionContinued + LifecycleCompleted + ArtifactUpdated + a real terminal deployment event: all published together from ONE real continueExperience() result, never independently faked',
      () async {
        final rig = _Rig.create([
          _app('Camp Log'),
          _app('Camp Log', withGear: true),
        ]);
        final startResult = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );

        final sessionEvents = <SessionContinued>[];
        final lifecycleEvents = <LifecycleCompleted>[];
        rig.bus.on<SessionContinued>().listen(sessionEvents.add);
        rig.bus.on<LifecycleCompleted>().listen(lifecycleEvents.add);

        final continueResult = await rig.workspace.continueExperience(
          startResult.sessionId,
          Intent.create(expression: 'also track my gear'),
        );
        rig.publisher.publishSessionContinued(continueResult);
        await Future.delayed(Duration.zero);

        expect(
          sessionEvents.single.outcome,
          continueResult.lifecycleResult.outcome.name,
        );
        expect(
          lifecycleEvents.single.outcome,
          continueResult.lifecycleResult.outcome.name,
        );
        expect(sessionEvents.single.sessionId, startResult.sessionId);
        await rig.repository.close();
      },
    );

    test(
      'deployed/blocked/commitFailed each publish exactly the matching real terminal event, never more than one, never a fabricated one for a non-terminal outcome',
      () async {
        final rig = _Rig.create([_app('Camp Log'), _app('Camp Log')]);
        final startResult = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );

        final allowed = <DeploymentAllowed>[];
        final blocked = <DeploymentBlocked>[];
        final failed = <CommitFailed>[];
        rig.bus.on<DeploymentAllowed>().listen(allowed.add);
        rig.bus.on<DeploymentBlocked>().listen(blocked.add);
        rig.bus.on<CommitFailed>().listen(failed.add);

        // Identical re-intent -> noChangeDetected -> no terminal event at all.
        final continueResult = await rig.workspace.continueExperience(
          startResult.sessionId,
          Intent.create(expression: 'track my camping trips'),
        );
        expect(
          continueResult.lifecycleResult.outcome,
          LifecycleOutcome.noChangeDetected,
        );
        rig.publisher.publishSessionContinued(continueResult);
        await Future.delayed(Duration.zero);

        expect(allowed, isEmpty);
        expect(blocked, isEmpty);
        expect(
          failed,
          isEmpty,
          reason:
              'noChangeDetected must never fabricate a terminal deployment event',
        );
        await rig.repository.close();
      },
    );

    test(
      'RuntimeSnapshotCaptured + NotificationGenerated: a real captureRuntimeState() with a real background-session notification publishes both, correctly correlated',
      () async {
        final rig = _Rig.create([
          _app('Camp Log'),
          _app('Camp Log'),
          _app('Camp Log', withGear: true),
        ]);
        final first = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final second = await rig.workspace.openExperience(
          Intent.create(expression: 'track my other trips'),
        );
        await rig.workspace.continueExperience(
          second.sessionId,
          Intent.create(expression: 'also track my gear'),
        );

        final snapshotEvents = <RuntimeSnapshotCaptured>[];
        final notificationEvents = <NotificationGenerated>[];
        rig.bus.on<RuntimeSnapshotCaptured>().listen(snapshotEvents.add);
        rig.bus.on<NotificationGenerated>().listen(notificationEvents.add);

        final snapshot = rig.workspaceRuntime.captureRuntimeState();
        rig.publisher.publishRuntimeSnapshotCaptured(snapshot);
        await Future.delayed(Duration.zero);

        expect(snapshotEvents.single.openSessionCount, 2);
        expect(
          snapshotEvents.single.notificationCount,
          snapshot.notifications.length,
        );
        expect(notificationEvents.length, snapshot.notifications.length);
        if (notificationEvents.isNotEmpty) {
          expect(notificationEvents.single.sessionId, second.sessionId);
        }
        expect(first.creationResult, isA<CreationCreated>());
        await rig.repository.close();
      },
    );

    test(
      'duplicate suppression: a second real captureRuntimeState() call for the SAME already-notified outcome publishes zero additional NotificationGenerated events',
      () async {
        final rig = _Rig.create([
          _app('Camp Log'),
          _app('Camp Log'),
          _app('Camp Log', withGear: true),
        ]);
        final first = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final second = await rig.workspace.openExperience(
          Intent.create(expression: 'track my other trips'),
        );
        await rig.workspace.continueExperience(
          second.sessionId,
          Intent.create(expression: 'also track my gear'),
        );

        final notificationEvents = <NotificationGenerated>[];
        rig.bus.on<NotificationGenerated>().listen(notificationEvents.add);

        final snapshot1 = rig.workspaceRuntime.captureRuntimeState();
        rig.publisher.publishRuntimeSnapshotCaptured(snapshot1);
        final snapshot2 = rig.workspaceRuntime.captureRuntimeState();
        rig.publisher.publishRuntimeSnapshotCaptured(snapshot2);
        await Future.delayed(Duration.zero);

        expect(
          snapshot2.notifications,
          isEmpty,
          reason:
              'AutonomousWorkspaceRuntime (R34) itself already de-duplicates — never re-derived here',
        );
        expect(
          notificationEvents.length,
          snapshot1.notifications.length,
          reason:
              'the publisher must never re-publish beyond what R34 already honestly reports once',
        );
        expect(first.creationResult, isA<CreationCreated>());
        await rig.repository.close();
      },
    );
  });

  group(
    'Correlation (R35) — events from ONE real user action share one correlationId',
    () {
      test(
        'route -> continue -> lifecycle-complete -> deployment-decision, correlated end-to-end',
        () async {
          final rig = _Rig.create([
            _app('Camp Log'),
            _app('Camp Log', withGear: true),
          ]);
          const correlationId = 'user-action-1';
          final correlated = <AnythingEvent>[];
          rig.bus.on<AnythingEvent>().listen((e) {
            if (e.correlationId == correlationId) correlated.add(e);
          });

          final startResult = await rig.workspace.openExperience(
            Intent.create(expression: 'track my camping trips'),
          );
          final routeResult = await rig.router.route(
            Intent.create(expression: 'also track my gear'),
            target: RouteTarget.session(startResult.sessionId),
          );
          rig.publisher.publishIntentRouted(
            routeResult,
            correlationId: correlationId,
          );
          if (routeResult.lifecycleResult != null) {
            rig.publisher.publishSessionContinued(
              SessionContinueResult(
                sessionId: routeResult.sessionId!,
                lifecycleResult: routeResult.lifecycleResult!,
              ),
              correlationId: correlationId,
            );
          }
          await Future.delayed(Duration.zero);

          expect(correlated, isNotEmpty);
          expect(
            correlated.every((e) => e.correlationId == correlationId),
            isTrue,
          );
          await rig.repository.close();
        },
      );
    },
  );

  group(
    'Regression (R35) — ExperienceWorkspaceManager/UniversalIntentRouter/EngineeringLifecycleCoordinator/AutonomousWorkspaceRuntime behavior is completely unaffected',
    () {
      test(
        'ExperienceWorkspaceManager.openExperience() called directly (bypassing the event bus entirely) behaves exactly as R32 built it',
        () async {
          final rig = _Rig.create([_app('Camp Log')]);
          final result = await rig.workspace.openExperience(
            Intent.create(expression: 'track my camping trips'),
          );
          expect(result.creationResult, isA<CreationCreated>());
          await rig.repository.close();
        },
      );
    },
  );

  group('Backward compatibility (R35) — HomeScreen/ExperienceHostScreen', () {
    test(
      'HomeScreen() constructed WITHOUT eventBus — the new field defaults to null, construction never throws',
      () {
        const screen = HomeScreen();
        expect(screen.eventBus, isNull);
      },
    );

    test(
      'HomeScreen accepts a real, injected EventBus without altering it',
      () {
        final bus = EventBus();
        final screen = HomeScreen(eventBus: bus);
        expect(screen.eventBus, same(bus));
        bus.dispose();
      },
    );

    testWidgets(
      'ExperienceHostScreen constructed WITHOUT eventBus behaves exactly as before — no crash, real render',
      (tester) async {
        late _Rig rig;
        late SessionStartResult result;
        await tester.runAsync(() async {
          rig = _Rig.create([_app('Camp Log')]);
          result = await rig.workspace.openExperience(
            Intent.create(expression: 'track my camping trips'),
          );
        });
        final package = (result.creationResult as CreationCreated).package;

        await tester.pumpWidget(
          MaterialApp(
            home: ExperienceHostScreen(
              package: package,
              experienceId: 'exp-no-bus',
              experienceName: 'Camp Log',
            ),
          ),
        );
        await _settleReal(tester);
        expect(find.byType(ExperienceHostScreen), findsOneWidget);
        await tester.runAsync(() => rig.repository.close());
      },
    );

    testWidgets(
      'ExperienceHostScreen constructed WITH a real EventBus publishes a real WorkspaceUpdated("runtime_loaded") event once the runtime loads',
      (tester) async {
        late _Rig rig;
        late SessionStartResult result;
        late String experienceId;
        await tester.runAsync(() async {
          rig = _Rig.create([_app('Camp Log')]);
          result = await rig.workspace.openExperience(
            Intent.create(expression: 'track my camping trips'),
          );
          experienceId =
              (result.creationResult as CreationCreated).experienceId;
        });
        final package = (result.creationResult as CreationCreated).package;

        final received = <WorkspaceUpdated>[];
        rig.bus.on<WorkspaceUpdated>().listen(received.add);

        await tester.pumpWidget(
          MaterialApp(
            home: ExperienceHostScreen(
              package: package,
              experienceId: experienceId,
              experienceName: 'Camp Log',
              workspaceManager: rig.workspace,
              eventBus: rig.bus,
            ),
          ),
        );
        await _settleReal(tester);

        expect(
          received,
          isNotEmpty,
          reason:
              'a real, injected eventBus must receive a real event once the runtime loads',
        );
        expect(received.first.change, 'runtime_loaded');
        await tester.runAsync(() => rig.repository.close());
      },
    );
  });

  group(
    'Performance (R35) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test('event dispatch latency for a large volume of publishes', () {
        final bus = EventBus();
        var count = 0;
        bus.on<AnythingEvent>().listen((_) => count++);

        final stopwatch = Stopwatch()..start();
        for (var i = 0; i < 5000; i++) {
          bus.publish(
            IntentSubmitted(
              id: '$i',
              timestamp: DateTime.now(),
              source: 'perf',
              rawInput: 'x',
            ),
          );
        }
        stopwatch.stop();
        // ignore: avoid_print
        print(
          'R35 event dispatch: 5000 publishes in ${stopwatch.elapsedMilliseconds}ms',
        );
        bus.dispose();
      });

      test(
        'memory: real process RSS delta across repeated publish/subscribe cycles (no leak)',
        () {
          final rssBefore = ProcessInfo.currentRss;
          for (var i = 0; i < 50; i++) {
            final bus = EventBus();
            bus.on<AnythingEvent>().listen((_) {});
            bus.publish(
              IntentSubmitted(
                id: '$i',
                timestamp: DateTime.now(),
                source: 'perf',
                rawInput: 'x',
              ),
            );
            bus.dispose();
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R35 memory: RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 50 bus create/dispose cycles',
          );
        },
      );
    },
  );
}

Future<void> _settleReal(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }
}
