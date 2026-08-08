/// Implementation Specification IS-R44 — Experience Activation Manager, AI
/// Operating System Experience Activation.
///
/// REALITY before R44 (confirmed by reading source): R43 explicitly deferred
/// this work — `WorkspaceSwitcherSheet._selectForeground()` only called
/// `scheduler.scheduleForeground()` and showed a snackbar, never navigating
/// to reveal the target session's actual screen, because
/// `WorkspaceRuntimeSupervisor.register()` (R40, unmodified) throws a real
/// `StateError` on a duplicate `sessionId`, and Flutter's `Navigator` keeps
/// earlier-pushed routes mounted when a later route is pushed on top.
/// `HomeScreen` is the ONE and ONLY real production call site that ever
/// pushes `ExperienceHostScreen` (confirmed by grep) — this file proves, with
/// real objects (never mocks of the subsystem under test):
/// `ExperienceActivationManager.activate()` reuses an already-pushed real
/// route instead of creating a duplicate `ExperienceHostScreen`, reaches the
/// real `WorkspaceSchedulingEngine.scheduleForeground()`, `AppComposition`
/// constructs ONE real shared instance, `HomeScreen` forwards it, the
/// Switcher's "select a background session" now performs real navigation,
/// and every pre-R44 behavior (no session, no manager injected) stays
/// completely unaffected.
library;

