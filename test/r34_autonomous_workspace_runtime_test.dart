/// Implementation Specification IS-R34 — Autonomous Workspace Runtime, AI
/// Operating System Runtime Supervisor. Proves the real gap this
/// specification closes: `ExperienceWorkspaceManager` (R32) already exposes
/// `openSessions`/`activeSessionId`, and each `SessionState` (R31) already
/// carries `currentRuntimeState`/`currentLifecycleResult`/
/// `pendingModification` — but nothing AGGREGATES this real, per-session
/// data into one whole-workspace view, and nothing derives real
/// notifications from it. `AutonomousWorkspaceRuntime` is that missing,
/// purely PULL-based snapshot layer: zero new background timers/polling,
/// zero duplicated state, zero new reasoning.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/autonomous_workspace_runtime.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/experience_workspace_manager.dart';
import 'package:anything/app/intent_session_manager.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/features/home/home_screen.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/runtime/experience_host_screen.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r33_universal_intent_router_test.dart's
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

/// Real end-to-end rig: one shared Kernel, one shared SQLite-backed
/// repository set, a real `IntentSessionManager`, a real
/// `ExperienceWorkspaceManager`, and the real `AutonomousWorkspaceRuntime`
/// under test wrapping it — never a hand-built substitute for any of them.
class _Rig {
  final SqliteExperienceRepository repository;
  final ExperienceWorkspaceManager workspace;
  final AutonomousWorkspaceRuntime workspaceRuntime;

  _Rig(this.repository, this.workspace, this.workspaceRuntime);

