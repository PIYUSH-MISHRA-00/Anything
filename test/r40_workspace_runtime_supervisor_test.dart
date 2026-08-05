/// Implementation Specification IS-R40 — Workspace Runtime Supervisor, AI
/// Operating System Multi-Runtime Coordination.
///
/// REALITY before R40 (confirmed by reading source): no registry mapping
/// sessionId to `ExperienceRuntimeController` existed anywhere in this
/// codebase — `ExperienceHostScreen` self-constructed exactly ONE controller
/// per screen instance, with zero shared bookkeeping across screens. This
/// file proves, with real objects (never mocks of the subsystem under test):
/// registration/lookup/removal work correctly, duplicate registration is
/// honestly rejected, workspace-wide pause/resume reaches every registered
/// real runtime, the Inactive Runtime policy (R39, unmodified) now applies
/// across MULTIPLE real runtime controllers by resolving them through this
/// supervisor, disposed controllers can be swept on request, and a real,
/// live `ExperienceHostScreen` auto-registers/unregisters with an injected
/// supervisor while every pre-R40 behavior stays completely unaffected.
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
// / test/r39_workspace_lifecycle_policy_engine_test.dart's established
// shapes exactly. ────────────────────────────────────────────────────────

SemanticApp _app(String name) => SemanticApp(
  name: name,
  purpose: 'Track $name',
  entities: [SemanticEntity(id: 'trip', name: 'Trip', displayField: 'title', fields: const [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)])],
  requiredCapabilities: const ['storage'],
);