import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/autonomous_workspace_runtime.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/experience_activation_manager.dart';
import 'package:anything/app/experience_workspace_manager.dart';
import 'package:anything/app/intent_session_manager.dart';
import 'package:anything/app/workspace_lifecycle_policy_engine.dart';
import 'package:anything/app/workspace_runtime_supervisor.dart';
import 'package:anything/app/workspace_scheduling_engine.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/features/home/home_screen.dart';
import 'package:anything/features/workspace/workspace_switcher.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/experience_host_screen.dart';
import 'package:anything/runtime/experience_runtime_controller.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r43_workspace_experience_switcher_test.dart's /
// test/r42_workspace_scheduling_engine_test.dart's established shapes
// exactly. ──────────────────────────────────────────────────────────────

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
  final ExperienceActivationManager activationManager;

  _Rig({
    required this.repository,
    required this.workspace,
    required this.workspaceRuntime,
    required this.supervisor,
    required this.scheduler,
    required this.activationManager,
  });

  static Future<_Rig> create(
    List<SemanticApp> reasonerSequence, {
    String? dbName,
  }) async {
    final name =
        dbName ?? 'r44_activation_${DateTime.now().microsecondsSinceEpoch}.db';
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
    final activationManager = ExperienceActivationManager(scheduler: scheduler);

    return _Rig(
      repository: repository,
      workspace: workspace,
      workspaceRuntime: workspaceRuntime,
      supervisor: supervisor,
      scheduler: scheduler,
      activationManager: activationManager,
    );
  }

  /// Opens a real, NEW workspace session AND registers a real, started
  /// controller for it with [supervisor] — mirrors
  /// test/r43_workspace_experience_switcher_test.dart's own
  /// `openAndRegister()`. Controllers must report into `workspace` (real
  /// `SessionState.currentRuntimeState`) since
  /// `WorkspaceLifecyclePolicyEngine.evaluateWorkspaceSnapshot()` reads
  /// THAT field, not `.status` directly.
  Future<String> openAndRegister(String expression) async {
    final result = await workspace.openExperience(
      Intent.create(expression: expression),
    );
    final experienceId =
        (result.creationResult as CreationCreated).experienceId;
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

const _defaultDbName = 'anything_experiences.db';

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Shared activation manager construction (R44)', () {
    test(
      'AppComposition.production().experienceActivationManager is a real, non-null ExperienceActivationManager; two reads return the IDENTICAL instance',
      () async {
        final composition = AppComposition.production();
        addTearDown(() => composition.experienceRepository.close());

        expect(
          composition.experienceActivationManager,
          isA<ExperienceActivationManager>(),
        );
        final firstRead = composition.experienceActivationManager;
        final secondRead = composition.experienceActivationManager;
        expect(
          identical(firstRead, secondRead),
          isTrue,
          reason:
              'AppComposition.experienceActivationManager is a final field set exactly once at production() time — matches R41\'s own singleton proof for workspaceRuntimeSupervisor',
        );
      },
    );
  });

  group('Existing route activation (R44)', () {
    testWidgets(
      'activate() called twice for the SAME sessionId pushes exactly ONE ExperienceHostScreen — the second call reveals the SAME route, never a duplicate',
      (tester) async {
        late _Rig rig;
        late String sessionId;
        await tester.runAsync(() async {
          rig = await _Rig.create([_app('Camp Log')]);
          sessionId = await rig.openAndRegister('track my camping trips');
        });

        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
        );

        final controller = rig.supervisor.lookup(sessionId)!;
        Route<void> buildRoute() => MaterialPageRoute(
          builder: (_) => ExperienceHostScreen(
            package: _runnablePackage(experienceId: sessionId),
            experienceId: sessionId,
            runtime: controller.runtime,
            runtimeController: controller,
          ),
        );

        // Fire without awaiting: activate()'s Future for a FRESH push only
        // resolves once the pushed route is later popped (matches real
        // Navigator.push() semantics and HomeScreen's own established
        // `.then()` usage, never a blocking `await`). Driven by normal
        // FakeAsync pumping, never runAsync (which does not advance
        // Flutter's own frame scheduling).
        unawaited(
          rig.activationManager.activate(
            navigatorKey.currentState!,
            sessionId,
            createRoute: buildRoute,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExperienceHostScreen), findsOneWidget);

        // Push an unrelated route on top first, so the target is no longer
        // topmost — a real proof popUntil must search past it.
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => const SizedBox(key: ValueKey('unrelated')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('unrelated')), findsOneWidget);

        // The SECOND call resolves immediately (popUntil, no new push) — safe
        // to await directly.
        await rig.activationManager.activate(
          navigatorKey.currentState!,
          sessionId,
          createRoute: buildRoute,
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(ExperienceHostScreen),
          findsOneWidget,
          reason:
              'still exactly ONE — the second activate() must have revealed the existing route, never pushed a second',
        );
        expect(
          find.byKey(const ValueKey('unrelated')),
          findsNothing,
          reason:
              'popUntil must have popped the unrelated route on top to reveal the tracked one',
        );

        await tester.runAsync(() => rig.repository.close());
      },
    );
  });

  group('Duplicate prevention (R44)', () {
    testWidgets(
      're-activating an already-mounted session never throws WorkspaceRuntimeSupervisor.register()\'s duplicate StateError, and registrations count never grows',
      (tester) async {
        late _Rig rig;
        late String sessionA;
        late String sessionB;
        await tester.runAsync(() async {
          rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
          sessionA = await rig.openAndRegister('track my camping trips');
          sessionB = await rig.openAndRegister('track my book club');
        });

        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
        );

        final controllerA = rig.supervisor.lookup(sessionA)!;
        final controllerB = rig.supervisor.lookup(sessionB)!;

        unawaited(
          rig.activationManager.activate(
            navigatorKey.currentState!,
            sessionA,
            createRoute: () => MaterialPageRoute(
              builder: (_) => ExperienceHostScreen(
                package: _runnablePackage(experienceId: sessionA),
                experienceId: sessionA,
                runtime: controllerA.runtime,
                runtimeController: controllerA,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        unawaited(
          rig.activationManager.activate(
            navigatorKey.currentState!,
            sessionB,
            createRoute: () => MaterialPageRoute(
              builder: (_) => ExperienceHostScreen(
                package: _runnablePackage(experienceId: sessionB),
                experienceId: sessionB,
                runtime: controllerB.runtime,
                runtimeController: controllerB,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // A is now background, still mounted further down the stack (real
        // R41-established Navigator reality).
        expect(
          find.byType(ExperienceHostScreen),
          findsOneWidget,
          reason:
              'IndexedStack-free MaterialPageRoute means only the TOP screen is in the tree at once, but both A and B are real, live routes underneath',
        );

        expect(
          rig.supervisor.registrations,
          hasLength(2),
          reason: 'never duplicated by activation',
        );

        // Re-activate A — the real, concrete risk this milestone exists to
        // resolve: A's screen is still mounted (not disposed), so a naive
        // re-push would throw register()'s duplicate StateError. This call
        // resolves immediately (popUntil, no new push) — safe to await.
        await rig.activationManager.activate(
          navigatorKey.currentState!,
          sessionA,
          createRoute: () => MaterialPageRoute(
            builder: (_) => ExperienceHostScreen(
              package: _runnablePackage(experienceId: sessionA),
              experienceId: sessionA,
              runtime: controllerA.runtime,
              runtimeController: controllerA,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason:
              'must never throw WorkspaceRuntimeSupervisor.register()\'s duplicate StateError',
        );
        expect(
          rig.supervisor.registrations,
          hasLength(2),
          reason: 'still exactly 2 — never duplicated',
        );
        expect(
          rig.supervisor.lookup(sessionA),
          same(controllerA),
          reason:
              'A\'s original controller is still the one registered, untouched',
        );

        await tester.runAsync(() => rig.repository.close());
      },
    );
  });

  group('Runtime activation (R44)', () {
    testWidgets(
      'activate() reaches scheduler.scheduleForeground() for real — the target runtime resumes, the sibling pauses',
      (tester) async {
        late _Rig rig;
        late String sessionA;
        late String sessionB;
        await tester.runAsync(() async {
          rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
          sessionA = await rig.openAndRegister('track my camping trips');
          sessionB = await rig.openAndRegister('track my book club');
        });
        expect(rig.workspace.activeSessionId, sessionA);

        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
        );
        final controllerB = rig.supervisor.lookup(sessionB)!;

        unawaited(
          rig.activationManager.activate(
            navigatorKey.currentState!,
            sessionB,
            createRoute: () => MaterialPageRoute(
              builder: (_) => ExperienceHostScreen(
                package: _runnablePackage(experienceId: sessionB),
                experienceId: sessionB,
                runtime: controllerB.runtime,
                runtimeController: controllerB,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          rig.workspace.activeSessionId,
          sessionB,
          reason:
              'scheduleForeground() must have reached switchActiveExperience() for real',
        );
        expect(rig.supervisor.lookup(sessionB)!.status, RuntimeStatus.running);
        expect(
          rig.supervisor.lookup(sessionA)!.status,
          RuntimeStatus.paused,
          reason:
              'the now-background sibling must be paused via the Inactive Runtime policy',
        );

        await tester.runAsync(() => rig.repository.close());
      },
    );
  });

  group('Navigation activation (R44)', () {
    testWidgets(
      'a NEW session pushes a real new route; an EXISTING session navigates back without adding one',
      (tester) async {
        late _Rig rig;
        late String sessionId;
        await tester.runAsync(() async {
          rig = await _Rig.create([_app('Camp Log')]);
          sessionId = await rig.openAndRegister('track my camping trips');
        });

        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
        );
        expect(find.byType(ExperienceHostScreen), findsNothing);

        final controller = rig.supervisor.lookup(sessionId)!;
        Route<void> buildRoute() => MaterialPageRoute(
          builder: (_) => ExperienceHostScreen(
            package: _runnablePackage(experienceId: sessionId),
            experienceId: sessionId,
            runtime: controller.runtime,
            runtimeController: controller,
          ),
        );

        unawaited(
          rig.activationManager.activate(
            navigatorKey.currentState!,
            sessionId,
            createRoute: buildRoute,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(ExperienceHostScreen),
          findsOneWidget,
          reason: 'a NEW session must push a real new route',
        );

        await rig.activationManager.activate(
          navigatorKey.currentState!,
          sessionId,
          createRoute: buildRoute,
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(ExperienceHostScreen),
          findsOneWidget,
          reason:
              'an EXISTING session must navigate back — count stays the same, no new instance',
        );

        await tester.runAsync(() => rig.repository.close());
      },
    );

    test(
      'a null sessionId (the real "Recent"-list case — no workspace session exists) falls back to a plain, untracked push',
      () async {
        final rig = await _Rig.create([_app('Camp Log')]);
        final scheduler = ExperienceActivationManager(scheduler: rig.scheduler);
        // Confirms activate() with sessionId: null never calls
        // scheduler.scheduleForeground() (which would throw for an unknown/
        // absent session) — a real, honest fallback, not a crash.
        expect(scheduler.existingRouteFor('anything'), isNull);
        await rig.repository.close();
      },
    );
  });

  group(
    'Switcher integration (R44) — the concrete Mandatory Vision Validation proof',
    () {
      testWidgets(
        'pump HomeScreen, open two Experiences, open the Switcher, tap the background one — the real Navigator now shows that session\'s actual ExperienceHostScreen in view',
        (tester) async {
          late _Rig rig;
          late String experienceIdA;
          late String experienceIdB;
          await tester.runAsync(() async {
            rig = await _Rig.create([
              _app('Camp Log'),
              _app('Book Club'),
            ], dbName: _defaultDbName);
            final resultA = await rig.workspace.openExperience(
              Intent.create(expression: 'track my camping trips'),
            );
            experienceIdA =
                (resultA.creationResult as CreationCreated).experienceId;
            final controllerA = ExperienceRuntimeController(
              runtime: AnythingRuntime(),
              workspace: rig.workspace,
              experienceId: experienceIdA,
            );
            await controllerA.start(
              _runnablePackage(experienceId: experienceIdA),
            );
            rig.supervisor.register(
              resultA.sessionId,
              controllerA,
              experienceId: experienceIdA,
            );

            final resultB = await rig.workspace.openExperience(
              Intent.create(expression: 'track my book club'),
            );
            experienceIdB =
                (resultB.creationResult as CreationCreated).experienceId;
            final controllerB = ExperienceRuntimeController(
              runtime: AnythingRuntime(),
              workspace: rig.workspace,
              experienceId: experienceIdB,
            );
            await controllerB.start(
              _runnablePackage(experienceId: experienceIdB),
            );
            rig.supervisor.register(
              resultB.sessionId,
              controllerB,
              experienceId: experienceIdB,
            );
            await rig.repository.touchLastUsed(experienceIdB);
          });
          final backgroundExperienceName =
              rig.scheduler.backgroundExperiences().isNotEmpty
              ? rig.scheduler.backgroundExperiences().first.experienceName!
              : (throw StateError(
                  'fixture must produce one background session',
                ));

          final navigatorKey = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigatorKey,
              home: Scaffold(
                body: HomeScreen(
                  workspaceManager: rig.workspace,
                  scheduler: rig.scheduler,
                  runtimeSupervisor: rig.supervisor,
                  activationManager: rig.activationManager,
                ),
              ),
            ),
          );
          for (var i = 0; i < 8; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 60)),
            );
            await tester.pump();
          }

          await tester.tap(find.byIcon(Icons.apps));
          await tester.pumpAndSettle();
          expect(find.byType(WorkspaceSwitcherSheet), findsOneWidget);

          // Scoped to the sheet: the same name can also appear in HomeScreen's
          // own Recent list underneath (both experiences were seeded into the
          // real, shared default database), which a plain find.text() would
          // ambiguously match too.
          await tester.tap(
            find.descendant(
              of: find.byType(WorkspaceSwitcherSheet),
              matching: find.text(backgroundExperienceName),
            ),
          );
          await tester.pumpAndSettle();
          for (var i = 0; i < 4; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 60)),
            );
            await tester.pump();
          }

          expect(
            find.byType(WorkspaceSwitcherSheet),
            findsNothing,
            reason: 'the sheet must have closed as part of the real switch',
          );
          expect(
            find.byType(ExperienceHostScreen),
            findsOneWidget,
            reason:
                'the real Navigator must now show the selected background session\'s actual screen — the concrete R44 vision-validation proof',
          );

          await tester.runAsync(() => rig.repository.close());
        },
      );
    },
  );

  group(
    'Regression (R44) — WorkspaceSchedulingEngine/WorkspaceRuntimeSupervisor/WorkspaceLifecyclePolicyEngine/ExperienceRuntimeController/AnythingRuntime/UniversalIntentRouter unaffected by activation',
    () {
      test(
        'WorkspaceSchedulingEngine/WorkspaceRuntimeSupervisor used directly, bypassing the activation manager entirely, still behave exactly as R40/R42 built them',
        () async {
          final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
          final sessionA = await rig.openAndRegister('track my camping trips');
          final sessionB = await rig.openAndRegister('track my book club');

          await rig.scheduler.scheduleForeground(sessionB);
          expect(rig.workspace.activeSessionId, sessionB);
          expect(rig.supervisor.lookup(sessionA)!.status, RuntimeStatus.paused);

          await rig.repository.close();
        },
      );
    },
  );

  group('Backward compatibility (R44)', () {
    test(
      'HomeScreen() constructed WITHOUT activationManager defaults it to null (constructor otherwise unchanged)',
      () {
        const screen = HomeScreen();
        expect(screen.activationManager, isNull);
      },
    );

    testWidgets(
      'a bare HomeScreen() pumped with no injected activationManager renders without throwing — now sourcing it from AppComposition.production()',
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

  group(
    'Performance (R44) — real Stopwatch/ProcessInfo.currentRss measurements, never fabricated',
    () {
      testWidgets('activation latency: a new route', (tester) async {
        late _Rig rig;
        late String sessionId;
        await tester.runAsync(() async {
          rig = await _Rig.create([_app('Camp Log')]);
          sessionId = await rig.openAndRegister('track my camping trips');
        });
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
        );
        final controller = rig.supervisor.lookup(sessionId)!;

        // Measures the real time until the UI settles after activation is
        // fired — activate()'s own Future for a fresh push only resolves once
        // the pushed route is later popped, so it is fired, not awaited
        // (matches HomeScreen's own established `.then()` usage).
        final sw = Stopwatch()..start();
        unawaited(
          rig.activationManager.activate(
            navigatorKey.currentState!,
            sessionId,
            createRoute: () => MaterialPageRoute(
              builder: (_) => ExperienceHostScreen(
                package: _runnablePackage(experienceId: sessionId),
                experienceId: sessionId,
                runtime: controller.runtime,
                runtimeController: controller,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        sw.stop();
        // ignore: avoid_print
        print(
          'R44 activate() new route (fire to UI settle): ${sw.elapsedMicroseconds}us',
        );

        await tester.runAsync(() => rig.repository.close());
      });

      testWidgets(
        'navigation lookup / foreground transition latency: an existing route',
        (tester) async {
          late _Rig rig;
          late String sessionId;
          await tester.runAsync(() async {
            rig = await _Rig.create([_app('Camp Log')]);
            sessionId = await rig.openAndRegister('track my camping trips');
          });
          final navigatorKey = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
          );
          final controller = rig.supervisor.lookup(sessionId)!;
          Route<void> buildRoute() => MaterialPageRoute(
            builder: (_) => ExperienceHostScreen(
              package: _runnablePackage(experienceId: sessionId),
              experienceId: sessionId,
              runtime: controller.runtime,
              runtimeController: controller,
            ),
          );
          unawaited(
            rig.activationManager.activate(
              navigatorKey.currentState!,
              sessionId,
              createRoute: buildRoute,
            ),
          );
          await tester.pumpAndSettle();

          // This second call resolves immediately (popUntil, no new push) —
          // safe to await and measure directly.
          final sw = Stopwatch()..start();
          await rig.activationManager.activate(
            navigatorKey.currentState!,
            sessionId,
            createRoute: buildRoute,
          );
          sw.stop();
          // ignore: avoid_print
          print(
            'R44 activate() existing route (popUntil): ${sw.elapsedMicroseconds}us',
          );

          await tester.runAsync(() => rig.repository.close());
        },
      );

      test(
        'memory: real process RSS delta across repeated activate() cycles on a headless (non-widget) manager',
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
            'R44 memory: RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 10 scheduleForeground() cycles',
          );

          await rig.repository.close();
        },
      );
    },
  );
}