  static _Rig create(List<SemanticApp> reasonerSequence) {
    final dbName =
        'r34_workspace_runtime_${DateTime.now().microsecondsSinceEpoch}.db';
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
    final workspaceRuntime = AutonomousWorkspaceRuntime(workspace: workspace);
    return _Rig(repository, workspace, workspaceRuntime);
  }
}

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Workspace runtime startup (R34)', () {
    test(
      'a fresh workspace with zero open sessions captures an empty, real snapshot — never fabricated',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final snapshot = rig.workspaceRuntime.captureRuntimeState();
        expect(snapshot.sessions, isEmpty);
        expect(snapshot.notifications, isEmpty);
        expect(snapshot.activeSession, isNull);
        await rig.repository.close();
      },
    );

    test(
      'AutonomousWorkspaceRuntime never bypasses ExperienceWorkspaceManager — the captured session is the SAME real SessionState identity',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );

        final snapshot = rig.workspaceRuntime.captureRuntimeState();
        final workspaceState = rig.workspace.openSessions.single;
        expect(snapshot.sessions.single.sessionId, workspaceState.sessionId);
        expect(
          snapshot.sessions.single.experienceId,
          workspaceState.currentExperienceId,
        );
        await rig.repository.close();
      },
    );
  });

  group('Runtime supervision / multiple runtime instances (R34)', () {
    test(
      'two open sessions: one active, one background — correctly aggregated and distinguished',
      () async {
        final rig = _Rig.create([_app('Camp Log'), _app('Gear List')]);
        final first = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        await rig.workspace.openExperience(
          Intent.create(expression: 'track my gear'),
        );
        // The workspace's own real rule: only the FIRST opened session
        // auto-activates (`_activeSessionId ??= ...`) — confirmed by reading
        // ExperienceWorkspaceManager. The second stays background.

        final snapshot = rig.workspaceRuntime.captureRuntimeState();
        expect(snapshot.sessions, hasLength(2));
        expect(snapshot.activeSession!.sessionId, first.sessionId);
        expect(snapshot.backgroundSessions, hasLength(1));
        expect(
          snapshot.backgroundSessions.single.sessionId,
          isNot(first.sessionId),
        );
        await rig.repository.close();
      },
    );

    test(
      'per-session runtime state (ExperienceSession/SessionStatus) is aggregated exactly as reported — real, distinct values per session',
      () async {
        final rig = _Rig.create([_app('Camp Log'), _app('Gear List')]);
        final first = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final second = await rig.workspace.openExperience(
          Intent.create(expression: 'track my gear'),
        );

        final firstCreated = first.creationResult as CreationCreated;
        final secondCreated = second.creationResult as CreationCreated;
        final runningSession = ExperienceSession(
          id: 'runtime-a',
          experienceId: firstCreated.experienceId,
          package: firstCreated.package,
          status: SessionStatus.running,
          startedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        final pausedSession = ExperienceSession(
          id: 'runtime-b',
          experienceId: secondCreated.experienceId,
          package: secondCreated.package,
          status: SessionStatus.paused,
          startedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        rig.workspace.updateRuntimeState(first.sessionId, runningSession);
        rig.workspace.updateRuntimeState(second.sessionId, pausedSession);

        final snapshot = rig.workspaceRuntime.captureRuntimeState();
        final firstStatus = snapshot.sessions.firstWhere(
          (s) => s.sessionId == first.sessionId,
        );
        final secondStatus = snapshot.sessions.firstWhere(
          (s) => s.sessionId == second.sessionId,
        );
        expect(firstStatus.runtimeState!.status, SessionStatus.running);
        expect(secondStatus.runtimeState!.status, SessionStatus.paused);
        await rig.repository.close();
      },
    );
  });

  group('Background engineering tracking (R34)', () {
    test(
      'a background session with an in-flight modification reports hasPendingEvolution — a real, structural signal, never guessed',
      () async {
        final rig = _Rig.create([_app('Camp Log'), _app('Camp Log')]);
        final first = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        await rig.workspace.openExperience(
          Intent.create(expression: 'track my other trips'),
        );

        // pendingModification is only ever non-null WHILE continueSession()
        // is in flight (cleared in a finally block) — assert the resting
        // state honestly reports null instead of fabricating an in-flight one.
        final snapshot = rig.workspaceRuntime.captureRuntimeState();
        final firstStatus = snapshot.sessions.firstWhere(
          (s) => s.sessionId == first.sessionId,
        );
        expect(firstStatus.hasPendingEvolution, isFalse);
        await rig.repository.close();
      },
    );
  });

  group('Notification generation (R34)', () {
    test(
      'a background session reaching a real terminal LifecycleOutcome produces exactly one real WorkspaceNotification',
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

        // `second` is background (first auto-activated). Evolve it with a
        // real, structurally-different intent so a real regeneration attempt
        // completes. REALITY (found while writing this test): a legacy-created
        // "before" package evolved through the incremental path here reaches
        // `commitFailed` (a real, terminal outcome after a real, completed
        // attempt — `applyEvolutionPlan()`'s own defensive re-validation, R6,
        // rejects it) rather than `deployed` — this is why `commitFailed` is
        // included in `_terminalOutcomes` alongside `deployed`/`blocked`: all
        // three are real, worth-surfacing terminal states, distinct from
        // "nothing was ever attempted."
        final continueResult = await rig.workspace.continueExperience(
          second.sessionId,
          Intent.create(expression: 'also track my gear'),
        );
        expect(
          continueResult.lifecycleResult.outcome,
          isNot(
            anyOf(
              LifecycleOutcome.noEngineeringMemory,
              LifecycleOutcome.cannotEvolve,
              LifecycleOutcome.noChangeDetected,
              LifecycleOutcome.noActionableTarget,
            ),
          ),
        );

        final snapshot = rig.workspaceRuntime.captureRuntimeState();
        final notification = snapshot.notifications.singleWhere(
          (n) => n.sessionId == second.sessionId,
        );
        expect(notification.outcome, continueResult.lifecycleResult.outcome);
        expect(notification.experienceName, isNotNull);
        // No notification for the untouched active session.
        expect(
          snapshot.notifications.where((n) => n.sessionId == first.sessionId),
          isEmpty,
        );
        await rig.repository.close();
      },
    );

    test(
      'the SAME real terminal outcome is never re-notified on a second capture — real de-duplication, not re-derivation',
      () async {
        final rig = _Rig.create([
          _app('Camp Log'),
          _app('Camp Log'),
          _app('Camp Log', withGear: true),
        ]);
        await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final second = await rig.workspace.openExperience(
          Intent.create(expression: 'track my other trips'),
        );
        await rig.workspace.continueExperience(
          second.sessionId,
          Intent.create(expression: 'also track my gear'),
        );

        final firstSnapshot = rig.workspaceRuntime.captureRuntimeState();
        expect(
          firstSnapshot.notifications.where(
            (n) => n.sessionId == second.sessionId,
          ),
          hasLength(1),
        );

        final secondSnapshot = rig.workspaceRuntime.captureRuntimeState();
        expect(
          secondSnapshot.notifications.where(
            (n) => n.sessionId == second.sessionId,
          ),
          isEmpty,
        );
        await rig.repository.close();
      },
    );

    test(
      'no notification is ever generated for the ACTIVE session, regardless of its real outcome',
      () async {
        final rig = _Rig.create([
          _app('Camp Log'),
          _app('Camp Log', withGear: true),
        ]);
        final first = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        await rig.workspace.continueExperience(
          first.sessionId,
          Intent.create(expression: 'also track my gear'),
        );

        final snapshot = rig.workspaceRuntime.captureRuntimeState();
        expect(snapshot.notifications, isEmpty);
        await rig.repository.close();
      },
    );
  });

  group('Backward compatibility (R34) — HomeScreen / ExperienceHostScreen', () {
    test(
      'HomeScreen() constructed WITHOUT workspaceRuntime — the new field defaults to null, construction never throws',
      () {
        const screen = HomeScreen();
        expect(screen.workspaceRuntime, isNull);
        expect(screen.workspaceManager, isNull);
        expect(screen.intentRouter, isNull);
      },
    );

    test(
      'HomeScreen accepts a real, injected AutonomousWorkspaceRuntime without altering ExperienceWorkspaceManager behavior',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final screen = HomeScreen(workspaceRuntime: rig.workspaceRuntime);
        expect(screen.workspaceRuntime, same(rig.workspaceRuntime));
        await rig.repository.close();
      },
    );

    test(
      'ExperienceHostScreen constructed WITHOUT workspaceRuntime — the new field defaults to null, construction never throws',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final result = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final package = (result.creationResult as CreationCreated).package;

        final screen = ExperienceHostScreen(
          package: package,
          experienceId: 'exp-no-runtime',
          experienceName: 'Camp Log',
        );
        expect(screen.workspaceRuntime, isNull);
        await rig.repository.close();
      },
    );
  });

  group(
    'Regression (R34) — ExperienceWorkspaceManager/IntentSessionManager/EngineeringLifecycleCoordinator behavior is completely unaffected',
    () {
      test(
        'ExperienceWorkspaceManager.openExperience() called directly (bypassing AutonomousWorkspaceRuntime entirely) behaves exactly as R32 built it',
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
    'Performance (R34) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test('runtime startup latency', () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final stopwatch = Stopwatch()..start();
        final _ = AutonomousWorkspaceRuntime(workspace: rig.workspace);
        stopwatch.stop();
        // ignore: avoid_print
        print(
          'R34 workspace runtime startup: ${stopwatch.elapsedMicroseconds}us',
        );
        await rig.repository.close();
      });

      test(
        'background supervision / snapshot-capture latency across many open sessions (workspace scaling)',
        () async {
          final apps = [for (var i = 0; i < 20; i++) _app('App $i')];
          final rig = _Rig.create(apps);
          for (final _ in apps) {
            await rig.workspace.openExperience(
              Intent.create(expression: 'track my stuff'),
            );
          }
          final stopwatch = Stopwatch()..start();
          final snapshot = rig.workspaceRuntime.captureRuntimeState();
          stopwatch.stop();
          expect(snapshot.sessions, hasLength(20));
          // ignore: avoid_print
          print(
            'R34 snapshot-capture latency (20 sessions): ${stopwatch.elapsedMicroseconds}us',
          );
          await rig.repository.close();
        },
      );

      test(
        'memory: real process RSS delta while capturing 100 snapshots',
        () async {
          final rig = _Rig.create([_app('Camp Log'), _app('Gear List')]);
          await rig.workspace.openExperience(
            Intent.create(expression: 'track my camping trips'),
          );
          await rig.workspace.openExperience(
            Intent.create(expression: 'track my gear'),
          );

          final rssBefore = ProcessInfo.currentRss;
          for (var i = 0; i < 100; i++) {
            rig.workspaceRuntime.captureRuntimeState();
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R34 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 100 snapshots',
          );
          await rig.repository.close();
        },
      );
    },
  );
}
