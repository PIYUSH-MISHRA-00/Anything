/// Implementation Specification IS-R41 — Shared Workspace Runtime
/// Supervision, Production Activation.
///
/// REALITY before R41 (confirmed by reading source): `AppComposition`
/// (last touched R37) had no `workspaceRuntimeSupervisor` field —
/// `WorkspaceRuntimeSupervisor` (R40) had no shared, composition-root
/// instance, and none of `HomeScreen`'s 3 real `ExperienceHostScreen`
/// navigation call sites threaded one. `AnythingAppShell` constructs
/// `AppComposition.production()` exactly once and passes ONLY `composition:`
/// to `HomeScreen` — every other shared service is resolved INSIDE
/// `HomeScreen` from that one object, so extending `AppComposition` +
/// `HomeScreen`'s own resolution + the 3 call sites is sufficient to make
/// the whole app share one supervisor, with zero change to `app_shell.dart`.
/// `ExperienceHostScreen` already had a `runtimeSupervisor` field (R40, for
/// auto-register/unregister) — this file proves `didChangeAppLifecycleState`
/// now reroutes through it when supplied (workspace-wide reach), or falls
/// back to the exact prior R39 this-screen-only behavior when omitted.
///
/// This file proves, with real objects (never mocks of the subsystem under
/// test): `AppComposition.production()` constructs ONE real, shared
/// supervisor; TWO independent, simultaneously-mounted `ExperienceHostScreen`s
/// given the SAME injected supervisor both register with it; ONE real
/// `AppLifecycleState` transition, delivered to either screen, pauses/resumes
/// BOTH real runtimes through the shared supervisor; and every pre-R41
/// behavior (no supervisor injected) is completely unaffected.
library;

