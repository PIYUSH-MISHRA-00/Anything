/// Implementation Specification IS-R43 — Workspace Experience Switcher, AI
/// Operating System Multitasking UI.
///
/// REALITY before R43 (confirmed by reading source): `AppComposition` (last
/// touched R41) had no `WorkspaceSchedulingEngine` field — `HomeScreen`
/// never threaded one into `ExperienceHostScreen`'s own `scheduler` field
/// (added R42, always `null` in production). This file proves, with real
/// objects (never mocks of the subsystem under test):
/// `AppComposition.production().workspaceSchedulingEngine` is a real,
/// shared singleton; the real Switcher widget displays the real
/// active/background sessions read directly from `WorkspaceSchedulingEngine`
/// (never re-deriving workspace bookkeeping itself); selecting a background
/// session reaches the real `scheduleForeground()` (the target runtime
/// resumes, siblings pause); `HomeScreen` forwards the shared scheduler into
/// `ExperienceHostScreen` at its real navigation call site; and every pre-R43
/// behavior stays completely unaffected.
///
/// SCOPE (see `docs/architecture/WORKSPACE_EXPERIENCE_SWITCHER.md` for the
/// full reasoning): the Switcher invokes `scheduleForeground()` for real but
/// does not attempt real navigation-based switching (revealing the target
/// session's actual screen) — `WorkspaceRuntimeSupervisor.register()` throws
/// on a duplicate sessionId, and Flutter's Navigator keeps earlier-pushed
/// routes mounted, so naively re-pushing an already-mounted session's screen
/// would throw. Deferred to R44.
library;

import 'dart:io';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/autonomous_workspace_runtime.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
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