CapabilityRegistry _registryWithStorage() {
  final registry = CapabilityRegistry();
  registry.register(
    const CapabilityDescriptor(id: 'storage', version: '1.0.0', name: 'Storage', description: 'Local storage', category: CapabilityCategory.storage, inputContract: 'data', outputContract: 'stored data'),
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

  _Rig({required this.repository, required this.workspace});

  static Future<_Rig> create(List<SemanticApp> reasonerSequence) async {
    final name = 'r40_supervisor_${DateTime.now().microsecondsSinceEpoch}.db';
    final repository = SqliteExperienceRepository(dbName: name);
    final engineeringMemory = EngineeringMemoryRepository(experienceRepository: repository);
    final activity = ActivityRepository();
    final reasoner = _SequencedReasoner(reasonerSequence);
    final kernel = AnythingKernel(providerRegistry: _FakeProviderRegistry(), capabilityRegistry: _registryWithStorage(), reasoner: reasoner);

    final creationCoordinator = ExperienceCreationCoordinator(kernel: kernel, repository: repository, engineeringMemory: engineeringMemory);
    final lifecycleCoordinator = EngineeringLifecycleCoordinator(kernel: kernel, engineeringMemory: engineeringMemory, repository: repository);
    final sessionManager = IntentSessionManager(creationCoordinator: creationCoordinator, lifecycleCoordinator: lifecycleCoordinator, engineeringMemory: engineeringMemory, activity: activity);
    final workspace = ExperienceWorkspaceManager(sessionManager: sessionManager, activity: activity);

    return _Rig(repository: repository, workspace: workspace);
  }

  Future<String> openRealSession() async {
    final result = await workspace.openExperience(Intent.create(expression: 'track my camping trips'));
    return (result.creationResult as CreationCreated).experienceId;
  }
}

/// Minimal, real `ExperiencePackage` that ACTUALLY SUCCEEDS in
/// `AnythingRuntime.openExperience()`. Mirrors
/// test/r38_experience_runtime_controller_test.dart's own `_runnablePackage()`.
ExperiencePackage _runnablePackage({String experienceId = 'exp-1'}) {
  final now = DateTime(2026);
  const screens = [InterfaceScreen(id: 's1', title: 'Home', children: [InterfaceNode(type: 'text', id: 'n1', properties: {'text': 'Hi'})])];
  return ExperiencePackage(
    manifest: ExperienceManifest(experienceId: experienceId, name: 'Test', description: 'd', category: 'general', entryPoint: 's1', version: '1', createdAt: now, updatedAt: now),
    interface: const InterfaceDefinition(screens: screens),
    behavior: const BehaviorGraph(),
    state: const StateSchema(),
    capabilityDeclarations: const [],
    provenance: const PackageProvenance(creationEngineVersion: 'test', specVersion: 1, planVersion: 1),
    integrity: PackageIntegrity(contentHash: 'h', computedAt: now),
  );
}

/// A real `SessionRuntimeStatus` fixture — mirrors
/// test/r39_workspace_lifecycle_policy_engine_test.dart's own `_status()`
/// helper, the real shape `AutonomousWorkspaceRuntime.captureRuntimeState()`
/// produces.
SessionRuntimeStatus _status({required String sessionId, required bool isActive, SessionStatus? runtimeStatus}) {
  return SessionRuntimeStatus(
    sessionId: sessionId,
    experienceId: 'exp-$sessionId',
    experienceName: 'Exp $sessionId',
    isActive: isActive,
    runtimeState: runtimeStatus == null
        ? null
        : ExperienceSession(id: 'rt-$sessionId', experienceId: 'exp-$sessionId', package: _runnablePackage(experienceId: 'exp-$sessionId'), status: runtimeStatus, startedAt: DateTime(2026), lastActiveAt: DateTime(2026)),
    deploymentStatus: null,
    artifactStatus: null,
    hasPendingEvolution: false,
  );
}

/// A real, started controller — one per fixture session — used by the
/// multi-controller tests below.
Future<ExperienceRuntimeController> _startedController(String experienceId) async {
  final controller = ExperienceRuntimeController(runtime: AnythingRuntime());
  await controller.start(_runnablePackage(experienceId: experienceId));
  return controller;
}

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Controller registration (R40)', () {
    test('register() then lookup() returns the SAME real controller; registrations carries the correct record', () async {
      final supervisor = WorkspaceRuntimeSupervisor();
      final controller = await _startedController('exp-1');

      supervisor.register('s1', controller, experienceId: 'exp-1');

      expect(supervisor.lookup('s1'), same(controller));
      expect(supervisor.registrations, hasLength(1));
      final record = supervisor.registrations.single;
      expect(record.sessionId, 's1');
      expect(record.experienceId, 'exp-1');
      expect(record.currentStatus, RuntimeStatus.running);
      expect(record.registrationTime, isNotNull);
    });

    test('register() publishes a real controller_registered WorkspaceUpdated event', () async {
      final bus = EventBus();
      final publisher = WorkspaceEventPublisher(bus: bus, source: 'test');
      final supervisor = WorkspaceRuntimeSupervisor(eventPublisher: publisher);
      final received = <WorkspaceUpdated>[];
      bus.on<WorkspaceUpdated>().listen(received.add);

      supervisor.register('s1', await _startedController('exp-1'));
      await Future.delayed(Duration.zero);

      expect(received.map((e) => e.change), contains('controller_registered'));
    });
  });

  group('Duplicate prevention (R40)', () {
    test('registering the same sessionId twice throws a real StateError; the FIRST controller stays registered/lookup-able', () async {
      final supervisor = WorkspaceRuntimeSupervisor();
      final first = await _startedController('exp-1');
      final second = await _startedController('exp-2');
      supervisor.register('s1', first);

      expect(() => supervisor.register('s1', second), throwsStateError);
      expect(supervisor.lookup('s1'), same(first), reason: 'the first registration must be unaffected by the rejected duplicate');
    });
  });

  group('Controller removal (R40)', () {
    test('unregister() removes it; a subsequent lookup() returns null; unregistering an unknown id is a harmless no-op', () async {
      final supervisor = WorkspaceRuntimeSupervisor();
      supervisor.register('s1', await _startedController('exp-1'));

      supervisor.unregister('s1');
      expect(supervisor.lookup('s1'), isNull);

      expect(() => supervisor.unregister('never-registered'), returnsNormally);
    });
  });

  group('Session lookup (R40)', () {
    test('lookup() for an unknown sessionId returns null, never throws', () {
      final supervisor = WorkspaceRuntimeSupervisor();
      expect(supervisor.lookup('nope'), isNull);
    });
  });

  group('Workspace-wide pause / resume (R40)', () {
    test('applyAppLifecyclePolicy(paused, engine) pauses EVERY registered real runtime; (resumed, engine) resumes every one', () async {
      final supervisor = WorkspaceRuntimeSupervisor();
      const engine = WorkspaceLifecyclePolicyEngine();
      final c1 = await _startedController('exp-1');
      final c2 = await _startedController('exp-2');
      final c3 = await _startedController('exp-3');
      supervisor.register('s1', c1);
      supervisor.register('s2', c2);
      supervisor.register('s3', c3);

      await supervisor.applyAppLifecyclePolicy(AppLifecycleState.paused, engine);
      expect(c1.status, RuntimeStatus.paused);
      expect(c2.status, RuntimeStatus.paused);
      expect(c3.status, RuntimeStatus.paused);

      await supervisor.applyAppLifecyclePolicy(AppLifecycleState.resumed, engine);
      expect(c1.status, RuntimeStatus.running);
      expect(c2.status, RuntimeStatus.running);
      expect(c3.status, RuntimeStatus.running);
    });
  });

  group('Inactive Runtime policy application (R40) — across MULTIPLE real runtime controllers', () {
    test('applyInactiveRuntimePolicy() pauses only the background/running controllers a real multi-session snapshot names; the active one is unaffected', () async {
      final supervisor = WorkspaceRuntimeSupervisor();
      const engine = WorkspaceLifecyclePolicyEngine();

      final active = await _startedController('exp-active');
      final bg1 = await _startedController('exp-bg1');
      final bg2 = await _startedController('exp-bg2');
      supervisor.register('s-active', active);
      supervisor.register('s-bg-running-1', bg1);
      supervisor.register('s-bg-running-2', bg2);

      final snapshot = WorkspaceRuntimeSnapshot(
        sessions: [
          _status(sessionId: 's-active', isActive: true, runtimeStatus: SessionStatus.running),
          _status(sessionId: 's-bg-running-1', isActive: false, runtimeStatus: SessionStatus.running),
          _status(sessionId: 's-bg-running-2', isActive: false, runtimeStatus: SessionStatus.running),
        ],
        notifications: const [],
        capturedAt: DateTime(2026),
      );

      await supervisor.applyInactiveRuntimePolicy(snapshot, engine);

      expect(active.status, RuntimeStatus.running, reason: 'the active session must never be paused by the Inactive Runtime policy');
      expect(bg1.status, RuntimeStatus.paused);
      expect(bg2.status, RuntimeStatus.paused);
    });

    test('a decision naming a sessionId this supervisor has no registration for is silently skipped, never throws', () async {
      final supervisor = WorkspaceRuntimeSupervisor();
      const engine = WorkspaceLifecyclePolicyEngine();
      final snapshot = WorkspaceRuntimeSnapshot(
        sessions: [_status(sessionId: 'unregistered-session', isActive: false, runtimeStatus: SessionStatus.running)],
        notifications: const [],
        capturedAt: DateTime(2026),
      );

      await expectLater(supervisor.applyInactiveRuntimePolicy(snapshot, engine), completes);
    });
  });

  group('Disposed controller cleanup (R40)', () {
    test('removeDisposed() removes a registration whose controller was terminated; a still-running registration is left alone; the returned count is correct', () async {
      final supervisor = WorkspaceRuntimeSupervisor();
      final terminated = await _startedController('exp-terminated');
      final running = await _startedController('exp-running');
      supervisor.register('s-terminated', terminated);
      supervisor.register('s-running', running);

      await terminated.terminate();
      expect(terminated.status, RuntimeStatus.idle);

      final removedCount = supervisor.removeDisposed();

      expect(removedCount, 1);
      expect(supervisor.lookup('s-terminated'), isNull);
      expect(supervisor.lookup('s-running'), same(running));
    });
  });

  group('Regression (R40) — ExperienceRuntimeController/WorkspaceLifecyclePolicyEngine/AnythingRuntime/ExperienceWorkspaceManager unaffected by the supervisor', () {
    test('ExperienceRuntimeController and WorkspaceLifecyclePolicyEngine used directly, bypassing the supervisor entirely, still behave exactly as R38/R39 built them', () async {
      final runtime = AnythingRuntime();
      final controller = ExperienceRuntimeController(runtime: runtime);
      await controller.start(_runnablePackage());
      const engine = WorkspaceLifecyclePolicyEngine();

      await engine.apply(engine.evaluateAppLifecycle(AppLifecycleState.paused), controller);
      expect(runtime.status, RuntimeStatus.paused);
      await engine.apply(engine.evaluateAppLifecycle(AppLifecycleState.resumed), controller);
      expect(runtime.status, RuntimeStatus.running);
    });

    test('ExperienceWorkspaceManager.openExperience() called directly, bypassing the supervisor entirely, still behaves exactly as R32 built it', () async {
      final rig = await _Rig.create([_app('Camp Log')]);
      final experienceId = await rig.openRealSession();
      expect(experienceId, isNotEmpty);
      await rig.repository.close();
    });
  });

  group('Backward compatibility (R40) — ExperienceHostScreen', () {
    test('ExperienceHostScreen constructed WITHOUT runtimeSupervisor defaults it to null (constructor otherwise unchanged)', () {
      final widget = ExperienceHostScreen(package: _runnablePackage());
      expect(widget.runtimeSupervisor, isNull);
      expect(widget.runtimeController, isNull);
    });

    testWidgets('every pre-R40 widget behavior (load, dispose) is unaffected when no runtimeSupervisor is injected', (tester) async {
      final before = _runnablePackage(experienceId: 'exp-compat');
      final runtime = AnythingRuntime();
      await runtime.openExperience(before);

      await tester.pumpWidget(MaterialApp(home: ExperienceHostScreen(package: before, experienceId: 'exp-compat', runtime: runtime)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();

      expect(find.text('Home'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull, reason: 'dispose() must not throw when no supervisor was ever injected');
    });

    testWidgets('a real, injected WorkspaceRuntimeSupervisor receives a registration once the screen loads, and an unregistration on dispose', (tester) async {
      // Real SQLite/Kernel I/O (`_Rig.create()`/`openRealSession()`) must run
      // inside `tester.runAsync()` when called from within a `testWidgets`
      // callback — that callback body runs in a FakeAsync zone, which never
      // completes real, native async I/O on its own (confirmed the hard way:
      // calling these directly, un-wrapped, deterministically hung for the
      // full 10-minute test timeout, reproduced twice). No prior test file
      // in this codebase ever calls `_Rig.create()` from inside
      // `testWidgets` for exactly this reason — every one of them keeps real
      // `_Rig` work in a plain `test()` block instead.
      late _Rig rig;
      late String experienceId;
      late ExperiencePackage pkg;
      final supervisor = WorkspaceRuntimeSupervisor();
      final runtime = AnythingRuntime();
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log')]);
        experienceId = await rig.openRealSession();
        pkg = _runnablePackage(experienceId: experienceId);
        await runtime.openExperience(pkg);
      });

      await tester.pumpWidget(
        MaterialApp(home: ExperienceHostScreen(package: pkg, experienceId: experienceId, runtime: runtime, workspaceManager: rig.workspace, runtimeSupervisor: supervisor)),
      );
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();

      final sessionId = rig.workspace.sessionForExperience(experienceId)!.sessionId;
      expect(supervisor.lookup(sessionId), isNotNull, reason: 'the live screen must have auto-registered its real controller once loaded');

      await tester.pumpWidget(const SizedBox());
      expect(supervisor.lookup(sessionId), isNull, reason: 'dispose() must have auto-unregistered the same registration');

      await rig.repository.close();
    });
  });

  group('Performance (R40) — real Stopwatch/ProcessInfo.currentRss measurements, never fabricated', () {
    test('registration / lookup latency', () async {
      final supervisor = WorkspaceRuntimeSupervisor();
      final controller = await _startedController('exp-perf');

      final sw = Stopwatch()..start();
      supervisor.register('s-perf', controller);
      supervisor.lookup('s-perf');
      sw.stop();
      // ignore: avoid_print
      print('R40 single register()+lookup(): ${sw.elapsedMicroseconds}us');
    });

    test('100-controller registration + lookup', () async {
      final supervisor = WorkspaceRuntimeSupervisor();
      final controllers = <ExperienceRuntimeController>[];
      for (var i = 0; i < 100; i++) {
        controllers.add(ExperienceRuntimeController(runtime: AnythingRuntime()));
      }

      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        supervisor.register('s$i', controllers[i]);
      }
      for (var i = 0; i < 100; i++) {
        supervisor.lookup('s$i');
      }
      sw.stop();
      // ignore: avoid_print
      print('R40 100-controller register()+lookup(): ${sw.elapsedMicroseconds}us');
    });

    test('pause-all latency across N registered controllers', () async {
      final supervisor = WorkspaceRuntimeSupervisor();
      const engine = WorkspaceLifecyclePolicyEngine();
      for (var i = 0; i < 20; i++) {
        supervisor.register('s$i', await _startedController('exp-$i'));
      }

      final sw = Stopwatch()..start();
      await supervisor.applyAppLifecyclePolicy(AppLifecycleState.paused, engine);
      sw.stop();
      // ignore: avoid_print
      print('R40 applyAppLifecyclePolicy(paused) across 20 controllers: ${sw.elapsedMicroseconds}us');
    });

    test('memory: real process RSS delta across repeated register/unregister cycles', () async {
      final rssBefore = ProcessInfo.currentRss;
      final supervisor = WorkspaceRuntimeSupervisor();
      for (var i = 0; i < 10; i++) {
        final controller = await _startedController('exp-mem-$i');
        supervisor.register('s-mem-$i', controller);
        await controller.terminate();
        supervisor.unregister('s-mem-$i');
      }
      final rssAfter = ProcessInfo.currentRss;
      // ignore: avoid_print
      print('R40 memory: RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 10 register/unregister cycles');
    });
  });
}