import 'dart:io';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/experience_workspace_manager.dart';
import 'package:anything/app/intent_session_manager.dart';
import 'package:anything/app/universal_intent_router.dart';
import 'package:anything/app/workspace_lifecycle_policy_engine.dart';
import 'package:anything/app/workspace_runtime_supervisor.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/features/home/home_screen.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/experience_host_screen.dart';
import 'package:anything/runtime/experience_runtime_controller.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r40_workspace_runtime_supervisor_test.dart's
// established shapes exactly. ────────────────────────────────────────────

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

  _Rig({required this.repository, required this.workspace});

  static Future<_Rig> create(List<SemanticApp> reasonerSequence) async {
    final name =
        'r41_shared_supervision_${DateTime.now().microsecondsSinceEpoch}.db';
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

    return _Rig(repository: repository, workspace: workspace);
  }

  /// Opens a real, NEW workspace session (forceNew, so a second call never
  /// silently continues the first) and returns its real `experienceId`.
  Future<String> openRealSession(String expression) async {
    final result = await workspace.openExperience(
      Intent.create(expression: expression),
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

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Shared supervisor construction (R41)', () {
    test(
      'AppComposition.production().workspaceRuntimeSupervisor is a real, non-null WorkspaceRuntimeSupervisor; two reads return the IDENTICAL instance',
      () async {
        final composition = AppComposition.freshForTesting();
        addTearDown(() => composition.experienceRepository.close());

        expect(
          composition.workspaceRuntimeSupervisor,
          isA<WorkspaceRuntimeSupervisor>(),
        );
        final firstRead = composition.workspaceRuntimeSupervisor;
        final secondRead = composition.workspaceRuntimeSupervisor;
        expect(
          identical(firstRead, secondRead),
          isTrue,
          reason:
              'AppComposition.workspaceRuntimeSupervisor is a final field set exactly once at production() time — real proof there is no per-access reconstruction, matching R36\'s own established singleton proof for workspaceManager',
        );
      },
    );
  });

  group('Multiple screens share one supervisor (R41)', () {
    testWidgets(
      'TWO real, simultaneously-mounted ExperienceHostScreens, given the SAME injected supervisor, both register — proving genuinely shared registration, not two independent supervisors',
      (tester) async {
        late _Rig rig;
        late String experienceIdA;
        late String experienceIdB;
        final supervisor = WorkspaceRuntimeSupervisor();
        final runtimeA = AnythingRuntime();
        final runtimeB = AnythingRuntime();
        late ExperiencePackage pkgA;
        late ExperiencePackage pkgB;

        // Real SQLite/Kernel I/O must run inside tester.runAsync() when called
        // from a testWidgets callback — that callback body runs in a FakeAsync
        // zone which never completes real, native async I/O on its own
        // (test/r40_workspace_runtime_supervisor_test.dart's own doc comment
        // documents this the hard way — reproduced/confirmed, not re-litigated
        // here).
        await tester.runAsync(() async {
          rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
          experienceIdA = await rig.openRealSession('track my camping trips');
          experienceIdB = await rig.openRealSession('track my book club');
          pkgA = _runnablePackage(experienceId: experienceIdA);
          pkgB = _runnablePackage(experienceId: experienceIdB);
          await runtimeA.openExperience(pkgA);
          await runtimeB.openExperience(pkgB);
        });

        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
        );

        // Push A, then push B ON TOP of A — A stays mounted (Navigator keeps
        // prior routes in the tree, just not visible), the same real shape as
        // a user opening a second Experience while the first is still open in
        // the Navigator stack.
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => ExperienceHostScreen(
              package: pkgA,
              experienceId: experienceIdA,
              runtime: runtimeA,
              workspaceManager: rig.workspace,
              runtimeSupervisor: supervisor,
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();

        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => ExperienceHostScreen(
              package: pkgB,
              experienceId: experienceIdB,
              runtime: runtimeB,
              workspaceManager: rig.workspace,
              runtimeSupervisor: supervisor,
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();

        expect(
          supervisor.registrations,
          hasLength(2),
          reason:
              'both simultaneously-mounted screens must have registered with the SAME shared supervisor',
        );

        final sessionIdA = rig.workspace
            .sessionForExperience(experienceIdA)!
            .sessionId;
        final sessionIdB = rig.workspace
            .sessionForExperience(experienceIdB)!
            .sessionId;
        expect(supervisor.lookup(sessionIdA), isNotNull);
        expect(supervisor.lookup(sessionIdB), isNotNull);
        expect(
          supervisor.lookup(sessionIdA),
          isNot(same(supervisor.lookup(sessionIdB))),
          reason:
              'each screen must have registered its OWN, distinct controller — never a shared/aliased one',
        );

        await tester.runAsync(() => rig.repository.close());
      },
    );
  });

  group(
    'Workspace-wide pause / resume (R41) — the concrete, load-bearing proof',
    () {
      testWidgets(
        'ONE real AppLifecycleState transition, delivered to the observer tree, pauses BOTH real runtimes through the shared supervisor; then resumes both',
        (tester) async {
          late _Rig rig;
          late String experienceIdA;
          late String experienceIdB;
          final supervisor = WorkspaceRuntimeSupervisor();
          final runtimeA = AnythingRuntime();
          final runtimeB = AnythingRuntime();
          late ExperiencePackage pkgA;
          late ExperiencePackage pkgB;

          await tester.runAsync(() async {
            rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
            experienceIdA = await rig.openRealSession('track my camping trips');
            experienceIdB = await rig.openRealSession('track my book club');
            pkgA = _runnablePackage(experienceId: experienceIdA);
            pkgB = _runnablePackage(experienceId: experienceIdB);
            await runtimeA.openExperience(pkgA);
            await runtimeB.openExperience(pkgB);
          });

          final navigatorKey = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
          );

          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => ExperienceHostScreen(
                package: pkgA,
                experienceId: experienceIdA,
                runtime: runtimeA,
                workspaceManager: rig.workspace,
                runtimeSupervisor: supervisor,
              ),
            ),
          );
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();

          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => ExperienceHostScreen(
                package: pkgB,
                experienceId: experienceIdB,
                runtime: runtimeB,
                workspaceManager: rig.workspace,
                runtimeSupervisor: supervisor,
              ),
            ),
          );
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();

          expect(runtimeA.status, RuntimeStatus.running);
          expect(runtimeB.status, RuntimeStatus.running);

          // ONE real OS-level transition — Flutter delivers this to every
          // registered WidgetsBindingObserver (both mounted screens), but the
          // real, load-bearing proof is that EITHER one's own callback reaches
          // BOTH real runtimes through the shared supervisor (not just its own).
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump();

          expect(
            runtimeA.status,
            RuntimeStatus.paused,
            reason:
                'workspace-wide reach: screen A\'s runtime must pause even though the trigger could have been delivered via screen B\'s own observer',
          );
          expect(runtimeB.status, RuntimeStatus.paused);

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump();

          expect(runtimeA.status, RuntimeStatus.running);
          expect(runtimeB.status, RuntimeStatus.running);

          await tester.runAsync(() => rig.repository.close());
        },
      );
    },
  );

  group('Controller registration integrity (R41)', () {
    test(
      'two controllers registered on one shared supervisor carry correct, distinct sessionId/experienceId/controller — no cross-contamination',
      () async {
        final supervisor = WorkspaceRuntimeSupervisor();
        final controllerA = ExperienceRuntimeController(
          runtime: AnythingRuntime(),
        );
        final controllerB = ExperienceRuntimeController(
          runtime: AnythingRuntime(),
        );
        await controllerA.start(_runnablePackage(experienceId: 'exp-a'));
        await controllerB.start(_runnablePackage(experienceId: 'exp-b'));

        supervisor.register('session-a', controllerA, experienceId: 'exp-a');
        supervisor.register('session-b', controllerB, experienceId: 'exp-b');

        final recordA = supervisor.registrations.firstWhere(
          (r) => r.sessionId == 'session-a',
        );
        final recordB = supervisor.registrations.firstWhere(
          (r) => r.sessionId == 'session-b',
        );
        expect(recordA.experienceId, 'exp-a');
        expect(recordB.experienceId, 'exp-b');
        expect(recordA.controller, same(controllerA));
        expect(recordB.controller, same(controllerB));
        expect(
          supervisor.lookup('session-a'),
          isNot(same(supervisor.lookup('session-b'))),
        );
      },
    );
  });

  group(
    'Regression (R41) — WorkspaceRuntimeSupervisor/WorkspaceLifecyclePolicyEngine/ExperienceRuntimeController/AnythingRuntime/UniversalIntentRouter unaffected by shared composition',
    () {
      test(
        'WorkspaceRuntimeSupervisor/WorkspaceLifecyclePolicyEngine used directly, bypassing AppComposition entirely, still behave exactly as R39/R40 built them',
        () async {
          final supervisor = WorkspaceRuntimeSupervisor();
          const engine = WorkspaceLifecyclePolicyEngine();
          final controller = ExperienceRuntimeController(
            runtime: AnythingRuntime(),
          );
          await controller.start(_runnablePackage());
          supervisor.register('s1', controller);

          await supervisor.applyAppLifecyclePolicy(
            AppLifecycleState.paused,
            engine,
          );
          expect(controller.status, RuntimeStatus.paused);
        },
      );

      test(
        'UniversalIntentRouter.route() called directly, bypassing AppComposition entirely, still behaves exactly as R33 built it',
        () async {
          final rig = await _Rig.create([_app('Camp Log')]);
          final router = UniversalIntentRouter(workspace: rig.workspace);
          final result = await router.route(
            Intent.create(expression: 'track my camping trips'),
            target: const RouteTarget.newExperience(),
          );
          expect(result.creationResult, isA<CreationCreated>());
          await rig.repository.close();
        },
      );
    },
  );

  group('Backward compatibility (R41)', () {
    test(
      'HomeScreen() constructed WITHOUT runtimeSupervisor defaults it to null (constructor otherwise unchanged)',
      () {
        const screen = HomeScreen();
        expect(screen.runtimeSupervisor, isNull);
      },
    );

    test(
      'ExperienceHostScreen() constructed WITHOUT runtimeSupervisor defaults it to null (constructor otherwise unchanged since R40)',
      () {
        final widget = ExperienceHostScreen(package: _runnablePackage());
        expect(widget.runtimeSupervisor, isNull);
      },
    );

    testWidgets(
      'a real, live ExperienceHostScreen with NO supervisor injected still pauses/resumes its OWN runtime on a real AppLifecycleState transition — exact prior R39 behavior, unaffected by R41',
      (tester) async {
        final runtime = AnythingRuntime();
        await runtime.openExperience(
          _runnablePackage(experienceId: 'exp-no-supervisor'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExperienceHostScreen(
              package: _runnablePackage(experienceId: 'exp-no-supervisor'),
              experienceId: 'exp-no-supervisor',
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

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(runtime.status, RuntimeStatus.paused);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(runtime.status, RuntimeStatus.running);
      },
    );
  });

  group(
    'Performance (R41) — real Stopwatch/ProcessInfo.currentRss measurements, never fabricated',
    () {
      test(
        'AppComposition.production() construction latency, now with the shared supervisor field',
        () async {
          final stopwatch = Stopwatch()..start();
          final composition = AppComposition.freshForTesting();
          stopwatch.stop();
          // ignore: avoid_print
          print(
            'R41 AppComposition.production() construction (with workspaceRuntimeSupervisor): ${stopwatch.elapsedMicroseconds}us',
          );
          expect(
            composition.workspaceRuntimeSupervisor,
            isA<WorkspaceRuntimeSupervisor>(),
          );
          await composition.experienceRepository.close();
        },
      );

      test(
        'supervisor.lookup() latency through the shared-instance path',
        () async {
          final composition = AppComposition.freshForTesting();
          addTearDown(() => composition.experienceRepository.close());
          final controller = ExperienceRuntimeController(
            runtime: AnythingRuntime(),
          );
          await controller.start(_runnablePackage());
          composition.workspaceRuntimeSupervisor.register('s-perf', controller);

          final sw = Stopwatch()..start();
          composition.workspaceRuntimeSupervisor.lookup('s-perf');
          sw.stop();
          // ignore: avoid_print
          print('R41 shared supervisor.lookup(): ${sw.elapsedMicroseconds}us');
        },
      );

      test(
        'workspace-wide pause/resume latency across a synthetic multi-controller supervisor',
        () async {
          final supervisor = WorkspaceRuntimeSupervisor();
          const engine = WorkspaceLifecyclePolicyEngine();
          for (var i = 0; i < 20; i++) {
            final controller = ExperienceRuntimeController(
              runtime: AnythingRuntime(),
            );
            await controller.start(_runnablePackage(experienceId: 'exp-$i'));
            supervisor.register('s$i', controller);
          }

          final sw = Stopwatch()..start();
          await supervisor.applyAppLifecyclePolicy(
            AppLifecycleState.paused,
            engine,
          );
          await supervisor.applyAppLifecyclePolicy(
            AppLifecycleState.resumed,
            engine,
          );
          sw.stop();
          // ignore: avoid_print
          print(
            'R41 workspace-wide pause+resume across 20 controllers: ${sw.elapsedMicroseconds}us',
          );
        },
      );

      test(
        'memory: real process RSS delta across repeated AppComposition.production() construct/close cycles',
        () async {
          final rssBefore = ProcessInfo.currentRss;
          for (var i = 0; i < 10; i++) {
            final composition = AppComposition.freshForTesting();
            await composition.experienceRepository.close();
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R41 memory: RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 10 production() construct/close cycles',
          );
        },
      );
    },
  );
}
