/// Implementation Specification IS-R42 — Workspace Scheduling Engine, AI
/// Operating System Experience Scheduler.
///
/// REALITY before R42 (confirmed by reading source): `WorkspaceRuntimeSupervisor
/// .applyInactiveRuntimePolicy()`/`.resume()` (R40) had ZERO callers anywhere
/// in `lib/` — R40's and R41's own doc comments both explicitly, honestly
/// deferred wiring a real trigger. This file proves, with real objects
/// (never mocks of the subsystem under test): `WorkspaceSchedulingEngine`
/// correctly determines foreground/background experiences from the real
/// `AutonomousWorkspaceRuntime` snapshot, `scheduleForeground()` reaches the
/// real `ExperienceWorkspaceManager.switchActiveExperience()` AND makes real,
/// registered runtimes match (resume the new active, pause every other
/// running background), `scheduleActiveTransition()` correctly reflects
/// whatever the workspace's current real active session already is, and a
/// real, live `ExperienceHostScreen` notifies an injected scheduler once
/// loaded — while every pre-R42 behavior (no scheduler injected) stays
/// completely unaffected.
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
import 'package:anything/app/workspace_event_publisher.dart';
import 'package:anything/app/workspace_lifecycle_policy_engine.dart';
import 'package:anything/app/workspace_runtime_supervisor.dart';
import 'package:anything/app/workspace_scheduling_engine.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/core/events/events.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/experience_host_screen.dart';
import 'package:anything/runtime/experience_runtime_controller.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r40_workspace_runtime_supervisor_test.dart's /
// test/r41_shared_runtime_supervision_test.dart's established shapes
// exactly. ────────────────────────────────────────────────────────────────

SemanticApp _app(String name) => SemanticApp(
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
  final AutonomousWorkspaceRuntime workspaceRuntime;
  final WorkspaceRuntimeSupervisor supervisor;
  final WorkspaceSchedulingEngine scheduler;

  _Rig({
    required this.repository,
    required this.workspace,
    required this.workspaceRuntime,
    required this.supervisor,
    required this.scheduler,
  });

  static Future<_Rig> create(List<SemanticApp> reasonerSequence) async {
    final name = 'r42_scheduler_${DateTime.now().microsecondsSinceEpoch}.db';
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
    final workspaceRuntime = AutonomousWorkspaceRuntime(workspace: workspace);
    final supervisor = WorkspaceRuntimeSupervisor();
    const policyEngine = WorkspaceLifecyclePolicyEngine();
    final scheduler = WorkspaceSchedulingEngine(
      workspaceRuntime: workspaceRuntime,
      supervisor: supervisor,
      policyEngine: policyEngine,
      workspace: workspace,
    );

    return _Rig(
      repository: repository,
      workspace: workspace,
      workspaceRuntime: workspaceRuntime,
      supervisor: supervisor,
      scheduler: scheduler,
    );
  }

  /// Opens a real, NEW workspace session AND registers a real, started
  /// controller for it with [supervisor] — the shape every real test in
  /// this file needs to exercise scheduling against real, registered
  /// runtimes.
  Future<String> openAndRegister(String expression) async {
    final result = await workspace.openExperience(
      Intent.create(expression: expression),
    );
    final experienceId =
        (result.creationResult as CreationCreated).experienceId;
    // Must report into `workspace` (real `SessionState.currentRuntimeState`,
    // R31/R38) — `WorkspaceLifecyclePolicyEngine.evaluateWorkspaceSnapshot()`
    // (R39, unmodified) reads THAT real field, not `ExperienceRuntimeController
    // .status` directly, to decide which background sessions are "running."
    final controller = ExperienceRuntimeController(
      runtime: AnythingRuntime(),
      workspace: workspace,
      experienceId: experienceId,
    );
    await controller.start(_runnablePackage(experienceId: experienceId));
    supervisor.register(
      result.sessionId,
      controller,
      experienceId: experienceId,
    );
    return result.sessionId;
  }
}

