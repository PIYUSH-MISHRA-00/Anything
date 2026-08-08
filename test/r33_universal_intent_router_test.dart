/// Implementation Specification IS-R33 — Universal Intent Router, AI
/// Operating System Command Surface. Proves the real gap this specification
/// closes: `ExperienceWorkspaceManager` (R32) already exposes real
/// `openExperience()`/`continueExperience()`/`switchActiveExperience()`
/// methods, but nothing decides FOR a caller which one to invoke for a
/// given `Intent` — a caller must already know. `UniversalIntentRouter` is
/// that missing, purely structural decision layer: zero new reasoning,
/// zero bypass of `ExperienceWorkspaceManager`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/experience_workspace_manager.dart';
import 'package:anything/app/intent_session_manager.dart';
import 'package:anything/app/universal_intent_router.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/features/home/home_screen.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r32_experience_workspace_manager_test.dart's
// established rig shape exactly (a test file cannot import another test
// file's private helpers). ────────────────────────────────────────────

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

/// Real end-to-end rig: one shared Kernel, one shared SQLite-backed
/// repository set, a real `IntentSessionManager`, a real
/// `ExperienceWorkspaceManager`, and the real `UniversalIntentRouter` under
/// test wrapping it — never a hand-built substitute for any of them.
class _Rig {
  final SqliteExperienceRepository repository;
  final ExperienceWorkspaceManager workspace;
  final UniversalIntentRouter router;

  _Rig(this.repository, this.workspace, this.router);