// ── Fixtures — mirrors test/r42_workspace_scheduling_engine_test.dart's own
// established shapes exactly. ─────────────────────────────────────────────

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
  final ExperienceCreationCoordinator creationCoordinator;
  final ExperienceWorkspaceManager workspace;
  final AutonomousWorkspaceRuntime workspaceRuntime;
  final WorkspaceRuntimeSupervisor supervisor;
  final WorkspaceSchedulingEngine scheduler;

  _Rig({
    required this.repository,
    required this.creationCoordinator,
    required this.workspace,
    required this.workspaceRuntime,
    required this.supervisor,
    required this.scheduler,
  });

  static Future<_Rig> create(List<SemanticApp> reasonerSequence, {String? dbName}) async {
    final name = dbName ?? 'r43_switcher_${DateTime.now().microsecondsSinceEpoch}.db';
    final repository = SqliteExperienceRepository(dbName: name);
    final engineeringMemory = EngineeringMemoryRepository(experienceRepository: repository);
    final activity = ActivityRepository();
    final reasoner = _SequencedReasoner(reasonerSequence);
    final kernel = AnythingKernel(providerRegistry: _FakeProviderRegistry(), capabilityRegistry: _registryWithStorage(), reasoner: reasoner);

    final creationCoordinator = ExperienceCreationCoordinator(kernel: kernel, repository: repository, engineeringMemory: engineeringMemory);
    final lifecycleCoordinator = EngineeringLifecycleCoordinator(kernel: kernel, engineeringMemory: engineeringMemory, repository: repository);
    final sessionManager = IntentSessionManager(creationCoordinator: creationCoordinator, lifecycleCoordinator: lifecycleCoordinator, engineeringMemory: engineeringMemory, activity: activity);
    final workspace = ExperienceWorkspaceManager(sessionManager: sessionManager, activity: activity);
    final workspaceRuntime = AutonomousWorkspaceRuntime(workspace: workspace);
    final supervisor = WorkspaceRuntimeSupervisor();
    const policyEngine = WorkspaceLifecyclePolicyEngine();
    final scheduler = WorkspaceSchedulingEngine(workspaceRuntime: workspaceRuntime, supervisor: supervisor, policyEngine: policyEngine, workspace: workspace);

    return _Rig(repository: repository, creationCoordinator: creationCoordinator, workspace: workspace, workspaceRuntime: workspaceRuntime, supervisor: supervisor, scheduler: scheduler);
  }

  /// Opens a real, NEW workspace session AND registers a real, started
  /// controller for it with [supervisor] — mirrors
  /// test/r42_workspace_scheduling_engine_test.dart's own `openAndRegister()`.
  /// Controllers must report into `workspace` (real `SessionState
  /// .currentRuntimeState`) since `WorkspaceLifecyclePolicyEngine
  /// .evaluateWorkspaceSnapshot()` reads THAT field, not `.status` directly.
  Future<String> openAndRegister(String expression) async {
    final result = await workspace.openExperience(Intent.create(expression: expression));
    final experienceId = (result.creationResult as CreationCreated).experienceId;
    final controller = ExperienceRuntimeController(runtime: AnythingRuntime(), workspace: workspace, experienceId: experienceId);
    await controller.start(_runnablePackage(experienceId: experienceId));
    supervisor.register(result.sessionId, controller, experienceId: experienceId);
    return result.sessionId;
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

const _defaultDbName = 'anything_experiences.db';

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Shared scheduler construction (R43)', () {
    test('AppComposition.production().workspaceSchedulingEngine is a real, non-null WorkspaceSchedulingEngine; two reads return the IDENTICAL instance', () async {
      final composition = AppComposition.production();
      addTearDown(() => composition.experienceRepository.close());

      expect(composition.workspaceSchedulingEngine, isA<WorkspaceSchedulingEngine>());
      final firstRead = composition.workspaceSchedulingEngine;
      final secondRead = composition.workspaceSchedulingEngine;
      expect(identical(firstRead, secondRead), isTrue, reason: 'AppComposition.workspaceSchedulingEngine is a final field set exactly once at production() time — no per-access reconstruction, matching R41\'s own singleton proof for workspaceRuntimeSupervisor');
    });
  });

  group('Workspace switcher rendering (R43)', () {
    testWidgets('displays the real active session and every real background session, read directly from WorkspaceSchedulingEngine — never a fabricated or stale list', (tester) async {
      // Real SQLite/Kernel I/O must run inside tester.runAsync() when called
      // from a testWidgets callback — that callback body runs in a FakeAsync
      // zone which never completes real, native async I/O on its own
      // (test/r40_workspace_runtime_supervisor_test.dart's own doc comment
      // documents this the hard way).
      late _Rig rig;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log'), _app('Book Club'), _app('Todo')]);
        await rig.openAndRegister('track my camping trips');
        await rig.openAndRegister('track my book club');
        await rig.openAndRegister('track my todos');
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkspaceSwitcherSheet(scheduler: rig.scheduler))));
      await tester.pump();

      expect(find.text('Camp Log'), findsOneWidget, reason: 'the real active session (first opened) must render');
      expect(find.text('Foreground'), findsOneWidget);
      expect(find.text('Book Club'), findsOneWidget, reason: 'a real background session must render');
      expect(find.text('Todo'), findsOneWidget, reason: 'a real background session must render');

      await tester.runAsync(() => rig.repository.close());
    });

    testWidgets('an empty workspace renders an honest empty state, never a fabricated session', (tester) async {
      late _Rig rig;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log')]);
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkspaceSwitcherSheet(scheduler: rig.scheduler))));
      await tester.pump();

      expect(find.text('No apps are currently running.'), findsOneWidget);

      await tester.runAsync(() => rig.repository.close());
    });
  });

  group('Foreground switching (R43)', () {
    testWidgets('tapping a background session in the real, pumped Switcher reaches scheduleForeground() for real — the target runtime resumes, the previously-active runtime pauses', (tester) async {
      late _Rig rig;
      late String sessionA;
      late String sessionB;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
        sessionA = await rig.openAndRegister('track my camping trips');
        sessionB = await rig.openAndRegister('track my book club');
      });
      expect(rig.workspace.activeSessionId, sessionA);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkspaceSwitcherSheet(scheduler: rig.scheduler))));
      await tester.pump();

      await tester.tap(find.text('Book Club'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();

      expect(rig.workspace.activeSessionId, sessionB, reason: 'scheduleForeground() must have reached switchActiveExperience() for real');
      expect(rig.supervisor.lookup(sessionB)!.status, RuntimeStatus.running, reason: 'the new active runtime must be resumed');
      expect(rig.supervisor.lookup(sessionA)!.status, RuntimeStatus.paused, reason: 'the now-background runtime must be paused via the Inactive Runtime policy');

      await tester.runAsync(() => rig.repository.close());
    });
  });

  group('Background switching (R43)', () {
    testWidgets('after a foreground switch, a re-rendered Switcher correctly shows the previously-active session as background', (tester) async {
      late _Rig rig;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
        await rig.openAndRegister('track my camping trips');
        await rig.openAndRegister('track my book club');
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkspaceSwitcherSheet(scheduler: rig.scheduler))));
      await tester.pump();
      expect(find.text('Camp Log'), findsOneWidget);

      await tester.tap(find.text('Book Club'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();

      // Re-pump a FRESH sheet instance (the real one closes itself via
      // Navigator.pop after a real switch) reading the scheduler's now
      // real, current state — proving the refresh is a genuine re-read,
      // never a stale, cached list.
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkspaceSwitcherSheet(scheduler: rig.scheduler))));
      await tester.pump();

      final campLogTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Camp Log'));
      expect((campLogTile.subtitle as Text).data, 'Background', reason: 'Camp Log must now render as background after the real switch');

      await tester.runAsync(() => rig.repository.close());
    });
  });

  group('Scheduler integration (R43) — HomeScreen forwards the shared scheduler', () {
    testWidgets('real, end-to-end wiring: HomeScreen forwards its resolved scheduler into ExperienceHostScreen at its real navigation call site, never silently dropping an injected instance', (tester) async {
      late _Rig rig;
      late CreationResult seedResult;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log')], dbName: _defaultDbName);
        seedResult = await rig.creationCoordinator.createFromIntent(Intent.create(expression: 'track my camping trips'));
        await rig.repository.touchLastUsed((seedResult as CreationCreated).experienceId);
      });
      expect(seedResult, isA<CreationCreated>());
      final experienceName = (seedResult as CreationCreated).package.manifest.name;

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HomeScreen(scheduler: rig.scheduler))),
      );
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump();
      }

      final tile = find.widgetWithText(ListTile, experienceName);
      expect(tile, findsOneWidget, reason: 'the seeded Experience must appear in Recent');

      await tester.tap(tile);
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump();
      }

      expect(find.byType(ExperienceHostScreen), findsOneWidget);
      final hostWidget = tester.widget<ExperienceHostScreen>(find.byType(ExperienceHostScreen));
      expect(hostWidget.scheduler, same(rig.scheduler), reason: 'the real navigation call site must forward the SAME resolved scheduler, never a fresh/dropped one');

      await tester.runAsync(() => rig.repository.close());
    });

    testWidgets('tapping the "Running apps" header button opens the real Switcher sheet', (tester) async {
      // A distinctive app name — HomeScreen's own internal `_repository`
      // always points at the real default db name regardless of the
      // injected `workspaceManager`/`scheduler` (this file's own scheduler-
      // integration test above seeds real data into that SAME default db,
      // per its established, documented reality — see
      // test/r36_operating_system_composition_test.dart's own
      // `_defaultDbName` doc comment). A distinct name avoids colliding
      // with HomeScreen's own, unrelated Recent list.
      late _Rig rig;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Solo Runner Xyz')]);
        await rig.openAndRegister('track my solo runs');
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeScreen(scheduler: rig.scheduler, workspaceManager: rig.workspace))));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump();
      }

      await tester.tap(find.byIcon(Icons.apps));
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceSwitcherSheet), findsOneWidget);
      expect(find.text('Solo Runner Xyz'), findsOneWidget);

      await tester.runAsync(() => rig.repository.close());
    });
  });

  group('Regression (R43) — WorkspaceSchedulingEngine/WorkspaceRuntimeSupervisor/WorkspaceLifecyclePolicyEngine unaffected by the Switcher/AppComposition', () {
    test('WorkspaceSchedulingEngine used directly, bypassing the Switcher/AppComposition entirely, still behaves exactly as R42 built it', () async {
      final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
      final sessionA = await rig.openAndRegister('track my camping trips');
      final sessionB = await rig.openAndRegister('track my book club');

      await rig.scheduler.scheduleForeground(sessionB);
      expect(rig.workspace.activeSessionId, sessionB);
      expect(rig.supervisor.lookup(sessionA)!.status, RuntimeStatus.paused);

      await rig.repository.close();
    });
  });

  group('Backward compatibility (R43)', () {
    test('HomeScreen() constructed WITHOUT scheduler defaults it to null (constructor otherwise unchanged)', () {
      const screen = HomeScreen();
      expect(screen.scheduler, isNull);
    });

    testWidgets('a bare HomeScreen() pumped with no injected scheduler renders without throwing — now sourcing its scheduler from AppComposition.production()', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HomeScreen())));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.apps), findsOneWidget);
    });
  });

  group('Performance (R43) — real Stopwatch/ProcessInfo.currentRss measurements, never fabricated', () {
    testWidgets('Switcher rendering latency', (tester) async {
      late _Rig rig;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
        await rig.openAndRegister('track my camping trips');
        await rig.openAndRegister('track my book club');
      });

      final sw = Stopwatch()..start();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkspaceSwitcherSheet(scheduler: rig.scheduler))));
      await tester.pump();
      sw.stop();
      // ignore: avoid_print
      print('R43 WorkspaceSwitcherSheet render: ${sw.elapsedMicroseconds}us');

      await tester.runAsync(() => rig.repository.close());
    });

    test('foreground transition latency through the scheduler (as the Switcher invokes it)', () async {
      final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
      await rig.openAndRegister('track my camping trips');
      final sessionB = await rig.openAndRegister('track my book club');

      final sw = Stopwatch()..start();
      await rig.scheduler.scheduleForeground(sessionB);
      sw.stop();
      // ignore: avoid_print
      print('R43 scheduleForeground() via Switcher path: ${sw.elapsedMicroseconds}us');

      await rig.repository.close();
    });

    test('workspace refresh (foregroundExperience()+backgroundExperiences()) latency', () async {
      final rig = await _Rig.create(List.generate(5, (i) => _app('App $i')));
      for (var i = 0; i < 5; i++) {
        await rig.openAndRegister('track app $i');
      }

      final sw = Stopwatch()..start();
      rig.scheduler.foregroundExperience();
      rig.scheduler.backgroundExperiences();
      sw.stop();
      // ignore: avoid_print
      print('R43 workspace refresh: ${sw.elapsedMicroseconds}us');

      await rig.repository.close();
    });

    test('memory: real process RSS delta across repeated Switcher-driven scheduling cycles', () async {
      final rssBefore = ProcessInfo.currentRss;
      final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
      final sessionA = await rig.openAndRegister('track my camping trips');
      final sessionB = await rig.openAndRegister('track my book club');
      for (var i = 0; i < 10; i++) {
        await rig.scheduler.scheduleForeground(i.isEven ? sessionA : sessionB);
      }
      final rssAfter = ProcessInfo.currentRss;
      // ignore: avoid_print
      print('R43 memory: RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 10 scheduleForeground() cycles');

      await rig.repository.close();
    });
  });
}