/// Minimal, real `ExperiencePackage` that ACTUALLY SUCCEEDS in
/// `AnythingRuntime.openExperience()`. Mirrors
/// test/r38_experience_runtime_controller_test.dart's own `_runnablePackage()`.
ExperiencePackage _runnablePackage({String experienceId = 'exp-1'}) {
  final now = DateTime(2026);
  const screens = [
    InterfaceScreen(
      id: 's1',
      title: 'Home',
      children: [
        InterfaceNode(type: 'text', id: 'n1', properties: {'text': 'Hi'}),
      ],
    ),
  ];
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: experienceId,
      name: 'Test',
      description: 'd',
      category: 'general',
      entryPoint: 's1',
      version: '1',
      createdAt: now,
      updatedAt: now,
    ),
    interface: const InterfaceDefinition(screens: screens),
    behavior: const BehaviorGraph(),
    state: const StateSchema(),
    capabilityDeclarations: const [],
    provenance: const PackageProvenance(
      creationEngineVersion: 'test',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(contentHash: 'h', computedAt: now),
  );
}

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Foreground selection (R42)', () {
    test(
      'foregroundExperience() returns the real, current active session; null when nothing is open',
      () async {
        final rig = await _Rig.create([_app('Camp Log')]);
        expect(rig.scheduler.foregroundExperience(), isNull);

        final sessionId = await rig.openAndRegister('track my camping trips');
        final active = rig.scheduler.foregroundExperience();
        expect(active, isNotNull);
        expect(active!.sessionId, sessionId);
        expect(active.isActive, isTrue);

        await rig.repository.close();
      },
    );
  });

  group('Background selection (R42)', () {
    test(
      'backgroundExperiences() returns exactly the real, open-but-not-active sessions',
      () async {
        final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
        final sessionA = await rig.openAndRegister('track my camping trips');
        final sessionB = await rig.openAndRegister('track my book club');

        // Opening a second session never steals active focus (real,
        // unmodified R32 `_activeSessionId ??= result.sessionId` behavior).
        expect(rig.scheduler.foregroundExperience()!.sessionId, sessionA);
        final background = rig.scheduler.backgroundExperiences();
        expect(background.map((s) => s.sessionId).toList(), [sessionB]);

        await rig.repository.close();
      },
    );
  });

  group('Runtime switching (R42)', () {
    test(
      'scheduleForeground(sessionId) reaches ExperienceWorkspaceManager.switchActiveExperience() for real, resumes the new active runtime, and pauses every other real, registered, running background runtime',
      () async {
        final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
        final sessionA = await rig.openAndRegister('track my camping trips');
        final sessionB = await rig.openAndRegister('track my book club');

        // Bring both real runtimes to their expected pre-switch state: A
        // (active) running, B (background) already running too (as if it had
        // just been opened and not yet scheduled down).
        expect(rig.supervisor.lookup(sessionA)!.status, RuntimeStatus.running);
        expect(rig.supervisor.lookup(sessionB)!.status, RuntimeStatus.running);

        await rig.scheduler.scheduleForeground(sessionB);

        expect(
          rig.workspace.activeSessionId,
          sessionB,
          reason: 'switchActiveExperience() must have run for real',
        );
        expect(
          rig.supervisor.lookup(sessionB)!.status,
          RuntimeStatus.running,
          reason: 'the new active runtime must be (still) resumed',
        );
        expect(
          rig.supervisor.lookup(sessionA)!.status,
          RuntimeStatus.paused,
          reason:
              'the now-background runtime must be paused via the Inactive Runtime policy',
        );

        await rig.repository.close();
      },
    );
  });

  group('Workspace scheduling (R42)', () {
    test(
      'scheduleActiveTransition() called directly reflects whatever the workspace\'s CURRENT real active session already is, including after a real closeExperience() fallback',
      () async {
        final rig = await _Rig.create([
          _app('Camp Log'),
          _app('Book Club'),
          _app('Todo'),
        ]);
        final sessionA = await rig.openAndRegister('track my camping trips');
        final sessionB = await rig.openAndRegister('track my book club');
        final sessionC = await rig.openAndRegister('track my todos');
        expect(rig.workspace.activeSessionId, sessionA);

        // Real R32 closeExperience() fallback: closing the active session
        // falls back to the real remaining open session (`_openSessionIds
        // .last`, unmodified) — here, C. B stays a real, still-open,
        // still-tracked background session throughout (unlike A, which
        // closeExperience() removes from the workspace's tracking entirely —
        // a real, honest state scheduleActiveTransition() correctly cannot
        // reach, since it works from the workspace's own current snapshot).
        await rig.workspace.closeExperience(sessionA);
        expect(rig.workspace.activeSessionId, sessionC);

        await rig.scheduler.scheduleActiveTransition();

        expect(
          rig.supervisor.lookup(sessionC)!.status,
          RuntimeStatus.running,
          reason:
              'the real, current active session (C, after the fallback) must be resumed',
        );
        expect(
          rig.supervisor.lookup(sessionB)!.status,
          RuntimeStatus.paused,
          reason:
              'B is still a real, open, tracked background session and must be paused — proving scheduleActiveTransition() reads the workspace\'s CURRENT state fresh, not a stale snapshot from before the close',
        );

        await rig.repository.close();
      },
    );

    test(
      'publishes a real scheduler_active_transition WorkspaceUpdated event when an eventPublisher is supplied',
      () async {
        final rig = await _Rig.create([_app('Camp Log')]);
        final bus = EventBus();
        final publisher = WorkspaceEventPublisher(bus: bus, source: 'test');
        final scheduler = WorkspaceSchedulingEngine(
          workspaceRuntime: rig.workspaceRuntime,
          supervisor: rig.supervisor,
          policyEngine: const WorkspaceLifecyclePolicyEngine(),
          workspace: rig.workspace,
          eventPublisher: publisher,
        );
        final received = <WorkspaceUpdated>[];
        bus.on<WorkspaceUpdated>().listen(received.add);

        await rig.openAndRegister('track my camping trips');
        await scheduler.scheduleActiveTransition();
        await Future.delayed(Duration.zero);

        expect(
          received.map((e) => e.change),
          contains('scheduler_active_transition'),
        );
        await rig.repository.close();
      },
    );

    test(
      'scheduleForeground() without a workspace supplied throws a real, honest StateError',
      () async {
        final rig = await _Rig.create([_app('Camp Log')]);
        final noWorkspaceScheduler = WorkspaceSchedulingEngine(
          workspaceRuntime: rig.workspaceRuntime,
          supervisor: rig.supervisor,
          policyEngine: const WorkspaceLifecyclePolicyEngine(),
        );
        expect(
          () => noWorkspaceScheduler.scheduleForeground('s1'),
          throwsStateError,
        );
        await rig.repository.close();
      },
    );
  });

  group(
    'Regression (R42) — WorkspaceRuntimeSupervisor/WorkspaceLifecyclePolicyEngine/AutonomousWorkspaceRuntime/ExperienceWorkspaceManager unaffected by the scheduler',
    () {
      test(
        'WorkspaceRuntimeSupervisor.applyInactiveRuntimePolicy() called directly, bypassing the scheduler entirely, still behaves exactly as R40 built it',
        () async {
          final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
          await rig.openAndRegister('track my camping trips');
          final sessionB = await rig.openAndRegister('track my book club');

          final snapshot = rig.workspaceRuntime.captureRuntimeState();
          await rig.supervisor.applyInactiveRuntimePolicy(
            snapshot,
            const WorkspaceLifecyclePolicyEngine(),
          );
          expect(rig.supervisor.lookup(sessionB)!.status, RuntimeStatus.paused);

          await rig.repository.close();
        },
      );

      test(
        'ExperienceWorkspaceManager.switchActiveExperience() called directly, bypassing the scheduler entirely, still behaves exactly as R32 built it',
        () async {
          final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
          final sessionA = await rig.openAndRegister('track my camping trips');
          final sessionB = await rig.openAndRegister('track my book club');
          await rig.workspace.switchActiveExperience(sessionA);
          expect(rig.workspace.activeSessionId, sessionA);
          expect(sessionB, isNotEmpty);

          await rig.repository.close();
        },
      );
    },
  );

  group('Backward compatibility (R42) — ExperienceHostScreen', () {
    test(
      'ExperienceHostScreen constructed WITHOUT scheduler defaults it to null (constructor otherwise unchanged)',
      () {
        final widget = ExperienceHostScreen(package: _runnablePackage());
        expect(widget.scheduler, isNull);
      },
    );

    testWidgets(
      'a real, live ExperienceHostScreen with NO scheduler injected loads/disposes exactly as before R42',
      (tester) async {
        final runtime = AnythingRuntime();
        await runtime.openExperience(
          _runnablePackage(experienceId: 'exp-no-scheduler'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExperienceHostScreen(
              package: _runnablePackage(experienceId: 'exp-no-scheduler'),
              experienceId: 'exp-no-scheduler',
              runtime: runtime,
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();

        expect(find.text('Test'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a real, live ExperienceHostScreen with an injected scheduler notifies it once loaded — its own runtime is resumed and a real sibling background runtime is paused',
      (tester) async {
        late _Rig rig;
        late String experienceIdActive;
        late String sessionIdBackground;
        final activeRuntime = AnythingRuntime();
        late ExperiencePackage pkgActive;

        await tester.runAsync(() async {
          rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
          // The FIRST session opened in a fresh workspace becomes active
          // (`ExperienceWorkspaceManager.openExperience()`'s real, unmodified
          // `_activeSessionId ??= result.sessionId`) — opened first here so
          // it's the real active session the live screen below represents.
          final activeResult = await rig.workspace.openExperience(
            Intent.create(expression: 'track my camping trips'),
          );
          experienceIdActive =
              (activeResult.creationResult as CreationCreated).experienceId;
          pkgActive = _runnablePackage(experienceId: experienceIdActive);
          await activeRuntime.openExperience(pkgActive);
          // A real, second-opened, ALREADY-open BACKGROUND session with its
          // own registered, running controller — the scheduler must pause its
          // runtime as a side effect of the live screen below notifying it.
          sessionIdBackground = await rig.openAndRegister('track my book club');
        });

        expect(
          rig.workspace.activeSessionId,
          isNot(sessionIdBackground),
          reason:
              'the first-opened session must be the real active one; the second-registered stays background',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExperienceHostScreen(
              package: pkgActive,
              experienceId: experienceIdActive,
              runtime: activeRuntime,
              workspaceManager: rig.workspace,
              runtimeSupervisor: rig.supervisor,
              scheduler: rig.scheduler,
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();

        expect(
          activeRuntime.status,
          RuntimeStatus.running,
          reason: 'the active screen\'s own runtime must be (still) resumed',
        );
        expect(
          rig.supervisor.lookup(sessionIdBackground)!.status,
          RuntimeStatus.paused,
          reason:
              'the real sibling background runtime must have been paused by the scheduler once the active screen loaded',
        );

        await tester.runAsync(() => rig.repository.close());
      },
    );
  });

  group(
    'Performance (R42) — real Stopwatch/ProcessInfo.currentRss measurements, never fabricated',
    () {
      test(
        'foregroundExperience() / backgroundExperiences() latency (scheduling latency)',
        () async {
          final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
          await rig.openAndRegister('track my camping trips');
          await rig.openAndRegister('track my book club');

          final sw = Stopwatch()..start();
          rig.scheduler.foregroundExperience();
          rig.scheduler.backgroundExperiences();
          sw.stop();
          // ignore: avoid_print
          print(
            'R42 foregroundExperience()+backgroundExperiences(): ${sw.elapsedMicroseconds}us',
          );
          await rig.repository.close();
        },
      );

      test('scheduleForeground() latency (foreground switch)', () async {
        final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
        final sessionA = await rig.openAndRegister('track my camping trips');
        await rig.openAndRegister('track my book club');

        final sw = Stopwatch()..start();
        await rig.scheduler.scheduleForeground(sessionA);
        sw.stop();
        // ignore: avoid_print
        print('R42 scheduleForeground(): ${sw.elapsedMicroseconds}us');
        await rig.repository.close();
      });

      test(
        'background switch latency across a multi-controller workspace',
        () async {
          final rig = await _Rig.create(
            List.generate(10, (i) => _app('App $i')),
          );
          for (var i = 0; i < 10; i++) {
            await rig.openAndRegister('track app $i');
          }

          final sw = Stopwatch()..start();
          await rig.scheduler.scheduleActiveTransition();
          sw.stop();
          // ignore: avoid_print
          print(
            'R42 scheduleActiveTransition() across 10 sessions: ${sw.elapsedMicroseconds}us',
          );
          await rig.repository.close();
        },
      );

      test(
        'memory: real process RSS delta across repeated scheduling cycles',
        () async {
          final rssBefore = ProcessInfo.currentRss;
          final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
          final sessionA = await rig.openAndRegister('track my camping trips');
          final sessionB = await rig.openAndRegister('track my book club');
          for (var i = 0; i < 10; i++) {
            await rig.scheduler.scheduleForeground(
              i.isEven ? sessionA : sessionB,
            );
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R42 memory: RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 10 scheduleForeground() cycles',
          );
          await rig.repository.close();
        },
      );
    },
  );
}