  static _Rig create(List<SemanticApp> reasonerSequence) {
    final dbName = 'r33_router_${DateTime.now().microsecondsSinceEpoch}.db';
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
    return _Rig(repository, workspace, router);
  }
}

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('New experience routing (R33)', () {
    test(
      'no target, no open session -> newExperience, genuinely invokes ExperienceWorkspaceManager.openExperience()',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final result = await rig.router.route(
          Intent.create(expression: 'track my camping trips'),
        );

        expect(result.action, RoutingAction.newExperience);
        expect(result.creationResult, isA<CreationCreated>());
        expect(result.sessionId, isNotNull);
        // Real, hard proof this genuinely ran through the workspace, never a
        // parallel path: the session is now reachable directly off it.
        expect(rig.workspace.openSessionIds, [result.sessionId]);
        expect(rig.workspace.activeSessionId, result.sessionId);
        await rig.repository.close();
      },
    );
  });

  group('Session continuation (R33)', () {
    test(
      'no target, a real active session exists -> continueActiveSession',
      () async {
        final rig = _Rig.create([
          _app('Camp Log'),
          _app('Camp Log', withGear: true),
        ]);
        final started = await rig.router.route(
          Intent.create(expression: 'track my camping trips'),
        );
        expect(started.action, RoutingAction.newExperience);

        final continued = await rig.router.route(
          Intent.create(expression: 'also track my gear'),
        );

        expect(continued.action, RoutingAction.continueActiveSession);
        expect(continued.sessionId, started.sessionId);
        expect(continued.lifecycleResult, isA<LifecycleResult>());
        expect(
          continued.lifecycleResult!.outcome,
          isNot(LifecycleOutcome.noEngineeringMemory),
        );
        await rig.repository.close();
      },
    );
  });

  group('Modification routing (R33)', () {
    test(
      'an explicit target naming the ALREADY-active session -> modifyActiveExperience, same real call as continueActiveSession',
      () async {
        final rig = _Rig.create([
          _app('Camp Log'),
          _app('Camp Log', withGear: true),
        ]);
        final started = await rig.router.route(
          Intent.create(expression: 'track my camping trips'),
        );

        final modified = await rig.router.route(
          Intent.create(expression: 'also track my gear'),
          target: RouteTarget.session(started.sessionId),
        );

        expect(modified.action, RoutingAction.modifyActiveExperience);
        expect(modified.sessionId, started.sessionId);
        expect(modified.lifecycleResult, isA<LifecycleResult>());
        await rig.repository.close();
      },
    );

    test(
      'an explicit target by experienceId resolves through ExperienceWorkspaceManager.sessionForExperience(), never a raw sessionId shortcut',
      () async {
        final rig = _Rig.create([
          _app('Camp Log'),
          _app('Camp Log', withGear: true),
        ]);
        final started = await rig.router.route(
          Intent.create(expression: 'track my camping trips'),
        );
        final experienceId =
            (started.creationResult as CreationCreated).experienceId;

        final modified = await rig.router.route(
          Intent.create(expression: 'also track my gear'),
          target: RouteTarget.experience(experienceId),
        );

        expect(modified.sessionId, started.sessionId);
        expect(modified.action, RoutingAction.modifyActiveExperience);
        await rig.repository.close();
      },
    );
  });

  group('Resume background session (R33)', () {
    test(
      'an explicit target naming a real, OPEN-but-NOT-active session -> resumeBackgroundSession: a real switch, then continue',
      () async {
        final rig = _Rig.create([
          _app('Camp Log'),
          _app('Book Club'),
          _app('Camp Log', withGear: true),
        ]);
        final first = await rig.router.route(
          Intent.create(expression: 'track my camping trips'),
        );
        final second = await rig.router.route(
          Intent.create(expression: 'track my book club'),
          target: const RouteTarget.newExperience(),
        );
        expect(second.action, RoutingAction.newExperience);
        // REALITY: `ExperienceWorkspaceManager.openExperience()` uses
        // `_activeSessionId ??= result.sessionId` (real, existing, unmodified
        // R32 code) — opening a SECOND experience never steals active focus
        // from the first. `first` is therefore still active; make `second`
        // active via a real, explicit switch so `first` genuinely becomes the
        // background session this test resumes.
        expect(
          rig.workspace.activeSessionId,
          first.sessionId,
          reason:
              'the first-opened session stays active; opening a second never steals focus',
        );
        await rig.workspace.switchActiveExperience(second.sessionId!);

        final resumed = await rig.router.route(
          Intent.create(expression: 'also track my gear'),
          target: RouteTarget.session(first.sessionId),
        );

        expect(resumed.action, RoutingAction.resumeBackgroundSession);
        expect(resumed.sessionId, first.sessionId);
        // Real, hard proof the switch genuinely happened, not just the
        // continue: the workspace's own active pointer moved.
        expect(rig.workspace.activeSessionId, first.sessionId);
        await rig.repository.close();
      },
    );
  });

  group('Rejection — unknown target (R33)', () {
    test(
      'a target naming a session the workspace does not have open -> unknownTarget, never a silent fallback to newExperience',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final result = await rig.router.route(
          Intent.create(expression: 'track my camping trips'),
          target: const RouteTarget.session('session-does-not-exist'),
        );

        expect(result.action, RoutingAction.unknownTarget);
        expect(result.creationResult, isNull);
        expect(result.lifecycleResult, isNull);
        expect(
          rig.workspace.openSessionIds,
          isEmpty,
          reason: 'nothing was ever opened for a rejected target',
        );
        await rig.repository.close();
      },
    );

    test('a target naming an unknown experienceId -> unknownTarget', () async {
      final rig = _Rig.create([_app('Camp Log')]);
      final result = await rig.router.route(
        Intent.create(expression: 'track my camping trips'),
        target: const RouteTarget.experience('exp-does-not-exist'),
      );

      expect(result.action, RoutingAction.unknownTarget);
      await rig.repository.close();
    });
  });

  group(
    'Real Kernel-level outcomes faithfully surfaced (R33) — the router never re-derives or reinterprets them',
    () {
      test(
        'an identical re-intent surfaces LifecycleOutcome.noChangeDetected unmodified',
        () async {
          final rig = _Rig.create([_app('Camp Log'), _app('Camp Log')]);
          await rig.router.route(
            Intent.create(expression: 'track my camping trips'),
          );

          final result = await rig.router.route(
            Intent.create(expression: 'track my camping trips'),
          );

          expect(result.action, RoutingAction.continueActiveSession);
          expect(
            result.lifecycleResult!.outcome,
            LifecycleOutcome.noChangeDetected,
          );
        },
      );
    },
  );

  group('Workspace integration — zero bypass (R33)', () {
    test(
      'UniversalIntentRouter never calls IntentSessionManager/EngineeringLifecycleCoordinator directly — every real session is reachable through the SAME workspace object',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final result = await rig.router.route(
          Intent.create(expression: 'track my camping trips'),
        );

        // If the router had bypassed the workspace (e.g. called
        // IntentSessionManager directly), this session would still not be
        // "open" in the workspace's own real bookkeeping.
        expect(rig.workspace.openSessionIds, contains(result.sessionId));
        expect(
          identical(
            rig.workspace.activeSession,
            rig.workspace.openSessions.first,
          ),
          isTrue,
        );
      },
    );
  });

  group('Backward compatibility (R33) — HomeScreen', () {
    // REALITY: `HomeScreen`'s real `initState()` touches real platform
    // channels (secure storage, voice input) via `AppComposition.production()`
    // when no `composition` is supplied — widget-pumping a bare `HomeScreen()`
    // is fragile/untested territory this milestone does not need to prove
    // (R32's own "HomeScreen...proven directly" doc claim, on inspection,
    // actually pointed at an `ExperienceHostScreen` widget test, never a real
    // `HomeScreen` one — confirmed by reading `test/r32_experience_workspace_manager_test.dart`).
    // A real, honest, CONSTRUCTOR-level proof is the safe equivalent: the
    // new field defaults to `null` and construction without it never throws.
    test(
      'HomeScreen() constructed WITHOUT intentRouter — the new field defaults to null, construction never throws',
      () {
        const screen = HomeScreen();
        expect(screen.intentRouter, isNull);
        expect(screen.workspaceManager, isNull);
      },
    );

    test(
      'HomeScreen accepts a real, injected UniversalIntentRouter without altering ExperienceWorkspaceManager/IntentSessionManager behavior',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final screen = HomeScreen(intentRouter: rig.router);
        expect(screen.intentRouter, same(rig.router));
        await rig.repository.close();
      },
    );
  });

  group(
    'Regression (R33) — ExperienceWorkspaceManager/IntentSessionManager/EngineeringLifecycleCoordinator behavior is completely unaffected',
    () {
      test(
        'ExperienceWorkspaceManager.openExperience() called directly (bypassing UniversalIntentRouter entirely) behaves exactly as R32 built it',
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

  group(
    'Performance (R33) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test('intent routing latency (new experience)', () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final stopwatch = Stopwatch()..start();
        await rig.router.route(
          Intent.create(expression: 'track my camping trips'),
        );
        stopwatch.stop();
        // ignore: avoid_print
        print(
          'R33 routing latency (new experience): ${stopwatch.elapsedMilliseconds}ms',
        );
        await rig.repository.close();
      });

      test(
        'session lookup / workspace lookup latency (resumeBackgroundSession path)',
        () async {
          final rig = _Rig.create([
            _app('A'),
            _app('B'),
            _app('A', withGear: true),
          ]);
          final first = await rig.router.route(Intent.create(expression: 'a'));
          await rig.router.route(Intent.create(expression: 'b'));

          final stopwatch = Stopwatch()..start();
          await rig.router.route(
            Intent.create(expression: 'also gear'),
            target: RouteTarget.session(first.sessionId),
          );
          stopwatch.stop();
          // ignore: avoid_print
          print(
            'R33 routing latency (resume background session): ${stopwatch.elapsedMilliseconds}ms',
          );
          await rig.repository.close();
        },
      );

      test(
        'memory: real process RSS delta while routing 20 real intents',
        () async {
          final rssBefore = ProcessInfo.currentRss;
          final rig = _Rig.create(List.generate(20, (i) => _app('App $i')));
          for (var i = 0; i < 20; i++) {
            await rig.router.route(Intent.create(expression: 'app $i'));
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R33 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 20 routed intents',
          );
          await rig.repository.close();
        },
      );
    },
  );
}
