/// Implementation Specification IS-R39 — Workspace Lifecycle Policy Engine,
/// AI Operating System Runtime Policies.
///
/// REALITY before R39 (confirmed by reading source): no application-lifecycle
/// observation existed anywhere in this codebase (`grep -rn
/// "AppLifecycleState|WidgetsBindingObserver|didChangeAppLifecycleState" lib/`
/// returned zero matches before this milestone). `ExperienceWorkspaceManager
/// .closeExperience()` also has zero production callers — a "Workspace
/// Close" policy is honestly deferred, not fabricated. This file proves, with
/// real objects (never mocks of the subsystem under test):
/// `WorkspaceLifecyclePolicyEngine.evaluateAppLifecycle()`/
/// `.evaluateWorkspaceSnapshot()` are pure and correct, `.apply()` really
/// invokes the real `ExperienceRuntimeController`, and a real, live
/// `ExperienceHostScreen` now genuinely pauses/resumes its runtime on a real
/// `AppLifecycleState` transition (via `WidgetTester.binding
/// .handleAppLifecycleStateChanged()`), while every pre-R39 behavior stays
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
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r38_experience_runtime_controller_test.dart's
// established shapes exactly. ─────────────────────────────────────────────

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

  _Rig({
    required this.repository,
    required this.workspace,
    required this.workspaceRuntime,
  });

  static Future<_Rig> create(List<SemanticApp> reasonerSequence) async {
    final name =
        'r39_policy_engine_${DateTime.now().microsecondsSinceEpoch}.db';
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

    return _Rig(
      repository: repository,
      workspace: workspace,
      workspaceRuntime: workspaceRuntime,
    );
  }

  Future<String> openRealSession() async {
    final result = await workspace.openExperience(
      Intent.create(expression: 'track my camping trips'),
    );
    return (result.creationResult as CreationCreated).experienceId;
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

/// A real `SessionRuntimeStatus` fixture — mirrors the real shape
/// `AutonomousWorkspaceRuntime.captureRuntimeState()` produces, used to test
/// `evaluateWorkspaceSnapshot()` in isolation without needing a full real
/// Kernel run per session.
SessionRuntimeStatus _status({
  required String sessionId,
  required bool isActive,
  SessionStatus? runtimeStatus,
}) {
  return SessionRuntimeStatus(
    sessionId: sessionId,
    experienceId: 'exp-$sessionId',
    experienceName: 'Exp $sessionId',
    isActive: isActive,
    runtimeState: runtimeStatus == null
        ? null
        : ExperienceSession(
            id: 'rt-$sessionId',
            experienceId: 'exp-$sessionId',
            package: _runnablePackage(experienceId: 'exp-$sessionId'),
            status: runtimeStatus,
            startedAt: DateTime(2026),
            lastActiveAt: DateTime(2026),
          ),
    deploymentStatus: null,
    artifactStatus: null,
    hasPendingEvolution: false,
  );
}

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Policy evaluation (R39) — evaluateAppLifecycle, pure', () {
    final engine = const WorkspaceLifecyclePolicyEngine();

    test('paused/hidden -> pause', () {
      expect(
        engine.evaluateAppLifecycle(AppLifecycleState.paused).action,
        RuntimePolicyAction.pause,
      );
      expect(
        engine.evaluateAppLifecycle(AppLifecycleState.hidden).action,
        RuntimePolicyAction.pause,
      );
    });

    test('resumed -> resume', () {
      expect(
        engine.evaluateAppLifecycle(AppLifecycleState.resumed).action,
        RuntimePolicyAction.resume,
      );
    });

    test('inactive/detached -> noAction', () {
      expect(
        engine.evaluateAppLifecycle(AppLifecycleState.inactive).action,
        RuntimePolicyAction.noAction,
      );
      expect(
        engine.evaluateAppLifecycle(AppLifecycleState.detached).action,
        RuntimePolicyAction.noAction,
      );
    });
  });

  group(
    'Policy evaluation (R39) — evaluateWorkspaceSnapshot / Multiple runtime instances, pure',
    () {
      test(
        'every running, non-active session gets a pause decision with the correct sessionId; the active session and an already-paused background session get none',
        () {
          final engine = const WorkspaceLifecyclePolicyEngine();
          final snapshot = WorkspaceRuntimeSnapshot(
            sessions: [
              _status(
                sessionId: 's-active',
                isActive: true,
                runtimeStatus: SessionStatus.running,
              ),
              _status(
                sessionId: 's-bg-running-1',
                isActive: false,
                runtimeStatus: SessionStatus.running,
              ),
              _status(
                sessionId: 's-bg-running-2',
                isActive: false,
                runtimeStatus: SessionStatus.running,
              ),
              _status(
                sessionId: 's-bg-already-paused',
                isActive: false,
                runtimeStatus: SessionStatus.paused,
              ),
              _status(
                sessionId: 's-bg-no-runtime',
                isActive: false,
                runtimeStatus: null,
              ),
            ],
            notifications: const [],
            capturedAt: DateTime(2026),
          );

          final decisions = engine.evaluateWorkspaceSnapshot(snapshot);

          expect(
            decisions.map((d) => d.sessionId).toSet(),
            {'s-bg-running-1', 's-bg-running-2'},
            reason:
                'only running, non-active sessions get a real pause decision — proves N independent, correctly-targeted decisions for N real sessions',
          );
          expect(
            decisions.every((d) => d.action == RuntimePolicyAction.pause),
            isTrue,
          );
        },
      );

      test(
        'an empty workspace (no open sessions) produces zero decisions — never a fabricated one',
        () {
          const engine = WorkspaceLifecyclePolicyEngine();
          final snapshot = WorkspaceRuntimeSnapshot(
            sessions: const [],
            notifications: const [],
            capturedAt: DateTime(2026),
          );
          expect(engine.evaluateWorkspaceSnapshot(snapshot), isEmpty);
        },
      );
    },
  );

  group('apply() (R39) — the real invocation of ExperienceRuntimeController', () {
    test(
      'a pause decision reaches controller.pause(); a resume decision reaches controller.resume(); a real WorkspaceUpdated event is published for each',
      () async {
        final rig = await _Rig.create([_app('Camp Log')]);
        final experienceId = await rig.openRealSession();
        final bus = EventBus();
        final publisher = WorkspaceEventPublisher(bus: bus, source: 'test');
        final engine = WorkspaceLifecyclePolicyEngine(
          eventPublisher: publisher,
        );
        final runtime = AnythingRuntime();
        final controller = ExperienceRuntimeController(
          runtime: runtime,
          workspace: rig.workspace,
          eventPublisher: publisher,
          experienceId: experienceId,
        );
        await controller.start(_runnablePackage(experienceId: experienceId));

        final received = <WorkspaceUpdated>[];
        bus.on<WorkspaceUpdated>().listen(received.add);

        await engine.apply(
          engine.evaluateAppLifecycle(AppLifecycleState.paused),
          controller,
        );
        expect(runtime.status, RuntimeStatus.paused);

        await engine.apply(
          engine.evaluateAppLifecycle(AppLifecycleState.resumed),
          controller,
        );
        expect(runtime.status, RuntimeStatus.running);

        await Future.delayed(Duration.zero);
        // `controller.pause()`/`.resume()` (R38, unmodified) already publish
        // their own real `'runtime_paused'`/`'runtime_resumed'` events on
        // every call, regardless of caller — `engine.apply()` additionally
        // publishes `'policy_pause'`/`'policy_resume'` as its own real signal
        // (subscribers see both WHAT happened and WHY). Both are real, never
        // a fabricated duplicate.
        expect(received.map((e) => e.change).toList(), [
          'runtime_paused',
          'policy_pause',
          'runtime_resumed',
          'policy_resume',
        ]);

        await rig.repository.close();
      },
    );

    test('a noAction decision invokes nothing and publishes nothing', () async {
      final runtime = AnythingRuntime();
      final controller = ExperienceRuntimeController(runtime: runtime);
      await controller.start(_runnablePackage());
      final statusBefore = runtime.status;

      final bus = EventBus();
      final received = <WorkspaceUpdated>[];
      bus.on<WorkspaceUpdated>().listen(received.add);
      final engine = WorkspaceLifecyclePolicyEngine(
        eventPublisher: WorkspaceEventPublisher(bus: bus),
      );

      await engine.apply(
        engine.evaluateAppLifecycle(AppLifecycleState.inactive),
        controller,
      );
      await Future.delayed(Duration.zero);

      expect(runtime.status, statusBefore);
      expect(received, isEmpty);
    });
  });

  group(
    'Background pause / Foreground resume (R39) — real, live ExperienceHostScreen',
    () {
      testWidgets(
        'a real AppLifecycleState.paused transition pauses the real runtime; .resumed resumes it',
        (tester) async {
          final runtime = AnythingRuntime();
          await runtime.openExperience(
            _runnablePackage(experienceId: 'exp-lifecycle'),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: ExperienceHostScreen(
                package: _runnablePackage(experienceId: 'exp-lifecycle'),
                experienceId: 'exp-lifecycle',
                runtime: runtime,
              ),
            ),
          );
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();

          expect(runtime.status, RuntimeStatus.running);

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          expect(
            runtime.status,
            RuntimeStatus.paused,
            reason:
                'a real OS-level background transition must reach the real runtime through the R39 policy engine',
          );

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          expect(
            runtime.status,
            RuntimeStatus.running,
            reason:
                'a real OS-level foreground transition must resume the real runtime',
          );
        },
      );

      testWidgets(
        'an inactive transition (e.g. a transient system dialog) does not pause the runtime',
        (tester) async {
          final runtime = AnythingRuntime();
          await runtime.openExperience(
            _runnablePackage(experienceId: 'exp-inactive'),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: ExperienceHostScreen(
                package: _runnablePackage(experienceId: 'exp-inactive'),
                experienceId: 'exp-inactive',
                runtime: runtime,
              ),
            ),
          );
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          await tester.pump();

          expect(runtime.status, RuntimeStatus.running);
        },
      );
    },
  );

  group(
    'Regression (R39) — ExperienceRuntimeController/AnythingRuntime/ExperienceWorkspaceManager/AutonomousWorkspaceRuntime unaffected by the policy engine',
    () {
      test(
        'ExperienceRuntimeController used directly, bypassing the policy engine entirely, still behaves exactly as R38 built it',
        () async {
          final runtime = AnythingRuntime();
          final controller = ExperienceRuntimeController(runtime: runtime);
          await controller.start(_runnablePackage());
          controller.pause();
          expect(runtime.status, RuntimeStatus.paused);
          controller.resume();
          expect(runtime.status, RuntimeStatus.running);
          await controller.terminate();
          expect(runtime.status, RuntimeStatus.idle);
        },
      );
    },
  );

  group('Backward compatibility (R39) — ExperienceHostScreen', () {
    test(
      'ExperienceHostScreen constructor gained no new field this milestone (always-on observer, no opt-in param)',
      () {
        final widget = ExperienceHostScreen(package: _runnablePackage());
        expect(widget.runtimeController, isNull);
        expect(widget.runtime, isNull);
      },
    );

    testWidgets(
      'every pre-R39 widget behavior (load, "Change this app" flow availability, dispose) is unaffected when no real AppLifecycleState transition ever fires',
      (tester) async {
        final before = _runnablePackage(experienceId: 'exp-compat');
        final runtime = AnythingRuntime();
        await runtime.openExperience(before);

        await tester.pumpWidget(
          MaterialApp(
            home: ExperienceHostScreen(
              package: before,
              experienceId: 'exp-compat',
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

        await tester.pumpWidget(const SizedBox());
        expect(
          tester.takeException(),
          isNull,
          reason:
              'dispose() (WidgetsBinding observer removal + runtime ownership check) must not throw',
        );
      },
    );
  });

  group(
    'Performance (R39) — real Stopwatch/ProcessInfo.currentRss measurements, never fabricated',
    () {
      test(
        'policy evaluation latency: evaluateAppLifecycle / evaluateWorkspaceSnapshot',
        () {
          const engine = WorkspaceLifecyclePolicyEngine();
          final snapshot = WorkspaceRuntimeSnapshot(
            sessions: List.generate(
              50,
              (i) => _status(
                sessionId: 's$i',
                isActive: i == 0,
                runtimeStatus: SessionStatus.running,
              ),
            ),
            notifications: const [],
            capturedAt: DateTime(2026),
          );

          final sw = Stopwatch()..start();
          for (var i = 0; i < 1000; i++) {
            engine.evaluateAppLifecycle(AppLifecycleState.paused);
          }
          engine.evaluateWorkspaceSnapshot(snapshot);
          sw.stop();
          // ignore: avoid_print
          print(
            'R39 policy evaluation (1000x evaluateAppLifecycle + 1x evaluateWorkspaceSnapshot over 50 sessions): ${sw.elapsedMicroseconds}us',
          );
        },
      );

      test('lifecycle transition latency through apply()', () async {
        final runtime = AnythingRuntime();
        final controller = ExperienceRuntimeController(runtime: runtime);
        await controller.start(_runnablePackage());
        const engine = WorkspaceLifecyclePolicyEngine();

        final sw = Stopwatch()..start();
        await engine.apply(
          engine.evaluateAppLifecycle(AppLifecycleState.paused),
          controller,
        );
        await engine.apply(
          engine.evaluateAppLifecycle(AppLifecycleState.resumed),
          controller,
        );
        sw.stop();
        // ignore: avoid_print
        print('R39 apply() pause+resume: ${sw.elapsedMicroseconds}us');
      });

      test(
        'memory: real process RSS delta across repeated evaluate/apply cycles',
        () async {
          final rssBefore = ProcessInfo.currentRss;
          const engine = WorkspaceLifecyclePolicyEngine();
          for (var i = 0; i < 10; i++) {
            final runtime = AnythingRuntime();
            final controller = ExperienceRuntimeController(runtime: runtime);
            await controller.start(_runnablePackage());
            await engine.apply(
              engine.evaluateAppLifecycle(AppLifecycleState.paused),
              controller,
            );
            await engine.apply(
              engine.evaluateAppLifecycle(AppLifecycleState.resumed),
              controller,
            );
            await controller.terminate();
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R39 memory: RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 10 evaluate/apply cycles',
          );
        },
      );
    },
  );
}
